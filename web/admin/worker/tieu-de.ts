// Header bảo mật của compass-admin (SEC-HDR, SEC-WEB-CSP). SPA không có script / style nội tuyến -> CSP chỉ 'self';
// WebSocket SOC cùng origin ('self' phủ wss cùng host). Trusted Types để Report-Only trước (lớp khiên + React).
const BAO_CAO = 'https://compass-api.tsudev.com/v1/web/csp';

export const TIEU_DE_ADMIN: Readonly<Record<string, string>> = Object.freeze({
  'strict-transport-security': 'max-age=31536000; includeSubDomains',
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'referrer-policy': 'no-referrer',
  'permissions-policy': 'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()',
  'cross-origin-opener-policy': 'same-origin',
  'cross-origin-resource-policy': 'same-origin',
  'x-robots-tag': 'noindex, nofollow',
});

const CHUNG =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; " +
  "connect-src 'self' https://compass-api.tsudev.com; manifest-src 'self'; base-uri 'none'; form-action 'none'; " +
  "frame-ancestors 'none'; object-src 'none'";

export function cspAdmin(): Record<string, string> {
  return {
    'content-security-policy': `${CHUNG}; upgrade-insecure-requests; report-uri ${BAO_CAO}; report-to csp`,
    'content-security-policy-report-only': `${CHUNG}; require-trusted-types-for 'script'; trusted-types 'none'; report-uri ${BAO_CAO}; report-to csp`,
    'reporting-endpoints': `csp="${BAO_CAO}"`,
  };
}
