import type { MiddlewareHandler } from 'hono';
import { rutGonIp } from '../thuan/che-pii';
import { khoaGioiHan, type LuatGioiHan } from '../thuan/gioi-han';
import { LoiApi } from '../thuan/loi';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from './ghi-log';

/** Lớp thô: Rate Limiting binding theo IP cho MỌI route (thiếu binding -> bỏ qua, ghi log một lần mỗi isolate). */
let daBaoThieuRl = false;
export const gioiHanThoIp: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const rl = c.env.RL_IP;
  if (!rl) {
    if (!daBaoThieuRl && c.env.MOI_TRUONG !== 'test') ghiLog('warn', 'thieu-binding-RL_IP');
    daBaoThieuRl = true;
  } else if (c.get('ip')) {
    const { success } = await rl.limit({ key: c.get('ip') });
    if (!success) throw new LoiApi(429, 'qua-nhieu-yeu-cau', { lop: 'RL_IP' }, { 'retry-after': '60' });
  }
  await next();
};

/** Giá trị của một chiều cho yêu cầu hiện tại (null = không áp dụng, vd. chưa có phiên). */
function giaTriChieu(c: Ngu, chieu: LuatGioiHan['chieu']): string | null {
  switch (chieu) {
    case 'ip':
      return c.get('ip') || null;
    case 'endpoint':
      return 'tat-ca';
    // Thiết bị / phiên chỉ có sau xác thực (S2) - middleware xác thực đặt phamViIdem = 'thiet-bi:<id>' / 'phien:<id>'.
    case 'thiet-bi':
    case 'phien': {
      const p = c.get('phamViIdem');
      return p?.startsWith(`${chieu}:`) ? p.slice(chieu.length + 1) : null;
    }
  }
}

/**
 * Giới hạn nhiều chiều chính xác bằng DO GioiHanToc cho route nhạy cảm. Vượt bất kỳ chiều nào -> 429 + Retry-After.
 * Lỗi DO -> cho qua (ưu tiên sẵn sàng; lớp RL_IP + WAF vẫn chặn lũ) và ghi log.
 */
export function gioiHanRoute(dsLuat: LuatGioiHan[]): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    const ns = c.env.GIOI_HAN_TOC;
    if (ns && dsLuat.length) {
      const kq = await Promise.all(
        dsLuat.map(async (l) => {
          const gt = giaTriChieu(c, l.chieu);
          if (gt === null) return null;
          const khoa = khoaGioiHan(l.chieu, gt, `${c.req.method} ${c.get('tuyen') ?? c.req.path}`);
          try {
            const res = await ns.get(ns.idFromName(khoa)).fetch('https://do/gioi-han', {
              method: 'POST',
              body: JSON.stringify({ khoa, gioiHan: l.gioiHan, cuaSoMs: l.cuaSoMs }),
            });
            return res.ok ? ((await res.json()) as { choPhep: boolean; thuLaiSau: number }) : null;
          } catch (e) {
            ghiLog('error', 'gioi-han-do-loi', { chieu: l.chieu, loi: String(e) });
            return null;
          }
        }),
      );
      const bi = kq.filter((k) => k && !k.choPhep);
      if (bi.length) {
        const cho = Math.max(...bi.map((k) => k?.thuLaiSau ?? 1));
        throw new LoiApi(429, 'qua-nhieu-yeu-cau', { ip: rutGonIp(c.get('ip')) }, { 'retry-after': String(cho) });
      }
    }
    await next();
  };
}
