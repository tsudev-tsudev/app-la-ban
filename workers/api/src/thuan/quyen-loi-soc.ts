// SOC trang Quyền lợi (M1a bước 4 - 5, SEC-IAP, Q55) - hàm thuần: phân loại ô tra cứu, bộ lọc danh sách -> SQL có tham
// số, schema thao tác (thu hồi four-eyes, gỡ thiết bị khỏi quyền lợi), doanh thu ước tính từ Analytics Engine. Không I/O.
import { z } from 'zod';
import { docGioiHanTrang, giaiMaCursor, type Cursor } from './cursor';
import { LoiApi } from './loi';
import { DS_SAN_PHAM, TRANG_THAI_QL, type SanPham } from './quyen-loi';

/** Yêu cầu thu hồi chờ duyệt tối đa 24 giờ (giống four-eyes can thiệp). */
export const QL_YEU_CAU_HAN_MS = 24 * 60 * 60 * 1000;

/** Giá niêm yết (VND, Q55) - CHỈ để ước tính doanh thu thô trên SOC (chưa trừ phí Play / thuế / dùng thử / quy đổi). */
export const GIA_NIEM_YET: Record<SanPham, number> = { pro_thang: 19_000, pro_nam: 99_000, pro_vinh_vien: 149_000 };

export const NGUON_QL = ['play_sub', 'play_inapp', 'pro_app', 'manual'] as const;

export type TraCuu =
  | { loai: 'id'; giaTri: string }
  | { loai: 'thiet-bi'; giaTri: string }
  | { loai: 'token'; giaTri: string }
  | { loai: 'don'; giaTri: string };

/**
 * Ô tra cứu duy nhất của SOC: băm token (64 hex) / mã đơn Play (GPA.) / mã quyền lợi hoặc mã thiết bị (ULID 26 ký tự -
 * thử cả hai) / `pro_app:<thiết bị>` (quyền lợi app Pro). Dạng khác -> 400 (không LIKE tự do lên bảng quyền lợi).
 */
export function phanLoaiTraCuu(q: string): TraCuu[] {
  const v = q.trim();
  if (/^[0-9a-f]{64}$/i.test(v)) return [{ loai: 'token', giaTri: v.toLowerCase() }];
  if (/^GPA\.[0-9A-Za-z.-]{4,60}$/.test(v)) return [{ loai: 'don', giaTri: v }];
  if (/^pro_app:[0-9A-Za-z-]{8,40}$/.test(v)) return [{ loai: 'id', giaTri: v }];
  if (/^[0-9A-Za-z-]{8,40}$/.test(v)) return [{ loai: 'id', giaTri: v }, { loai: 'thiet-bi', giaTri: v }];
  throw new LoiApi(400, 'tra-cuu-loi');
}

const SchemaLoc = z.strictObject({
  q: z.string().max(80).optional(),
  trangThai: z.enum([...TRANG_THAI_QL, 'hieu-luc']).optional(),
  nguon: z.enum(NGUON_QL).optional(),
  sanPham: z.string().regex(/^[a-z][a-z0-9_.]{1,60}$/).optional(),
  thu: z.enum(['0', '1']).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.string().max(4).optional(),
});

export type LocQl = { traCuu: TraCuu[] | null; trangThai?: string; nguon?: string; sanPham?: string; thu?: 0 | 1; cursor: Cursor | null; gioiHan: number };

export function docLocQl(query: Record<string, string>): LocQl {
  const kq = SchemaLoc.safeParse(query);
  if (!kq.success) throw new LoiApi(400, 'loc-loi');
  const l = kq.data;
  return {
    traCuu: l.q?.trim() ? phanLoaiTraCuu(l.q) : null,
    ...(l.trangThai ? { trangThai: l.trangThai } : {}),
    ...(l.nguon ? { nguon: l.nguon } : {}),
    ...(l.sanPham ? { sanPham: l.sanPham } : {}),
    ...(l.thu ? { thu: l.thu === '1' ? 1 : 0 } : {}),
    cursor: giaiMaCursor(l.cursor),
    gioiHan: docGioiHanTrang(l.limit),
  };
}

