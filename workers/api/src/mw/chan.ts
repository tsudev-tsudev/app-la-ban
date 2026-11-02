import type { MiddlewareHandler } from 'hono';
import { napChan, napChoPhep } from '../threat/nap';
import { rutGonIp } from '../thuan/che-pii';
import { LoiApi } from '../thuan/loi';
import { doBuoc, DUONG_KHONG_KIEM_CHAN } from '../thuan/do-tre';
import { khopQuyTac } from '../thuan/thuc-thi';
import type { MoiTruongHono } from '../moi-truong';
import { ghiLog } from './ghi-log';

/**
 * Chặn ở tầng Worker IP / dải / ASN có enforcement còn hiệu lực (trước cả WAF List, có hiệu lực ngay ở isolate ghi và
 * <= 3 s ở isolate khác (DEM_CHAN_MS)). Allow-list thắng. Lỗi D1 -> cho qua (ưu tiên sẵn sàng) + log.
 */
export const chanTheoThucThi: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const db = c.env.DB;
  const ip = c.get('ip');
  // /v1/health không chạm D1 (R3c): IP bị chặn ở prod vẫn bị WAF List chặn trước Worker; health không có dữ liệu.
  if (db && ip && !DUONG_KHONG_KIEM_CHAN.has(c.req.path)) {
    const asn = (c.req.raw as { cf?: { asn?: number } }).cf?.asn ?? null;
    let bi = false;
    try {
      bi = await doBuoc(c.get('dongHo'), 'chan', async () => {
        const chan = await napChan(db);
        return chan.length > 0 && !!khopQuyTac(chan, { ip, asn }) && !khopQuyTac(await napChoPhep(db), { ip, asn });
      });
    } catch (e) {
      ghiLog('error', 'chan-loi', { loi: String(e) });
    }
    if (bi) throw new LoiApi(403, 'bi-chan', { ip: rutGonIp(ip) });
  }
  await next();
};
