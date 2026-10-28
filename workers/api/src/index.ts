import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import { donDep } from './d1/don-dep';
import type { Env, MoiTruongHono } from './moi-truong';
import { chanTheoThucThi } from './mw/chan';
import { coBan, traVanDe, xuLyLoi } from './mw/co-ban';
import { ghiLog } from './mw/ghi-log';
import { gioiHanThoIp } from './mw/gioi-han';
import { nguonChoPhep } from './thuan/cors';
import { laLuotHangNgay } from './thuan/don-dep';
import { sucKhoe } from './thuan/suc-khoe';
import { capNhatNguyCo } from './threat/dinh-ky';
import { dongBoLists } from './threat/dong-bo-lists';
import { BoTuyen } from './tuyen';

export { KhoNonce } from './do/kho-nonce';
export { GioiHanToc } from './do/gioi-han-toc';
export { PhongSoc } from './do/phong-soc';
export type { Env } from './moi-truong';

export const app = new Hono<MoiTruongHono>();
app.use('*', coBan);
app.use('*', chanTheoThucThi);
app.use('*', gioiHanThoIp);

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

// API không cần được lập chỉ mục.
app.get('/robots.txt', (c) => c.text('User-agent: *\nDisallow: /\n'));

// Mọi lỗi trả dạng RFC 7807 chung chung, không lộ stack (SEC-API API-04).
app.onError(xuLyLoi);
app.notFound((c) => traVanDe(c, 404));

export default {
  fetch: app.fetch,
  async scheduled(su: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    if (!env.DB) return;
    const viec: [string, () => Promise<unknown>][] = [
      ['nguy-co', () => capNhatNguyCo(env)],
      ['dong-bo-lists', () => dongBoLists(env)],
    ];
    if (laLuotHangNgay(su.scheduledTime)) viec.push(['don-dep', () => donDep(env.DB as D1Database)]);
    for (const [ten, chay] of viec) {
      ctx.waitUntil(
        chay().then(
          (kq) => ghiLog('info', ten, { kq }),
          (e: unknown) => ghiLog('error', `${ten}-loi`, { loi: String(e) }),
        ),
      );
    }
  },
} satisfies ExportedHandler<Env>;
