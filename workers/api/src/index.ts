import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { nguonChoPhep } from './thuan/cors';
import { sucKhoe } from './thuan/suc-khoe';
import { ganTieuDe } from './thuan/tieu-de';

export { KhoNonce, GioiHanToc, PhongSoc } from './do/khung';

// Binding khai báo ở wrangler.toml (N2); S1 trở đi mới dùng D1 / KV / R2 / DO / Analytics Engine.
export type Env = {
  MOI_TRUONG: string;
  BAN_BUILD?: string;
  DB?: D1Database;
  CAU_HINH?: KVNamespace;
  CDN?: R2Bucket;
  NHAT_KY?: R2Bucket;
  KHO_NONCE?: DurableObjectNamespace;
  GIOI_HAN_TOC?: DurableObjectNamespace;
  PHONG_SOC?: DurableObjectNamespace;
  SU_KIEN?: AnalyticsEngineDataset;
};

const app = new Hono<{ Bindings: Env }>();

app.use('*', async (c, next) => {
  await next();
  c.res = new Response(c.res.body, { status: c.res.status, statusText: c.res.statusText, headers: ganTieuDe(c.res.headers) });
});

// Trang compass-status đọc health từ trình duyệt.
app.use('/v1/health', cors({ origin: (o) => nguonChoPhep(o), allowMethods: ['GET'], maxAge: 600 }));
app.get('/v1/health', (c) => c.json(sucKhoe(c.env.MOI_TRUONG, c.env.BAN_BUILD)));

// API không cần được lập chỉ mục.
app.get('/robots.txt', (c) => c.text('User-agent: *\nDisallow: /\n'));

// Mọi lỗi trả dạng RFC 7807, không lộ stack.
app.onError((_err, c) =>
  c.json({ type: 'about:blank', title: 'Internal Server Error', status: 500 }, 500, {
    'content-type': 'application/problem+json',
  }),
);
app.notFound((c) =>
  c.json({ type: 'about:blank', title: 'Not Found', status: 404 }, 404, {
    'content-type': 'application/problem+json',
  }),
);

export default app;
