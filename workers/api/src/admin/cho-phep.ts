// Allow-list từ SOC (R2 - miễn trừ thiết bị duyệt store): xem / thêm (có hạn, lý do, passkey) / gỡ. Mọi thay đổi ghi audit,
// xoá đệm isolate (hiệu lực ngay ở isolate này, <= 3 s ở isolate khác) + đồng bộ Cloudflare List (bỏ IP được cho phép).
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from '../mw/ghi-log';
import { dongBoLists } from '../threat/dong-bo-lists';
import { xoaDem } from '../threat/nap';
import { ASN_GOOGLE, chuanHoaChoPhep, HAN_CHO_PHEP_MS, SchemaGoChoPhep, SchemaThemChoPhep } from '../thuan/cho-phep';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { cheIp, type VaiTro } from '../thuan/soc';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

const qt = (c: Ngu) => c.get('quanTri') as { email: string; vaiTro: VaiTro };

function dongBoNen(c: Ngu): void {
  xoaDem();
  try {
    c.executionCtx.waitUntil(dongBoLists(c.env).then(() => undefined, (e: unknown) => ghiLog('error', 'dong-bo-lists', { loi: String(e) })));
  } catch {
    // Ngoài workerd (test đơn vị) không có executionCtx.
  }
}

type Dong = { id: string; target_type: string; target_value: string; reason: string; created_by: string; created_at: number; expires_at: number | null; revoked_at: number | null };

export function dangKyChoPhep(r: Hono<MoiTruongHono>): void {
  r.get('/cho-phep', canQuyen('luat:xem'), async (c) => {
    const bayGio = Date.now();
    const tatCa = c.req.query('trangThai') === 'tat-ca';
    const { results } = await db(c)
      .prepare(
        `SELECT id, target_type, target_value, reason, created_by, created_at, expires_at, revoked_at FROM allow_list${tatCa ? '' : ' WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > ?1)'} ORDER BY created_at DESC LIMIT 200`,
      )
      .bind(...(tatCa ? [] : [bayGio]))
      .all<Dong>();
    const vt = qt(c).vaiTro;
    return c.json({
      ds: results.map((x) => ({ ...x, target_value: x.target_type === 'ip' ? cheIp(x.target_value, vt) : x.target_value, hieuLuc: x.revoked_at === null && (x.expires_at === null || x.expires_at > bayGio) })),
      asnGoogle: ASN_GOOGLE,
    });
  });

  r.post('/cho-phep/them', canQuyen('cho-phep'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaThemChoPhep);
    const { dich, loi } = chuanHoaChoPhep(b.dich);
    if (loi.length) throw new LoiApi(400, 'dich-loi', loi);
    const d = db(c);
    const bayGio = Date.now();
    const het = bayGio + HAN_CHO_PHEP_MS[b.thoiHan];
    const toi = qt(c).email;
    const ids = dich.map((_, i) => taoUlid(bayGio + i));
    await d.batch(
      dich.map((x, i) =>
        d
          .prepare('INSERT INTO allow_list (id, target_type, target_value, reason, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
          .bind(ids[i], x.loai, x.giaTri, b.lyDo, toi, bayGio, het),
      ),
    );
    await ghiAudit(d, {
      id: taoUlid(bayGio + dich.length),
      actor: toi,
      action: 'cho-phep:them',
      target: dich.length === 1 ? `${dich[0]?.loai}:${dich[0]?.giaTri}` : `allow_list:${dich.length}`,
      before: null,
      after: { dich, het, lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    dongBoNen(c);
    return c.json({ ok: true, ids, het }, 201);
  });

  r.post('/cho-phep/go', canQuyen('cho-phep'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaGoChoPhep);
    const d = db(c);
    const bayGio = Date.now();
    const dong = await d.prepare('SELECT target_type, target_value FROM allow_list WHERE id = ? AND revoked_at IS NULL').bind(b.id).first<{ target_type: string; target_value: string }>();
    if (!dong) throw new LoiApi(404, 'khong-thay');
    await d.prepare('UPDATE allow_list SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL').bind(bayGio, b.id).run();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: qt(c).email,
      action: 'cho-phep:go',
      target: `${dong.target_type}:${dong.target_value}`,
      before: { id: b.id },
      after: { lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    dongBoNen(c);
    return c.json({ ok: true });
  });
}
