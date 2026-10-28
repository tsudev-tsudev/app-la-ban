import { describe, expect, it } from 'vitest';
import { chuanHoaIp, dangChoCloudflare, ipTrongDai, phanTichCidr, phanTichIp } from '../src/thuan/ip';
import { laLuotHangNgay } from '../src/thuan/don-dep';
import {
  cauDem,
  coTheBatThucThi,
  khoaNhom,
  luatQuanTam,
  nenKichHoat,
  phanTichHanhDong,
  phanTichLuat,
  SHADOW_TOI_THIEU_MS,
  type DongLuat,
} from '../src/thuan/luat';
import {
  CAU_HINH_MAC_DINH as CFG,
  congDiem,
  diemSuKien,
  hoiPhuc,
  nangHon,
  phanTichCauHinh,
  trangThaiHieuLuc,
  trangThaiTuDiem,
  ttlLeoThang,
  TUAN_MS,
} from '../src/thuan/nguy-co';
import { schemaLoSuKien, tinHieuLuu } from '../src/thuan/su-kien';
import { canDuyet, chenhLechLists, diemLienKet, khopQuyTac, NGUONG_LIEN_KET, type DauVetThietBi } from '../src/thuan/thuc-thi';

const NGAY = 24 * 60 * 60 * 1000;

describe('bảng điểm + ngưỡng (Spec §7.6c)', () => {
  it('điểm theo loại, loại lạ = 0', () => {
    expect(diemSuKien(CFG, 'ATTEST_FAIL')).toBe(60);
    expect(diemSuKien(CFG, 'HOOK_FRIDA')).toBe(50);
    expect(diemSuKien(CFG, 'SAFE_MODE')).toBe(0);
  });
  it('ngưỡng 0-29 / 30-59 / 60-89 / >=90', () => {
    expect([0, 29, 30, 59, 60, 89, 90, 500].map((d) => trangThaiTuDiem(CFG, d))).toEqual([
      'clean', 'clean', 'suspicious', 'suspicious', 'restricted', 'restricted', 'banned', 'banned',
    ]);
  });
  it('cộng điểm kẹp [0, diemToiDa]', () => {
    expect(congDiem(CFG, 990, 50)).toBe(1000);
    expect(congDiem(CFG, 3, -10)).toBe(0);
  });
  it('trạng thái hiệu lực = nặng nhất của điểm và enforcement', () => {
    expect(trangThaiHieuLuc(CFG, 10, ['restrict'])).toBe('restricted');
    expect(trangThaiHieuLuc(CFG, 95, ['restrict'])).toBe('banned');
    expect(trangThaiHieuLuc(CFG, 40, [])).toBe('suspicious');
    expect(trangThaiHieuLuc(CFG, 0, ['ban', 'block'])).toBe('banned');
    expect(nangHon('clean', 'suspicious')).toBe('suspicious');
  });
  it('cấu hình D1: hợp lệ thì dùng, hỏng / ngưỡng không tăng dần -> null', () => {
    expect(phanTichCauHinh(JSON.stringify(CFG))).toEqual(CFG);
    expect(phanTichCauHinh(JSON.stringify({ ...CFG, nguong: { suspicious: 50, restricted: 40, banned: 90 } }))).toBeNull();
    expect(phanTichCauHinh(JSON.stringify({ ...CFG, la: 1 }))).toBeNull();
    expect(phanTichCauHinh('{')).toBeNull();
    expect(phanTichCauHinh(null)).toBeNull();
  });
});

