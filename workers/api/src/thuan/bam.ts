// Băm SHA-256 + JSON chuẩn hoá (khoá sắp xếp) - dùng cho idempotency, audit, rút gọn IP.

/** JSON với khoá object sắp xếp đệ quy -> cùng dữ liệu luôn cùng chuỗi. `undefined` trong object bị bỏ. */
export function jsonChuan(giaTri: unknown): string {
  if (giaTri === null || typeof giaTri !== 'object') return JSON.stringify(giaTri) ?? 'null';
  if (Array.isArray(giaTri)) return `[${giaTri.map((v) => jsonChuan(v ?? null)).join(',')}]`;
  const o = giaTri as Record<string, unknown>;
  const khoa = Object.keys(o)
    .filter((k) => o[k] !== undefined)
    .sort();
  return `{${khoa.map((k) => `${JSON.stringify(k)}:${jsonChuan(o[k])}`).join(',')}}`;
}

export async function sha256Hex(vanBan: string): Promise<string> {
  const so = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(vanBan));
  return [...new Uint8Array(so)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
