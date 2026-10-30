// Passkey + phiên SOC (S6, SEC-ADM): đăng ký passkey, mở phiên / step-up bằng passkey, đăng xuất. Danh tính đã có từ
// Access (middleware danhTinh); passkey là yếu tố thứ hai do chính SOC kiểm (không phụ thuộc IdP).
import type { Hono } from 'hono';
import { z } from 'zod';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { sha256Hex } from '../thuan/bam';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { b64urlTuByte } from '../thuan/ma-hoa';
import { conStepUp, cookiePhien, PHIEN } from '../thuan/soc';
import {
  kiemDangKy,
  kiemXacThuc,
  LoiXacMinh,
  rpIdTuNguon,
  THACH_THUC_HAN_MS,
  tuyChonDangKy,
  tuyChonXacThuc,
  type KhoaCongKhai,
} from '../thuan/webauthn';
import { docPhien, nguonSoc } from './xac-thuc';

const B64 = z.string().regex(/^[A-Za-z0-9_-]{1,8192}$/);
const SchemaBatDau = z.strictObject({});
const SchemaDangKyXong = z.strictObject({
  thachThucId: z.string().regex(/^[0-9A-Z]{26}$/),
  clientDataJSON: B64,
  attestationObject: B64,
  ten: z.string().trim().min(1).max(40).optional(),
});
const SchemaXacThucXong = z.strictObject({
  thachThucId: z.string().regex(/^[0-9A-Z]{26}$/),
  id: B64,
  clientDataJSON: B64,
  authenticatorData: B64,
  signature: B64,
});

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

async function body<T extends z.ZodType>(c: Ngu, schema: T): Promise<z.infer<T>> {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
  return phanTichBody(await c.req.text(), schema, { toiDa: 32 * 1024 });
}

function rpId(c: Ngu): string {
  const rp = rpIdTuNguon(c.req.header('origin'), nguonSoc(c));
  if (!rp) throw new LoiApi(403, 'nguon');
  return rp;
}

function ngauNhien(n: number): string {
  return b64urlTuByte(crypto.getRandomValues(new Uint8Array(n)));
}

