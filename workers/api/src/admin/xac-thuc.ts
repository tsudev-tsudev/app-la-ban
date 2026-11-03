// Chuỗi xác thực Admin SOC (S6, SEC-ADM): Access JWT (danh tính) -> vai trò D1 -> phiên passkey (MFA) -> quyền.
// Mọi lớp kiểm ở Worker; giao diện chỉ ẩn / hiện theo `/admin/v1/toi`, không phải ranh giới bảo mật.
import type { MiddlewareHandler } from 'hono';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { kidCua, kiemJwtAccess, LoiJwtAccess, tachDs } from '../thuan/access-jwt';
import { sha256Hex } from '../thuan/bam';
import { CUA_SO_KHOA_ADMIN_MS } from '../thuan/khien-web';
import { LoiApi } from '../thuan/loi';
import { canGhiHoatDong, coQuyen, conStepUp, docCookie, laVaiTro, PHIEN, tinhTrangPhien, type DongPhien, type Quyen } from '../thuan/soc';

const JWKS_HAN_MS = 10 * 60_000;
const JWKS_NAP_LAI_TOI_THIEU_MS = 30_000;
let boNhoJwks: { team: string; khoa: JsonWebKey[]; het: number; napLuc: number } | null = null;

/** JWKS của team: giữ 10 phút; gặp kid lạ (Access xoay khoá) thì nạp lại ngay, nhưng không quá mỗi 30 giây một lần. */
async function napJwks(team: string, epNap: boolean): Promise<JsonWebKey[]> {
  const bayGio = Date.now();
  const bn = boNhoJwks?.team === team ? boNhoJwks : null;
  if (bn && (epNap ? bayGio - bn.napLuc < JWKS_NAP_LAI_TOI_THIEU_MS : bayGio < bn.het)) return bn.khoa;
  const res = await fetch(`https://${team}/cdn-cgi/access/certs`, { cf: { cacheTtl: 300 } } as RequestInit);
  if (!res.ok) throw new LoiApi(503, 'access-khong-san-sang', { jwks: res.status });
  const j = (await res.json()) as { keys?: JsonWebKey[] };
  const khoa = Array.isArray(j.keys) ? j.keys : [];
  boNhoJwks = { team, khoa, het: bayGio + JWKS_HAN_MS, napLuc: bayGio };
  return khoa;
}

/** Chỉ dùng trong test: xoá bộ nhớ JWKS giữa các ca. */
export function xoaBoNhoJwks(): void {
  boNhoJwks = null;
}

function dbCua(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

export function nguonSoc(c: Ngu): string[] {
  return tachDs(c.env.SOC_NGUON);
}

/** Lớp 1 + 2: JWT Access hợp lệ và email có vai trò (chưa vô hiệu). Không có vai trò -> 403. */
export const danhTinh: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const team = c.env.ACCESS_TEAM;
  const aud = tachDs(c.env.ACCESS_AUD);
  if (!team || aud.length === 0) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'ACCESS_TEAM/ACCESS_AUD' });
  const token = c.req.header('cf-access-jwt-assertion');
  const kid = token ? kidCua(token) : null;
  let khoa = await napJwks(team, false);
  if (kid && !khoa.some((k) => (k as { kid?: string }).kid === kid)) khoa = await napJwks(team, true);
  let email: string;
  try {
    const dt = await kiemJwtAccess(token, khoa, { team, aud, bayGioGiay: Math.floor(Date.now() / 1000) });
    if (dt.email) email = dt.email;
    else if (dt.dichVu && tachDs(c.env.ACCESS_DICH_VU).includes(dt.dichVu)) email = `svc:${dt.dichVu}`;
    else throw new LoiJwtAccess('danh-tinh');
  } catch (e) {
    if (e instanceof LoiJwtAccess) throw new LoiApi(401, 'access', { ly_do: e.ma });
    throw e;
  }
  const nd = await dbCua(c)
    .prepare('SELECT role FROM admin_users WHERE email = ? AND disabled_at IS NULL')
    .bind(email)
    .first<{ role: string }>();
  if (!nd || !laVaiTro(nd.role)) throw new LoiApi(403, 'khong-co-vai-tro', { email });
  // S11 (Q58): khiên trang admin vừa báo DevTools / debugger / tự động hoá từ IP này -> không trả dữ liệu trong 10 phút
  // (dữ liệu thật không xuống trình duyệt đang bị soi - SH-07). Giao diện hiện màn chặn của khiên.
  const ip = c.get('ip');
  if (ip) {
    const vuaBao = await dbCua(c)
      .prepare(
        "SELECT 1 AS c FROM security_events WHERE ip = ? AND ts > ? AND type = 'WEB_DEVTOOLS' AND json_extract(signals, '$.trang') = 'admin' LIMIT 1",
      )
      .bind(ip, Date.now() - CUA_SO_KHOA_ADMIN_MS)
      .first();
    if (vuaBao) throw new LoiApi(403, 'khien-devtools', undefined, { 'retry-after': String(CUA_SO_KHOA_ADMIN_MS / 1000) });
  }
  c.set('quanTri', { email, vaiTro: nd.role });
  c.set('phamViIdem', `soc:${email}`);
  await next();
  c.header('cache-control', 'no-store');
};

