// Đánh giá phán quyết Play Integrity (SEC-ID ID-03, ID-05) - hàm thuần. Token do app xin bằng Standard API với
// requestHash = base64url(SHA-256(chuỗi đăng ký / xác thực)); Worker gửi Google giải mã (attest/google.ts) rồi gọi
// danhGiaPhanQuyet. Quyết định tin cậy ở đây, KHÔNG ở app.
import { z } from 'zod';
import { digestSangHex } from './ma-hoa';

/** Mức tin cậy lưu ở devices.attestation_level. */
export const MUC_TIN = ['strong', 'device', 'basic', 'failed', 'unverified'] as const;
export type MucTin = (typeof MUC_TIN)[number];

/** Token lệch giờ server quá mức này -> coi là phát lại (Google khuyên vài phút). */
export const TOKEN_TUOI_TOI_DA_MS = 10 * 60 * 1000;
const LECH_TUONG_LAI_MS = 60 * 1000;

const chuoiSo = z.union([z.string().regex(/^\d{1,16}$/), z.number().int().nonnegative()]).transform(Number);

// Google có thể thêm trường mới -> object thường (không strict); chỉ kiểm phần dùng tới.
export const schemaPhanQuyet = z.object({
  requestDetails: z.object({
    requestPackageName: z.string().max(255),
    requestHash: z.string().max(500).optional(),
    nonce: z.string().max(500).optional(),
    timestampMillis: chuoiSo,
  }),
  appIntegrity: z
    .object({
      appRecognitionVerdict: z.string().max(64),
      packageName: z.string().max(255).optional(),
      certificateSha256Digest: z.array(z.string().max(128)).max(8).optional(),
      versionCode: chuoiSo.optional(),
    })
    .optional(),
  deviceIntegrity: z
    .object({
      deviceRecognitionVerdict: z.array(z.string().max(64)).max(8).optional(),
    })
    .optional(),
  accountDetails: z.object({ appLicensingVerdict: z.string().max(64).optional() }).optional(),
});
export type PhanQuyet = z.infer<typeof schemaPhanQuyet>;

export type KyVong = {
  /** Gói app được chấp nhận ở môi trường này (prod chỉ `com.tsudev.laban`). */
  dsGoi: readonly string[];
  /** SHA-256 chứng chỉ ký (hex). Rỗng = không kiểm (staging: bản dev / stg ký khoá debug). */
  dsChungChi: readonly string[];
  requestHash: string;
  bayGio: number;
};

/** 'tu-choi' = token không thuộc yêu cầu này (phát lại, sai gói, giả) -> từ chối yêu cầu; còn lại -> mức tin cậy. */
export type KetQuaDanhGia =
  | { loai: 'tu-choi'; lyDo: string }
  | { loai: 'muc'; muc: MucTin; lyDo: string[]; tinHieu: Record<string, string | number | boolean | null> };

export function danhGiaPhanQuyet(pq: PhanQuyet, k: KyVong): KetQuaDanhGia {
  const rd = pq.requestDetails;
  if (!k.dsGoi.includes(rd.requestPackageName)) return { loai: 'tu-choi', lyDo: 'goi-yeu-cau' };
  if (rd.requestHash !== k.requestHash) return { loai: 'tu-choi', lyDo: 'request-hash' };
  if (rd.timestampMillis > k.bayGio + LECH_TUONG_LAI_MS || k.bayGio - rd.timestampMillis > TOKEN_TUOI_TOI_DA_MS) {
    return { loai: 'tu-choi', lyDo: 'token-cu' };
  }

  const lyDo: string[] = [];
  const app = pq.appIntegrity;
  const nhanApp = app?.appRecognitionVerdict ?? 'UNEVALUATED';
  // App tải ngoài Play (R0) / Play chưa liên kết -> UNRECOGNIZED_VERSION: hợp lệ nếu đúng gói + đúng chứng chỉ ký.
  if (app?.packageName !== undefined && app.packageName !== rd.requestPackageName) lyDo.push('goi-app');
  if (k.dsChungChi.length) {
    const ds = (app?.certificateSha256Digest ?? []).map(digestSangHex);
    if (!ds.length) {
      if (nhanApp !== 'UNEVALUATED') lyDo.push('thieu-chung-chi');
    } else if (!ds.every((d) => d !== null && k.dsChungChi.includes(d))) lyDo.push('chung-chi');
  }

  const thietBi = new Set(pq.deviceIntegrity?.deviceRecognitionVerdict ?? []);
  let muc: MucTin;
  if (thietBi.has('MEETS_STRONG_INTEGRITY')) muc = 'strong';
  else if (thietBi.has('MEETS_DEVICE_INTEGRITY')) muc = 'device';
  else if (thietBi.has('MEETS_BASIC_INTEGRITY') || thietBi.has('MEETS_VIRTUAL_INTEGRITY')) muc = 'basic';
  else {
    muc = 'failed';
    lyDo.push('thiet-bi');
  }
  if (lyDo.some((l) => l !== 'thiet-bi')) muc = 'failed';

  return {
    loai: 'muc',
    muc,
    lyDo,
    tinHieu: {
      app: nhanApp.slice(0, 32),
      thiet_bi: [...thietBi].map((t) => t.replace(/^MEETS_|_INTEGRITY$/g, '')).sort().join(',').slice(0, 64) || null,
      ao: thietBi.has('MEETS_VIRTUAL_INTEGRITY'),
      giay_phep: pq.accountDetails?.appLicensingVerdict?.slice(0, 32) ?? null,
      phien_ban: app?.versionCode ?? null,
    },
  };
}

/** Tính năng nhạy cảm (chia sẻ, đồng bộ, thưởng) chỉ mở từ mức này trở lên. 'unverified' = dịch vụ lỗi -> hạn chế. */
export function duTinCay(muc: MucTin): boolean {
  return muc === 'strong' || muc === 'device';
}

/** Claim JWT service account đổi lấy access token Google (RFC 7523). */
export function claimGoogle(email: string, bayGio: number): Record<string, string | number> {
  const iat = Math.floor(bayGio / 1000);
  return {
    iss: email,
    scope: 'https://www.googleapis.com/auth/playintegrity',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  };
}

export const schemaServiceAccount = z.object({
  type: z.literal('service_account'),
  client_email: z.string().email().max(200),
  private_key: z.string().startsWith('-----BEGIN PRIVATE KEY-----').max(4096),
  private_key_id: z.string().max(64).optional(),
});
export type ServiceAccount = z.infer<typeof schemaServiceAccount>;

/** PEM PKCS#8 -> byte DER. */
export function pemSangDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const nhiPhan = atob(b64);
  const b = new Uint8Array(nhiPhan.length);
  for (let i = 0; i < nhiPhan.length; i++) b[i] = nhiPhan.charCodeAt(i);
  return b;
}