describe('hồi phục uy tín -5/tuần', () => {
  const t = { diem: 40, viPhamCuoi: 0, truCuoi: null, lanDau: 0 };
  it('chưa đủ tuần -> null; đủ n tuần -> trừ 5n, mốc trừ dịch đúng n tuần', () => {
    expect(hoiPhuc(CFG, t, TUAN_MS - 1)).toBeNull();
    expect(hoiPhuc(CFG, t, TUAN_MS)).toEqual({ diem: 35, truLuc: TUAN_MS });
    expect(hoiPhuc(CFG, t, 3 * TUAN_MS + 5)).toEqual({ diem: 25, truLuc: 3 * TUAN_MS });
  });
  it('tính từ mốc muộn hơn (vi phạm mới / lần trừ trước), không xuống dưới sàn', () => {
    expect(hoiPhuc(CFG, { ...t, viPhamCuoi: 2 * TUAN_MS }, 2 * TUAN_MS + 10)).toBeNull();
    expect(hoiPhuc(CFG, { ...t, truCuoi: TUAN_MS }, TUAN_MS + 10)).toBeNull();
    expect(hoiPhuc(CFG, { ...t, diem: 7 }, 10 * TUAN_MS)?.diem).toBe(0);
    expect(hoiPhuc({ ...CFG, hoiPhuc: { diemMoiTuan: 5, san: 10 } }, { ...t, diem: 10 }, 10 * TUAN_MS)).toBeNull();
    expect(hoiPhuc(CFG, { ...t, viPhamCuoi: null, lanDau: 0 }, TUAN_MS)?.diem).toBe(35);
  });
});

describe('TTL leo thang 24h -> 7d -> 30d -> 365d (mọi chặn có hạn)', () => {
  it('theo số lần trước, kẹp bậc cuối', () => {
    expect([0, 1, 2, 3, 9, -1].map((n) => ttlLeoThang(CFG, n).ttlMs / NGAY)).toEqual([1, 7, 30, 365, 365, 1]);
    expect(ttlLeoThang(CFG, 2).bac).toBe(2);
  });
});

const dongLuat = (them: Partial<DongLuat> = {}): DongLuat => ({
  id: 'R-003',
  name: 'Sai chữ ký',
  condition: '{"event":["SIGNATURE_MISMATCH"],"group_by":"device"}',
  window: 600,
  threshold: 5,
  action: '["add_risk_40","restrict_device"]',
  enabled: 1,
  version: 2,
  mode: 'shadow',
  shadow_since: 1000,
  ...them,
});

