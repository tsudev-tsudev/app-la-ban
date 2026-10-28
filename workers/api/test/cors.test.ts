import { describe, expect, it } from 'vitest';
import app from '../src/index';
import { nguonChoPhep } from '../src/thuan/cors';

describe('nguonChoPhep', () => {
  it('chỉ khớp nguyên chuỗi', () => {
    expect(nguonChoPhep('https://compass-status.tsudev.com')).toBe('https://compass-status.tsudev.com');
    expect(nguonChoPhep('https://compass-status.tsudev.com.evil.io')).toBeNull();
    expect(nguonChoPhep('http://compass-status.tsudev.com')).toBeNull();
    expect(nguonChoPhep('https://evil.io')).toBeNull();
    expect(nguonChoPhep(undefined)).toBeNull();
  });
});

describe('CORS /v1/health', () => {
  const env = { MOI_TRUONG: 'test' };
  it('origin hợp lệ được phản chiếu', async () => {
    const res = await app.request('/v1/health', { headers: { origin: 'https://compass-status.tsudev.com' } }, env);
    expect(res.headers.get('access-control-allow-origin')).toBe('https://compass-status.tsudev.com');
  });
  it('origin lạ không có header CORS', async () => {
    const res = await app.request('/v1/health', { headers: { origin: 'https://evil.io' } }, env);
    expect(res.headers.get('access-control-allow-origin')).toBeNull();
  });
});
