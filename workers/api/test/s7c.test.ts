import { describe, expect, it } from 'vitest';
import { HASH_GOC, kiemChuoiAudit, taoDongAudit, type DongAudit } from '../src/thuan/audit';
import { maRef } from '../src/thuan/kenh';
import { docLocAudit, dsTenMien, duoiTuRef, kiemTurnstile, SchemaGuiKhieuNai, truyVanAudit } from '../src/thuan/khieu-nai';
import { LoiApi } from '../src/thuan/loi';
import { coQuyen } from '../src/thuan/soc';

describe('S7c1: mã REF + form khiếu nại', () => {
  it('REF -> hậu tố id; chấp nhận chữ thường, thiếu gạch, ký tự Crockford gõ nhầm', () => {
    const id = '01JTB0000000000000000K7QZ1';
    expect(maRef(id)).toBe('REF-00000-K7QZ1');
    expect(duoiTuRef('REF-00000-K7QZ1')).toBe('00000K7QZ1');
    expect(duoiTuRef('ref-ooooo-k7qzi')).toBe('00000K7QZ1');
    expect(duoiTuRef(' 00000 k7qzl ')).toBe('00000K7QZ1');
    expect(duoiTuRef('REF-00000-K7QZU')).toBeNull();
    expect(duoiTuRef('REF-0000-K7QZ1')).toBeNull();
    expect(duoiTuRef('')).toBeNull();
  });

  it('schema: nội dung 20..2000, email tuỳ chọn hợp lệ hoặc rỗng, trường lạ bị từ chối', () => {
    const goc = { ref: 'REF-0000K-7QZ11', noiDung: 'Tôi không dùng root, xin xem lại.', ngonNgu: 'vi', turnstile: 't' };
    expect(SchemaGuiKhieuNai.safeParse(goc).success).toBe(true);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, lienHe: '' }).success).toBe(true);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, lienHe: 'ban@vi.du' }).success).toBe(true);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, lienHe: 'khong-phai-email' }).success).toBe(false);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, noiDung: 'ngắn quá' }).success).toBe(false);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, noiDung: 'x'.repeat(2001) }).success).toBe(false);
    expect(SchemaGuiKhieuNai.safeParse({ ...goc, la: 1 }).success).toBe(false);
  });

  it('Turnstile: thất bại / sai tên miền / sai action bị từ chối; khoá thử (không action) đạt khi không kiểm tên miền', () => {
    expect(kiemTurnstile({ success: true, hostname: 'compass.tsudev.com', action: 'khieu-nai' }, ['compass.tsudev.com'])).toEqual({ hopLe: true, loi: [] });
    expect(kiemTurnstile({ success: true, hostname: 'example.com' }, [])).toEqual({ hopLe: true, loi: [] });
    expect(kiemTurnstile({ success: true, hostname: 'gia.vn', action: 'khieu-nai' }, ['compass.tsudev.com']).loi).toEqual(['sai-ten-mien']);
    expect(kiemTurnstile({ success: true, hostname: 'compass.tsudev.com', action: 'dang-nhap' }, ['compass.tsudev.com']).loi).toEqual(['sai-hanh-dong']);
    expect(kiemTurnstile({ success: false, 'error-codes': ['timeout-or-duplicate'] }, []).loi).toEqual(['timeout-or-duplicate']);
    expect(kiemTurnstile('rac', []).hopLe).toBe(false);
    expect(dsTenMien(' Compass.tsudev.com, ,a.vn ')).toEqual(['compass.tsudev.com', 'a.vn']);
    expect(dsTenMien(undefined)).toEqual([]);
  });

  it('quyền: analyst xem khiếu nại, responder quyết, chỉ security_admin xem audit', () => {
    expect(coQuyen('viewer', 'khieu-nai:xem')).toBe(false);
    expect(coQuyen('analyst', 'khieu-nai:xem')).toBe(true);
    expect(coQuyen('analyst', 'khieu-nai:xu-ly')).toBe(false);
    expect(coQuyen('responder', 'khieu-nai:xu-ly')).toBe(true);
    expect(coQuyen('responder', 'audit:xem')).toBe(false);
    expect(coQuyen('security_admin', 'audit:xem')).toBe(true);
  });
});

describe('S7c1: audit', () => {
  it('lọc -> SQL có tham số; tiền tố hành động; ký tự đại diện LIKE bị từ chối', () => {
    expect(truyVanAudit(docLocAudit({}))).toEqual({ where: '', thamSo: [] });
    expect(truyVanAudit(docLocAudit({ tacNhan: 'A@b.vn', hanhDong: 'can-thiep', truoc: '42' }))).toEqual({
      where: ' WHERE actor = ? COLLATE NOCASE AND (action = ? OR action LIKE ?) AND rowid < ?',
      thamSo: ['A@b.vn', 'can-thiep', 'can-thiep:%', 42],
    });
    expect(truyVanAudit(docLocAudit({ hanhDong: 'khieu-nai:' })).thamSo).toEqual(['khieu-nai:', 'khieu-nai:%']);
    expect(() => docLocAudit({ tacNhan: 'a%b' })).toThrow(LoiApi);
    expect(() => docLocAudit({ hanhDong: 'a_b' })).toThrow(LoiApi);
    expect(() => docLocAudit({ truoc: '-1' })).toThrow(LoiApi);
  });

  it('kiểm theo lô: nối hash cuối lô trước; sửa / xoá giữa chuỗi chỉ ra đúng dòng', async () => {
    const ds: DongAudit[] = [];
    let truoc = HASH_GOC;
    for (let i = 0; i < 5; i++) {
      const d = await taoDongAudit({ id: `id${i}`, actor: 'a@b.vn', action: 'x:y', target: null, before: null, after: { i }, ip: null, ts: i }, truoc);
      ds.push(d);
      truoc = d.hash_self;
    }
    expect(await kiemChuoiAudit(ds.slice(0, 2))).toBe(-1);
    expect(await kiemChuoiAudit(ds.slice(2), ds[1]?.hash_self)).toBe(-1);
    expect(await kiemChuoiAudit(ds.slice(2), HASH_GOC)).toBe(0);
    const sua = ds.map((d, i) => (i === 3 ? { ...d, after: '{"i":99}' } : d));
    expect(await kiemChuoiAudit(sua)).toBe(3);
    expect(await kiemChuoiAudit([...ds.slice(0, 2), ...ds.slice(3)])).toBe(2);
  });
});