/** Đọc phiên từ cookie; trả null nếu không có / không hợp lệ (không ném - /toi cần biết trạng thái). */
export async function docPhien(c: Ngu): Promise<{ idHash: string; dong: DongPhien } | null> {
  const id = docCookie(c.req.header('cookie'), PHIEN.cookie);
  const qt = c.get('quanTri');
  if (!id || !qt) return null;
  const idHash = await sha256Hex(id);
  const dong = await dbCua(c)
    .prepare('SELECT email, created_at, last_active, step_up_at, expires_at, revoked_at FROM admin_sessions WHERE id_hash = ?')
    .bind(idHash)
    .first<DongPhien>();
  if (!dong || tinhTrangPhien(dong, qt.email, Date.now()) !== 'hop-le') return null;
  return { idHash, dong };
}

/**
 * Lớp 3: phiên passkey còn hạn (nhàn rỗi 15 phút, tuyệt đối 8 giờ). Request nền (`x-soc-nen: 1` - làm mới số liệu tự
 * động) KHÔNG gia hạn nhàn rỗi: người bỏ máy đi vẫn bị khoá dù màn hình còn tự cập nhật.
 */
export const canPhien: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const p = await docPhien(c);
  if (!p) throw new LoiApi(401, 'can-phien');
  const bayGio = Date.now();
  if (c.req.header('x-soc-nen') !== '1' && canGhiHoatDong(p.dong, bayGio)) {
    await dbCua(c).prepare('UPDATE admin_sessions SET last_active = ? WHERE id_hash = ?').bind(bayGio, p.idHash).run();
  }
  c.set('phienSoc', { idHash: p.idHash, stepUpAt: p.dong.step_up_at, expiresAt: p.dong.expires_at });
  await next();
};

export function canQuyen(q: Quyen): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    const qt = c.get('quanTri');
    if (!qt || !coQuyen(qt.vaiTro, q)) throw new LoiApi(403, 'thieu-quyen', { quyen: q });
    await next();
  };
}

/** Thao tác nhạy cảm: passkey trong 5 phút gần nhất, không thì 401 `can-step-up` (giao diện hỏi passkey rồi gửi lại). */
export const canStepUp: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const p = c.get('phienSoc');
  if (!p || !conStepUp({ step_up_at: p.stepUpAt }, Date.now())) throw new LoiApi(401, 'can-step-up');
  await next();
};

/**
 * Chống CSRF cho mọi request ghi + nâng cấp WebSocket: Origin đúng giao diện SOC, Sec-Fetch-Site same-origin (nếu trình
 * duyệt gửi), header tự đặt `x-soc: 1` (form / thẻ img của trang khác không đặt được). Cookie còn SameSite=Strict.
 */
export const chongCsrf: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const ghi = c.req.method !== 'GET' && c.req.method !== 'HEAD';
  const ws = c.req.header('upgrade')?.toLowerCase() === 'websocket';
  if (ghi || ws) {
    const origin = c.req.header('origin');
    if (!origin || !nguonSoc(c).includes(origin)) throw new LoiApi(403, 'nguon');
    const site = c.req.header('sec-fetch-site');
    if (site && site !== 'same-origin') throw new LoiApi(403, 'nguon');
    if (ghi && c.req.header('x-soc') !== '1') throw new LoiApi(403, 'nguon');
  }
  await next();
};