async function taoThachThuc(c: Ngu, email: string, kind: 'dang-ky' | 'xac-thuc', rp: string): Promise<{ id: string; challenge: string }> {
  const bayGio = Date.now();
  const id = taoUlid(bayGio);
  const challenge = ngauNhien(32);
  await db(c).batch([
    db(c).prepare('DELETE FROM admin_challenges WHERE expires_at < ?').bind(bayGio),
    db(c)
      .prepare('INSERT INTO admin_challenges (id, email, kind, challenge, rp_id, expires_at) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(id, email, kind, challenge, rp, bayGio + THACH_THUC_HAN_MS),
  ]);
  return { id, challenge };
}

/** Lấy + XOÁ thách thức (dùng một lần); sai chủ / loại / rp / hết hạn -> 400. */
async function layThachThuc(c: Ngu, id: string, email: string, kind: 'dang-ky' | 'xac-thuc', rp: string): Promise<string> {
  const dong = await db(c)
    .prepare('DELETE FROM admin_challenges WHERE id = ? RETURNING email, kind, challenge, rp_id, expires_at')
    .bind(id)
    .first<{ email: string; kind: string; challenge: string; rp_id: string; expires_at: number }>();
  if (!dong || dong.email.toLowerCase() !== email || dong.kind !== kind || dong.rp_id !== rp || dong.expires_at < Date.now()) {
    throw new LoiApi(400, 'thach-thuc');
  }
  return dong.challenge;
}

/** Tạo phiên mới (sau passkey) + đặt cookie. Phiên cũ của trình duyệt này (nếu có) bị thu hồi. */
async function moPhien(c: Ngu, email: string, cuHash: string | null): Promise<number> {
  const bayGio = Date.now();
  const id = ngauNhien(32);
  const het = bayGio + PHIEN.tuyetDoiMs;
  const lenh = [
    db(c)
      .prepare('INSERT INTO admin_sessions (id_hash, email, created_at, last_active, step_up_at, expires_at, ip) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(await sha256Hex(id), email, bayGio, bayGio, bayGio, het, c.get('ip') || null),
    db(c).prepare('UPDATE admin_users SET last_login = ? WHERE email = ?').bind(bayGio, email),
  ];
  if (cuHash) lenh.push(db(c).prepare('UPDATE admin_sessions SET revoked_at = ? WHERE id_hash = ? AND revoked_at IS NULL').bind(bayGio, cuHash));
  await db(c).batch(lenh);
  c.header('set-cookie', cookiePhien(id, PHIEN.tuyetDoiMs / 1000));
  return het;
}

function loiXacMinh(e: unknown): never {
  if (e instanceof LoiXacMinh) throw new LoiApi(400, 'passkey', { ly_do: e.ma });
  throw e;
}

export function dangKyPasskey(r: Hono<MoiTruongHono>): void {
  r.post('/passkey/dang-ky/bat-dau', async (c) => {
    await body(c, SchemaBatDau);
    const { email } = c.get('quanTri') as { email: string };
    const rp = rpId(c);
    const { results: daCo } = await db(c).prepare('SELECT id FROM admin_passkeys WHERE email = ? AND rp_id = ?').bind(email, rp).all<{ id: string }>();
    // Passkey đầu tiên: chỉ cần Access. Thêm passkey: phải đang có phiên + passkey vừa xác thực (chống chiếm phiên Access).
    if (daCo.length > 0) {
      const p = await docPhien(c);
      if (!p || !conStepUp(p.dong, Date.now())) throw new LoiApi(401, 'can-step-up');
    }
    const t = await taoThachThuc(c, email, 'dang-ky', rp);
    const userId = b64urlTuByte(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`la-ban-soc:${email}`))));
    return c.json({ thachThucId: t.id, tuyChon: tuyChonDangKy({ thachThuc: t.challenge, rpId: rp, email, userId, loaiTru: daCo.map((x) => x.id) }) });
  });

  r.post('/passkey/dang-ky/xong', async (c) => {
    const b = await body(c, SchemaDangKyXong);
    const { email } = c.get('quanTri') as { email: string };
    const rp = rpId(c);
    const thachThuc = await layThachThuc(c, b.thachThucId, email, 'dang-ky', rp);
    const kq = await kiemDangKy(b, thachThuc, rp, nguonSoc(c)).catch(loiXacMinh);
    const bayGio = Date.now();
    const dau = await db(c).prepare('SELECT COUNT(*) AS n FROM admin_passkeys WHERE email = ?').bind(email).first<{ n: number }>();
    try {
      await db(c).batch([
        db(c)
          .prepare('INSERT INTO admin_passkeys (id, email, public_key, alg, sign_count, rp_id, name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
          .bind(kq.credentialId, email, JSON.stringify(kq.khoa.jwk), kq.khoa.alg, kq.signCount, rp, b.ten ?? null, bayGio),
        db(c).prepare('UPDATE admin_users SET mfa_enrolled = 1 WHERE email = ?').bind(email),
      ]);
    } catch (e) {
      if (/UNIQUE/i.test(String(e))) throw new LoiApi(409, 'passkey-da-co');
      throw e;
    }
    await ghiAudit(db(c), {
      id: taoUlid(bayGio),
      actor: email,
      action: 'passkey:dang-ky',
      target: `passkey:${kq.credentialId.slice(0, 16)}`,
      before: null,
      after: { alg: kq.khoa.alg, rp, ten: b.ten ?? null },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    // Passkey đầu tiên vừa được xác minh người dùng (UV) -> mở phiên luôn, đỡ chạm sinh trắc lần hai.
    const p = await docPhien(c);
    const het = (dau?.n ?? 0) === 0 && !p ? await moPhien(c, email, null) : null;
    return c.json({ ok: true, phienHet: het }, 201);
  });

  r.post('/phien/bat-dau', async (c) => {
    await body(c, SchemaBatDau);
    const { email } = c.get('quanTri') as { email: string };
    const rp = rpId(c);
    const { results } = await db(c).prepare('SELECT id FROM admin_passkeys WHERE email = ? AND rp_id = ?').bind(email, rp).all<{ id: string }>();
    if (results.length === 0) throw new LoiApi(409, 'chua-co-passkey');
    const t = await taoThachThuc(c, email, 'xac-thuc', rp);
    return c.json({ thachThucId: t.id, tuyChon: tuyChonXacThuc({ thachThuc: t.challenge, rpId: rp, choPhep: results.map((x) => x.id) }) });
  });

  // Dùng cho cả đăng nhập (chưa có phiên) lẫn step-up (đang có phiên -> chỉ làm mới step_up_at).
  r.post('/phien/xong', async (c) => {
    const b = await body(c, SchemaXacThucXong);
    const { email } = c.get('quanTri') as { email: string };
    const rp = rpId(c);
    const thachThuc = await layThachThuc(c, b.thachThucId, email, 'xac-thuc', rp);
    const pk = await db(c)
      .prepare('SELECT public_key, alg, sign_count FROM admin_passkeys WHERE id = ? AND email = ? AND rp_id = ?')
      .bind(b.id, email, rp)
      .first<{ public_key: string; alg: number; sign_count: number }>();
    if (!pk) throw new LoiApi(400, 'passkey', { ly_do: 'khong-thay' });
    const khoa = { alg: pk.alg, jwk: JSON.parse(pk.public_key) as JsonWebKey } as KhoaCongKhai;
    const { signCount } = await kiemXacThuc(b, khoa, pk.sign_count, thachThuc, rp, nguonSoc(c)).catch(loiXacMinh);
    const bayGio = Date.now();
    await db(c).prepare('UPDATE admin_passkeys SET sign_count = ?, last_used = ? WHERE id = ?').bind(signCount, bayGio, b.id).run();
    const dangCo = await docPhien(c);
    let het: number;
    if (dangCo) {
      await db(c).prepare('UPDATE admin_sessions SET step_up_at = ?, last_active = ? WHERE id_hash = ?').bind(bayGio, bayGio, dangCo.idHash).run();
      het = dangCo.dong.expires_at;
    } else {
      het = await moPhien(c, email, null);
    }
    await ghiAudit(db(c), {
      id: taoUlid(bayGio),
      actor: email,
      action: dangCo ? 'phien:step-up' : 'phien:dang-nhap',
      target: `passkey:${b.id.slice(0, 16)}`,
      before: null,
      after: null,
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, phienHet: het });
  });

  r.post('/phien/ket-thuc', async (c) => {
    await body(c, SchemaBatDau);
    const { email } = c.get('quanTri') as { email: string };
    const p = await docPhien(c);
    const bayGio = Date.now();
    if (p) {
      await db(c).prepare('UPDATE admin_sessions SET revoked_at = ? WHERE id_hash = ?').bind(bayGio, p.idHash).run();
      await ghiAudit(db(c), { id: taoUlid(bayGio), actor: email, action: 'phien:dang-xuat', target: null, before: null, after: null, ip: c.get('ip') || null, ts: bayGio });
    }
    c.header('set-cookie', cookiePhien('', 0));
    return c.json({ ok: true });
  });
}
