// SEC-HDR HDR-01 + TLS-01: header bảo mật nền cho MỌI phản hồi của API (JSON, không phục vụ HTML).
// CSP chặn tất cả vì API không bao giờ trả tài liệu để trình duyệt hiển thị.
export const TIEU_DE_BAO_MAT: Readonly<Record<string, string>> = Object.freeze({
  'strict-transport-security': 'max-age=31536000; includeSubDomains',
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  'referrer-policy': 'no-referrer',
  'permissions-policy': 'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()',
  'cross-origin-opener-policy': 'same-origin',
  'cross-origin-resource-policy': 'same-site',
  'cache-control': 'no-store',
});

// Ghép header bảo mật vào header sẵn có; header đã đặt riêng ở route (vd. cache-control) được giữ nguyên.
export function ganTieuDe(sanCo: Headers): Headers {
  const kq = new Headers(sanCo);
  for (const [ten, giaTri] of Object.entries(TIEU_DE_BAO_MAT)) {
    if (!kq.has(ten)) kq.set(ten, giaTri);
  }
  kq.delete('x-powered-by');
  return kq;
}