/** Cột trả cho SOC - KHÔNG có token_enc; account_hash rút gọn ở Worker. */
export const COT_QL =
  'q.id, q.source, q.package_name, q.product_id, q.state, q.expires_at, q.token_hash, q.order_id, q.account_hash, q.auto_renew, q.acknowledged, q.test_purchase, q.reason, q.created_at, q.updated_at';

/** Bộ lọc -> SQL (mệnh đề literal, giá trị qua bind). Sắp theo updated_at mới nhất, cursor (updated_at, id). */
export function sqlDsQl(l: LocQl, bayGio: number): { sql: string; thamSo: (string | number)[] } {
  const dk: string[] = [];
  const ts: (string | number)[] = [];
  if (l.traCuu) {
    const hoac: string[] = [];
    for (const t of l.traCuu) {
      if (t.loai === 'id') hoac.push('q.id = ?');
      else if (t.loai === 'token') hoac.push('q.token_hash = ?');
      else if (t.loai === 'don') hoac.push('q.order_id = ?');
      else hoac.push('q.id IN (SELECT entitlement_id FROM quyen_loi_devices WHERE device_id = ?)');
      ts.push(t.giaTri);
    }
    dk.push(`(${hoac.join(' OR ')})`);
  }
  if (l.trangThai === 'hieu-luc') {
    dk.push("q.state IN ('active', 'grace', 'canceled') AND (q.expires_at IS NULL OR q.expires_at > ?)");
    ts.push(bayGio);
  } else if (l.trangThai) {
    dk.push('q.state = ?');
    ts.push(l.trangThai);
  }
  if (l.nguon) {
    dk.push('q.source = ?');
    ts.push(l.nguon);
  }
  if (l.sanPham) {
    dk.push('q.product_id = ?');
    ts.push(l.sanPham);
  }
  if (l.thu !== undefined) {
    dk.push('q.test_purchase = ?');
    ts.push(l.thu);
  }
  if (l.cursor) {
    dk.push('(q.updated_at, q.id) < (?, ?)');
    ts.push(l.cursor.t, l.cursor.id);
  }
  const sql =
    `SELECT ${COT_QL}, (SELECT count(*) FROM quyen_loi_devices d WHERE d.entitlement_id = q.id) AS so_thiet_bi FROM quyen_loi q` +
    `${dk.length ? ` WHERE ${dk.join(' AND ')}` : ''} ORDER BY q.updated_at DESC, q.id DESC LIMIT ?`;
  return { sql, thamSo: [...ts, l.gioiHan + 1] };
}

/** Băm tài khoản (SHA-256 định danh cài đặt) chỉ hiện 12 ký tự đầu - đủ so khớp bằng mắt, không lộ trọn giá trị. */
export function rutGonBam(s: string | null): string | null {
  return s ? `${s.slice(0, 12)}…` : null;
}

const id = z.string().regex(/^[0-9A-Za-z:_-]{8,60}$/);
const lyDo = z.string().trim().min(10).max(500);

export const SchemaThuHoiQl = z.strictObject({ id, lyDo });
export const SchemaGoThietBiQl = z.strictObject({ id, thietBi: z.string().regex(/^[0-9A-Za-z-]{8,40}$/), lyDo });
export const SchemaQuyetQl = z.strictObject({ id: z.string().regex(/^[0-9A-Za-z]{20,40}$/), dongY: z.boolean(), ghiChu: z.string().trim().max(500).optional() });
export const SchemaHuyQl = z.strictObject({ id: z.string().regex(/^[0-9A-Za-z]{20,40}$/) });

/** Quyền lợi thu hồi được: chưa thu hồi. Dòng `pro_app` thu hồi được nhưng sẽ cấp lại nếu Play vẫn báo LICENSED. */
export function kiemThuHoiDuoc(state: string): void {
  if (state === 'revoked') throw new LoiApi(409, 'da-thu-hoi');
}

