import { describe, expect, it } from 'vitest';
import { laTrangKhieuNai, maLoiTuPhanHoi, NGUON_TURNSTILE, refTuQuery, themTurnstile } from '../src/lib/khieu-nai';

describe('S7c1: form khiếu nại', () => {
  it('chỉ 2 trang khiếu nại (có / không gạch cuối)', () => {
    expect(['/khieu-nai/', '/khieu-nai', '/en/appeal/', '/en/appeal'].every(laTrangKhieuNai)).toBe(true);
    expect(['/', '/quyen-rieng-tu/', '/khieu-nai/x/', '/en/'].some(laTrangKhieuNai)).toBe(false);
  });

  it('mã lỗi Worker -> thông báo', () => {
    expect(maLoiTuPhanHoi(404, 'ref-khong-thay')).toBe('ref-khong-thay');
    expect(maLoiTuPhanHoi(409, 'da-co-khieu-nai')).toBe('da-co-khieu-nai');
    expect(maLoiTuPhanHoi(403, 'turnstile')).toBe('turnstile');
    expect(maLoiTuPhanHoi(429, 'gioi-han')).toBe('qua-nhieu');
    expect(maLoiTuPhanHoi(422, 'sai-du-lieu')).toBe('du-lieu');
    expect(maLoiTuPhanHoi(503, undefined)).toBe('chung');
  });

  it('REF điền sẵn từ ?ref=, bỏ giá trị lạ', () => {
    expect(refTuQuery('?ref=ref-0000k-7qz1a')).toBe('REF-0000K-7QZ1A');
    expect(refTuQuery('?ref=<script>')).toBe('');
    expect(refTuQuery('')).toBe('');
  });

  it('CSP: thêm đúng một origin vào script-src + frame-src, không đụng chỉ thị khác, không từ khoá nguy hiểm', () => {
    const goc = "default-src 'none'; script-src 'self'; frame-ancestors 'none'; connect-src 'self' https://compass-api.tsudev.com";
    const moi = themTurnstile(goc);
    expect(moi).toBe(`default-src 'none'; script-src 'self' ${NGUON_TURNSTILE}; frame-ancestors 'none'; connect-src 'self' https://compass-api.tsudev.com; frame-src ${NGUON_TURNSTILE}`);
    expect(themTurnstile(moi)).toBe(moi);
    expect(themTurnstile("frame-src 'none'; script-src 'strict-dynamic'")).toBe(`frame-src ${NGUON_TURNSTILE}; script-src 'strict-dynamic' ${NGUON_TURNSTILE}`);
    expect(moi).not.toMatch(/unsafe-|\*/);
  });
});
