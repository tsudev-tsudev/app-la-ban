import { describe, expect, it } from 'vitest';
import { chuanHoaDich, kiemQuyet, kiemYeuCauChan, loaiDuyet, SchemaChan, ttlCanThiep, dieuKienTrangThai } from '../src/thuan/can-thiep';
import { LoiApi } from '../src/thuan/loi';
import { phanTichLuat } from '../src/thuan/luat';
import { dauNgayVn, doiLogic, moPhongLuat, SchemaThanLuat, type SuKienMoPhong, type ThanLuat } from '../src/thuan/mo-phong';
import { CAU_HINH_MAC_DINH } from '../src/thuan/nguy-co';
import { CAI_DAT_SOC_MAC_DINH, coQuyen, docCaiDatSoc, dongCaiDatSoc, dsQuyen } from '../src/thuan/soc';

const PHUT = 60_000;
const NGAY = 24 * 60 * PHUT;

const than = (p: Partial<ThanLuat> = {}): ThanLuat =>
  SchemaThanLuat.parse({
    ten: 'Sai chữ ký',
    dieuKien: { event: ['SIGNATURE_MISMATCH'], group_by: 'device', count: 'events' },
    cuaSo: 600,
    nguong: 3,
    hanhDong: ['alert_medium'],
    ...p,
  });

const sk = (ts: number, device_id: string | null, type = 'SIGNATURE_MISMATCH', ip: string | null = '203.0.113.7'): SuKienMoPhong => ({ ts, device_id, ip, type });

describe('S7b: mô phỏng rule 7 ngày', () => {
  const den = Date.UTC(2026, 9, 30, 10);
  const tu = den - 7 * NGAY;

  it('cửa sổ trượt + ngưỡng >= + không kích hoạt lặp trong cùng cửa sổ (giống Threat Engine)', () => {
    const t0 = den - NGAY;
    const ds = [0, 1, 2, 3, 4, 11, 12, 13].map((p) => sk(t0 + p * PHUT, 'A'));
    const kq = moPhongLuat(than(), ds, tu, den);
    // Lần 1 ở phút 2 (3 sự kiện). Phút 3, 4 trong cửa sổ 10 phút từ lần 1 -> không lặp. Phút 12: >= 10 phút từ lần 1 và
    // cửa sổ (2..12] có 4, 11, 12 -> lần 2.
    expect(kq.soLanKichHoat).toBe(2);
    expect(kq.soNhom).toBe(1);
    expect(kq.topNhom).toEqual([{ khoa: 'device:A', n: 2 }]);
    expect(kq.theoNgay).toHaveLength(8);
    expect(kq.theoNgay.reduce((a, x) => a + x.n, 0)).toBe(2);
    expect(kq.hanhDong).toEqual({ alert_medium: 2 });
  });

  it('gom theo dải /24, đếm thiết bị khác nhau; loại khác + ngoài khoảng bị bỏ', () => {
    const t0 = den - 2 * NGAY;
    const l = than({ dieuKien: { event: ['DEVICE_BANNED'], group_by: 'cidr24', count: 'devices' }, cuaSo: 86400, nguong: 3 });
    const ds = [
      sk(t0, 'A', 'DEVICE_BANNED', '198.51.100.1'),
      sk(t0 + 1, 'A', 'DEVICE_BANNED', '198.51.100.2'),
      sk(t0 + 2, 'B', 'DEVICE_BANNED', '198.51.100.3'),
      sk(t0 + 3, 'C', 'ROOT', '198.51.100.4'),
      sk(tu - 1, 'Z', 'DEVICE_BANNED', '198.51.100.9'),
      sk(t0 + 4, 'C', 'DEVICE_BANNED', '198.51.100.5'),
    ];
    const kq = moPhongLuat(l, ds, tu, den);
    expect(kq.soLanKichHoat).toBe(1);
    expect(kq.topNhom).toEqual([{ khoa: 'cidr24:198.51.100.0/24', n: 1 }]);
    expect(moPhongLuat({ ...l, nguong: 4 }, ds, tu, den).soLanKichHoat).toBe(0);
  });

  it('đếm loại khác nhau; ngày theo giờ Việt Nam', () => {
    const t0 = den - 3 * NGAY;
    const l = than({ dieuKien: { event: ['HOOK_FRIDA', 'APP_REPACKAGED'], group_by: 'device', count: 'types' }, nguong: 2 });
    expect(moPhongLuat(l, [sk(t0, 'A', 'HOOK_FRIDA'), sk(t0 + 1, 'A', 'HOOK_FRIDA')], tu, den).soLanKichHoat).toBe(0);
    expect(moPhongLuat(l, [sk(t0, 'A', 'HOOK_FRIDA'), sk(t0 + 1, 'A', 'APP_REPACKAGED')], tu, den).soLanKichHoat).toBe(1);
    // 17:00 UTC = 00:00 giờ VN hôm sau.
    expect(dauNgayVn(Date.UTC(2026, 9, 29, 17, 0))).toBe(Date.UTC(2026, 9, 29, 17, 0));
    expect(dauNgayVn(Date.UTC(2026, 9, 29, 16, 59))).toBe(Date.UTC(2026, 9, 28, 17, 0));
  });

  it('đổi logic -> về shadow; đổi tên / thứ tự sự kiện / thứ tự hành động thì không', () => {
    const cu = phanTichLuat({
      id: 'R-003',
      name: 'Sai chữ ký liên tiếp',
      condition: '{"event":["SIGNATURE_MISMATCH","TOKEN_REUSE"],"group_by":"device","count":"events"}',
      window: 600,
      threshold: 5,
      action: '["add_risk_40","restrict_device"]',
      enabled: 1,
      version: 1,
      mode: 'active',
      shadow_since: 1,
    });
    if (!cu) throw new Error('rule hỏng');
    const giu = than({ ten: 'Tên mới', dieuKien: { event: ['TOKEN_REUSE', 'SIGNATURE_MISMATCH'], group_by: 'device', count: 'events' }, nguong: 5, hanhDong: ['restrict_device', 'add_risk_40'] });
    expect(doiLogic(cu, giu)).toBe(false);
    expect(doiLogic(cu, { ...giu, nguong: 4 })).toBe(true);
    expect(doiLogic(cu, { ...giu, cuaSo: 601 })).toBe(true);
    expect(doiLogic(cu, { ...giu, hanhDong: ['ban_device'] })).toBe(true);
    expect(SchemaThanLuat.safeParse({ ...giu, hanhDong: ['xoa_het'] }).success).toBe(false);
    expect(SchemaThanLuat.safeParse({ ...giu, cuaSo: 10 }).success).toBe(false);
  });
});

