// Chống phát lại (replay): mỗi nonce chỉ được dùng MỘT lần trong thời hạn của nó. Trạng thái giữ trong D1 (R3c, trước là DO KhoNonce).

export const NONCE_TTL_MAC_DINH_MS = 5 * 60 * 1000;
export const NONCE_TTL_TOI_DA_MS = 24 * 60 * 60 * 1000;
const MAU_NONCE = /^[A-Za-z0-9_-]{16,128}$/;

export function laNonceHopLe(n: unknown): n is string {
  return typeof n === 'string' && MAU_NONCE.test(n);
}

/** [hetHanCu] = hạn đang lưu của nonce (undefined nếu chưa thấy). Trả hạn mới để lưu, hoặc null nếu là phát lại. */
export function dungNonce(hetHanCu: number | undefined, bayGio: number, ttlMs: number): number | null {
  if (hetHanCu !== undefined && hetHanCu > bayGio) return null;
  return bayGio + Math.min(Math.max(1000, ttlMs), NONCE_TTL_TOI_DA_MS);
}
