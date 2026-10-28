const TIEU_DE = {
  'content-type': 'text/html; charset=utf-8',
  'cache-control': 'no-store',
  'strict-transport-security': 'max-age=31536000; includeSubDomains',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'referrer-policy': 'no-referrer',
  'permissions-policy': 'camera=(), geolocation=(), microphone=(), payment=(), usb=()',
  'cross-origin-opener-policy': 'same-origin',
  'cross-origin-resource-policy': 'same-origin',
  'x-robots-tag': 'noindex, nofollow',
};

const TRANG =
  '<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
  '<meta name="robots" content="noindex, nofollow"><title>403</title></head><body><main><h1>403</h1>' +
  '<p>Truy cập bị từ chối.</p><p lang="en">Access denied.</p></main></body></html>';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/robots.txt') {
      return new Response('User-agent: *\nDisallow: /\n', {
        headers: { ...TIEU_DE, 'content-type': 'text/plain; charset=utf-8' },
      });
    }
    return new Response(TRANG, { status: 403, headers: TIEU_DE });
  },
};
