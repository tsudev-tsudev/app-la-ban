// Form khiếu nại (S7c1): hàm thuần dùng chung cho mã trình duyệt (khieu-nai-trang.ts) + edge (CSP) + test.

/**
 * Site key Turnstile (CÔNG KHAI - chỉ bí mật nằm ở Worker). Rỗng = chưa có widget -> trang chỉ hiện cách gửi email.
 * Widget "la-ban-khieu-nai": hostname compass.tsudev.com + la-ban-landing.pages.dev (bản xem trước) + localhost.
 */
export const TURNSTILE_SITE_KEY = '';

export const API_KHIEU_NAI = 'https://compass-api.tsudev.com/v1/khieu-nai';

/** Nguồn của Turnstile - chỉ trang khiếu nại được nạp script / khung từ đây (edge thêm vào CSP). */
export const NGUON_TURNSTILE = 'https://challenges.cloudflare.com';

export const DUONG_KHIEU_NAI: readonly string[] = Object.freeze(['/khieu-nai/', '/en/appeal/']);

export function laTrangKhieuNai(duongDan: string): boolean {
  return DUONG_KHIEU_NAI.includes(duongDan.endsWith('/') ? duongDan : `${duongDan}/`);
}

export type MaLoi = 'ref-loi' | 'ref-khong-thay' | 'da-co-khieu-nai' | 'turnstile' | 'qua-nhieu' | 'du-lieu' | 'chung';

/** Phản hồi lỗi RFC 7807 của Worker (status + `code`) -> thông báo cho người dùng. */
export function maLoiTuPhanHoi(status: number, code: string | null | undefined): MaLoi {
  if (code === 'ref-loi' || code === 'ref-khong-thay' || code === 'da-co-khieu-nai' || code === 'turnstile') return code;
  if (status === 429) return 'qua-nhieu';
  if (status === 400 || status === 422) return 'du-lieu';
  return 'chung';
}

/** `?ref=REF-...` (app có thể mở trang kèm mã) -> giá trị điền sẵn; ký tự lạ / quá dài -> rỗng. */
export function refTuQuery(search: string): string {
  const v = new URLSearchParams(search).get('ref') ?? '';
  return /^[A-Za-z0-9-]{10,24}$/.test(v) ? v.toUpperCase() : '';
}

/**
 * Thêm nguồn Turnstile vào `script-src` và `frame-src` (tạo `frame-src` nếu thiếu - mặc định rơi về default-src 'none').
 * Chỉ áp cho trang khiếu nại; không đụng chỉ thị khác, không thêm từ khoá nào ngoài đúng một origin.
 */
export function themTurnstile(csp: string): string {
  const ds = csp
    .split(';')
    .map((d) => d.trim())
    .filter(Boolean);
  let coFrame = false;
  const kq = ds.map((d) => {
    const [ten = '', ...gt] = d.split(/\s+/);
    const t = ten.toLowerCase();
    if (t !== 'script-src' && t !== 'frame-src') return d;
    if (t === 'frame-src') coFrame = true;
    const con = gt.filter((g) => g !== "'none'" && g !== NGUON_TURNSTILE);
    return [ten, ...con, NGUON_TURNSTILE].join(' ');
  });
  if (!coFrame) kq.push(`frame-src ${NGUON_TURNSTILE}`);
  return kq.join('; ');
}