describe('S7b: can thiệp', () => {
  it('chuẩn hoá đích: IPv6 gọn, dải về địa chỉ mạng, /32 thành ip, dải quá rộng / ASN sai bị từ chối', () => {
    expect(chuanHoaDich({ loai: 'ip', giaTri: '2001:db8::1' })).toEqual({ loai: 'ip', giaTri: '2001:db8:0:0:0:0:0:1' });
    expect(chuanHoaDich({ loai: 'cidr', giaTri: '198.51.100.77/24' })).toEqual({ loai: 'cidr', giaTri: '198.51.100.0/24' });
    expect(chuanHoaDich({ loai: 'cidr', giaTri: '198.51.100.77/32' })).toEqual({ loai: 'ip', giaTri: '198.51.100.77' });
    expect(chuanHoaDich({ loai: 'cidr', giaTri: '10.0.0.0/8' })).toBeNull();
    expect(chuanHoaDich({ loai: 'cidr', giaTri: '198.51.100.7' })).toBeNull();
    expect(chuanHoaDich({ loai: 'asn', giaTri: 'AS7552' })).toEqual({ loai: 'asn', giaTri: '7552' });
    expect(chuanHoaDich({ loai: 'asn', giaTri: '0' })).toBeNull();
    expect(chuanHoaDich({ loai: 'device', giaTri: "x' OR 1" })).toBeNull();
  });

  it('kiểm yêu cầu: hành động khớp loại đích, gộp trùng, lý do bắt buộc >= 10 ký tự', () => {
    const y = SchemaChan.parse({ dich: [{ loai: 'ip', giaTri: '203.0.113.7' }, { loai: 'ip', giaTri: '203.0.113.7' }], hanhDong: 'block', thoiHan: '24h', lyDo: 'Quét API liên tục' });
    expect(kiemYeuCauChan(y).dich).toHaveLength(1);
    expect(() => kiemYeuCauChan({ ...y, hanhDong: 'ban' })).toThrow(LoiApi);
    expect(SchemaChan.safeParse({ ...y, lyDo: 'ngắn' }).success).toBe(false);
    expect(SchemaChan.safeParse({ ...y, dich: [] }).success).toBe(false);
  });

  it('four-eyes: hàng loạt -> yêu cầu; dải / ASN -> đề xuất trừ Under Attack; một IP / thiết bị -> ngay', () => {
    const d = (loai: 'ip' | 'cidr' | 'asn' | 'device') => ({ loai, giaTri: 'x' });
    expect(loaiDuyet({ dich: [d('ip'), d('ip')] }, true)).toBe('yeu-cau');
    expect(loaiDuyet({ dich: [d('cidr')] }, false)).toBe('de-xuat');
    expect(loaiDuyet({ dich: [d('asn')] }, true)).toBe('ngay');
    expect(loaiDuyet({ dich: [d('device')] }, false)).toBe('ngay');
  });

  it('người tạo không tự duyệt; đã quyết / hết hạn -> 409', () => {
    const yc = { created_by: 'A@thu.vn', status: 'pending', expires_at: 100 };
    expect(() => kiemQuyet(yc, 'a@thu.vn', 1)).toThrow(expect.objectContaining({ status: 403, ma: 'khong-tu-duyet' }));
    expect(() => kiemQuyet({ ...yc, status: 'approved' }, 'b@thu.vn', 1)).toThrow(expect.objectContaining({ ma: 'da-quyet' }));
    expect(() => kiemQuyet(yc, 'b@thu.vn', 100)).toThrow(expect.objectContaining({ ma: 'het-han' }));
    expect(() => kiemQuyet(yc, 'b@thu.vn', 99)).not.toThrow();
  });

  it('TTL: cố định hoặc leo thang theo bậc cấu hình', () => {
    expect(ttlCanThiep(CAU_HINH_MAC_DINH, '1h', 5)).toEqual({ bac: 0, ttlMs: 60 * PHUT });
    expect(ttlCanThiep(CAU_HINH_MAC_DINH, 'leo-thang', 1)).toEqual({ bac: 1, ttlMs: 7 * NGAY });
    expect(dieuKienTrangThai('tat-ca')).toBeNull();
    expect(dieuKienTrangThai(undefined)?.sql).toContain('pending_approval = 0 OR approved_by IS NOT NULL');
  });
});

