import { describe, expect, it } from 'vitest';
import { apThaoTac, canBaoTelegram, cheKhoaNhom, dichKhoaNhom, docLocCanhBao, khoaNhomNgoai, noiDungTelegram, SchemaThaoTac, truyVanCanhBao, type DongCb } from '../src/thuan/canh-bao';
import { maHoaCursor } from '../src/thuan/cursor';
import { LoiApi } from '../src/thuan/loi';

const tt = (b: unknown) => SchemaThaoTac.parse(b);
const mo: DongCb = { id: 'A1', status: 'open', assignee: null, resolution: null };

describe('canh-bao: khoá nhóm', () => {
  it('viewer thấy dải IP, analyst thấy IP đầy đủ; device / cidr giữ nguyên', () => {
    expect(cheKhoaNhom('ip:203.0.113.7', 'viewer')).toBe('ip:203.0.113.0/24');
    expect(cheKhoaNhom('ip:203.0.113.7', 'analyst')).toBe('ip:203.0.113.7');
    expect(cheKhoaNhom('device:01JX', 'viewer')).toBe('device:01JX');
    expect(dichKhoaNhom('cidr24:10.0.0.0/24')).toEqual({ loai: 'cidr', giaTri: '10.0.0.0/24' });
    expect(dichKhoaNhom('la')).toEqual({ loai: 'khac', giaTri: 'la' });
  });

  it('kênh ngoài: IP -> dải, device id -> 8 ký tự', () => {
    expect(khoaNhomNgoai('ip:2001:db8:1:2::9')).toBe('ip:2001:db8:1::/48');
    expect(khoaNhomNgoai('device:01JTB0000000000000000000AA')).toBe('device:01JTB000…');
  });
});

describe('canh-bao: lọc -> SQL', () => {
  it('mặc định chỉ open + ack, keyset theo last_ts', () => {
    const v = truyVanCanhBao(docLocCanhBao({}), 'a@b.vn');
    expect(v.sql).toContain("a.status IN ('open', 'ack')");
    expect(v.thamSo).toEqual([51]);
    const c = truyVanCanhBao(docLocCanhBao({ trangThai: 'closed', mucDo: 'high', nguoi: 'toi', shadow: 'an', q: '203.0', cursor: maHoaCursor({ t: 9, id: 'X' }), limit: '10' }), 'a@b.vn');
    expect(c.sql).toContain('a.shadow = 0');
    expect(c.thamSo).toEqual(['closed', 'high', 'a@b.vn', '203.0%', 9, 'X', 11]);
    expect(truyVanCanhBao(docLocCanhBao({ nguoi: 'chua', trangThai: 'tat-ca' }), 'x@y.z').sql).toContain('a.assignee IS NULL');
  });

  it('giá trị lạ -> 400 loc-loi', () => {
    for (const q of [{ trangThai: 'x' }, { q: '%' }, { nguoi: 'khong-phai-email' }, { la: '1' }]) {
      expect(() => docLocCanhBao(q)).toThrow(LoiApi);
    }
  });
});

