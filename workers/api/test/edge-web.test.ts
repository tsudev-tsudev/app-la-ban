// S8: bẫy quét (honeypot) + báo cáo CSP - phần thuần.
import { describe, expect, it } from 'vitest';
import { khopBay, nenBao } from '../src/thuan/bay';
import { laLoaiBaoCao, phanTichBaoCaoCsp } from '../src/thuan/bao-cao-csp';
import { nguonChoPhep, NGUON_WEB } from '../src/thuan/cors';

describe('khopBay', () => {
  it('khớp đường dẫn máy quét, không chạm route thật', () => {
    expect(khopBay('/.env')).toBe('/.env');
    expect(khopBay('/.env.production')).toBe('/.env');
    expect(khopBay('/.git/config')).toBe('/.git');
    expect(khopBay('/wp-login.php')).toBe('/wp-');
    expect(khopBay('/WordPress/wp-admin/')).toBe('/wordpress');
    expect(khopBay('/xmlrpc.php')).toBe('*.php');
    expect(khopBay('/a/b/index.php7')).toBe('*.php7');
    expect(khopBay('/backup.sql')).toBe('*.sql');
    expect(khopBay('/default.aspx')).toBe('*.aspx');
    for (const p of ['/v1/health', '/v1/web/csp', '/robots.txt', '/', '/v1/events', '/v1/devices/register', '/v1/x.json']) {
      expect(khopBay(p)).toBeNull();
    }
  });
});

describe('nenBao', () => {
  it('một lần / IP / khoảng, IP khác độc lập, hết khoảng báo lại', () => {
    const b = new Map<string, number>();
    expect(nenBao(b, '1.1.1.1', 0)).toBe(true);
    expect(nenBao(b, '1.1.1.1', 9_999)).toBe(false);
    expect(nenBao(b, '2.2.2.2', 5_000)).toBe(true);
    expect(nenBao(b, '1.1.1.1', 10_000)).toBe(true);
  });
  it('bảng đầy -> dọn khoá cũ, toàn khoá mới thì xoá sạch (bộ nhớ có trần)', () => {
    const b = new Map<string, number>();
    nenBao(b, 'a', 0, 10, 2);
    nenBao(b, 'b', 5, 10, 2);
    expect(nenBao(b, 'c', 12, 10, 2)).toBe(true);
    expect([...b.keys()].sort()).toEqual(['b', 'c']);
    expect(nenBao(b, 'd', 13, 10, 2)).toBe(true);
    expect([...b.keys()]).toEqual(['d']);
  });
});

describe('phanTichBaoCaoCsp', () => {
  it('report-uri (application/csp-report): chuẩn hoá, bỏ query + PII trong URL', () => {
    const kq = phanTichBaoCaoCsp(
      JSON.stringify({
        'csp-report': {
          'document-uri': 'https://compass.tsudev.com/tai-ve?email=a@b.c#x',
          'violated-directive': 'script-src-elem',
          'effective-directive': 'script-src-elem',
          'blocked-uri': 'https://evil.example/x.js?token=bi-mat',
          disposition: 'report',
          'source-file': 'https://compass.tsudev.com/js/a.js',
        },
      }),
    );
    expect(kq).toEqual([
      { chiThi: 'script-src-elem', biChan: 'https://evil.example', trang: '/tai-ve', cheDo: 'report', nguon: 'https://compass.tsudev.com' },
    ]);
  });
  it('Reporting API (application/reports+json): lọc csp-violation, tối đa 10', () => {
    const mot = { type: 'csp-violation', body: { documentURL: 'https://compass.tsudev.com/', effectiveDirective: 'script-src-elem', blockedURL: 'inline', disposition: 'enforce' } };
    const kq = phanTichBaoCaoCsp(JSON.stringify([...Array(12).fill(mot), { type: 'deprecation', body: {} }]));
    expect(kq).toHaveLength(10);
    expect(kq[0]).toEqual({ chiThi: 'script-src-elem', biChan: 'inline', trang: '/', cheDo: 'enforce', nguon: '' });
  });
  it('blocked trusted-types-sink / eval / scheme / rác', () => {
    const r = (blockedURL: string, effectiveDirective = 'require-trusted-types-for') =>
      phanTichBaoCaoCsp(JSON.stringify([{ type: 'csp-violation', body: { blockedURL, effectiveDirective } }]))[0];
    expect(r('trusted-types-sink')?.biChan).toBe('trusted-types-sink');
    expect(r('eval', 'script-src')?.biChan).toBe('eval');
    expect(r('data', 'img-src')?.biChan).toBe('data');
    expect(r('chrome-extension://abc/x.js', 'script-src')?.biChan).toBe('chrome-extension:');
    expect(r('<<rác>>', 'script-src x y')).toMatchObject({ biChan: 'khac', chiThi: 'script-src' });
    expect(r('', '')).toBeUndefined();
  });
  it('JSON hỏng / hình dạng lạ / quá lớn -> []', () => {
    expect(phanTichBaoCaoCsp('{')).toEqual([]);
    expect(phanTichBaoCaoCsp('{"a":1}')).toEqual([]);
    expect(phanTichBaoCaoCsp('[1,null,{"type":"csp-violation","body":[]}]')).toEqual([]);
    expect(phanTichBaoCaoCsp(' '.repeat(17 * 1024))).toEqual([]);
  });
  it('loại nội dung', () => {
    expect(laLoaiBaoCao('application/csp-report')).toBe(true);
    expect(laLoaiBaoCao('application/reports+json; charset=utf-8')).toBe(true);
    expect(laLoaiBaoCao('text/plain')).toBe(false);
    expect(laLoaiBaoCao(undefined)).toBe(false);
  });
  it('CORS báo cáo chỉ cho landing + admin', () => {
    expect(nguonChoPhep('https://compass.tsudev.com', NGUON_WEB)).toBe('https://compass.tsudev.com');
    expect(nguonChoPhep('https://compass.tsudev.com.evil.io', NGUON_WEB)).toBeNull();
  });
});
