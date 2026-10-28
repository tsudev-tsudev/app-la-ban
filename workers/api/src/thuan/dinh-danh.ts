// ID dạng UUID / ULID (SEC-API API-03). ULID: 48 bit thời gian + 80 bit ngẫu nhiên, Crockford base32, sắp theo thời gian.
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const MAU_ULID = /^[0-7][0-9A-HJKMNP-TV-Z]{25}$/;
const MAU_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** ULID tại [bayGio] (ms). [ngauNhien] để test cố định; mặc định crypto.getRandomValues. */
export function taoUlid(bayGio: number = Date.now(), ngauNhien: (n: number) => Uint8Array = ngauNhienMatMa): string {
  if (!Number.isInteger(bayGio) || bayGio < 0 || bayGio > 2 ** 48 - 1) throw new RangeError('thời gian ULID ngoài khoảng');
  let thoiGian = '';
  let t = bayGio;
  for (let i = 0; i < 10; i++) {
    thoiGian = CROCKFORD[t % 32] + thoiGian;
    t = Math.floor(t / 32);
  }
  const b = ngauNhien(16);
  let ngau = '';
  for (let i = 0; i < 16; i++) ngau += CROCKFORD[(b[i] ?? 0) % 32];
  return thoiGian + ngau;
}

function ngauNhienMatMa(n: number): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(n));
}

export function laUlid(s: string): boolean {
  return MAU_ULID.test(s);
}

export function laUuid(s: string): boolean {
  return MAU_UUID.test(s);
}

/** Khoá idempotency / id client gửi lên: UUID (v1-v8) hoặc ULID. */
export function laIdHopLe(s: string | null | undefined): s is string {
  return typeof s === 'string' && (laUuid(s) || laUlid(s));
}

/** Thời điểm (ms) mã hoá trong ULID. */
export function thoiGianUlid(ulid: string): number {
  let t = 0;
  for (const c of ulid.slice(0, 10)) t = t * 32 + CROCKFORD.indexOf(c);
  return t;
}
