// SH-03: dò công cụ nhà phát triển theo nhiều tín hiệu, có ngưỡng chống báo nhầm. Hàm thuần - lớp DOM chỉ đo và gọi vào.
//
// Tín hiệu:
// - kích thước: ước lượng mức phóng to z = ngoàiRộng / trongRộng (chiều ngang không có thanh trình duyệt), suy ra phần
//   thanh trình duyệt dọc c = ngoàiCao - trongCao * z. Cửa sổ thường hoặc phóng to: c trong [0, ~200]. Công cụ GẮN CẠNH
//   làm z phình -> c âm; GẮN ĐÁY làm c vượt xa phần thanh. Màn cảm ứng (pointer: coarse) bỏ qua; phải giữ >= 2 lần đo.
// - phím tắt mở công cụ (F12, Ctrl+Shift+I...) và menu chuột phải: cộng điểm, tự giảm theo thời gian.
// - debugger (S11, Q58): câu lệnh `debugger` chỉ dừng khi có DevTools gắn vào trang - kể cả công cụ TÁCH cửa sổ và
//   remote debugging qua USB / Wi-Fi (chrome://inspect) trên điện thoại. Đo thời gian quanh câu lệnh; > ngưỡng = đang soi.
// - tự động hoá (S11): navigator.webdriver, trình duyệt headless -> chặn cứng cả phiên trang.
// Không có API nào cho trang biết Developer options / USB debugging của máy đang bật mà không gắn công cụ (giới hạn
// trình duyệt, đã báo người dùng ở Q58).

export type DoKichThuoc = { ngoaiRong: number; ngoaiCao: number; trongRong: number; trongCao: number; camUng: boolean };

export const NGUONG = Object.freeze({
  /** Hụt chiều ngang tối thiểu (px CSS) mới xét công cụ gắn cạnh. */
  hutNgang: 160,
  /** c dưới mức này -> chiều ngang hụt nhiều hơn mức phóng to giải thích được (gắn cạnh). */
  thanhAm: -30,
  /** c trên mức này -> chiều dọc hụt quá phần thanh tab / địa chỉ / dấu trang (gắn đáy). */
  thanhToiDa: 300,
  lanDoLienTiep: 2,
  diemNghi: 4,
  diemPhimDevtools: 2,
  diemMenuChuot: 1,
  /** `debugger` dừng lâu hơn mức này (ms) = có công cụ gắn vào. Không DevTools: < 1 ms. */
  debuggerMs: 80,
  /** Điểm giảm 1 mỗi khoảng này (ms). */
  giamMoiMs: 10_000,
});

export function kichThuocBatThuong(d: DoKichThuoc): boolean {
  if (d.camUng || d.ngoaiRong <= 0 || d.ngoaiCao <= 0 || d.trongRong <= 0 || d.trongCao <= 0) return false;
  const z = d.ngoaiRong / d.trongRong;
  const thanh = d.ngoaiCao - d.trongCao * z;
  const ganCanh = d.ngoaiRong - d.trongRong > NGUONG.hutNgang && thanh < NGUONG.thanhAm;
  return ganCanh || thanh > NGUONG.thanhToiDa;
}

export type DauHieuTuDong = { webdriver: boolean; ua: string; brands: readonly string[] };

/** Trình duyệt do máy điều khiển (Selenium / Puppeteer / Playwright mặc định, Chrome headless). */
/** Bot tìm kiếm / xem trước liên kết / đo hiệu năng render bằng trình duyệt tự động - xoá nội dung trước chúng là mất SEO.
 *  UA giả mạo được, nhưng đây chỉ là lớp răn đe (chốt thật ở Worker, SH-07). */
const BOT_HOP_LE = /Googlebot|Google-InspectionTool|AdsBot-Google|Storebot-Google|bingbot|Applebot|DuckDuckBot|YandexBot|facebookexternalhit|Twitterbot|LinkedInBot|Slackbot|Discordbot|Zalo|Chrome-Lighthouse/i;

export function laTuDongHoa(d: DauHieuTuDong): boolean {
  if (BOT_HOP_LE.test(d.ua)) return false;
  return d.webdriver || /HeadlessChrome|PhantomJS|SlimerJS/i.test(d.ua) || d.brands.some((b) => /Headless/i.test(b));
}

/** Thời gian chạy qua câu lệnh `debugger` -> có công cụ gắn vào không. */
export function debuggerDangGan(msTruoc: number, msSau: number): boolean {
  return msSau - msTruoc > NGUONG.debuggerMs;
}

export type TrangThaiDo = { lanBatThuong: number; diem: number; capNhat: number; tuDong: boolean };

export const TRANG_THAI_DAU: TrangThaiDo = Object.freeze({ lanBatThuong: 0, diem: 0, capNhat: 0, tuDong: false });

export type SuKienDo =
  | { loai: 'do'; kichThuoc: DoKichThuoc }
  | { loai: 'phimDevtools' }
  | { loai: 'menuChuot' }
  | { loai: 'debugger' }
  | { loai: 'tuDong' };

function giam(t: TrangThaiDo, bayGio: number): TrangThaiDo {
  if (t.diem === 0 || bayGio <= t.capNhat) return { ...t, capNhat: Math.max(t.capNhat, bayGio) };
  const buoc = Math.floor((bayGio - t.capNhat) / NGUONG.giamMoiMs);
  if (buoc === 0) return t;
  return { ...t, diem: Math.max(0, t.diem - buoc), capNhat: t.capNhat + buoc * NGUONG.giamMoiMs };
}

export function capNhatDo(t: TrangThaiDo, e: SuKienDo, bayGio: number): TrangThaiDo {
  const s = giam(t.diem === 0 ? { ...t, capNhat: bayGio } : t, bayGio);
  switch (e.loai) {
    case 'do':
      return { ...s, lanBatThuong: kichThuocBatThuong(e.kichThuoc) ? s.lanBatThuong + 1 : 0 };
    case 'phimDevtools':
      return { ...s, diem: s.diem + NGUONG.diemPhimDevtools };
    case 'menuChuot':
      return { ...s, diem: s.diem + NGUONG.diemMenuChuot };
    case 'debugger':
      // Đủ điểm nghi ngay; đóng công cụ thì điểm tự giảm (~40 giây) rồi trả nội dung.
      return { ...s, diem: Math.max(s.diem, NGUONG.diemNghi) + 1 };
    case 'tuDong':
      return { ...s, tuDong: true };
  }
}

export type KetLuan = { nghi: boolean; kichThuoc: boolean; diem: number; tuDong: boolean };

export function ketLuan(t: TrangThaiDo): KetLuan {
  const kichThuoc = t.lanBatThuong >= NGUONG.lanDoLienTiep;
  return { nghi: t.tuDong || kichThuoc || t.diem >= NGUONG.diemNghi, kichThuoc, diem: t.diem, tuDong: t.tuDong };
}
