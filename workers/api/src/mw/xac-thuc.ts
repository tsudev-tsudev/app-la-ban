import type { MiddlewareHandler } from 'hono';
import { kiemJwt, napKhoaPhien } from '../attest/khoa';
import { LoiApi } from '../thuan/loi';
import { docBearer } from '../thuan/phien';
import type { MoiTruongHono } from '../moi-truong';

/**
 * Phiên thiết bị (S2, ID-04): JWT ES256 hợp lệ + phiên chưa thu hồi + thiết bị không bị cấm. Đọc D1 MỖI yêu cầu để thu
 * hồi / cấm (SOC, Threat Engine) có hiệu lực ngay, không chờ JWT hết hạn. Đặt thietBi / phien / mucTin + phamViIdem.
 */
export const xacThuc: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const token = docBearer(c.req.header('authorization'));
  if (!token) throw new LoiApi(401, 'can-xac-thuc', undefined, { 'www-authenticate': 'Bearer' });
  if (!c.env.KHOA_PHIEN || !c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: !c.env.KHOA_PHIEN ? 'KHOA_PHIEN' : 'DB' });
  const claim = await kiemJwt(await napKhoaPhien(c.env.KHOA_PHIEN), token, c.env.MOI_TRUONG, Date.now());
  if (!claim) throw new LoiApi(401, 'token-sai', undefined, { 'www-authenticate': 'Bearer error="invalid_token"' });
  const d = await c.env.DB.prepare(
    'SELECT s.revoked_at, d.status, d.attestation_level FROM sessions s JOIN devices d ON d.id = s.device_id WHERE s.id = ? AND s.device_id = ?',
  )
    .bind(claim.sid, claim.sub)
    .first<{ revoked_at: number | null; status: string; attestation_level: string }>();
  if (!d || d.revoked_at !== null) throw new LoiApi(401, 'phien-thu-hoi', undefined, { 'www-authenticate': 'Bearer error="invalid_token"' });
  if (d.status === 'banned') throw new LoiApi(403, 'thiet-bi-bi-cam');
  c.set('thietBi', claim.sub);
  c.set('phien', claim.sid);
  c.set('mucTin', d.attestation_level);
  c.set('phamViIdem', `thiet-bi:${claim.sub}`);
  await next();
};
