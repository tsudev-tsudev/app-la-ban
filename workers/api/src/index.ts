import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import { taoAdmin } from './admin';
import { phucVuBanDo } from './ban-do';
import { donDep } from './d1/don-dep';
import { dangKyDinhDanh } from './dinh-danh';
import { dangKyKenh } from './kenh';
import { dangKyKhienWeb } from './khien-web';
import { dangKyKhieuNai } from './khieu-nai';
import type { Env, MoiTruongHono } from './moi-truong';
import { bayQuet } from './mw/bay';
import { chanTheoThucThi } from './mw/chan';
import { coBan, traVanDe, xuLyLoi } from './mw/co-ban';
import { ghiLog } from './mw/ghi-log';
import { gioiHanRoute, gioiHanThoIp } from './mw/gioi-han';
import { BAO_CAO_TOI_DA, laLoaiBaoCao, phanTichBaoCaoCsp } from './thuan/bao-cao-csp';
import { NGUON_WEB, nguonChoPhep } from './thuan/cors';
import { LoiApi } from './thuan/loi';
import { laLuotHangNgay } from './thuan/don-dep';
import { laLuotSaoLuu } from './thuan/sao-luu';
import { sucKhoe } from './thuan/suc-khoe';
import { capNhatNguyCo } from './threat/dinh-ky';
import { dongBoLists } from './threat/dong-bo-lists';
import { BoTuyen } from './tuyen';
import { xuatNhatKy } from './van-hanh/nhat-ky';
import { saoLuuD1 } from './van-hanh/sao-luu';
import { baoVanHanh, kiemDotBien } from './van-hanh/canh-bao';

export { KhoNonce } from './do/kho-nonce';
export { GioiHanToc } from './do/gioi-han-toc';
export { PhongSoc } from './do/phong-soc';
export type { Env } from './moi-truong';

export const app = new Hono<MoiTruongHono>();
app.use('*', coBan);
app.use('*', chanTheoThucThi);
app.use('*', gioiHanThoIp);
app.use('*', bayQuet);

// Trang compass-status đọc health từ trình duyệt.
app.use('/v1/health', cors({ origin: (o) => nguonChoPhep(o), allowMethods: ['GET'], maxAge: 600 }));

export const boTuyen = new BoTuyen(app);
boTuyen.dangKy(
  {
    phuongThuc: 'get',
    duongDan: '/v1/health',
    tomTat: 'Tình trạng dịch vụ và mã build đang phục vụ',
    phanHoi: z.object({ ok: z.literal(true), moiTruong: z.string(), build: z.string() }),
  },
  (c) => c.json(sucKhoe(c.env.MOI_TRUONG, c.env.BAN_BUILD)),
);

// Báo cáo vi phạm CSP từ landing / admin (S8, CSP-01). Trình duyệt tự gửi (report-uri: no-cors; Reporting API: có
// preflight) nên route này đứng ngoài BoTuyen: không zod / idempotency, chỉ giới hạn kích thước + tốc độ, ghi Analytics Engine.
app.use('/v1/web/csp', cors({ origin: (o) => nguonChoPhep(o, NGUON_WEB), allowMethods: ['POST'], allowHeaders: ['content-type'], maxAge: 86400 }));
app.post(
  '/v1/web/csp',
  async (c, next) => {
    c.set('tuyen', '/v1/web/csp');
    await next();
  },
  gioiHanRoute([{ chieu: 'ip', gioiHan: 30, cuaSoMs: 60_000 }]),
  async (c) => {
    if (!laLoaiBaoCao(c.req.header('content-type'))) throw new LoiApi(415, 'can-json');
    if (Number(c.req.header('content-length') ?? '0') > BAO_CAO_TOI_DA) throw new LoiApi(413, 'qua-lon');
    const vanBan = await c.req.text();
    const quocGia = c.req.header('cf-ipcountry') ?? '';
    for (const b of phanTichBaoCaoCsp(vanBan)) {
      c.env.SU_KIEN?.writeDataPoint({ indexes: ['csp'], blobs: ['csp', b.chiThi, b.biChan, b.trang, b.cheDo, b.nguon, quocGia], doubles: [1] });
    }
    return c.body(null, 204);
  },
);

dangKyKhienWeb(app, boTuyen);
dangKyDinhDanh(app, boTuyen);
dangKyKenh(app, boTuyen);
dangKyKhieuNai(app, boTuyen);
// Admin SOC (S6): Access JWT + vai trò + phiên passkey - xem src/admin/.
app.route('/admin/v1', taoAdmin());

// API không cần được lập chỉ mục.
app.get('/robots.txt', (c) => c.text('User-agent: *\nDisallow: /\n'));

// Mọi lỗi trả dạng RFC 7807 chung chung, không lộ stack (SEC-API API-04).
app.onError(xuLyLoi);
app.notFound((c) => traVanDe(c, 404));

export default {
  // /ban-do/* (A7a) đi đường nhẹ, ngoài middleware API - xem src/ban-do.ts.
  fetch(req: Request, env: Env, ctx: ExecutionContext): Response | Promise<Response> {
    if (new URL(req.url).pathname.startsWith('/ban-do/')) return phucVuBanDo(req, env, ctx);
    return app.fetch(req, env, ctx);
  },
  async scheduled(su: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    if (!env.DB) return;
    const viec: [string, () => Promise<unknown>][] = [
      ['nguy-co', () => capNhatNguyCo(env)],
      ['dong-bo-lists', () => dongBoLists(env)],
      ['nhat-ky', () => xuatNhatKy(env)],
      ['dot-bien', () => kiemDotBien(env)],
    ];
    if (laLuotHangNgay(su.scheduledTime)) viec.push(['don-dep', () => donDep(env.DB as D1Database)]);
    // 'thu:sao-luu' = kích tay khi diễn tập (`wrangler dev --remote --test-scheduled`, /__scheduled?cron=thu:sao-luu):
    // handler scheduled chỉ Cloudflare gọi được, cron thật không bao giờ có chuỗi này.
    if (laLuotSaoLuu(su.scheduledTime) || su.cron === 'thu:sao-luu') viec.push(['sao-luu', () => saoLuuD1(env)]);
    for (const [ten, chay] of viec) {
      ctx.waitUntil(
        chay().then(
          (kq) => ghiLog('info', ten, { kq }),
          (e: unknown) => {
            ghiLog('error', `${ten}-loi`, { loi: String(e) });
            return baoVanHanh(env, ten, String(e));
          },
        ),
      );
    }
  },
} satisfies ExportedHandler<Env>;
