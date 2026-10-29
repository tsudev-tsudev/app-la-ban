// SEC-API API-05: CORS allowlist CHÍNH XÁC (so khớp nguyên chuỗi origin, không wildcard / hậu tố).
export const NGUON_CORS: readonly string[] = Object.freeze(['https://compass-status.tsudev.com']);

/** Trang web gửi báo cáo CSP về `/v1/web/csp`. */
export const NGUON_WEB: readonly string[] = Object.freeze(['https://compass.tsudev.com', 'https://compass-admin.tsudev.com']);

export function nguonChoPhep(origin: string | undefined, dsChoPhep: readonly string[] = NGUON_CORS): string | null {
  if (!origin) return null;
  return dsChoPhep.includes(origin) ? origin : null;
}
