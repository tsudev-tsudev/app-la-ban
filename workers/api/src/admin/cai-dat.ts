// Cài đặt SOC toàn hệ thống (S7b): Super Admin bật / tắt thuỷ vân, ép độ đậm tối thiểu, ép che khi rời cửa sổ cho MỌI
// người xem. Đọc kèm /toi (mọi vai trò cần để vẽ khung); ghi cần step-up + lý do, có audit chuỗi băm (QUYET_DINH Q41).
import type { Hono } from 'hono';
import { z } from 'zod';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { docCaiDatSoc, dongCaiDatSoc, SchemaCaiDatSoc, type CaiDatSoc } from '../thuan/soc';
import { canQuyen, canStepUp } from './xac-thuc';

const SchemaGhi = z.strictObject({ caiDat: SchemaCaiDatSoc, ghiChu: z.string().trim().min(10).max(500) });

export async function napCaiDatSoc(db: D1Database): Promise<CaiDatSoc> {
  const { results } = await db.prepare('SELECT key, value FROM soc_settings').all<{ key: string; value: string }>();
  return docCaiDatSoc(results);
}

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

export function dangKyCaiDat(r: Hono<MoiTruongHono>): void {
  r.get('/cai-dat-soc', canQuyen('cai-dat-soc'), async (c) => {
    const d = db(c);
    const [caiDat, lichSu] = await Promise.all([
      napCaiDatSoc(d),
      d
        .prepare("SELECT actor, after, ts FROM audit_logs WHERE action = 'cai-dat-soc:sua' ORDER BY ts DESC LIMIT 20")
        .all<{ actor: string; after: string; ts: number }>(),
    ]);
    return c.json({ caiDat, lichSu: lichSu.results.map((x) => ({ ...x, after: JSON.parse(x.after) as unknown })) });
  });

  r.post('/cai-dat-soc', canQuyen('cai-dat-soc'), canStepUp, async (c) => {
    if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
    const b = phanTichBody(await c.req.text(), SchemaGhi);
    const d = db(c);
    const truoc = await napCaiDatSoc(d);
    const bayGio = Date.now();
    const ai = (c.get('quanTri') as { email: string }).email;
    await d.batch(
      dongCaiDatSoc(b.caiDat).map((x) =>
        d
          .prepare('INSERT INTO soc_settings (key, value, updated_by, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_by = excluded.updated_by, updated_at = excluded.updated_at')
          .bind(x.key, x.value, ai, bayGio),
      ),
    );
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: ai,
      action: 'cai-dat-soc:sua',
      target: 'soc_settings',
      before: truoc,
      after: { ...b.caiDat, ghiChu: b.ghiChu },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, caiDat: b.caiDat });
  });
}
