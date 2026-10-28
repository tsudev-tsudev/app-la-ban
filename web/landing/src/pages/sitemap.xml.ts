import type { APIRoute } from 'astro';
import { DUONG_DAN } from '../i18n/noi-dung';

// Sitemap sinh từ DUONG_DAN (nguồn duy nhất) kèm hreflang vi / en.
export const GET: APIRoute = ({ site }) => {
  const goc = site ?? new URL('https://compass.tsudev.com');
  const u = (p: string) => new URL(p, goc).href;
  const dong = Object.values(DUONG_DAN).flatMap((d) =>
    (['vi', 'en'] as const).map(
      (l) =>
        `<url><loc>${u(d[l])}</loc><xhtml:link rel="alternate" hreflang="vi" href="${u(d.vi)}"/><xhtml:link rel="alternate" hreflang="en" href="${u(d.en)}"/></url>`,
    ),
  );
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${dong.join('')}</urlset>\n`,
    { headers: { 'content-type': 'application/xml; charset=utf-8' } },
  );
};
