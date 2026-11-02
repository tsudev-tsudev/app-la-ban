// S7c2 (Spec §8.2-7, SEC-NET) - phần thuần của quản lý Remote Config ký số từ SOC: đề xuất -> four-eyes -> Worker ký
// Ed25519 bằng khoá trong `wrangler secret` -> KV CAU_HINH. Nội dung khớp `taoNoiDung` / `taoNoiDungApp` của
// tools/cau-hinh/ky-cau-hinh.mjs (app kiểm ở packages/network cau_hinh_tu_xa.dart, web ở web/shield cau-hinh.ts).
// Chính sách SOC hẹp hơn công cụ ngoại tuyến: KHÔNG thêm CA mới (PEM) - chỉ chọn pin trong bộ CA app đã đóng gói; CA mới
// phải đi bằng công cụ ngoại tuyến (khoá ở máy người giữ khoá).
import { z } from 'zod';

export const KID_APP = 'app-1';
export const KID_WEB = 'web-1';
/**
 * Khoá công khai đang được app / web tin (khớp khoa_cau_hinh.dart + web/shield/src/khoa.ts) - kiểm secret đặt đúng khoá.
 * Không đóng băng: chỉ worker test tích hợp (test/tich-hop/worker-thu.ts) thay bằng khoá thử.
 */
export const KHOA_CONG_KHAI: Record<string, string> = {
  'app-1': 'zHKWsqNcIOz0IRp8RfWbwH4ozMqR8s7MlJOkQvdjKAw',
  'web-1': 'QPX9JM3fQcv8QJKWHhcAkQdx53JL-76y3USxg7LH4w4',
};

/** CA gốc app đóng gói (khớp tools/cau-hinh/goc-tin-cay.json - test kiểm trùng). */
export const GOC_DONG_GOI: readonly { ten: string; pin: string; het: string }[] = Object.freeze([
  { ten: 'GTS_Root_R1', pin: 'hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=', het: '2036-06-22' },
  { ten: 'GTS_Root_R3', pin: 'QXnt2YHvdHR3tJYmQIr0Paosp6t/nggsEGD4QJZ3Q0g=', het: '2036-06-22' },
  { ten: 'GTS_Root_R4', pin: 'mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c=', het: '2036-06-22' },
  { ten: 'ISRG_Root_X1', pin: 'C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=', het: '2035-06-04' },
  { ten: 'ISRG_Root_X2', pin: 'diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=', het: '2040-09-17' },
]);

/** Cờ tắt từ xa app hiểu (khớp TINH_NANG của công cụ + CoTinhNang ở packages/storage). */
export const TINH_NANG = ['ban-do', 'ar', 'chia-se', 'dong-bo', 'quang-cao'] as const;
export const MUC_KHIEN = ['tat', 'nhe', 'chat'] as const;
export const YEU_CAU_CAU_HINH_HAN_MS = 24 * 60 * 60_000;
const NGAY_MS = 86_400_000;
const MAU_PIN = /^[A-Za-z0-9+/]{43}=$/;

export type NoiDungApp = {
  v: 1;
  phatHanh: number;
  het: number;
  capNhat: { toiThieu: number; khuyenNghi: number };
  tat: string[];
  pin: string[];
  gocThem: string[];
};
export type NoiDungWeb = { v: 1; phatHanh: number; het: number; muc: { landing: string; admin: string } };
export type GoiKy = { kid: string; duLieu: string; chuKy: string };

const soNgay = z.number().int().min(1).max(365);
export const SchemaDeXuatApp = z.strictObject({
  toiThieu: z.number().int().min(1).max(1_000_000_000),
  khuyenNghi: z.number().int().min(1).max(1_000_000_000),
  tat: z.array(z.enum(TINH_NANG)).max(TINH_NANG.length),
  pin: z.array(z.string().regex(MAU_PIN)).min(2).max(10),
  ngay: soNgay,
});
export const SchemaDeXuatWeb = z.strictObject({ landing: z.enum(MUC_KHIEN), admin: z.enum(MUC_KHIEN), ngay: soNgay });
export type DeXuatApp = z.infer<typeof SchemaDeXuatApp>;
export type DeXuatWeb = z.infer<typeof SchemaDeXuatWeb>;