// ---------------------------------------------------------------- doanh thu ước tính (Analytics Engine, không PII)

export type SuKienDoanhThu = 'mua-moi' | 'gia-han' | 'hoan';

/** RTDN gói đăng ký có thu tiền: SUBSCRIPTION_RECOVERED (1) - thanh toán lại sau tạm giữ, SUBSCRIPTION_RENEWED (2). */
export function rtdnCoThuTien(kieu: number): boolean {
  return kieu === 1 || kieu === 2;
}

/** Điểm AE cho một sự kiện doanh thu: index 'doanh-thu', blob sản phẩm / sự kiện / mua thử, double số lần + VND ước tính. */
export function diemDoanhThu(sanPham: string, suKien: SuKienDoanhThu, thu: boolean): { indexes: string[]; blobs: string[]; doubles: number[] } {
  const gia = GIA_NIEM_YET[sanPham as SanPham] ?? 0;
  return { indexes: ['doanh-thu'], blobs: ['doanh-thu', sanPham.slice(0, 60), suKien, thu ? '1' : '0'], doubles: [1, suKien === 'hoan' ? -gia : gia] };
}

export const NGAY_DOANH_THU = [7, 30, 90] as const;

export function sqlDoanhThu(bangAe: string, ngay: number): string {
  if (!/^[a-z0-9_]+$/.test(bangAe)) throw new Error('ten-bang-ae');
  if (!(NGAY_DOANH_THU as readonly number[]).includes(ngay)) throw new LoiApi(400, 'ngay-loi');
  return (
    'SELECT blob2 AS sanPham, blob3 AS suKien, blob4 AS thu, SUM(_sample_interval) AS n, SUM(_sample_interval * double2) AS vnd ' +
    `FROM ${bangAe} WHERE index1 = 'doanh-thu' AND timestamp > NOW() - INTERVAL '${ngay}' DAY GROUP BY sanPham, suKien, thu FORMAT JSON`
  );
}

export type DongDoanhThu = { sanPham: string; suKien: string; thu: string; n: number | string; vnd: number | string };
export type TongDoanhThu = {
  theoSanPham: { sanPham: string; muaMoi: number; giaHan: number; hoan: number; vnd: number }[];
  tongVnd: number;
  /** Giao dịch license tester - không tính vào doanh thu. */
  soMuaThu: number;
};

/** Gộp dòng AE -> bảng theo sản phẩm (sản phẩm đã chốt luôn có dòng, kể cả 0). Mua thử tách riêng, không cộng tiền. */
export function tongHopDoanhThu(ds: readonly DongDoanhThu[]): TongDoanhThu {
  const bang = new Map<string, { sanPham: string; muaMoi: number; giaHan: number; hoan: number; vnd: number }>();
  for (const sp of DS_SAN_PHAM) bang.set(sp, { sanPham: sp, muaMoi: 0, giaHan: 0, hoan: 0, vnd: 0 });
  let soMuaThu = 0;
  for (const d of ds) {
    const n = Math.round(Number(d.n) || 0);
    if (d.thu === '1') {
      soMuaThu += n;
      continue;
    }
    const dong = bang.get(d.sanPham) ?? { sanPham: d.sanPham, muaMoi: 0, giaHan: 0, hoan: 0, vnd: 0 };
    if (d.suKien === 'mua-moi') dong.muaMoi += n;
    else if (d.suKien === 'gia-han') dong.giaHan += n;
    else if (d.suKien === 'hoan') dong.hoan += n;
    else continue;
    dong.vnd += Math.round(Number(d.vnd) || 0);
    bang.set(d.sanPham, dong);
  }
  const theoSanPham = [...bang.values()];
  return { theoSanPham, tongVnd: theoSanPham.reduce((a, x) => a + x.vnd, 0), soMuaThu };
}
