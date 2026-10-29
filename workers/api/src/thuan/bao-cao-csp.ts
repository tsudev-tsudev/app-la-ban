// Báo cáo vi phạm CSP (S8 - SEC-WEB-CSP CSP-01) từ landing / admin. Hai định dạng: `application/csp-report` (report-uri,
// Firefox / Safari) và `application/reports+json` (Reporting API, Chromium). Chuẩn hoá thành bản ghi NGẮN, không PII:
// chỉ origin của tài nguyên bị chặn + đường dẫn trang (bỏ query / hash), để đếm trên Analytics Engine.

export const BAO_CAO_TOI_DA = 16 * 1024;
const SO_BAN_GHI_TOI_DA = 10;

export type BanGhiCsp = {
  /** Chỉ thị bị vi phạm, vd. `script-src-elem`. */
  chiThi: string;
  /** `inline` / `eval` / `trusted-types-sink` / `wasm-eval` / origin của URL / `khac`. */
  biChan: string;
  /** Đường dẫn trang (không query / hash), tối đa 96 ký tự. */
  trang: string;
  cheDo: 'enforce' | 'report';
  /** Origin tệp nguồn gây vi phạm ('' khi không có). */
  nguon: string;
};

const LOAI_HOP_LE = new Set(['application/csp-report', 'application/reports+json', 'application/json']);

export function laLoaiBaoCao(contentType: string | null | undefined): boolean {
  const loai = contentType?.split(';')[0]?.trim().toLowerCase();
  return loai !== undefined && LOAI_HOP_LE.has(loai);
}

function chuoi(v: unknown, toiDa = 200): string {
  return typeof v === 'string' ? v.slice(0, toiDa) : '';
}

function originCua(url: string): string | null {
  try {
    const u = new URL(url);
    return u.protocol === 'http:' || u.protocol === 'https:' ? u.origin : `${u.protocol}`;
  } catch {
    return null;
  }
}

function chuanBiChan(v: string): string {
  const t = v.trim().toLowerCase();
  if (t === '') return 'khac';
  if (t === 'inline' || t === 'eval' || t === 'wasm-eval' || t === 'trusted-types-sink' || t === 'trusted-types-policy') return t;
  if (t === 'self') return 'self';
  return originCua(v) ?? (/^[a-z-]{1,24}:?$/.test(t) ? t.replace(/:$/, '') : 'khac');
}

function chuanTrang(url: string): string {
  try {
    return new URL(url).pathname.slice(0, 96);
  } catch {
    return '';
  }
}

function chuanChiThi(v: string): string {
  const t = v.trim().split(/\s+/)[0]?.toLowerCase() ?? '';
  return /^[a-z-]{1,40}$/.test(t) ? t : 'khac';
}

function tuThan(b: Record<string, unknown>, kieuMoi: boolean): BanGhiCsp | null {
  const chiThi = kieuMoi ? chuoi(b.effectiveDirective) : chuoi(b['effective-directive']) || chuoi(b['violated-directive']);
  const biChan = kieuMoi ? chuoi(b.blockedURL, 2048) : chuoi(b['blocked-uri'], 2048);
  const trang = kieuMoi ? chuoi(b.documentURL, 2048) : chuoi(b['document-uri'], 2048);
  const cheDo = chuoi(b.disposition);
  const nguon = kieuMoi ? chuoi(b.sourceFile, 2048) : chuoi(b['source-file'], 2048);
  if (!chiThi && !biChan) return null;
  return {
    chiThi: chuanChiThi(chiThi),
    biChan: chuanBiChan(biChan),
    trang: chuanTrang(trang),
    cheDo: cheDo === 'report' ? 'report' : 'enforce',
    nguon: (nguon && originCua(nguon)) || '',
  };
}

function laDoiTuong(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** Văn bản báo cáo -> tối đa 10 bản ghi chuẩn hoá. JSON hỏng / hình dạng lạ -> []. */
export function phanTichBaoCaoCsp(vanBan: string): BanGhiCsp[] {
  if (vanBan.length > BAO_CAO_TOI_DA) return [];
  let j: unknown;
  try {
    j = JSON.parse(vanBan);
  } catch {
    return [];
  }
  const kq: BanGhiCsp[] = [];
  if (Array.isArray(j)) {
    for (const r of j) {
      if (kq.length >= SO_BAN_GHI_TOI_DA) break;
      if (!laDoiTuong(r) || r.type !== 'csp-violation' || !laDoiTuong(r.body)) continue;
      const b = tuThan(r.body, true);
      if (b) kq.push(b);
    }
  } else if (laDoiTuong(j) && laDoiTuong(j['csp-report'])) {
    const b = tuThan(j['csp-report'], false);
    if (b) kq.push(b);
  }
  return kq;
}
