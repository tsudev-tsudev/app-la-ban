import { asnCua } from './dich-vu';
import type { MiddlewareHandler } from 'hono';
import { xuLySuKien } from '../threat/dong-co';
import { dongBoLists } from '../threat/dong-bo-lists';
import { khopBay, nenBao } from '../thuan/bay';
import { taoUlid } from '../thuan/dinh-danh';
import type { MoiTruongHono } from '../moi-truong';
import { ghiLog } from './ghi-log';
import { traVanDe } from './co-ban';

const daBao = new Map<string, number>();

/**
 * Honeypot (S8): đường dẫn máy quét hay dò (`/.env`, `/wp-login.php`...) -> sự kiện HONEYPOT_HIT theo IP (rule R-006 chặn
 * IP khi lặp lại), phản hồi 404 y như đường dẫn không tồn tại để kẻ quét không phân biệt được bẫy.
 */
export const bayQuet: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const nhan = khopBay(c.req.path);
  if (!nhan) return next();
  c.set('tuyen', 'bay');
  const ip = c.get('ip');
  if (c.env.DB && ip && nenBao(daBao, ip, Date.now())) {
    const viec = xuLySuKien(c.env, { thietBi: null, ip, asn: asnCua(c), country: c.req.header('cf-ipcountry') ?? null }, [
      { id: taoUlid(), type: 'HONEYPOT_HIT', severity: 'high', signals: { bay: nhan, method: c.req.method } },
    ]).then(
      async (kq) => {
        if (kq.canDongBo) await dongBoLists(c.env);
      },
      (e: unknown) => ghiLog('error', 'bay-loi', { loi: String(e) }),
    );
    try {
      c.executionCtx.waitUntil(viec);
    } catch {
      // Ngoài workerd (test đơn vị) không có executionCtx: để promise tự chạy.
    }
  }
  return traVanDe(c, 404);
};
