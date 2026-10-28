import { Hono } from 'hono';
import { sucKhoe } from './thuan/suc-khoe';

type Env = { MOI_TRUONG: string; BAN_BUILD?: string };

const app = new Hono<{ Bindings: Env }>();

app.get('/v1/health', (c) => c.json(sucKhoe(c.env.MOI_TRUONG, c.env.BAN_BUILD)));

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
