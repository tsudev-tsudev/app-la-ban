// SEC-API API-05: CORS allowlist CHÍNH XÁC (so khớp nguyên chuỗi origin, không wildcard / hậu tố).
export const NGUON_CORS: readonly string[] = Object.freeze(['https://compass-status.tsudev.com']);

export function nguonChoPhep(origin: string | undefined, dsChoPhep: readonly string[] = NGUON_CORS): string | null {
  if (!origin) return null;
  return dsChoPhep.includes(origin) ? origin : null;
}
