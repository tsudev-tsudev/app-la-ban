// S3 - phần thuần cho Remote Config ký số của app, trạng thái thiết bị (/v1/status) và lô sự kiện (/v1/events).
import { z } from 'zod';

/** Khoá KV `CAU_HINH` chứa gói Remote Config đã ký Ed25519 của app (tools/cau-hinh/ky-cau-hinh.mjs dua-len-app). */
export const KHOA_KV_APP = 'app-cau-hinh';
/** `duLieu` (base64url) tối đa: đủ cho vài chứng chỉ CA dạng PEM khi xoay pin. */
export const GOI_APP_TOI_DA = 24 * 1024;

/**
 * Loại sự kiện CHỈ server sinh (từ chữ ký, phiên, attestation, giới hạn, bẫy, khiên web). App gửi các loại này -> 422:
 * client không được tự khai thay server (cũng không tự "xoá án" được vì server không tin lô sự kiện để hạ điểm).
 */
export const LOAI_CHI_SERVER: ReadonlySet<string> = new Set([
  'SIGNATURE_MISMATCH',
  'TOKEN_REUSE',
  'ATTEST_FAIL',
  'DEVICE_BANNED',
  'RATE_ABUSE',
  'HONEYPOT_HIT',
  'WEB_DEVTOOLS',
]);

/** Lô sự kiện từ app: mỗi loại tính điểm tối đa một lần / thiết bị / 24 giờ (`diemTheoLo`). */
export const GOP_LOAI_MS = 24 * 60 * 60 * 1000;

const CROCKFORD = /^[0-9A-HJKMNP-TV-Z]{26}$/;

/** Mã REF hiện trên màn khoá / khiếu nại: 10 ký tự cuối (phần ngẫu nhiên) của id thiết bị, SOC tra theo hậu tố. */
export function maRef(thietBiId: string): string {
  if (!CROCKFORD.test(thietBiId)) throw new RangeError('id thiết bị không phải ULID');
  const duoi = thietBiId.slice(-10);
  return `REF-${duoi.slice(0, 5)}-${duoi.slice(5)}`;
}

const schemaLatest = z.object({
  phienBan: z.string().regex(/^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$/).max(32),
  maPhienBan: z.number().int().min(1).max(1_000_000_000),
});
export type BanMoi = z.infer<typeof schemaLatest>;

/** `android/latest.json` (R0) -> bản mới nhất; sai dạng -> null (app coi như không có thông tin). */
export function docLatest(raw: string | null): BanMoi | null {
  if (!raw || raw.length > 16_384) return null;
  try {
    const kq = schemaLatest.safeParse(JSON.parse(raw));
    return kq.success ? { phienBan: kq.data.phienBan, maPhienBan: kq.data.maPhienBan } : null;
  } catch {
    return null;
  }
}

/** Mã ref chỉ lộ khi thiết bị bị hạn chế / cấm (màn khoá S4 + khiếu nại); trạng thái thường không cần. */
export function refChoTrangThai(trangThai: string, thietBiId: string): string | null {
  return trangThai === 'restricted' || trangThai === 'banned' ? maRef(thietBiId) : null;
}

/**
 * Header `x-app-version` app gửi kèm yêu cầu ký (dạng pubspec `0.1.0-beta.12+12`) -> phiên bản + build để cập nhật
 * `devices` khi người dùng nâng cấp (trước đây chỉ ghi lúc đăng ký - SOC hiện phiên bản cũ). Thông tin do client tự khai,
 * chỉ để hiển thị / thống kê - KHÔNG dùng cho quyết định chặn. Sai dạng -> null.
 */
export function docPhienBanApp(h: string | undefined | null): { phienBan: string; build: number } | null {
  const m = /^(\d{1,3}\.\d{1,3}\.\d{1,3}(?:-[a-z]{1,10}\.\d{1,4})?)\+(\d{1,9})$/.exec(h ?? '');
  return m?.[1] && m[2] ? { phienBan: m[1], build: Number(m[2]) } : null;
}
