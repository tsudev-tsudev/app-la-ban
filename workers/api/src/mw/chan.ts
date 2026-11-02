import type { MiddlewareHandler } from 'hono';
import { napChan, napChoPhep } from '../threat/nap';
import { rutGonIp } from '../thuan/che-pii';
import { LoiApi } from '../thuan/loi';
import { doBuoc, DUONG_KHONG_KIEM_CHAN } from '../thuan/do-tre';
import { khopQuyTac } from '../thuan/thuc-thi';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from './ghi-log';

/**
 * Route có xác thực (BoTuyen đăng ký, khoá "<METHOD> <đường dẫn>"): kiểm chặn chạy SONG SONG với truy vấn phiên ở
 * mw/xac-thuc.ts (R3c, Q52 - D1 prod ở ICN, mỗi vòng từ SIN ~70 ms). xacThuc chờ kết quả TRƯỚC mọi tác dụng phụ (nonce,
 * sự kiện), BoTuyen chờ lại trước handler - IP bị chặn vẫn nhận 403 như cũ.
 */
export const DUONG_CHAN_SONG_SONG = new Set<string>();

/** Kiểm chặn IP / ASN (đệm isolate 3 s); lỗi D1 -> false (ưu tiên sẵn sàng) + log. */
function kiemChan(c: Ngu, db: D1Database, ip: string): Promise<boolean> {
  const asn = (c.req.raw as { cf?: { asn?: number } }).cf?.asn ?? null;
  return doBuoc(c.get('dongHo'), 'chan', async () => {
    const chan = await napChan(db);
    return chan.length > 0 && !!khopQuyTac(chan, { ip, asn }) && !khopQuyTac(await napChoPhep(db), { ip, asn });
  }).catch((e: unknown) => {
    ghiLog('error', 'chan-loi', { loi: String(e) });
    return false;
  });
}

/** Chờ kết quả kiểm chặn đã hoãn (nếu có) -> 403 bi-chan. */
export async function choKiemChan(c: Ngu): Promise<void> {
  const p = c.get('choChan');
  if (p && (await p)) throw new LoiApi(403, 'bi-chan', { ip: rutGonIp(c.get('ip')) });
}

/**
 * Chặn ở tầng Worker IP / dải / ASN có enforcement còn hiệu lực (trước cả WAF List, có hiệu lực ngay ở isolate ghi và
 * <= 3 s ở isolate khác (DEM_CHAN_MS)). Allow-list thắng. Lỗi D1 -> cho qua (ưu tiên sẵn sàng) + log.
 */
export const chanTheoThucThi: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const db = c.env.DB;
  const ip = c.get('ip');
  // /v1/health không chạm D1 (R3c): IP bị chặn ở prod vẫn bị WAF List chặn trước Worker; health không có dữ liệu.
  if (db && ip && !DUONG_KHONG_KIEM_CHAN.has(c.req.path)) {
    const p = kiemChan(c, db, ip);
    c.set('choChan', p);
    if (!DUONG_CHAN_SONG_SONG.has(`${c.req.method} ${c.req.path}`)) await choKiemChan(c);
  }
  await next();
};
