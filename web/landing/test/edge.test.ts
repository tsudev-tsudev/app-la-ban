import { describe, expect, it } from 'vitest';
import { laHtml, taoNonce, themNonce } from '../edge/csp';
import worker from '../edge/_worker';
import { tuyenWorker } from '../edge/tuyen.mjs';

const N = 'AAECAwQFBgcICQoLDA0ODw==';

describe('taoNonce', () => {
  it('16 byte -> base64 24 ký tự, mỗi lần khác nhau', () => {
    expect(taoNonce((b) => b.map((_, i) => i))).toBe(N);
    const a = taoNonce();
    expect(a).toMatch(/^[A-Za-z0-9+/]{22}==$/);
    expect(taoNonce()).not.toBe(a);
  });
});

describe('themNonce', () => {
  it('thêm vào script-src, giữ chỉ thị khác nguyên văn', () => {
    expect(themNonce("default-src 'none'; script-src 'self'; style-src 'self'", N)).toBe(
      `default-src 'none'; script-src 'self' 'nonce-${N}'; style-src 'self'`,
    );
  });
  it('thay nonce cũ, phủ cả script-src-elem', () => {
    expect(themNonce("script-src 'nonce-cu' 'strict-dynamic'; script-src-elem 'self'", N)).toBe(
      `script-src 'strict-dynamic' 'nonce-${N}'; script-src-elem 'self' 'nonce-${N}'`,
    );
  });
  it('thiếu script-src -> tạo từ default-src (bỏ none)', () => {
    expect(themNonce("default-src 'none'; img-src 'self'", N)).toBe(`default-src 'none'; img-src 'self'; script-src 'nonce-${N}'`);
    expect(themNonce("default-src 'self'", N)).toBe(`default-src 'self'; script-src 'self' 'nonce-${N}'`);
  });
  it('nonce lạ (chèn chỉ thị) -> ném lỗi', () => {
    expect(() => themNonce("script-src 'self'", "x'; script-src *")).toThrow();
  });
  it('không bao giờ sinh unsafe-inline / unsafe-eval', () => {
    expect(themNonce("default-src 'none'", N)).not.toMatch(/unsafe/);
  });
});

describe('laHtml', () => {
  it('chỉ text/html', () => {
    expect(laHtml('text/html; charset=utf-8')).toBe(true);
    expect(laHtml('application/javascript')).toBe(false);
    expect(laHtml(null)).toBe(false);
  });
});

describe('_routes.json', () => {
  it('trang HTML qua worker; tài sản tĩnh + tệp gốc không phải HTML thì không', () => {
    const r = tuyenWorker([
      { ten: '_astro', thuMuc: true },
      { ten: 'tai-ve', thuMuc: true },
      { ten: 'en', thuMuc: true },
      { ten: 'fonts', thuMuc: true },
      { ten: 'js', thuMuc: true },
      { ten: '.well-known', thuMuc: true },
      { ten: 'index.html', thuMuc: false },
      { ten: '404.html', thuMuc: false },
      { ten: 'og.png', thuMuc: false },
      { ten: 'sitemap.xml', thuMuc: false },
      { ten: '_headers', thuMuc: false },
      { ten: '_worker.js', thuMuc: false },
    ]);
    expect(r).toEqual({ version: 1, include: ['/*'], exclude: ['/_astro/*', '/.well-known/*', '/fonts/*', '/js/*', '/og.png', '/sitemap.xml'] });
  });
  it('quá 100 luật -> lỗi', () => {
    expect(() => tuyenWorker(Array.from({ length: 100 }, (_, i) => ({ ten: `a${i}.png`, thuMuc: false })))).toThrow(/100/);
  });
});

// HTMLRewriter chỉ có trong workerd: giả lập tối thiểu để kiểm luồng header (gắn nonce vào thẻ script kiểm trên preview).
class GiaHTMLRewriter {
  static the: string[] = [];
  on(chon: string, xuLy: { element(e: { setAttribute(t: string, g: string): void }): void }) {
    xuLy.element({ setAttribute: (t, g) => GiaHTMLRewriter.the.push(`${chon}[${t}=${g}]`) });
    return this;
  }
  transform(res: Response) {
    return res;
  }
}
(globalThis as Record<string, unknown>).HTMLRewriter = GiaHTMLRewriter;

describe('_worker', () => {
  const CSP = "default-src 'none'; script-src 'self'";
  const RO = "default-src 'none'; script-src 'strict-dynamic'";
  const kho = (ct: string, them: Record<string, string> = {}) => {
    const da: Request[] = [];
    return {
      da,
      env: {
        ASSETS: {
          fetch: async (r: Request) => {
            da.push(r);
            return new Response('<script src="/js/a.js"></script>', {
              headers: { 'content-type': ct, 'content-security-policy': CSP, 'content-security-policy-report-only': RO, etag: '"x"', 'access-control-allow-origin': '*', ...them },
            });
          },
        },
      },
    };
  };
  it('HTML: nonce cùng giá trị ở 2 header + thẻ script; bỏ ETag / ACAO / header điều kiện', async () => {
    GiaHTMLRewriter.the = [];
    const k = kho('text/html; charset=utf-8');
    const res = await worker.fetch(new Request('https://compass.tsudev.com/', { headers: { 'if-none-match': '"x"' } }), k.env);
    const n = /'nonce-([^']+)'/.exec(res.headers.get('content-security-policy') ?? '')?.[1];
    expect(n).toMatch(/^[A-Za-z0-9+/]{22}==$/);
    expect(res.headers.get('content-security-policy-report-only')).toBe(`${RO} 'nonce-${n}'`);
    expect(GiaHTMLRewriter.the).toEqual([`script[nonce=${n}]`]);
    expect(res.headers.get('etag')).toBeNull();
    expect(res.headers.get('access-control-allow-origin')).toBeNull();
    expect(res.headers.get('cache-control')).toBe('private, no-cache');
    expect(k.da[0]?.headers.get('if-none-match')).toBeNull();
  });
  it('/w/<token> -> trang tĩnh /w/, noindex; đường dẫn /w/ lạ giữ nguyên', async () => {
    const k = kho('text/html; charset=utf-8');
    const res = await worker.fetch(new Request('https://compass.tsudev.com/w/AQ_-x9/'), k.env);
    expect(k.da[0]?.url).toBe('https://compass.tsudev.com/w/');
    expect(res.headers.get('x-robots-tag')).toBe('noindex');
    await worker.fetch(new Request('https://compass.tsudev.com/w/a/b'), k.env);
    expect(k.da[1]?.url).toBe('https://compass.tsudev.com/w/a/b');
  });
  it('không phải HTML -> trả nguyên', async () => {
    const k = kho('image/png');
    const res = await worker.fetch(new Request('https://compass.tsudev.com/og.png'), k.env);
    expect(res.headers.get('content-security-policy')).toBe(CSP);
    expect(res.headers.get('etag')).toBe('"x"');
  });
});
