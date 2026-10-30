// Pages advanced mode cho compass-admin (S6): đóng gói thành dist/_worker.js. Ba việc:
// 1) kiểm JWT Cloudflare Access TRƯỚC khi trả bất cứ thứ gì (Access là lớp ngoài, đây là lớp trong - bỏ qua Access trực
//    tiếp vào *.pages.dev cũng không thấy SPA);
// 2) /api/* -> Worker la-ban-api /admin/v1/* qua service binding API (prod -> la-ban-api, preview -> la-ban-api-staging);
// 3) SPA tĩnh + header bảo mật + CSP nghiêm (không unsafe-inline / unsafe-eval).
import { kidCua, kiemJwtAccess, tachDs } from '../../../workers/api/src/thuan/access-jwt';
import { cspAdmin, TIEU_DE_ADMIN } from './tieu-de';

type Env = {
  ASSETS: Fetcher;
  API?: Fetcher;
  ACCESS_TEAM?: string;
  ACCESS_AUD?: string;
};

const TRANG_403 =
  '<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
  '<meta name="robots" content="noindex, nofollow"><title>403</title></head><body><main><h1>403</h1>' +
  '<p>Truy cập bị từ chối.</p><p lang="en">Access denied.</p></main></body></html>';

let jwks: { team: string; khoa: JsonWebKey[]; het: number } | null = null;

async function khoaAccess(team: string, kid: string | null): Promise<JsonWebKey[]> {
  const bayGio = Date.now();
  if (jwks && jwks.team === team && bayGio < jwks.het && (!kid || jwks.khoa.some((k) => (k as { kid?: string }).kid === kid))) return jwks.khoa;
  const res = await fetch(`https://${team}/cdn-cgi/access/certs`);
  const j = res.ok ? ((await res.json()) as { keys?: JsonWebKey[] }) : {};
  jwks = { team, khoa: Array.isArray(j.keys) ? j.keys : [], het: bayGio + 10 * 60_000 };
  return jwks.khoa;
}

function voiTieuDe(res: Response, them: Record<string, string> = {}): Response {
  const h = new Headers(res.headers);
  for (const [k, v] of Object.entries({ ...TIEU_DE_ADMIN, ...them })) h.set(k, v);
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
}

function tuChoi(): Response {
  return new Response(TRANG_403, {
    status: 403,
    headers: { ...TIEU_DE_ADMIN, 'content-type': 'text/html; charset=utf-8', 'content-security-policy': "default-src 'none'; frame-ancestors 'none'" },
  });
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === '/robots.txt') {
      return new Response('User-agent: *\nDisallow: /\n', { headers: { ...TIEU_DE_ADMIN, 'content-type': 'text/plain; charset=utf-8' } });
    }
    const team = env.ACCESS_TEAM;
    const aud = tachDs(env.ACCESS_AUD);
    if (!team || aud.length === 0) return tuChoi();
    const token = req.headers.get('cf-access-jwt-assertion');
    try {
      await kiemJwtAccess(token, await khoaAccess(team, token ? kidCua(token) : null), { team, aud, bayGioGiay: Math.floor(Date.now() / 1000) });
    } catch {
      return tuChoi();
    }

    if (url.pathname.startsWith('/api/')) {
      if (!env.API) return new Response(null, { status: 503 });
      const dich = new URL(`/admin/v1/${url.pathname.slice(5)}${url.search}`, 'https://compass-api.internal');
      const res = await env.API.fetch(new Request(dich, req));
      // WebSocket: trả nguyên (dựng lại Response sẽ mất webSocket).
      return res.status === 101 ? res : voiTieuDe(res);
    }

    let res = await env.ASSETS.fetch(req);
    // SPA: đường dẫn không phải tệp -> index.html (router phía client).
    if (res.status === 404 && !/\.[a-z0-9]{1,8}$/i.test(url.pathname)) {
      res = await env.ASSETS.fetch(new Request(new URL('/', url), req));
    }
    const html = (res.headers.get('content-type') ?? '').includes('text/html');
    const bat = /^\/assets\//.test(url.pathname) ? { 'cache-control': 'public, max-age=31536000, immutable' } : { 'cache-control': 'no-store' };
    return voiTieuDe(res, html ? { ...bat, ...cspAdmin() } : bat);
  },
};
