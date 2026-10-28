import { describe, expect, it } from 'vitest';
import { app, PhongSoc } from '../src/index';
import { sucKhoe } from '../src/thuan/suc-khoe';

const env = { MOI_TRUONG: 'test' };

describe('/v1/health', () => {
  it('trả ok + môi trường + mã build', async () => {
    const res = await app.request('/v1/health', {}, { ...env, BAN_BUILD: 'abc1234' });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, moiTruong: 'test', build: 'abc1234' });
  });

  it('thiếu mã build -> local', () => {
    expect(sucKhoe('dev', undefined).build).toBe('local');
    expect(sucKhoe('dev', '').build).toBe('local');
  });

  it('có header bảo mật', async () => {
    const res = await app.request('/v1/health', {}, env);
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
    expect(res.headers.get('strict-transport-security')).toContain('includeSubDomains');
    expect(res.headers.get('content-security-policy')).toContain("default-src 'none'");
  });

  it('404 dạng problem+json, vẫn có header bảo mật', async () => {
    const res = await app.request('/khong-co', {}, env);
    expect(res.status).toBe(404);
    expect(res.headers.get('content-type')).toContain('application/problem+json');
    expect(res.headers.get('x-frame-options')).toBe('DENY');
  });

  it('robots.txt chặn lập chỉ mục', async () => {
    const res = await app.request('/robots.txt', {}, env);
    expect(await res.text()).toContain('Disallow: /');
  });
});

describe('Durable Object PhongSoc', () => {
  it('trả 501 tới S6', async () => {
    const res = await new PhongSoc().fetch();
    expect(res.status).toBe(501);
  });
});
