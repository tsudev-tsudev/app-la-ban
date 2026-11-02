// Nhật ký bất biến (S10a, MON-01 + mốc neo audit phát sinh từ S7c1). Cron xuất các bảng CHỈ THÊM của D1 sang R2 theo
// đoạn NDJSON nối chuỗi băm: hash_self = SHA-256(hash_prev + ':' + SHA-256(ndjson)). Bucket lock giữ đoạn >= 400 ngày, nên
// kẻ có quyền D1 sửa / xoá dòng (kể cả audit_logs khi gỡ trigger) vẫn để lại bằng chứng ngoài D1. Hàm thuần.
import { jsonChuan, sha256Hex } from './bam';

/** Bảng chỉ thêm được xuất, con trỏ = rowid (thứ tự ghi thật, không phụ thuộc đồng hồ isolate). */
export const BANG_NHAT_KY = ['audit_logs', 'security_events', 'rule_hits'] as const;
export type BangNhatKy = (typeof BANG_NHAT_KY)[number];

export const HASH_GOC_NHAT_KY = '0'.repeat(64);
export const LO_NHAT_KY = 1000;
/** Khoá R2 của đầu chuỗi (đối tượng sửa được - nằm NGOÀI tiền tố bị khoá). */
export const KHOA_DAU_CHUOI = 'trang-thai/dau-chuoi.json';
export const TIEN_TO_DOAN = 'nhat-ky/';

export type ConTro = Record<BangNhatKy, number>;

export type DauChuoi = {
  /** Số thứ tự đoạn cuối đã ghi (0 = chưa có đoạn). */
  so: number;
  hash: string;
  conTro: ConTro;
  /** Mốc neo audit: hash_self dòng audit cuối đã xuất + tổng số dòng audit đã xuất. */
  auditCuoi: string | null;
  auditSoDong: number;
};

export type DongXuat = { bang: BangNhatKy; so: number; dong: Record<string, unknown> };

export type Doan = {
  khoa: string;
  ndjson: string;
  dau: DauChuoi;
  meta: { so: string; hash_prev: string; hash_self: string; so_dong: string; bam_noi_dung: string };
};

export function dauChuoiGoc(): DauChuoi {
  return {
    so: 0,
    hash: HASH_GOC_NHAT_KY,
    conTro: { audit_logs: 0, security_events: 0, rule_hits: 0 },
    auditCuoi: null,
    auditSoDong: 0,
  };
}

/** Đọc đầu chuỗi từ JSON lưu ở R2; sai dạng -> null (KHÔNG tự về gốc: tạo chuỗi mới sẽ che mất chuỗi cũ). */
export function docDauChuoi(vanBan: string | null): DauChuoi | null {
  if (vanBan === null) return dauChuoiGoc();
  try {
    const o = JSON.parse(vanBan) as Partial<DauChuoi>;
    const goc = dauChuoiGoc();
    if (!Number.isInteger(o.so) || (o.so ?? -1) < 0 || typeof o.hash !== 'string' || !/^[0-9a-f]{64}$/.test(o.hash)) return null;
    const conTro = { ...goc.conTro };
    for (const b of BANG_NHAT_KY) {
      const v = o.conTro?.[b];
      if (v !== undefined && (!Number.isInteger(v) || v < 0)) return null;
      conTro[b] = v ?? 0;
    }
    return {
      so: o.so as number,
      hash: o.hash,
      conTro,
      auditCuoi: typeof o.auditCuoi === 'string' ? o.auditCuoi : null,
      auditSoDong: Number.isInteger(o.auditSoDong) ? (o.auditSoDong as number) : 0,
    };
  } catch {
    return null;
  }
}

export function khoaDoan(so: number, bayGio: number): string {
  const d = new Date(bayGio);
  const ngay = `${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${String(d.getUTCDate()).padStart(2, '0')}`;
  return `${TIEN_TO_DOAN}${ngay}/${String(so).padStart(10, '0')}.ndjson`;
}

export async function bamMatXich(hashTruoc: string, ndjson: string): Promise<{ bamNoiDung: string; hash: string }> {
  const bamNoiDung = await sha256Hex(ndjson);
  return { bamNoiDung, hash: await sha256Hex(`${hashTruoc}:${bamNoiDung}`) };
}

/** Gộp các dòng mới thành một đoạn kế tiếp; không có dòng -> null (không ghi đoạn rỗng). */
export async function taoDoan(dau: DauChuoi, dsDong: DongXuat[], bayGio: number): Promise<Doan | null> {
  if (!dsDong.length) return null;
  const conTro = { ...dau.conTro };
  let auditCuoi = dau.auditCuoi;
  let auditSoDong = dau.auditSoDong;
  const dong: string[] = [];
  for (const d of dsDong) {
    dong.push(jsonChuan({ b: d.bang, n: d.so, r: d.dong }));
    conTro[d.bang] = Math.max(conTro[d.bang], d.so);
    if (d.bang === 'audit_logs') {
      auditSoDong++;
      if (typeof d.dong.hash_self === 'string') auditCuoi = d.dong.hash_self;
    }
  }
  const ndjson = `${dong.join('\n')}\n`;
  const so = dau.so + 1;
  const { bamNoiDung, hash } = await bamMatXich(dau.hash, ndjson);
  return {
    khoa: khoaDoan(so, bayGio),
    ndjson,
    dau: { so, hash, conTro, auditCuoi, auditSoDong },
    meta: { so: String(so), hash_prev: dau.hash, hash_self: hash, so_dong: String(dsDong.length), bam_noi_dung: bamNoiDung },
  };
}

export type DoanDaGhi = { so: number; hash_prev: string; hash_self: string; ndjson: string };

/**
 * Kiểm chuỗi đoạn đọc lại từ R2 (theo số thứ tự): trả số đoạn đầu tiên sai (thiếu / chèn / sửa), -1 nếu nguyên vẹn.
 * [hashDau] cho phép kiểm từ giữa chuỗi khi đã có mốc tin cậy.
 */
export async function kiemChuoiDoan(ds: DoanDaGhi[], hashDau = HASH_GOC_NHAT_KY, soDau = 1): Promise<number> {
  let truoc = hashDau;
  let soMongDoi = soDau;
  for (const d of ds) {
    if (d.so !== soMongDoi || d.hash_prev !== truoc) return d.so;
    if ((await bamMatXich(truoc, d.ndjson)).hash !== d.hash_self) return d.so;
    truoc = d.hash_self;
    soMongDoi++;
  }
  return -1;
}
