// Worker CHỈ dùng trong test tích hợp: app thật + vài route thử để chạy middleware POST / D1 / DO trong workerd.
import { z } from 'zod';
import { docChuoiAudit, ghiAudit } from '../../src/d1/audit';
import { donDep } from '../../src/d1/don-dep';
import handler, { app, boTuyen } from '../../src/index';
import { capNhatNguyCo } from '../../src/threat/dinh-ky';
import { dongBoLists } from '../../src/threat/dong-bo-lists';
import { xuLySuKien, type NguCanhSuKien, type SuKienVao } from '../../src/threat/dong-co';
import { xoaDem } from '../../src/threat/nap';
import { kiemChuoiAudit } from '../../src/thuan/audit';
import { KHOA_CONG_KHAI } from '../../src/thuan/cau-hinh-tu-xa';
import { taoUlid } from '../../src/thuan/dinh-danh';

export { KhoNonce, GioiHanToc, PhongSoc } from '../../src/index';

let soLanXuLy = 0;

function db(c: { env: { DB?: D1Database } }): D1Database {
  if (!c.env.DB) throw new Error('thiếu DB');
  return c.env.DB;
}

boTuyen.dangKy(
  {
    phuongThuc: 'post',
    duongDan: '/thu/ghi',
    tomTat: 'thu',
    body: z.strictObject({ ten: z.string().min(1).max(20) }),
    phanHoi: z.object({ id: z.string(), ten: z.string() }),
    maThanhCong: 201,
    gioiHan: [{ chieu: 'ip', gioiHan: 4, cuaSoMs: 60_000 }],
  },
  (c, body) => {
    soLanXuLy++;
    return c.json({ id: taoUlid(), ten: body.ten }, 201);
  },
);
boTuyen.dangKy(
  { phuongThuc: 'post', duongDan: '/thu/loi', tomTat: 'thu', body: z.strictObject({}), phanHoi: z.object({}) },
  () => {
    throw new Error('BI_MAT_NOI_BO stack');
  },
);
app.get('/thu/dem', (c) => c.json({ soLanXuLy }));
app.post('/thu/audit', async (c) => {
  const b = (await c.req.json()) as { actor: string; ts: number };
  const d = await ghiAudit(db(c), { id: taoUlid(), actor: b.actor, action: 'thu', target: null, before: null, after: { a: 1 }, ip: null, ts: b.ts });
  return c.json(d);
});
app.get('/thu/audit', async (c) => c.json({ loi: await kiemChuoiAudit(await docChuoiAudit(db(c))) }));
app.post('/thu/don-dep', async (c) => c.json(await donDep(db(c), Number(c.req.query('bayGio')))));
app.post('/thu/nonce', async (c) => {
  const ns = c.env.KHO_NONCE;
  if (!ns) throw new Error('thiếu KHO_NONCE');
  const res = await ns.get(ns.idFromName('thiet-bi:thu')).fetch('https://do/nonce', { method: 'POST', body: await c.req.text() });
  return c.newResponse(res.body, res.status as 200);
});

app.post('/thu/su-kien', async (c) => {
  const b = (await c.req.json()) as { n: NguCanhSuKien; ds: SuKienVao[]; bayGio: number };
  return c.json(await xuLySuKien(c.env, b.n, b.ds, b.bayGio));
});
app.post('/thu/dinh-ky', async (c) => c.json(await capNhatNguyCo(c.env, Number(c.req.query('bayGio') ?? Date.now()))));
app.post('/thu/xoa-dem', (c) => {
  xoaDem();
  return c.json({});
});
// Cloudflare API giả: ghi lại lệnh gọi, trả item theo trạng thái trong bộ nhớ.
app.post('/thu/dong-bo', async (c) => {
  const b = (await c.req.json()) as { bayGio: number; hienCo: { id: string; ip: string; comment?: string }[] };
  const goi: { method: string; body: unknown }[] = [];
  const gia = (async (_u: string, init?: RequestInit) => {
    goi.push({ method: init?.method ?? 'GET', body: init?.body ? JSON.parse(String(init.body)) : null });
    return Response.json({ success: true, result: init?.method === 'GET' ? b.hienCo : { operation_id: 'x' } });
  }) as typeof fetch;
  const env = { ...c.env, MOI_TRUONG: 'prod', CF_LISTS_TOKEN: 't', CF_ACCOUNT_ID: 'a', CF_LIST_ID: 'l' };
  return c.json({ kq: await dongBoLists(env, b.bayGio, gia), goi });
});

// S7c2: thay khoá công khai app-1 / web-1 bằng khoá thử (test giữ khoá bí mật tương ứng ở binding KHOA_KY_*).
app.post('/thu/khoa-cong-khai', async (c) => {
  Object.assign(KHOA_CONG_KHAI, (await c.req.json()) as Record<string, string>);
  return c.json({});
});

export default handler;