describe('rule engine (Spec §7.6d)', () => {
  it('phân tích rule hợp lệ, mặc định count = events', () => {
    const l = phanTichLuat(dongLuat());
    expect(l).toMatchObject({ id: 'R-003', phienBan: 2, cuaSoMs: 600_000, nguong: 5, cheDo: 'shadow', bat: true });
    expect(l?.dieuKien.count).toBe('events');
  });
  it('rule hỏng -> null: JSON sai, trường lạ, hành động lạ, ngưỡng 0', () => {
    expect(phanTichLuat(dongLuat({ condition: '{' }))).toBeNull();
    expect(phanTichLuat(dongLuat({ condition: '{"event":["X_Y"],"group_by":"device","la":1}' }))).toBeNull();
    expect(phanTichLuat(dongLuat({ action: '["xoa_het"]' }))).toBeNull();
    expect(phanTichLuat(dongLuat({ action: '["add_risk_0"]' }))).toBeNull();
    expect(phanTichLuat(dongLuat({ threshold: 0 }))).toBeNull();
    expect(phanTichLuat(dongLuat({ condition: '{"event":["sai thuong"],"group_by":"device"}' }))).toBeNull();
  });
  it('shadow >= 7 ngày mới được bật thực thi', () => {
    expect(coTheBatThucThi({ cheDo: 'shadow', shadowTu: 0 }, SHADOW_TOI_THIEU_MS - 1)).toBe(false);
    expect(coTheBatThucThi({ cheDo: 'shadow', shadowTu: 0 }, SHADOW_TOI_THIEU_MS)).toBe(true);
    expect(coTheBatThucThi({ cheDo: 'shadow', shadowTu: null }, 1e15)).toBe(false);
    expect(coTheBatThucThi({ cheDo: 'active', shadowTu: null }, 0)).toBe(true);
  });
  it('khoá nhóm theo device / ip / dải; thiếu chiều -> null', () => {
    const l = (g: string) => ({ dieuKien: { event: ['A_B'], group_by: g as 'ip', count: 'events' as const } });
    expect(khoaNhom(l('device'), { thietBi: 'd1', ip: '1.2.3.4' })).toBe('device:d1');
    expect(khoaNhom(l('device'), { thietBi: null, ip: '1.2.3.4' })).toBeNull();
    expect(khoaNhom(l('ip'), { thietBi: null, ip: '1.2.3.4' })).toBe('ip:1.2.3.4');
    expect(khoaNhom(l('cidr24'), { thietBi: null, ip: '1.2.3.4' })).toBe('cidr24:1.2.3.0/24');
    expect(khoaNhom(l('cidr24'), { thietBi: null, ip: 'rac' })).toBeNull();
    expect(khoaNhom(l('ip'), { thietBi: 'x', ip: null })).toBeNull();
  });
  it('câu đếm tham số hoá đúng cột + biểu thức đếm', () => {
    const l = { dieuKien: { event: ['A_B', 'C_D'], group_by: 'cidr24' as const, count: 'devices' as const }, cuaSoMs: 1000 };
    expect(cauDem(l, 'cidr24:1.2.3.0/24', 5000)).toEqual({
      sql: 'SELECT COUNT(DISTINCT device_id) AS n FROM security_events WHERE ip_prefix = ? AND ts > ? AND type IN (?, ?)',
      thamSo: ['1.2.3.0/24', 4000, 'A_B', 'C_D'],
    });
    expect(cauDem({ ...l, dieuKien: { ...l.dieuKien, count: 'types' } }, 'device:x', 5000).sql).toContain('COUNT(DISTINCT type)');
    expect(cauDem({ ...l, dieuKien: { ...l.dieuKien, count: 'events' } }, 'ip:1.1.1.1', 5000).sql).toMatch(/COUNT\(\*\).*WHERE ip = \?/);
  });
  it('kích hoạt khi đạt ngưỡng và chưa kích hoạt trong cùng cửa sổ', () => {
    const l = { nguong: 5, cuaSoMs: 1000 };
    expect(nenKichHoat(l, 4, null, 0)).toBe(false);
    expect(nenKichHoat(l, 5, null, 0)).toBe(true);
    expect(nenKichHoat(l, 9, 500, 1000)).toBe(false);
    expect(nenKichHoat(l, 9, 0, 1000)).toBe(true);
  });
  it('rule tắt không quan tâm sự kiện', () => {
    const l = phanTichLuat(dongLuat({ enabled: 0 }));
    expect(l && luatQuanTam(l, 'SIGNATURE_MISMATCH')).toBe(false);
    const b = phanTichLuat(dongLuat());
    expect(b && luatQuanTam(b, 'SIGNATURE_MISMATCH')).toBe(true);
    expect(b && luatQuanTam(b, 'ROOT')).toBe(false);
  });
  it('phân tích hành động', () => {
    expect(phanTichHanhDong('add_risk_40')).toEqual({ loai: 'add_risk', diem: 40 });
    expect(phanTichHanhDong('alert_high')).toEqual({ loai: 'alert', muc: 'high' });
    expect(phanTichHanhDong('block_ip')).toEqual({ loai: 'block_ip' });
    expect(phanTichHanhDong('rm_rf')).toBeNull();
  });
});