const lyDo = z.string().trim().min(10).max(500);
export const SchemaYeuCauCauHinh = z.discriminatedUnion('dich', [
  z.strictObject({ dich: z.literal('app'), noiDung: SchemaDeXuatApp, lyDo }),
  z.strictObject({ dich: z.literal('web'), noiDung: SchemaDeXuatWeb, lyDo }),
]);
export const SchemaQuyetCauHinh = z.strictObject({
  id: z.string().regex(/^[0-9A-HJKMNP-TV-Z]{26}$/),
  dongY: z.boolean(),
  ghiChu: z.string().trim().max(500).optional(),
});
export const SchemaHuyCauHinh = z.strictObject({ id: z.string().regex(/^[0-9A-HJKMNP-TV-Z]{26}$/) });

function b64url(b: Uint8Array): string {
  let s = '';
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function tuB64url(s: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]+$/.test(s)) return null;
  try {
    const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));
    return Uint8Array.from(nhiPhan, (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

/** Giải mã gói `{kid, duLieu, chuKy}` đang ở KV -> nội dung JSON (KHÔNG kiểm chữ ký - dùng [kiemGoi] nếu cần). */
export function giaiMaGoi(raw: string | null): { kid: string; noiDung: Record<string, unknown> } | null {
  if (!raw) return null;
  try {
    const g = JSON.parse(raw) as Partial<GoiKy>;
    if (typeof g.kid !== 'string' || typeof g.duLieu !== 'string' || typeof g.chuKy !== 'string') return null;
    const b = tuB64url(g.duLieu);
    if (!b) return null;
    const nd = JSON.parse(new TextDecoder().decode(b)) as unknown;
    return nd && typeof nd === 'object' && !Array.isArray(nd) ? { kid: g.kid, noiDung: nd as Record<string, unknown> } : null;
  } catch {
    return null;
  }
}

/** Kiểm chữ ký gói bằng khoá công khai đã biết theo kid (giống app / web). */
export async function kiemGoi(raw: string): Promise<boolean> {
  try {
    const g = JSON.parse(raw) as GoiKy;
    const khoa = KHOA_CONG_KHAI[g.kid];
    const duLieu = tuB64url(g.duLieu);
    const chuKy = tuB64url(g.chuKy);
    const raw32 = khoa ? tuB64url(khoa) : null;
    if (!raw32 || !duLieu || !chuKy) return false;
    const k = await crypto.subtle.importKey('raw', raw32, { name: 'Ed25519' }, false, ['verify']);
    return await crypto.subtle.verify({ name: 'Ed25519' }, k, chuKy, duLieu);
  } catch {
    return false;
  }
}

/** Nạp khoá bí mật PKCS8 PEM (secret) + kiểm khoá công khai suy ra khớp kid đang được tin. Sai -> null. */
export async function napKhoaKy(pem: string | undefined, kid: string): Promise<CryptoKey | null> {
  if (!pem) return null;
  const than = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  let der: Uint8Array;
  try {
    der = Uint8Array.from(atob(than), (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
  try {
    const k = await crypto.subtle.importKey('pkcs8', der, { name: 'Ed25519' }, true, ['sign']);
    const jwk = (await crypto.subtle.exportKey('jwk', k)) as JsonWebKey;
    return jwk.x && jwk.x === KHOA_CONG_KHAI[kid] ? k : null;
  } catch {
    return null;
  }
}

/** Gói đã ký: chữ ký trên đúng byte của `duLieu` (JSON nội dung) - như `kyGoi` của công cụ ngoại tuyến. */
export async function kyGoi(khoa: CryptoKey, kid: string, noiDung: NoiDungApp | NoiDungWeb): Promise<GoiKy> {
  const duLieu = new TextEncoder().encode(JSON.stringify(noiDung));
  const chuKy = new Uint8Array(await crypto.subtle.sign({ name: 'Ed25519' }, khoa, duLieu));
  return { kid, duLieu: b64url(duLieu), chuKy: b64url(chuKy) };
}

export type LoiDeXuat =
  | 'khuyen-nghi-thap'
  | 'toi-thieu-vuot-ban-moi'
  | 'pin-la'
  | 'pin-it'
  | 'goc-them-can-cong-cu';

/**
 * Kiểm đề xuất app theo gói hiện tại. Pin chỉ được chọn trong CA đóng gói, hoặc pin "thêm" của gói hiện tại (CA đã thêm
 * bằng công cụ ngoại tuyến - PEM nằm ở `gocThem`); gói hiện tại có `gocThem` thì phải GIỮ mọi pin thêm (SOC không phân
 * tích được PEM nào ứng với pin nào, app từ chối PEM mồ côi). [banMoi] = mã build APK mới nhất (R2 latest.json): mã tối
 * thiểu vượt bản đã phát hành sẽ khoá MỌI người dùng ở màn bắt buộc cập nhật không có bản để cập nhật.
 */
export function kiemDeXuatApp(dx: DeXuatApp, hienTai: Partial<NoiDungApp> | null, banMoi: number | null): LoiDeXuat | null {
  if (dx.khuyenNghi < dx.toiThieu) return 'khuyen-nghi-thap';
  if (banMoi !== null && dx.toiThieu > banMoi) return 'toi-thieu-vuot-ban-moi';
  const dongGoi = new Set(GOC_DONG_GOI.map((g) => g.pin));
  const pinThem = (hienTai?.pin ?? []).filter((p) => !dongGoi.has(p));
  const coGocThem = (hienTai?.gocThem ?? []).length > 0;
  const ds = [...new Set(dx.pin)];
  if (ds.length < 2) return 'pin-it';
  for (const p of ds) if (!dongGoi.has(p) && !(coGocThem && pinThem.includes(p))) return 'pin-la';
  if (coGocThem && pinThem.some((p) => !ds.includes(p))) return 'goc-them-can-cong-cu';
  return null;
}

export function taoNoiDungApp(dx: DeXuatApp, hienTai: Partial<NoiDungApp> | null, bayGio: number): NoiDungApp {
  return {
    v: 1,
    phatHanh: bayGio,
    het: bayGio + dx.ngay * NGAY_MS,
    capNhat: { toiThieu: dx.toiThieu, khuyenNghi: dx.khuyenNghi },
    tat: [...new Set(dx.tat)].sort(),
    pin: [...new Set(dx.pin)],
    gocThem: Array.isArray(hienTai?.gocThem) ? hienTai.gocThem.filter((g): g is string => typeof g === 'string') : [],
  };
}

export function taoNoiDungWeb(dx: DeXuatWeb, bayGio: number): NoiDungWeb {
  return { v: 1, phatHanh: bayGio, het: bayGio + dx.ngay * NGAY_MS, muc: { landing: dx.landing, admin: dx.admin } };
}

/**
 * phatHanh mới phải LỚN HƠN gói đang phục vụ (app từ chối gói cũ hơn gói đang giữ - chống phát lại). Đồng hồ Worker lệch
 * hoặc hai lần ký trong cùng ms -> đẩy lên 1 ms.
 */
export function phatHanhMoi(bayGio: number, hienTai: number | null): number {
  return hienTai !== null && hienTai >= bayGio ? hienTai + 1 : bayGio;
}

/** Đề xuất theo gói hiện tại (điền sẵn form SOC); thiếu gói -> mặc định đóng gói (mọi CA, mã 1, 90 ngày). */
export function deXuatTuGoi(nd: Record<string, unknown> | null, dich: 'app' | 'web'): DeXuatApp | DeXuatWeb {
  if (dich === 'web') {
    const muc = (nd?.muc ?? {}) as { landing?: string; admin?: string };
    const m = (x: unknown) => (MUC_KHIEN as readonly string[]).includes(x as string) ? (x as DeXuatWeb['landing']) : 'chat';
    return { landing: m(muc.landing), admin: m(muc.admin), ngay: 90 };
  }
  const cn = (nd?.capNhat ?? {}) as { toiThieu?: number; khuyenNghi?: number };
  const pin = Array.isArray(nd?.pin) ? (nd.pin as unknown[]).filter((p): p is string => typeof p === 'string') : [];
  const tat = Array.isArray(nd?.tat) ? (nd.tat as unknown[]).filter((p): p is DeXuatApp['tat'][number] => (TINH_NANG as readonly unknown[]).includes(p)) : [];
  return {
    toiThieu: Number.isInteger(cn.toiThieu) ? (cn.toiThieu as number) : 1,
    khuyenNghi: Number.isInteger(cn.khuyenNghi) ? (cn.khuyenNghi as number) : 1,
    tat,
    pin: pin.length >= 2 ? pin : GOC_DONG_GOI.map((g) => g.pin),
    ngay: 90,
  };
}
