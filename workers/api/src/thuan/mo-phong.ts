// Rule UI (S7b, Spec §7.6d + §8.2): sửa rule có phiên bản + mô phỏng 7 ngày - chạy lại rule ỨNG VIÊN trên sự kiện thật
// đã lưu (security_events) đúng như Threat Engine (cửa sổ trượt, ngưỡng >=, không kích hoạt lặp trong cùng cửa sổ) để
// người duyệt thấy trước số lần kích hoạt / số nhóm / hành động trước khi lưu hoặc bật active. Hàm thuần.
import { z } from 'zod';
import { khoaNhom, schemaDieuKien, schemaHanhDong, type DieuKien, type Luat } from './luat';

export const MO_PHONG_CUA_SO_MS = 7 * 24 * 60 * 60_000;
/** Trần số sự kiện nạp cho một lần mô phỏng (D1 trả trong ~1 s); vượt -> kết quả đánh dấu `catBot`. */
export const MO_PHONG_TOI_DA_SU_KIEN = 50_000;
/** Ngày theo giờ Việt Nam (UTC+7) cho biểu đồ theo ngày. */
const LECH_VN_MS = 7 * 60 * 60_000;
const NGAY_MS = 24 * 60 * 60_000;

/** Thân rule do người sửa gửi (id cố định theo đường dẫn; phiên bản do server tăng). */
export const SchemaThanLuat = z.strictObject({
  ten: z.string().trim().min(3).max(120),
  dieuKien: schemaDieuKien,
  /** Giây, 1 phút .. 30 ngày. */
  cuaSo: z.number().int().min(60).max(30 * 24 * 3600),
  nguong: z.number().int().min(1).max(100_000),
  hanhDong: schemaHanhDong,
});
export type ThanLuat = z.infer<typeof SchemaThanLuat>;

export const SchemaSuaLuat = z.strictObject({
  id: z.string().regex(/^R-\d{3,6}$/),
  /** Phiên bản người sửa đang thấy - khác bản hiện tại -> 409 (hai người sửa cùng lúc). */
  phienBan: z.number().int().min(1),
  than: SchemaThanLuat,
  ghiChu: z.string().trim().min(10).max(500),
});

export const SchemaCheDoLuat = z.strictObject({
  id: z.string().regex(/^R-\d{3,6}$/),
  phienBan: z.number().int().min(1),
  /** active = thực thi; shadow = chỉ ghi log; tat = ngừng xét (enabled = 0). */
  cheDo: z.enum(['active', 'shadow', 'tat']),
  ghiChu: z.string().trim().min(10).max(500),
});

export const SchemaMoPhong = z.strictObject({
  than: SchemaThanLuat,
  id: z.string().regex(/^R-\d{3,6}$/).optional(),
});

/** Đổi điều kiện / cửa sổ / ngưỡng / hành động = đổi LOGIC -> rule quay về shadow >= 7 ngày; đổi tên thì không. */
export function doiLogic(cu: Pick<Luat, 'dieuKien' | 'cuaSoMs' | 'nguong' | 'hanhDong'>, moi: ThanLuat): boolean {
  return (
    JSON.stringify(chuanDieuKien(cu.dieuKien)) !== JSON.stringify(chuanDieuKien(moi.dieuKien)) ||
    cu.cuaSoMs !== moi.cuaSo * 1000 ||
    cu.nguong !== moi.nguong ||
    JSON.stringify([...cu.hanhDong].sort()) !== JSON.stringify([...moi.hanhDong].sort())
  );
}

function chuanDieuKien(d: DieuKien): DieuKien {
  return { event: [...new Set(d.event)].sort(), group_by: d.group_by, count: d.count };
}

/** Dòng D1 (rules) cho thân rule mới - cột condition / action là JSON. */
export function dongTuThan(t: ThanLuat): { name: string; condition: string; window: number; threshold: number; action: string } {
  return {
    name: t.ten,
    condition: JSON.stringify(chuanDieuKien(t.dieuKien)),
    window: t.cuaSo,
    threshold: t.nguong,
    action: JSON.stringify(t.hanhDong),
  };
}

export type SuKienMoPhong = { ts: number; device_id: string | null; ip: string | null; type: string };

