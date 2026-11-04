// Sao lưu D1 hằng ngày (S10a, MON-03). Mã hoá LAI: khoá AES-256-GCM ngẫu nhiên mỗi bản, bọc bằng RSA-OAEP-SHA256 với khoá
// CÔNG KHAI (biến môi trường) -> Worker ghi được nhưng KHÔNG đọc lại được bản sao lưu; khoá riêng chỉ ở máy người giữ
// (~/.config/la-ban/sao-luu/, ngoài repo). Tiêu đề (JSON) là AAD của GCM: sửa số dòng / bảng trong tiêu đề -> giải mã hỏng.
// Định dạng tệp: "LBSL1" | độ dài tiêu đề (uint32 BE) | tiêu đề UTF-8 | bản mã (gzip(ndjson) + thẻ GCM 16 byte).
// Hàm thuần dùng WebCrypto - chạy được trong Worker lẫn Node (công cụ khôi phục tools/sao-luu/).
import { jsonChuan, sha256Hex } from './bam';

/** Bảng được sao lưu, cha trước con (khoá ngoại). Bỏ dữ liệu phiên tạm (sessions, idempotency, challenge, admin_sessions). */
export const BANG_SAO_LUU = [
  'devices',
  'device_ips',
  'device_links',
  'security_events',
  'rules',
  'rule_versions',
  'threat_config',
  'enforcements',
  'appeals',
  'allow_list',
  'alerts',
  'alert_notes',
  'rule_hits',
  'admin_users',
  'admin_passkeys',
  'audit_logs',
  'approval_requests',
  'soc_settings',
  'config_requests',
  'config_versions',
  'app_crashes',
  // M1a (Q55): quyền lợi Pro - cha trước con (khôi phục theo thứ tự này).
  'quyen_loi',
  'quyen_loi_devices',
  'quyen_loi_events',
  'quyen_loi_requests',
] as const;
export type BangSaoLuu = (typeof BANG_SAO_LUU)[number];

/** Bảng có trigger chặn xoá: không DELETE trước khi nạp (CSDL khôi phục mới tạo - bảng trống). */
const BANG_CHI_THEM = new Set<string>(['audit_logs']);

export const MA_TEP = 'LBSL1';
export const TIEN_TO_SAO_LUU = 'sao-luu/';
export const LO_SAO_LUU = 1000;

export type TieuDe = {
  v: 1;
  moiTruong: string;
  tao: number;
  /** Định danh khoá công khai: 16 hex đầu SHA-256 của SPKI - chọn đúng khoá riêng khi đã xoay. */
  kid: string;
  khoa: string;
  iv: string;
  /** SHA-256 của ndjson gốc (trước nén) - kiểm sau giải mã. */
  bam: string;
  bang: Record<string, number>;
};

export function khoaSaoLuu(bayGio: number): string {
  return `${TIEN_TO_SAO_LUU}${new Date(bayGio).toISOString().slice(0, 10)}.lbsl`;
}

function b64(b: ArrayBuffer | Uint8Array): string {
  let s = '';
  for (const x of b instanceof Uint8Array ? b : new Uint8Array(b)) s += String.fromCharCode(x);
  return btoa(s);
}

function tuB64(s: string): Uint8Array<ArrayBuffer> {
  const n = atob(s);
  const b = new Uint8Array(n.length);
  for (let i = 0; i < n.length; i++) b[i] = n.charCodeAt(i);
  return b;
}

/** PEM hoặc base64 SPKI -> byte. */
export function spkiTu(chuoi: string): Uint8Array<ArrayBuffer> {
  return tuB64(chuoi.replace(/-----[^-]+-----/g, '').replace(/\s+/g, ''));
}

export async function kidCua(spki: Uint8Array<ArrayBuffer>): Promise<string> {
  const so = await crypto.subtle.digest('SHA-256', spki);
  return [...new Uint8Array(so)].slice(0, 8).map((x) => x.toString(16).padStart(2, '0')).join('');
}

const RSA = { name: 'RSA-OAEP', hash: 'SHA-256' } as const;

/** Một dòng ndjson cho mỗi bản ghi: {"t": bảng, "r": bản ghi}. */
export function dongNdjson(bang: string, banGhi: Record<string, unknown>): string {
  return `${jsonChuan({ r: banGhi, t: bang })}\n`;
}

/** Đóng gói: [nen] = gzip(ndjson) (Worker: CompressionStream; Node: zlib) - tách ra để hàm thuần không phụ thuộc luồng. */
export async function dongGoi(
  ndjson: string,
  nen: Uint8Array<ArrayBuffer>,
  dem: Record<string, number>,
  khoaCongKhai: string,
  moiTruong: string,
  bayGio: number,
): Promise<Uint8Array<ArrayBuffer>> {
  const spki = spkiTu(khoaCongKhai);
  const rsa = await crypto.subtle.importKey('spki', spki, RSA, false, ['encrypt']);
  const khoaThuan = crypto.getRandomValues(new Uint8Array(32));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const boc = await crypto.subtle.encrypt(RSA, rsa, khoaThuan);
  const tieuDe: TieuDe = {
    v: 1,
    moiTruong,
    tao: bayGio,
    kid: await kidCua(spki),
    khoa: b64(boc),
    iv: b64(iv),
    bam: await sha256Hex(ndjson),
    bang: dem,
  };
  const tdByte = new TextEncoder().encode(jsonChuan(tieuDe));
  const aes = await crypto.subtle.importKey('raw', khoaThuan, 'AES-GCM', false, ['encrypt']);
  const ma = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: tdByte }, aes, nen));
  const ra = new Uint8Array(MA_TEP.length + 4 + tdByte.length + ma.length);
  ra.set(new TextEncoder().encode(MA_TEP), 0);
  new DataView(ra.buffer).setUint32(MA_TEP.length, tdByte.length);
  ra.set(tdByte, MA_TEP.length + 4);
  ra.set(ma, MA_TEP.length + 4 + tdByte.length);
  return ra;
}

