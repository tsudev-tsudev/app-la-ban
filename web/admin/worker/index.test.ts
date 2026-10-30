// Pages _worker của compass-admin: không JWT Access hợp lệ -> 403 cho MỌI đường dẫn; /api/* -> /admin/v1/* qua binding;
// SPA fallback; header CSP nghiêm.
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { AccessGia } from '../../../workers/api/test/tich-hop/soc-gia';
import worker from './index';

let access: AccessGia;
const goiApi: Request[] = [];
const env = () => ({
  ACCESS_TEAM: access.team,
  ACCESS_AUD: access.aud,
  API: {
    fetch: async (r: Request) => {
      goiApi.push(r);
      return Response.json({ ok: true });
    },
  },
  ASSETS: {
    fetch: async (r: Request) => {
      const p = new URL(r.url).pathname;
      if (p === '/' || p === '/index.html') return new Response('<!doctype html><title>SOC</title>', { headers: { 'content-type': 'text/html' } });
      if (p === '/assets/a.js') return new Response('x', { headers: { 'content-type': 'text/javascript' } });
      return new Response('nf', { status: 404 });
    },
  },
});

beforeAll(async () => {
  access = await AccessGia.tao();
  vi.stubGlobal('fetch', async () => access.jwks());
});
afterEach(() => {
  goiApi.length = 0;
});

const goi = async (duong: string, jwt?: string) =>
  worker.fetch(new Request(`https://compass-admin.tsudev.com${duong}`, { headers: jwt ? { 'cf-access-jwt-assertion': jwt } : {} }), env() as never);

describe('_worker compass-admin', () => {
  it('không JWT / JWT sai aud -> 403 cả SPA lẫn API', async () => {
    expect((await goi('/')).status).toBe(403);
    expect((await goi('/api/toi')).status).toBe(403);
    expect((await goi('/', await access.jwt({ email: 'a@b.vn', aud: ['khac'] }))).status).toBe(403);
    expect(goiApi).toHaveLength(0);
  });

  it('robots.txt luôn chặn lập chỉ mục', async () => {
    expect(await (await goi('/robots.txt')).text()).toContain('Disallow: /');
  });

  it('JWT đúng: SPA + fallback + CSP; /api đổi sang /admin/v1', async () => {
    const jwt = await access.jwt({ email: 'a@b.vn' });
    const trang = await goi('/thiet-bi', jwt);
    expect(trang.status).toBe(200);
    expect(await trang.text()).toContain('<title>SOC</title>');
    const csp = trang.headers.get('content-security-policy') ?? '';
    expect(csp).toContain("script-src 'self'");
    expect(csp).not.toContain('unsafe');
    expect(trang.headers.get('x-frame-options')).toBe('DENY');
    expect((await goi('/assets/a.js', jwt)).headers.get('cache-control')).toContain('immutable');
    expect((await goi('/khong-co.js', jwt)).status).toBe(404);
    const api = await goi('/api/thiet-bi?trangThai=banned', jwt);
    expect(api.status).toBe(200);
    expect(new URL(goiApi[0]?.url ?? '').pathname + new URL(goiApi[0]?.url ?? '').search).toBe('/admin/v1/thiet-bi?trangThai=banned');
    expect(goiApi[0]?.headers.get('cf-access-jwt-assertion')).toBe(jwt);
  });
});