describe('S7b: quyền + cài đặt SOC', () => {
  it('quyền mới theo bậc vai trò; chỉ super_admin chỉnh cài đặt SOC', () => {
    expect(coQuyen('analyst', 'luat:xem')).toBe(true);
    expect(coQuyen('analyst', 'can-thiep')).toBe(false);
    expect(coQuyen('responder', 'can-thiep')).toBe(true);
    expect(coQuyen('responder', 'can-thiep:duyet')).toBe(false);
    expect(coQuyen('security_admin', 'cai-dat-soc')).toBe(false);
    expect(dsQuyen('super_admin')).toContain('cai-dat-soc');
  });

  it('đọc cài đặt: thiếu / hỏng lấy mặc định từng phần; ghi rồi đọc lại khớp', () => {
    expect(docCaiDatSoc([])).toEqual(CAI_DAT_SOC_MAC_DINH);
    expect(docCaiDatSoc([{ key: 'thuyvan', value: '{"bat":false}' }, { key: 'epchekhiroi', value: 'hong' }])).toEqual(CAI_DAT_SOC_MAC_DINH);
    const moi = { thuyVan: { bat: false, mucToiThieu: 'chuan' as const }, epCheKhiRoi: true };
    expect(docCaiDatSoc(dongCaiDatSoc(moi))).toEqual(moi);
    expect(CAI_DAT_SOC_MAC_DINH.thuyVan.bat).toBe(true);
  });
});
