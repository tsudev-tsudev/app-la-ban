// Quản lý quản trị viên SOC (Super Admin, Spec §8.1): xem, thêm, đổi vai trò, vô hiệu hoá. Cần step-up passkey; không tự
// hạ / khoá chính mình (tránh mất Super Admin cuối cùng); mọi thay đổi vào audit chuỗi băm. Người mới còn phải được thêm
// vào policy Access (tools/cloudflare/access.mjs) mới đăng nhập được - hai lớp độc lập.
import type { Hono } from 'hono';
import { z } from 'zod';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { VAI_TRO } from '../thuan/soc';
import { canQuyen, canStepUp } from './xac-thuc';

const SchemaDat = z.strictObject({
  email: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[^\s@]{1,64}@[^\s@]{1,190}$/),
  vaiTro: z.enum(VAI_TRO),
  voHieu: z.boolean().optional(),
});

type DongQt = { email: string; role: string; disabled_at: number | null };

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

export function dangKyQuanTriVien(r: Hono<MoiTruongHono>): void {
  r.get('/quan-tri-vien', canQuyen('quan-tri-vien'), async (c) => {
    const { results } = await db(c)
      .prepare(
        'SELECT u.email, u.role, u.mfa_enrolled, u.last_login, u.created_at, u.created_by, u.disabled_at, (SELECT COUNT(*) FROM admin_passkeys p WHERE p.email = u.email) AS so_passkey FROM admin_users u ORDER BY u.disabled_at IS NOT NULL, u.email',
      )
      .all();
    return c.json({ ds: results });
  });

  r.post('/quan-tri-vien', canQuyen('quan-tri-vien'), canStepUp, async (c) => {
    if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
    const b = phanTichBody(await c.req.text(), SchemaDat);
    const toi = c.get('quanTri') as { email: string };
    if (b.email === toi.email) throw new LoiApi(409, 'khong-tu-sua');
    const truoc = await db(c).prepare('SELECT email, role, disabled_at FROM admin_users WHERE email = ?').bind(b.email).first<DongQt>();
    const bayGio = Date.now();
    const voHieu = b.voHieu === true ? (truoc?.disabled_at ?? bayGio) : null;
    await db(c)
      .prepare(
        'INSERT INTO admin_users (id, email, role, created_at, created_by, disabled_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT (email) DO UPDATE SET role = excluded.role, disabled_at = excluded.disabled_at',
      )
      .bind(taoUlid(bayGio), b.email, b.vaiTro, bayGio, toi.email, voHieu)
      .run();
    // Vô hiệu hoá -> thu hồi mọi phiên SOC đang mở của người đó ngay.
    if (voHieu !== null) await db(c).prepare('UPDATE admin_sessions SET revoked_at = ? WHERE email = ? AND revoked_at IS NULL').bind(bayGio, b.email).run();
    await ghiAudit(db(c), {
      id: taoUlid(bayGio),
      actor: toi.email,
      action: truoc ? 'quan-tri-vien:sua' : 'quan-tri-vien:them',
      target: `admin:${b.email}`,
      before: truoc ? { vaiTro: truoc.role, voHieu: truoc.disabled_at !== null } : null,
      after: { vaiTro: b.vaiTro, voHieu: voHieu !== null },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true }, truoc ? 200 : 201);
  });
}
