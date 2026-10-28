// Enforcement + allow-list + đồng bộ Cloudflare Lists + liên kết thiết bị (Spec §7.6a/d, SEC-DET, QUYET_DINH Q12). Thuần.
import { chuanHoaIp, dangChoCloudflare, ipTrongDai } from './ip';

export type LoaiDich = 'device' | 'ip' | 'cidr' | 'asn';

export type MucTieu = { loai: LoaiDich; giaTri: string };

/** Một dòng enforcement / allow-list đã lọc "còn hiệu lực" ở SQL. */
export type QuyTac = { loai: LoaiDich; giaTri: string };

export type DoiTuong = { thietBi?: string | null; ip?: string | null; asn?: number | null };

/** [d] có khớp một quy tắc (thiết bị / IP / dải / ASN) trong [ds] không. */
export function khopQuyTac(ds: readonly QuyTac[], d: DoiTuong): QuyTac | null {
  const ip = d.ip ? chuanHoaIp(d.ip) : null;
  for (const q of ds) {
    switch (q.loai) {
      case 'device':
        if (d.thietBi && q.giaTri === d.thietBi) return q;
        break;
      case 'ip':
        if (ip && chuanHoaIp(q.giaTri) === ip) return q;
        break;
      case 'cidr':
        if (d.ip && ipTrongDai(d.ip, q.giaTri)) return q;
        break;
      case 'asn':
        if (d.asn !== null && d.asn !== undefined && q.giaTri === String(d.asn)) return q;
        break;
    }
  }
  return null;
}

/** Chặn dải / ASN / quốc gia luôn chỉ là ĐỀ XUẤT chờ duyệt, trừ khi người vận hành bật Under Attack. */
export function canDuyet(loai: LoaiDich, underAttack: boolean): boolean {
  return (loai === 'cidr' || loai === 'asn') && !underAttack;
}

/** Ghi chú item Lists: chỉ item có tiền tố của môi trường này mới do engine quản lý (list dùng chung tài khoản). */
export const tienToGhiChu = (moiTruong: string) => `la-ban:${moiTruong}:`;

export type ItemLists = { id: string; ip: string; comment?: string };
export type CanChan = { enforcementId: string; giaTri: string };

/**
 * Chênh lệch giữa các IP / dải đang bị chặn (D1) và item trong Cloudflare List:
 * - thêm item còn thiếu (ghi chú = tiền tố + id enforcement);
 * - xoá item của môi trường này không còn enforcement hiệu lực (hết hạn / thu hồi);
 * - bỏ qua item không thuộc engine (người thêm tay / môi trường khác).
 */
export function chenhLechLists(
  moiTruong: string,
  canChan: readonly CanChan[],
  hienCo: readonly ItemLists[],
): { them: { ip: string; comment: string }[]; xoa: string[] } {
  const tienTo = tienToGhiChu(moiTruong);
  const muon = new Map<string, string>();
  for (const c of canChan) {
    const g = dangChoCloudflare(c.giaTri);
    if (g && !muon.has(g)) muon.set(g, c.enforcementId);
  }
  const daCo = new Set<string>();
  const xoa: string[] = [];
  for (const it of hienCo) {
    if (!it.comment?.startsWith(tienTo)) continue;
    if (muon.has(it.ip) && !daCo.has(it.ip)) daCo.add(it.ip);
    else xoa.push(it.id);
  }
  const them = [...muon]
    .filter(([ip]) => !daCo.has(ip))
    .map(([ip, id]) => ({ ip, comment: `${tienTo}${id}` }));
  return { them, xoa };
}

export type DauVetThietBi = {
  id: string;
  platform: string;
  model: string | null;
  osVersion: string | null;
  build: number | null;
  locale: string | null;
  country: string | null;
  publicKey: string | null;
  /** Dải IP (rutGonIp) đã thấy gần đây. */
  daiIp: readonly string[];
  asn: readonly number[];
};

export const NGUONG_LIEN_KET = 0.7;

/**
 * Điểm tương đồng 0..1 giữa hai thiết bị từ tín hiệu MỀM (Spec §7.6d) - phát hiện cài lại / đổi Installation ID.
 * Khác nền tảng -> 0. Trùng khoá công khai attest -> 1. Không dùng định danh phần cứng.
 */
export function diemLienKet(a: DauVetThietBi, b: DauVetThietBi): { diem: number; tinHieu: Record<string, boolean> } {
  if (a.id === b.id || a.platform !== b.platform) return { diem: 0, tinHieu: {} };
  if (a.publicKey && a.publicKey === b.publicKey) return { diem: 1, tinHieu: { publicKey: true } };
  const trung = <T>(x: T | null, y: T | null) => x !== null && x === y;
  const giao = <T>(x: readonly T[], y: readonly T[]) => x.some((v) => y.includes(v));
  const tinHieu = {
    model: trung(a.model, b.model),
    osVersion: trung(a.osVersion, b.osVersion),
    build: trung(a.build, b.build),
    locale: trung(a.locale, b.locale),
    country: trung(a.country, b.country),
    daiIp: giao(a.daiIp, b.daiIp),
    asn: giao(a.asn, b.asn),
  };
  const trongSo: Record<keyof typeof tinHieu, number> = {
    model: 0.25,
    osVersion: 0.15,
    build: 0.1,
    locale: 0.05,
    country: 0.05,
    daiIp: 0.3,
    asn: 0.1,
  };
  let diem = 0;
  for (const k of Object.keys(tinHieu) as (keyof typeof tinHieu)[]) if (tinHieu[k]) diem += trongSo[k];
  return { diem: Math.round(diem * 100) / 100, tinHieu };
}
