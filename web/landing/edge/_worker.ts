// Pages advanced mode cho landing (S8): mọi trang HTML (lọc bởi `_routes.json`) qua đây để gắn nonce CSP mới mỗi lượt;
// tài sản tĩnh (ảnh, font, _astro) không gọi worker - giữ hạn mức 100.000 lượt / ngày của gói Free.
// Đóng gói bằng `edge/dong-goi.mjs` -> `dist/_worker.js` (minify, không comment - qua được ve-sinh-ban-build).
import { HEADER_DIEU_KIEN, laHtml, taoNonce, themNonce } from './csp';

type Moi = { ASSETS: { fetch(req: Request): Promise<Response> } };

type PhanTu = { setAttribute(ten: string, giaTri: string): void };
declare class HTMLRewriter {
  on(chon: string, xuLy: { element(e: PhanTu): void }): HTMLRewriter;
  transform(res: Response): Response;
}

export default {
  async fetch(req: Request, env: Moi): Promise<Response> {
    const h = new Headers(req.headers);
    for (const t of HEADER_DIEU_KIEN) h.delete(t);
    const res = await env.ASSETS.fetch(new Request(req, { headers: h }));
    const csp = res.headers.get('content-security-policy');
    if (!csp || !laHtml(res.headers.get('content-type'))) return res;

    const nonce = taoNonce();
    const tieuDe = new Headers(res.headers);
    tieuDe.set('content-security-policy', themNonce(csp, nonce));
    const thu = res.headers.get('content-security-policy-report-only');
    if (thu) tieuDe.set('content-security-policy-report-only', themNonce(thu, nonce));
    tieuDe.set('cache-control', 'private, no-cache');
    tieuDe.delete('etag');
    tieuDe.delete('last-modified');
    tieuDe.delete('access-control-allow-origin');

    const moi = new Response(res.body, { status: res.status, statusText: res.statusText, headers: tieuDe });
    return new HTMLRewriter()
      .on('script', {
        element(e) {
          e.setAttribute('nonce', nonce);
        },
      })
      .transform(moi);
  },
};
