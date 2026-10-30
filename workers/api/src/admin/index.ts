// Admin API (S6, SEC-ADM) gắn tại /admin/v1 của la-ban-api. Giao diện compass-admin gọi qua service binding của Pages
// (cùng origin, không CORS). Route này cũng tới được từ compass-api công khai nhưng không có JWT Access hợp lệ thì 401.
import { Hono } from 'hono';
import type { MoiTruongHono } from '../moi-truong';
import { gioiHanRoute } from '../mw/gioi-han';
import { dsQuyen, type VaiTro } from '../thuan/soc';
import { dangKyDuLieu } from './du-lieu';
import { dangKyPasskey } from './passkey';
import { dangKyQuanTriVien } from './quan-tri-vien';
import { canPhien, chongCsrf, danhTinh, docPhien } from './xac-thuc';

const KHONG_CAN_PHIEN = /^\/admin\/v1\/(toi|passkey\/dang-ky\/(bat-dau|xong)|phien\/(bat-dau|xong|ket-thuc))$/;

export function taoAdmin(): Hono<MoiTruongHono> {
  const r = new Hono<MoiTruongHono>();
  r.use('*', async (c, next) => {
    c.set('tuyen', c.req.path.replace(/\/thiet-bi\/[^/]+$/, '/thiet-bi/:id').slice(0, 64));
    await next();
  });
  r.use('*', gioiHanRoute([{ chieu: 'ip', gioiHan: 300, cuaSoMs: 60_000 }]));
  r.use('*', chongCsrf);
  r.use('*', danhTinh);
  // Mặc định CẦN phiên passkey; chỉ /toi + luồng passkey / phiên được miễn (route mới tự động được bảo vệ).
  r.use('*', async (c, next) => (KHONG_CAN_PHIEN.test(c.req.path) ? next() : canPhien(c, next)));

  // Trạng thái đăng nhập cho giao diện: chỉ cần Access + vai trò (chưa cần phiên passkey).
  r.get('/toi', async (c) => {
    const qt = c.get('quanTri') as { email: string; vaiTro: VaiTro };
    const db = c.env.DB as D1Database;
    const pk = await db.prepare('SELECT COUNT(*) AS n FROM admin_passkeys WHERE email = ?').bind(qt.email).first<{ n: number }>();
    const p = await docPhien(c);
    return c.json({
      email: qt.email,
      vaiTro: qt.vaiTro,
      quyen: dsQuyen(qt.vaiTro),
      soPasskey: pk?.n ?? 0,
      phien: p ? { het: p.dong.expires_at, stepUpLuc: p.dong.step_up_at, hoatDongLuc: p.dong.last_active } : null,
    });
  });

  dangKyPasskey(r);
  dangKyDuLieu(r);
  dangKyQuanTriVien(r);
  return r;
}