describe('IP / CIDR', () => {
  it('phân tích IPv4 / IPv6, từ chối dạng sai', () => {
    expect(phanTichIp('1.2.3.4')).toEqual({ v: 4, so: 0x01020304n });
    expect(phanTichIp('::1')).toEqual({ v: 6, so: 1n });
    expect(phanTichIp('2001:db8::')?.v).toBe(6);
    for (const s of ['256.1.1.1', '01.2.3.4', '1.2.3', '1::2::3', 'g::1', '1:2:3:4:5:6:7:8:9', '1:2:3:4:5:6:7', '']) expect(phanTichIp(s)).toBeNull();
    expect(phanTichCidr('1.2.3.4/33')).toBeNull();
    expect(phanTichCidr('1.2.3.4/x')).toBeNull();
    expect(phanTichCidr('10.1.2.3/8')).toEqual({ v: 4, goc: 0x0a000000n, doDai: 8 });
  });
  it('ip trong dải, khác họ -> false', () => {
    expect(ipTrongDai('10.9.8.7', '10.0.0.0/8')).toBe(true);
    expect(ipTrongDai('11.0.0.1', '10.0.0.0/8')).toBe(false);
    expect(ipTrongDai('2001:db8:1::5', '2001:db8:1::/48')).toBe(true);
    expect(ipTrongDai('2001:db8:2::5', '2001:db8:1::/48')).toBe(false);
    expect(ipTrongDai('10.0.0.1', '::/0')).toBe(false);
  });
  it('chuẩn hoá IPv6 viết gọn khác nhau', () => {
    expect(chuanHoaIp('2001:DB8::1')).toBe(chuanHoaIp('2001:db8:0:0:0:0:0:1'));
    expect(chuanHoaIp('1.2.3.4')).toBe('1.2.3.4');
    expect(chuanHoaIp('x')).toBeNull();
  });
  it('dạng Cloudflare Lists: IPv4 /8-/32, IPv6 đơn -> /64, ngoài khoảng -> null', () => {
    expect(dangChoCloudflare('1.2.3.4')).toBe('1.2.3.4');
    expect(dangChoCloudflare('1.2.3.4/32')).toBe('1.2.3.4');
    expect(dangChoCloudflare('1.2.3.9/24')).toBe('1.2.3.0/24');
    expect(dangChoCloudflare('1.0.0.0/7')).toBeNull();
    expect(dangChoCloudflare('2001:db8::1')).toBe('2001:db8:0:0:0:0:0:0/64');
    expect(dangChoCloudflare('2001:db8:1::/48')).toBe('2001:db8:1:0:0:0:0:0/48');
    expect(dangChoCloudflare('2001::/8')).toBeNull();
    expect(dangChoCloudflare('rac')).toBeNull();
  });
});

describe('allow-list / enforcement / Lists / liên kết', () => {
  const ds = [
    { loai: 'device' as const, giaTri: 'd1' },
    { loai: 'ip' as const, giaTri: '2001:db8::1' },
    { loai: 'cidr' as const, giaTri: '10.0.0.0/8' },
    { loai: 'asn' as const, giaTri: '15169' },
  ];
  it('khớp theo thiết bị / IP chuẩn hoá / dải / ASN', () => {
    expect(khopQuyTac(ds, { thietBi: 'd1' })?.loai).toBe('device');
    expect(khopQuyTac(ds, { ip: '2001:DB8:0::1' })?.loai).toBe('ip');
    expect(khopQuyTac(ds, { ip: '10.2.3.4' })?.loai).toBe('cidr');
    expect(khopQuyTac(ds, { ip: '8.8.8.8', asn: 15169 })?.loai).toBe('asn');
    expect(khopQuyTac(ds, { thietBi: 'd2', ip: '8.8.8.8', asn: 13335 })).toBeNull();
    expect(khopQuyTac(ds, {})).toBeNull();
  });
  it('chặn dải / ASN cần duyệt trừ Under Attack; IP / thiết bị không', () => {
    expect(canDuyet('cidr', false)).toBe(true);
    expect(canDuyet('asn', false)).toBe(true);
    expect(canDuyet('cidr', true)).toBe(false);
    expect(canDuyet('ip', false)).toBe(false);
    expect(canDuyet('device', false)).toBe(false);
  });
  it('chênh lệch Lists: thêm thiếu, xoá hết hạn, không đụng item người / môi trường khác, gộp trùng', () => {
    const kq = chenhLechLists(
      'prod',
      [
        { enforcementId: 'E1', giaTri: '1.1.1.1' },
        { enforcementId: 'E2', giaTri: '2.2.2.2' },
        { enforcementId: 'E3', giaTri: '2.2.2.2' },
        { enforcementId: 'E4', giaTri: '3.3.3.0/24' },
        { enforcementId: 'E5', giaTri: 'rac' },
      ],
      [
        { id: 'i1', ip: '1.1.1.1', comment: 'la-ban:prod:E1' },
        { id: 'i2', ip: '9.9.9.9', comment: 'la-ban:prod:E0' },
        { id: 'i3', ip: '8.8.8.8', comment: 'thu cong' },
        { id: 'i4', ip: '7.7.7.7', comment: 'la-ban:staging:X' },
        { id: 'i5', ip: '1.1.1.1', comment: 'la-ban:prod:E9' },
      ],
    );
    expect(kq.them).toEqual([
      { ip: '2.2.2.2', comment: 'la-ban:prod:E2' },
      { ip: '3.3.3.0/24', comment: 'la-ban:prod:E4' },
    ]);
    expect(kq.xoa).toEqual(['i2', 'i5']);
  });
  const tb = (them: Partial<DauVetThietBi>): DauVetThietBi => ({
    id: 'a', platform: 'android', model: 'Pixel 7', osVersion: '14', build: 42, locale: 'vi', country: 'VN', publicKey: null,
    daiIp: ['1.2.3.0/24'], asn: [7552], ...them,
  });
  it('liên kết thiết bị: trùng khoá = 1, đủ tín hiệu mềm >= ngưỡng, khác nền tảng = 0', () => {
    expect(diemLienKet(tb({}), tb({ id: 'b' })).diem).toBe(1);
    expect(diemLienKet(tb({}), tb({ id: 'b' })).diem).toBeGreaterThanOrEqual(NGUONG_LIEN_KET);
    expect(diemLienKet(tb({ publicKey: 'k' }), tb({ id: 'b', publicKey: 'k', model: 'X' }))).toEqual({ diem: 1, tinHieu: { publicKey: true } });
    expect(diemLienKet(tb({}), tb({ id: 'b', platform: 'ios' })).diem).toBe(0);
    expect(diemLienKet(tb({}), tb({})).diem).toBe(0);
    const yeu = diemLienKet(tb({}), tb({ id: 'b', model: 'Galaxy', osVersion: '13', daiIp: ['5.5.5.0/24'] }));
    expect(yeu.diem).toBeLessThan(NGUONG_LIEN_KET);
    expect(yeu.tinHieu.daiIp).toBe(false);
  });
});

