// M1a bước 4 - 5 (SOC Quyền lợi): hàm thuần tra cứu / bộ lọc -> SQL, doanh thu ước tính từ AE.
import { describe, expect, it } from 'vitest';
import { LoiApi } from '../src/thuan/loi';
import {
  diemDoanhThu,
  docLocQl,
  GIA_NIEM_YET,
  kiemThuHoiDuoc,
  phanLoaiTraCuu,
  rtdnCoThuTien,
  rutGonBam,
  SchemaThuHoiQl,
  sqlDoanhThu,
  sqlDsQl,
  tongHopDoanhThu,
} from '../src/thuan/quyen-loi-soc';

const ma = (f: () => unknown) => {
  try {
    f();
  } catch (e) {
    return e instanceof LoiApi ? e.ma : String(e);
  }
  return null;
};

describe('SOC quyền lợi: tra cứu + bộ lọc', () => {
  it('phân loại ô tra cứu: băm token / mã đơn / ULID (id hoặc thiết bị) / pro_app; dạng lạ -> 400', () => {
    expect(phanLoaiTraCuu('A'.repeat(64))).toEqual([{ loai: 'token', giaTri: 'a'.repeat(64) }]);
    expect(phanLoaiTraCuu(' GPA.3312-4455-6677-88990 ')).toEqual([{ loai: 'don', giaTri: 'GPA.3312-4455-6677-88990' }]);
    expect(phanLoaiTraCuu('01JTB0000000000000000000AA')).toEqual([
      { loai: 'id', giaTri: '01JTB0000000000000000000AA' },
      { loai: 'thiet-bi', giaTri: '01JTB0000000000000000000AA' },
    ]);
    expect(phanLoaiTraCuu('pro_app:01JTB0000000000000000000AA')).toEqual([{ loai: 'id', giaTri: 'pro_app:01JTB0000000000000000000AA' }]);
    expect(ma(() => phanLoaiTraCuu("x' OR 1=1 --"))).toBe('tra-cuu-loi');
    expect(ma(() => phanLoaiTraCuu('%'))).toBe('tra-cuu-loi');
  });

  it('bộ lọc -> SQL tham số, cursor theo updated_at, không lộ token_enc', () => {
    const l = docLocQl({ q: '01JTB0000000000000000000AA', trangThai: 'hieu-luc', nguon: 'play_sub', thu: '0', limit: '20' });
    const { sql, thamSo } = sqlDsQl(l, 1000);
    expect(sql).not.toMatch(/token_enc/);
    expect(sql).toMatch(/q\.id = \? OR q\.id IN \(SELECT entitlement_id FROM quyen_loi_devices WHERE device_id = \?\)/);
    expect(sql).toMatch(/ORDER BY q\.updated_at DESC, q\.id DESC LIMIT \?$/);
    expect(thamSo).toEqual(['01JTB0000000000000000000AA', '01JTB0000000000000000000AA', 1000, 'play_sub', 0, 21]);
    expect(ma(() => docLocQl({ trangThai: 'xoa' }))).toBe('loc-loi');
    expect(ma(() => docLocQl({ khac: '1' }))).toBe('loc-loi');
    expect(docLocQl({}).traCuu).toBeNull();
  });

  it('rút gọn băm tài khoản; thu hồi: lý do >= 10 ký tự, đã thu hồi -> 409', () => {
    expect(rutGonBam('0123456789abcdef'.repeat(4))).toBe('0123456789ab…');
    expect(rutGonBam(null)).toBeNull();
    expect(SchemaThuHoiQl.safeParse({ id: 'pro_app:01JTB0000000000000000000AA', lyDo: 'Gian lận hoàn tiền' }).success).toBe(true);
    expect(SchemaThuHoiQl.safeParse({ id: '01JTB0000000000000000000AA', lyDo: 'ngắn' }).success).toBe(false);
    expect(ma(() => kiemThuHoiDuoc('revoked'))).toBe('da-thu-hoi');
    expect(ma(() => kiemThuHoiDuoc('active'))).toBeNull();
  });
});

describe('SOC quyền lợi: doanh thu ước tính (AE)', () => {
  it('điểm AE: không PII, hoàn tiền âm, RTDN có thu tiền = RECOVERED / RENEWED', () => {
    expect(diemDoanhThu('pro_nam', 'mua-moi', false)).toEqual({ indexes: ['doanh-thu'], blobs: ['doanh-thu', 'pro_nam', 'mua-moi', '0'], doubles: [1, 99_000] });
    expect(diemDoanhThu('pro_thang', 'hoan', true).doubles).toEqual([1, -GIA_NIEM_YET.pro_thang]);
    expect([1, 2, 3, 4, 7, 13].map(rtdnCoThuTien)).toEqual([true, true, false, false, false, false]);
  });

  it('SQL AE chỉ nhận tên bảng an toàn + số ngày cho phép', () => {
    expect(sqlDoanhThu('la_ban_su_kien', 30)).toMatch(/FROM la_ban_su_kien WHERE index1 = 'doanh-thu' AND timestamp > NOW\(\) - INTERVAL '30' DAY/);
    expect(() => sqlDoanhThu('x; DROP', 30)).toThrow();
    expect(ma(() => sqlDoanhThu('la_ban_su_kien', 31))).toBe('ngay-loi');
  });

  it('gộp theo sản phẩm, mua thử tách riêng, sự kiện lạ bỏ qua', () => {
    const kq = tongHopDoanhThu([
      { sanPham: 'pro_nam', suKien: 'mua-moi', thu: '0', n: '2', vnd: '198000' },
      { sanPham: 'pro_nam', suKien: 'hoan', thu: '0', n: 1, vnd: -99000 },
      { sanPham: 'pro_thang', suKien: 'gia-han', thu: '0', n: 3, vnd: 57000 },
      { sanPham: 'pro_thang', suKien: 'mua-moi', thu: '1', n: 4, vnd: 76000 },
      { sanPham: 'pro_thang', suKien: 'la', thu: '0', n: 9, vnd: 9 },
    ]);
    expect(kq.tongVnd).toBe(156_000);
    expect(kq.soMuaThu).toBe(4);
    expect(kq.theoSanPham).toEqual([
      { sanPham: 'pro_thang', muaMoi: 0, giaHan: 3, hoan: 0, vnd: 57_000 },
      { sanPham: 'pro_nam', muaMoi: 2, giaHan: 0, hoan: 1, vnd: 99_000 },
      { sanPham: 'pro_tron_doi', muaMoi: 0, giaHan: 0, hoan: 0, vnd: 0 },
    ]);
  });
});
