// S9 - route cho lớp khiên web (SEC-WEB-SHIELD): cấu hình mức ký số, tín hiệu công cụ nhà phát triển, tài nguyên URL ký.
import type { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import type { MoiTruongHono } from './moi-truong';
import { traVanDe } from './mw/co-ban';
import { ghiLog } from './mw/ghi-log';
import { gioiHanRoute } from './mw/gioi-han';
import { xuLySuKien } from './threat/dong-co';
import { nenBao } from './thuan/bay';
import { NGUON_WEB, nguonChoPhep } from './thuan/cors';
import { taoUlid } from './thuan/dinh-danh';
import { goiCauHinhHopLe, KHOA_KV_KHIEN, schemaTinHieuWeb, suKienTuTinHieu } from './thuan/khien-web';
import { kiemUrl, laHotlink, maxAgeGiay } from './thuan/url-ky';
import type { BoTuyen } from './tuyen';

const daBao = new Map<string, number>();

export function dangKyKhienWeb(app: Hono<MoiTruongHono>, boTuyen: BoTuyen): void {
  const corsWeb = (phuongThuc: string[]) =>
    cors({ origin: (o) => nguonChoPhep(o, NGUON_WEB), allowMethods: phuongThuc, allowHeaders: ['content-type'], maxAge: 86400 });
  app.use('/v1/web/cau-hinh', corsWeb(['GET']));
  app.use('/v1/web/signals', corsWeb(['POST']));

  // Gói cấu hình nằm sẵn ở KV đã ký; Worker chỉ kiểm hình dạng rồi trả nguyên văn (trình duyệt tự kiểm chữ ký).
  app.get(
    '/v1/web/cau-hinh',
    async (c, next) => {
      c.set('tuyen', '/v1/web/cau-hinh');
      await next();
    },
    gioiHanRoute([{ chieu: 'ip', gioiHan: 60, cuaSoMs: 60_000 }]),
    async (c) => {
      const goi = goiCauHinhHopLe((await c.env.CAU_HINH?.get(KHOA_KV_KHIEN, { cacheTtl: 300 })) ?? null);
      if (!goi) return traVanDe(c, 404);
      return c.body(goi, 200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=300' });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/web/signals',
      tomTat: 'Tín hiệu khiên web (công cụ nhà phát triển) từ landing / admin -> Threat Engine theo IP',
      body: schemaTinHieuWeb,
      phanHoi: z.object({ ok: z.literal(true) }),
      maThanhCong: 202,
      idempotent: false,
      bodyToiDa: 1024,
      gioiHan: [{ chieu: 'ip', gioiHan: 10, cuaSoMs: 60_000 }],
    },
    (c, body) => {
      // Chỉ trang của mình gửi (trình duyệt luôn kèm Origin cho fetch CORS); thiếu / lạ -> 403.
      if (!nguonChoPhep(c.req.header('origin'), NGUON_WEB)) return traVanDe(c, 403);
      const ip = c.get('ip');
      if (c.env.DB && ip && nenBao(daBao, ip, Date.now(), 60_000)) {
        const viec = xuLySuKien(c.env, { thietBi: null, ip, country: c.req.header('cf-ipcountry') ?? null }, [suKienTuTinHieu(body, taoUlid())]).catch(
          (e: unknown) => ghiLog('error', 'tin-hieu-web-loi', { loi: String(e) }),
        );
        try {
          c.executionCtx.waitUntil(viec);
        } catch {
          // Ngoài workerd (test đơn vị) không có executionCtx.
        }
      }
      return c.json({ ok: true as const }, 202);
    },
  );

  // SH-05: tài nguyên R2 (tiền tố `ky/`) chỉ qua URL ký có hạn; thiếu bí mật -> 503 (đóng khi lỗi).
  app.get('/v1/tn/*', async (c) => {
    c.set('tuyen', '/v1/tn/*');
    const biMat = c.env.KHOA_URL_KY;
    if (!biMat || !c.env.CDN) return traVanDe(c, 503);
    if (laHotlink(c.req.header('sec-fetch-site'), c.req.header('referer'), NGUON_WEB)) return traVanDe(c, 403, 'hotlink');
    const khoa = c.req.path.slice('/v1/tn/'.length);
    const bayGio = Date.now();
    const het = c.req.query('het');
    const kq = await kiemUrl(biMat, khoa, het, c.req.query('ky'), bayGio);
    if (kq === 'sai') return traVanDe(c, 403);
    if (kq === 'het-han') return traVanDe(c, 410);
    const vat = await c.env.CDN.get(`ky/${khoa}`);
    if (!vat) return traVanDe(c, 404);
    return c.body(vat.body, 200, {
      'content-type': vat.httpMetadata?.contentType ?? 'application/octet-stream',
      'cache-control': `private, max-age=${maxAgeGiay(Number(het), bayGio)}`,
      'content-disposition': 'inline',
    });
  });
}
