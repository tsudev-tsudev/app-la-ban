import { describe, expect, it } from 'vitest';
import app from '../src/index';

describe('/v1/health', () => {
  it('trả ok + môi trường', async () => {
    const res = await app.request('/v1/health', {}, { MOI_TRUONG: 'test' });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, moiTruong: 'test', build: 'local' });
  });

  it('404 dạng problem+json', async () => {
    const res = await app.request('/khong-co', {}, { MOI_TRUONG: 'test' });
    expect(res.status).toBe(404);
    expect(res.headers.get('content-type')).toContain('application/problem+json');
  });
});
