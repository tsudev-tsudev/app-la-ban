// Phát hiện tăng đột biến (S10a, MON-02) từ Analytics Engine: so khung 5 phút vừa xong với trung bình 12 khung trước.
// Hàm thuần: nhận dòng đã gộp (khung, index1, blob3, số), trả danh sách chỉ số vượt ngưỡng.

export type DongAe = { khung: string; i: string; s: string; n: number | string };

export type ChiSo = 'loi-5xx' | 'loi-4xx' | 'tu-choi' | 'attest-loi' | 'phat-lai';

type Nguong = { toiThieu: number; heSo: number };

/** Ngưỡng tối thiểu tuyệt đối (tránh báo khi lưu lượng nhỏ) + hệ số so với nền. */
export const NGUONG: Record<ChiSo, Nguong> = {
  'loi-5xx': { toiThieu: 10, heSo: 3 },
  'loi-4xx': { toiThieu: 200, heSo: 5 },
  'tu-choi': { toiThieu: 100, heSo: 5 },
  'attest-loi': { toiThieu: 10, heSo: 5 },
  'phat-lai': { toiThieu: 10, heSo: 5 },
};

/** Chỉ mục AE không phải route (sự kiện riêng) - không tính vào mã HTTP. */
const KHONG_PHAI_ROUTE = new Set(['csp', 'attest', 'phat-lai', 'trang-thai']);

export function phanLoai(i: string, s: string): ChiSo[] {
  if (i === 'attest') return ['attest-loi'];
  if (i === 'phat-lai') return ['phat-lai'];
  if (KHONG_PHAI_ROUTE.has(i) || !/^\d{3}$/.test(s)) return [];
  const ma = Number(s);
  if (ma >= 500) return ['loi-5xx'];
  if (ma === 401 || ma === 403 || ma === 429) return ['loi-4xx', 'tu-choi'];
  if (ma >= 400) return ['loi-4xx'];
  return [];
}

export type DotBien = { chiSo: ChiSo; hienTai: number; nen: number };

/**
 * [khungHienTai] = khung 5 phút vừa đóng (ISO 'YYYY-MM-DD HH:MM:00' theo UTC như AE trả). Nền = trung bình mỗi khung
 * của các khung trước đó (khung trống tính 0, chia cho [soKhungNen]).
 */
export function danhGiaDotBien(ds: DongAe[], khungHienTai: string, soKhungNen = 12): DotBien[] {
  const hienTai = new Map<ChiSo, number>();
  const nen = new Map<ChiSo, number>();
  for (const d of ds) {
    if (d.khung > khungHienTai) continue;
    const n = Number(d.n) || 0;
    for (const c of phanLoai(d.i, d.s)) {
      const dich = d.khung === khungHienTai ? hienTai : nen;
      dich.set(c, (dich.get(c) ?? 0) + n);
    }
  }
  const ra: DotBien[] = [];
  for (const c of Object.keys(NGUONG) as ChiSo[]) {
    const h = hienTai.get(c) ?? 0;
    const tb = (nen.get(c) ?? 0) / soKhungNen;
    if (h >= NGUONG[c].toiThieu && h > tb * NGUONG[c].heSo) ra.push({ chiSo: c, hienTai: h, nen: Math.round(tb * 10) / 10 });
  }
  return ra;
}

/** Khung 5 phút vừa đóng trước [bayGio], dạng AE ('YYYY-MM-DD HH:MM:00', UTC). */
export function khungVuaDong(bayGio: number): string {
  const ms = Math.floor(bayGio / 300_000) * 300_000 - 300_000;
  return new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
}

export function sqlDotBien(bangAe: string): string {
  if (!/^[a-z0-9_]+$/.test(bangAe)) throw new Error('ten-bang-ae');
  return (
    "SELECT toStartOfInterval(timestamp, INTERVAL '5' MINUTE) AS khung, index1 AS i, blob3 AS s, SUM(_sample_interval) AS n " +
    `FROM ${bangAe} WHERE timestamp > NOW() - INTERVAL '70' MINUTE GROUP BY khung, i, s FORMAT JSON`
  );
}

const TEN: Record<ChiSo, string> = {
  'loi-5xx': 'Lỗi máy chủ 5xx',
  'loi-4xx': 'Lỗi 4xx',
  'tu-choi': 'Từ chối 401 / 403 / 429 (chặn hàng loạt)',
  'attest-loi': 'Attestation lỗi',
  'phat-lai': 'Phát lại request (nonce)',
};

export function noiDungDotBien(ds: DotBien[], moiTruong: string, khung: string): string {
  return [
    `⚠️ La bàn [${moiTruong}] tăng đột biến - khung ${khung} UTC`,
    ...ds.map((d) => `• ${TEN[d.chiSo]}: ${d.hienTai} / 5 phút (nền ${d.nen})`),
    'Xem runbook ung-pho-su-co.md mục Phát hiện.',
  ].join('\n');
}

export function noiDungViecLoi(ten: string, loi: string, moiTruong: string): string {
  return `🛑 La bàn [${moiTruong}] việc định kỳ "${ten}" lỗi: ${loi.slice(0, 300)}\nXem runbook sao-luu-khoi-phuc.md.`;
}