describe('canh-bao: thao tác', () => {
  it('schema: đóng cần kết luận, phân công cần người, ghi chú chỉ một id, id không trùng, tối đa 100', () => {
    expect(SchemaThaoTac.safeParse({ ids: ['A0000001'], hanhDong: 'dong' }).success).toBe(false);
    expect(SchemaThaoTac.safeParse({ ids: ['A0000001'], hanhDong: 'phan-cong' }).success).toBe(false);
    expect(SchemaThaoTac.safeParse({ ids: ['A0000001', 'A0000002'], hanhDong: 'ghi-chu', ghiChu: 'x' }).success).toBe(false);
    expect(SchemaThaoTac.safeParse({ ids: ['A0000001', 'A0000001'], hanhDong: 'ack' }).success).toBe(false);
    expect(SchemaThaoTac.safeParse({ ids: Array.from({ length: 101 }, (_, i) => `A${String(i).padStart(8, '0')}`), hanhDong: 'ack' }).success).toBe(false);
    expect(tt({ ids: ['A0000001'], hanhDong: 'phan-cong', nguoi: ' X@Y.vn ' }).nguoi).toBe('x@y.vn');
  });

  it('vòng đời open -> ack -> closed -> open', () => {
    const nhan = apThaoTac(mo, tt({ ids: ['A0000001'], hanhDong: 'nhan' }), 'me@x.vn');
    expect(nhan).toMatchObject({ status: 'ack', assignee: 'me@x.vn', ghi: [{ kind: 'assign', body: 'me@x.vn' }, { kind: 'status', body: 'open>ack' }] });
    const dong = apThaoTac({ ...mo, status: 'ack' }, tt({ ids: ['A0000001'], hanhDong: 'dong', ketLuan: 'benign', ghiChu: 'ok' }), 'me@x.vn');
    expect(dong).toMatchObject({ status: 'closed', resolution: 'benign', ghi: [{ kind: 'status', body: 'ack>closed:benign' }, { kind: 'note', body: 'ok' }] });
    const moLai = apThaoTac({ ...mo, status: 'closed', resolution: 'benign' }, tt({ ids: ['A0000001'], hanhDong: 'mo-lai' }), 'me@x.vn');
    expect(moLai).toMatchObject({ status: 'open', resolution: null });
  });

  it('thao tác sai trạng thái / không đổi gì -> null', () => {
    const dong = { ...mo, status: 'closed' as const };
    expect(apThaoTac(dong, tt({ ids: ['A0000001'], hanhDong: 'ack' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac(dong, tt({ ids: ['A0000001'], hanhDong: 'nhan' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac(dong, tt({ ids: ['A0000001'], hanhDong: 'dong', ketLuan: 'benign' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac(dong, tt({ ids: ['A0000001'], hanhDong: 'phan-cong', nguoi: null }), 'm@x.vn')).toBeNull();
    expect(apThaoTac(mo, tt({ ids: ['A0000001'], hanhDong: 'mo-lai' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac({ ...mo, status: 'ack' }, tt({ ids: ['A0000001'], hanhDong: 'ack' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac({ ...mo, assignee: 'a@x.vn' }, tt({ ids: ['A0000001'], hanhDong: 'phan-cong', nguoi: 'a@x.vn' }), 'm@x.vn')).toBeNull();
    expect(apThaoTac(dong, tt({ ids: ['A0000001'], hanhDong: 'ghi-chu', ghiChu: 'vẫn ghi được' }), 'm@x.vn')?.ghi).toEqual([{ kind: 'note', body: 'vẫn ghi được' }]);
  });
});

describe('canh-bao: Telegram', () => {
  it('chỉ cảnh báo thật mức cao chưa báo', () => {
    expect(canBaoTelegram({ severity: 'high', shadow: 0, notified_at: null })).toBe(true);
    expect(canBaoTelegram({ severity: 'critical', shadow: 1, notified_at: null })).toBe(false);
    expect(canBaoTelegram({ severity: 'medium', shadow: 0, notified_at: null })).toBe(false);
    expect(canBaoTelegram({ severity: 'high', shadow: 0, notified_at: 1 })).toBe(false);
  });

  it('nội dung không có IP đầy đủ, có liên kết SOC', () => {
    const s = noiDungTelegram({ id: 'A1', rule_id: 'R-001', rule_name: 'Rate', severity: 'critical', group_key: 'ip:203.0.113.7', count: 3 }, 'prod', 'https://soc');
    expect(s).toContain('CRITICAL · R-001 Rate');
    expect(s).toContain('ip:203.0.113.0/24 · 3 lần');
    expect(s).not.toContain('203.0.113.7');
    expect(s.endsWith('https://soc/#/canh-bao/A1')).toBe(true);
  });
});