export type KetQuaMoPhong = {
  tu: number;
  den: number;
  soSuKien: number;
  catBot: boolean;
  soLanKichHoat: number;
  soNhom: number;
  /** Số lần kích hoạt theo ngày (mốc 00:00 giờ VN, ms), đủ 7 ngày kể cả ngày 0. */
  theoNgay: { ngay: number; n: number }[];
  topNhom: { khoa: string; n: number }[];
  hanhDong: Record<string, number>;
};

/** Mốc 00:00 giờ Việt Nam chứa [ts] (ms UTC). */
export function dauNgayVn(ts: number): number {
  return Math.floor((ts + LECH_VN_MS) / NGAY_MS) * NGAY_MS - LECH_VN_MS;
}

/**
 * Chạy rule [than] trên [ds] (sắp theo ts tăng dần) trong [tu, den]: mỗi sự kiện khớp loại -> đếm trong cửa sổ
 * (ts - cuaSo, ts] của nhóm -> đạt ngưỡng và chưa kích hoạt trong cửa sổ -> một lần kích hoạt (giống `nenKichHoat`).
 */
export function moPhongLuat(than: ThanLuat, ds: readonly SuKienMoPhong[], tu: number, den: number, catBot = false): KetQuaMoPhong {
  const cuaSoMs = than.cuaSo * 1000;
  const loai = new Set(than.dieuKien.event);
  const luat = { dieuKien: than.dieuKien };
  const nhom = new Map<string, { ds: SuKienMoPhong[]; dau: number; cuoi: number | null; n: number }>();
  const theoNgay = new Map<number, number>();
  let tong = 0;
  for (const e of ds) {
    if (e.ts < tu || e.ts > den || !loai.has(e.type)) continue;
    const khoa = khoaNhom(luat, { thietBi: e.device_id, ip: e.ip });
    if (!khoa) continue;
    let g = nhom.get(khoa);
    if (!g) nhom.set(khoa, (g = { ds: [], dau: 0, cuoi: null, n: 0 }));
    g.ds.push(e);
    while (g.dau < g.ds.length && (g.ds[g.dau] as SuKienMoPhong).ts <= e.ts - cuaSoMs) g.dau++;
    const trong = g.ds.slice(g.dau);
    const dem =
      than.dieuKien.count === 'devices'
        ? new Set(trong.map((x) => x.device_id).filter((x) => x !== null)).size
        : than.dieuKien.count === 'types'
          ? new Set(trong.map((x) => x.type)).size
          : trong.length;
    if (dem >= than.nguong && (g.cuoi === null || e.ts - g.cuoi >= cuaSoMs)) {
      g.cuoi = e.ts;
      g.n++;
      tong++;
      const ngay = dauNgayVn(e.ts);
      theoNgay.set(ngay, (theoNgay.get(ngay) ?? 0) + 1);
    }
    // Giữ mảng gọn: bỏ phần đã trượt khỏi cửa sổ.
    if (g.dau > 512) {
      g.ds = g.ds.slice(g.dau);
      g.dau = 0;
    }
  }
  const ngayDau = dauNgayVn(tu);
  const dsNgay: { ngay: number; n: number }[] = [];
  for (let d = ngayDau; d <= den; d += NGAY_MS) dsNgay.push({ ngay: d, n: theoNgay.get(d) ?? 0 });
  const kichHoat = [...nhom].filter(([, g]) => g.n > 0);
  return {
    tu,
    den,
    soSuKien: ds.length,
    catBot,
    soLanKichHoat: tong,
    soNhom: kichHoat.length,
    theoNgay: dsNgay,
    topNhom: kichHoat
      .map(([khoa, g]) => ({ khoa, n: g.n }))
      .sort((a, b) => b.n - a.n || a.khoa.localeCompare(b.khoa))
      .slice(0, 10),
    hanhDong: Object.fromEntries(than.hanhDong.map((h) => [h, tong])),
  };
}

/** Câu nạp sự kiện cho mô phỏng: chỉ loại rule xét, trong cửa sổ, sắp theo ts, lấy dư 1 dòng để biết bị cắt. */
export function cauNapMoPhong(than: ThanLuat, tu: number): { sql: string; thamSo: (string | number)[] } {
  const loai = [...new Set(than.dieuKien.event)];
  return {
    sql: `SELECT ts, device_id, ip, type FROM security_events WHERE ts >= ? AND type IN (${loai.map(() => '?').join(', ')}) ORDER BY ts LIMIT ?`,
    thamSo: [tu, ...loai, MO_PHONG_TOI_DA_SU_KIEN + 1],
  };
}
