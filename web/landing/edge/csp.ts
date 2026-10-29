// CSP nonce theo TỪNG lượt tải trang (S8 - SEC-WEB-CSP CSP-01). Hàm thuần, dùng ở `_worker.ts` (Pages advanced mode).
//
// Vì sao cần: Bot Fight Mode / JavaScript Detections của Cloudflare chèn một <script> NỘI TUYẾN vào mọi trang HTML của
// compass.tsudev.com (không tắt được ở gói Free) -> CSP `script-src 'self'` chặn nó. Cloudflare đọc nonce trong TIÊU ĐỀ
// CSP của phản hồi và gắn vào script họ chèn, nên chỉ cần thêm `'nonce-<ngẫu nhiên>'` vào `script-src`. Không bao giờ
// `unsafe-inline` / `unsafe-eval`. Chính sách gốc nằm ở `public/_headers` (một nguồn); ở đây chỉ chèn nonce.

/** 16 byte ngẫu nhiên mật mã -> base64 (24 ký tự), đủ CSP L3 khuyến nghị (>= 128 bit). */
export function taoNonce(ngauNhien: (b: Uint8Array<ArrayBuffer>) => Uint8Array = (b) => crypto.getRandomValues(b)): string {
  const b = ngauNhien(new Uint8Array(16));
  let s = '';
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s);
}

const MAU_NONCE = /^[A-Za-z0-9+/]{22}==$/;

/**
 * Thêm `'nonce-X'` vào chỉ thị `script-src` (và `script-src-elem` nếu có). Thiếu `script-src` -> thêm mới từ
 * `default-src`. Chính sách đã có nonce cũ -> thay. Nonce sai dạng -> ném lỗi (không bao giờ chèn chuỗi lạ vào CSP).
 */
export function themNonce(csp: string, nonce: string): string {
  if (!MAU_NONCE.test(nonce)) throw new Error('nonce không hợp lệ');
  const tu = `'nonce-${nonce}'`;
  const ds = csp
    .split(';')
    .map((d) => d.trim())
    .filter(Boolean);
  let co = false;
  const kq = ds.map((d) => {
    const [ten = '', ...gt] = d.split(/\s+/);
    const t = ten.toLowerCase();
    if (t !== 'script-src' && t !== 'script-src-elem') return d;
    co = true;
    return [ten, ...gt.filter((g) => !/^'nonce-/.test(g)), tu].join(' ');
  });
  if (!co) {
    const md = ds.find((d) => /^default-src\s/i.test(d));
    const nguon = md ? md.split(/\s+/).slice(1).filter((g) => g !== "'none'") : [];
    kq.push(['script-src', ...nguon, tu].join(' '));
  }
  return kq.join('; ');
}

/** Chỉ tài liệu HTML cần nonce (CSP của ảnh / font / JS không có tác dụng). */
export function laHtml(contentType: string | null): boolean {
  return contentType !== null && /^text\/html\b/i.test(contentType.trim());
}

/** Header điều kiện bị bỏ trước khi hỏi kho tài sản: 304 trả HTML cũ mang nonce cũ -> lệch với nonce mới ở header. */
export const HEADER_DIEU_KIEN: readonly string[] = Object.freeze(['if-none-match', 'if-modified-since']);
