import { describe, expect, it } from 'vitest';
import { tenTepTai } from '../api';
import { chuoi } from '../i18n';
import { dauNgayVn, khacBietApp, khacBietWeb, khoangGanNhat, khoangTuO, loiDeXuatApp, ngayVn, tiLe } from './s7c2';

const NGAY = 86_400_000;

describe('S7c2: khoảng ngày giờ VN', () => {
  it('ô ngày -> [đầu ngày VN, hết ngày VN); quá 92 ngày / ngược -> null', () => {
    expect(dauNgayVn('2026-11-02')).toBe(Date.UTC(2026, 10, 1, 17));
    expect(dauNgayVn('02/11/2026')).toBeNull();
    const k = khoangTuO('2026-11-01', '2026-11-02');
    expect(k).toEqual({ tu: Date.UTC(2026, 9, 31, 17), den: Date.UTC(2026, 10, 2, 17) });
    expect(khoangTuO('2026-11-02', '2026-11-01')).toBeNull();
    expect(khoangTuO('2026-01-01', '2026-06-01')).toBeNull();
    expect(ngayVn(Date.UTC(2026, 10, 1, 18))).toBe('2026-11-02');
    expect(khoangGanNhat(7, Date.UTC(2026, 10, 1, 18))).toEqual({ tu: '2026-10-27', den: '2026-11-02' });
    expect(khoangTuO(khoangGanNhat(90, Date.now()).tu, khoangGanNhat(90, Date.now()).den)?.den).toBeGreaterThan(Date.now() - NGAY);
  });
});

describe('S7c2: Remote Config phía giao diện', () => {
  const goc = { toiThieu: 1, khuyenNghi: 2, tat: ['ar'], pin: ['a', 'b'], ngay: 90 };
  it('so sánh chỉ ra đúng trường đổi, bỏ qua thứ tự + hạn', () => {
    expect(khacBietApp(goc, { ...goc, tat: ['ar'], pin: ['b', 'a'], ngay: 5 }, (p) => p)).toEqual([]);
    expect(khacBietApp(goc, { ...goc, toiThieu: 2, tat: [] }, (p) => p.toUpperCase())).toEqual([
      { truong: 'toiThieu', cu: '1', moi: '2' },
      { truong: 'tat', cu: 'ar', moi: '-' },
    ]);
    expect(khacBietWeb({ landing: 'chat', admin: 'chat', ngay: 90 }, { landing: 'nhe', admin: 'chat', ngay: 1 })).toEqual([{ truong: 'landing', cu: 'chat', moi: 'nhe' }]);
  });

  it('kiểm sớm như server: khuyến nghị >= tối thiểu, tối thiểu <= bản phát hành, >= 2 pin', () => {
    expect(loiDeXuatApp(goc, 10)).toBeNull();
    expect(loiDeXuatApp({ ...goc, khuyenNghi: 0 }, 10)).toBe('khuyen-nghi-thap');
    expect(loiDeXuatApp({ ...goc, toiThieu: 11, khuyenNghi: 11 }, 10)).toBe('toi-thieu-vuot-ban-moi');
    expect(loiDeXuatApp({ ...goc, pin: ['a', 'a'] }, null)).toBe('pin-it');
    expect(tiLe(0, 10)).toBe(0);
    expect(tiLe(1, 1000)).toBe(1);
    expect(tiLe(10, 10)).toBe(100);
    expect(tenTepTai('attachment; filename="la-ban-su-kien-2026-11-01_2026-11-02.csv"', 'x.csv')).toBe('la-ban-su-kien-2026-11-01_2026-11-02.csv');
    expect(tenTepTai('attachment; filename="../../x"', 'x.csv')).toBe('x.csv');
  });

  it('vi / en đủ phím tắt mới, nhãn lỗi + nhãn trạng thái yêu cầu cùng khoá', () => {
    const [vi, en] = [chuoi('vi'), chuoi('en')];
    expect(vi.dsPhimTat.map(([k]) => k)).toEqual(expect.arrayContaining(['g b', 'g r']));
    expect(vi.dsPhimTat.map(([k]) => k)).toEqual(en.dsPhimTat.map(([k]) => k));
    for (const m of ['dang-co-yeu-cau', 'cau-hinh-da-doi', 'chua-co-khoa-ky', 'toi-thieu-vuot-ban-moi', 'pin-la', 'khoang-sai']) {
      expect(vi.loiMa[m]).toBeTruthy();
      expect(en.loiMa[m]).toBeTruthy();
    }
    expect(Object.keys(vi.chTtYeuCau)).toEqual(Object.keys(en.chTtYeuCau));
    expect(Object.keys(vi.bcLoai)).toEqual(Object.keys(en.bcLoai));
    expect(Object.keys(vi.chTinhNang)).toEqual(['ban-do', 'ar', 'chia-se', 'dong-bo', 'quang-cao', 'mua-pro', 'chanDevMode']);
  });
});