/** Tách tiêu đề (đọc được không cần khoá riêng - để kiểm kê / chọn khoá). Sai định dạng -> ném lỗi. */
export function docTieuDe(tep: Uint8Array): { tieuDe: TieuDe; tdByte: Uint8Array<ArrayBuffer>; ma: Uint8Array<ArrayBuffer> } {
  if (new TextDecoder().decode(tep.subarray(0, MA_TEP.length)) !== MA_TEP) throw new Error('khong-phai-tep-sao-luu');
  const n = new DataView(tep.buffer, tep.byteOffset, tep.byteLength).getUint32(MA_TEP.length);
  const dau = MA_TEP.length + 4;
  if (dau + n > tep.length) throw new Error('tieu-de-cut');
  const tdByte = tep.slice(dau, dau + n);
  const tieuDe = JSON.parse(new TextDecoder().decode(tdByte)) as TieuDe;
  if (tieuDe.v !== 1) throw new Error('phien-ban-la');
  return { tieuDe, tdByte, ma: tep.slice(dau + n) };
}

/** Giải mã bằng khoá riêng PKCS8 -> gzip(ndjson). Kiểm băm ndjson là việc của bên gọi sau khi giải nén. */
export async function moGoi(tep: Uint8Array, khoaRiengPkcs8: Uint8Array<ArrayBuffer>): Promise<{ tieuDe: TieuDe; nen: Uint8Array<ArrayBuffer> }> {
  const { tieuDe, tdByte, ma } = docTieuDe(tep);
  const rsa = await crypto.subtle.importKey('pkcs8', khoaRiengPkcs8, RSA, false, ['decrypt']);
  const khoaThuan = await crypto.subtle.decrypt(RSA, rsa, tuB64(tieuDe.khoa));
  const aes = await crypto.subtle.importKey('raw', khoaThuan, 'AES-GCM', false, ['decrypt']);
  const nen = new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: tuB64(tieuDe.iv), additionalData: tdByte }, aes, ma));
  return { tieuDe, nen };
}

function giaTriSql(v: unknown): string {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : 'NULL';
  if (typeof v === 'boolean') return v ? '1' : '0';
  return `'${String(v).replace(/'/g, "''")}'`;
}

const TEN_COT = /^[a-z_][a-z0-9_]*$/;

/**
 * ndjson đã giải mã -> SQL nạp vào CSDL mới (đã chạy migrations): xoá dữ liệu hạt giống của bảng có trong bản sao lưu rồi
 * INSERT theo đúng thứ tự gốc (giữ thứ tự rowid của chuỗi audit). Chỉ nhận bảng / cột hợp lệ - tệp hỏng không chèn được SQL lạ.
 */
export function sqlKhoiPhuc(ndjson: string): { sql: string; dem: Record<string, number> } {
  const dem: Record<string, number> = {};
  const chen: string[] = [];
  const hopLe = new Set<string>(BANG_SAO_LUU);
  for (const dong of ndjson.split('\n')) {
    if (!dong) continue;
    const { t, r } = JSON.parse(dong) as { t: string; r: Record<string, unknown> };
    if (!hopLe.has(t)) throw new Error(`bang-la:${t}`);
    const cot = Object.keys(r);
    if (!cot.length || !cot.every((c) => TEN_COT.test(c))) throw new Error(`cot-la:${t}`);
    chen.push(`INSERT INTO ${t} (${cot.map((c) => `"${c}"`).join(', ')}) VALUES (${cot.map((c) => giaTriSql(r[c])).join(', ')});`);
    dem[t] = (dem[t] ?? 0) + 1;
  }
  const xoa = BANG_SAO_LUU.filter((b) => dem[b] && !BANG_CHI_THEM.has(b))
    .reverse()
    .map((b) => `DELETE FROM ${b};`);
  return { sql: ['PRAGMA defer_foreign_keys = true;', ...xoa, ...chen, ''].join('\n'), dem };
}

/**
 * Cửa sổ sao lưu 19:30-19:59 UTC (02:30 giờ VN, sau lượt dọn 19:15): cron 5 phút gọi tới 6 lần, lần đầu ghi, các lần sau
 * thấy bản trong ngày đã có thì bỏ -> tự thử lại khi lần đầu lỗi.
 */
export function laLuotSaoLuu(lichMs: number): boolean {
  const d = new Date(lichMs);
  return d.getUTCHours() === 19 && d.getUTCMinutes() >= 30;
}