describe('lô sự kiện (Spec §7.6b)', () => {
  const e = {
    event_id: '01J9ZK3Q7V8X2M4N6P8R0T2V4W',
    ts: '2026-10-28T10:15:30Z',
    type: 'HOOK_FRIDA',
    severity: 'high',
    signals: { maps_agent: true, port_27042: false },
    app: { version: '1.0.3', build: 42, install_source: 'com.android.vending' },
    env: { os: 'android', os_ver: '14', model: 'Pixel 7', emulator: false, root: 'suspected' },
  };
  it('hợp lệ; trường lạ / lô rỗng / quá 50 / loại sai bị từ chối', () => {
    expect(schemaLoSuKien.safeParse({ events: [e] }).success).toBe(true);
    expect(schemaLoSuKien.safeParse({ events: [{ ...e, la: 1 }] }).success).toBe(false);
    expect(schemaLoSuKien.safeParse({ events: [] }).success).toBe(false);
    expect(schemaLoSuKien.safeParse({ events: Array(51).fill(e) }).success).toBe(false);
    expect(schemaLoSuKien.safeParse({ events: [{ ...e, type: 'hook' }] }).success).toBe(false);
    expect(schemaLoSuKien.safeParse({ events: [{ ...e, signals: { Lat: 1 } }] }).success).toBe(false);
  });
  it('tín hiệu lưu: kẹp giờ client lệch > 7 ngày', () => {
    const now = Date.parse(e.ts);
    expect(tinHieuLuu(e as never, now)).toMatchObject({ maps_agent: true, _app: '1.0.3+42', _ts_client: now });
    expect(tinHieuLuu(e as never, now + 8 * NGAY)._ts_client).toBeNull();
  });
});

describe('lịch cron', () => {
  it('việc hằng ngày chỉ ở lượt 19:15-19:19 UTC', () => {
    expect(laLuotHangNgay(Date.UTC(2026, 9, 28, 19, 15))).toBe(true);
    expect(laLuotHangNgay(Date.UTC(2026, 9, 28, 19, 20))).toBe(false);
    expect(laLuotHangNgay(Date.UTC(2026, 9, 28, 18, 15))).toBe(false);
  });
});
