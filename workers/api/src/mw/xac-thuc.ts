import type { MiddlewareHandler } from 'hono';
import { kiemChuKyThietBi, kiemJwt, napKhoaPhien, nhapKhoaThietBi } from '../attest/khoa';
import { nenBao } from '../thuan/bay';
import { sha256HexByte } from '../thuan/bam';
import {
  chuoiYeuCau,
  docTieuDeKy,
  kiemTruocKy,
  NONCE_YEU_CAU_TTL_MS,
  THAN_KY_TOI_DA,
} from '../thuan/ky-yeu-cau';
import { LoiApi } from '../thuan/loi';
import { docBearer, LECH_TS_MS } from '../thuan/phien';
import type { MoiTruongHono } from '../moi-truong';
import { baoSuKien, goiNonce } from './dich-vu';

const TOKEN_SAI = { 'www-authenticate': 'Bearer error="invalid_token"' };
/** SIGNATURE_MISMATCH tối đa 1 lần / thiết bị / phút / isolate - kẻ cầm JWT nhưng không có khoá không làm ngập D1. */
const daBaoKy = new Map<string, number>();

/**
 * Phiên thiết bị (S2, ID-04) + chữ ký request (S3, SEC-NET). Thứ tự: JWT ES256 hợp lệ -> phiên chưa thu hồi + thiết bị
 * không bị cấm (đọc D1 MỖI yêu cầu để thu hồi / cấm có hiệu lực ngay) -> header ký đủ + ts lệch <= 60 s -> khoá thiết bị
 * đang lưu khớp `cnf.jkt` của JWT -> chữ ký đúng trên chuỗi chuẩn -> nonce chưa dùng (DO KhoNonce, 5 phút). Nonce kiểm
 * SAU chữ ký để kẻ không có khoá không đốt được nonce của thiết bị. Đặt thietBi / phien / mucTin / trangThai + phamViIdem.
 * [choPhepBiCam]: chỉ /v1/status - thiết bị bị cấm vẫn đọc được trạng thái + mã REF để hiện màn khoá / khiếu nại.
 */
export function taoXacThuc(o: { choPhepBiCam?: boolean } = {}): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    const token = docBearer(c.req.header('authorization'));
    if (!token) throw new LoiApi(401, 'can-xac-thuc', undefined, { 'www-authenticate': 'Bearer' });
    if (!c.env.KHOA_PHIEN || !c.env.DB)
      throw new LoiApi(503, 'chua-cau-hinh', { thieu: !c.env.KHOA_PHIEN ? 'KHOA_PHIEN' : 'DB' });
    const bayGio = Date.now();
    const claim = await kiemJwt(await napKhoaPhien(c.env.KHOA_PHIEN), token, c.env.MOI_TRUONG, bayGio);
    if (!claim) throw new LoiApi(401, 'token-sai', undefined, TOKEN_SAI);
    const d = await c.env.DB.prepare(
      'SELECT s.revoked_at, d.status, d.attestation_level, d.public_key FROM sessions s JOIN devices d ON d.id = s.device_id WHERE s.id = ? AND s.device_id = ?',
    )
      .bind(claim.sid, claim.sub)
      .first<{
        revoked_at: number | null;
        status: string;
        attestation_level: string;
        public_key: string | null;
      }>();
    if (!d || d.revoked_at !== null) throw new LoiApi(401, 'phien-thu-hoi', undefined, TOKEN_SAI);
    if (d.status === 'banned' && !o.choPhepBiCam) throw new LoiApi(403, 'thiet-bi-bi-cam');

    const tieuDe = docTieuDeKy((ten) => c.req.header(ten));
    if (!tieuDe) throw new LoiApi(401, 'can-chu-ky');
    const truoc = kiemTruocKy(tieuDe, claim.sub, bayGio, LECH_TS_MS);
    // Lệch giờ: trả giờ server để app tự hiệu chỉnh đồng hồ rồi ký lại (không phải lỗi bảo mật).
    if (truoc)
      throw new LoiApi(
        401,
        truoc,
        undefined,
        truoc === 'lech-gio' ? { 'x-server-time': String(bayGio) } : {},
      );
    const khoa = d.public_key ? await nhapKhoaThietBi(d.public_key) : null;
    // Khoá đổi (đăng ký lại) mà JWT cũ còn hạn: token không còn gắn với khoá đang lưu.
    if (!khoa || khoa.jkt !== claim.cnf.jkt)
      throw new LoiApi(401, 'phien-thu-hoi', { ly_do: 'jkt' }, TOKEN_SAI);
    if (Number(c.req.header('content-length') ?? '0') > THAN_KY_TOI_DA) throw new LoiApi(413, 'qua-lon');
    const than =
      c.req.method === 'GET' || c.req.method === 'HEAD'
        ? new Uint8Array(0)
        : new Uint8Array(await c.req.arrayBuffer());
    if (than.length > THAN_KY_TOI_DA) throw new LoiApi(413, 'qua-lon');
    const url = new URL(c.req.url);
    const chuoi = chuoiYeuCau({
      phuongThuc: c.req.method,
      duongDan: url.pathname,
      query: url.search.slice(1),
      bamThan: await sha256HexByte(than),
      ts: tieuDe.ts,
      nonce: tieuDe.nonce,
    });
    if (!(await kiemChuKyThietBi(khoa.khoa, chuoi, tieuDe.chuKy))) {
      if (nenBao(daBaoKy, claim.sub, bayGio, 60_000))
        baoSuKien(c, claim.sub, 'SIGNATURE_MISMATCH', 'medium', {
          buoc: 'yeu-cau',
          tuyen: c.get('tuyen') ?? null,
        });
      throw new LoiApi(401, 'chu-ky');
    }
    if (
      !(await goiNonce(c.env, `thiet-bi:${claim.sub}`, '/nonce', {
        nonce: tieuDe.nonce,
        ttlMs: NONCE_YEU_CAU_TTL_MS,
      }))
    ) {
      c.env.SU_KIEN?.writeDataPoint({
        indexes: ['phat-lai'],
        blobs: ['phat-lai', c.get('tuyen') ?? ''],
        doubles: [1],
      });
      throw new LoiApi(401, 'nonce');
    }
    c.set('thietBi', claim.sub);
    c.set('phien', claim.sid);
    c.set('mucTin', d.attestation_level);
    c.set('trangThai', d.status);
    c.set('phamViIdem', `thiet-bi:${claim.sub}`);
    await next();
  };
}

export const xacThuc = taoXacThuc();
