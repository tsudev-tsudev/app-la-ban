// SOC - Sự cố app (S10b, QUYET_DINH Q49): nhóm theo dấu vết (viewer: không PII), chi tiết mẫu kèm ngăn xếp (analyst).
import type { Hono } from 'hono';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { LoiApi } from '../thuan/loi';
import { tyLeKhongLoi } from '../thuan/su-co-app';
import { canQuyen } from './xac-thuc';

const NGAY = 86_400_000;

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function soNgay(c: Ngu): number {
  const n = Number(c.req.query('ngay') ?? '7');
  return [1, 7, 30, 90].includes(n) ? n : 7;
}

export function dangKySuCoAppSoc(r: Hono<MoiTruongHono>): void {
  r.get('/su-co-app', canQuyen('su-co:xem'), async (c) => {
    const ngay = soNgay(c);
    const tu = Date.now() - ngay * NGAY;
    const d = db(c);
    const [nhom, hoatDong, coLoi] = await Promise.all([
      d
        .prepare(
          `SELECT fingerprint, kind, type, count(*) AS so_lan, count(DISTINCT device_id) AS so_thiet_bi, min(ts) AS dau, max(ts) AS cuoi,
             group_concat(DISTINCT app_version) AS phien_ban
           FROM app_crashes WHERE ts >= ? GROUP BY fingerprint ORDER BY so_thiet_bi DESC, so_lan DESC LIMIT 100`,
        )
        .bind(tu)
        .all<Record<string, unknown>>(),
      d.prepare('SELECT count(*) AS n FROM devices WHERE last_seen >= ?').bind(tu).first<{ n: number }>(),
      d
        .prepare('SELECT count(DISTINCT device_id) AS n FROM app_crashes WHERE ts >= ?')
        .bind(tu)
        .first<{ n: number }>(),
    ]);
    return c.json({
      ngay,
      thietBiHoatDong: hoatDong?.n ?? 0,
      thietBiCoLoi: coLoi?.n ?? 0,
      tyLeKhongLoi: tyLeKhongLoi(hoatDong?.n ?? 0, coLoi?.n ?? 0),
      nhom: nhom.results,
    });
  });

  r.get('/su-co-app/:dauVet', canQuyen('su-co:chi-tiet'), async (c) => {
    const dv = c.req.param('dauVet');
    if (!/^[0-9a-f]{16}$/.test(dv)) throw new LoiApi(400, 'dau-vet-sai');
    const { results } = await db(c)
      .prepare(
        'SELECT id, device_id, kind, type, message, stack, app_version, occurred_at, ts FROM app_crashes WHERE fingerprint = ? ORDER BY ts DESC LIMIT 20',
      )
      .bind(dv)
      .all<Record<string, unknown>>();
    if (!results.length) throw new LoiApi(404, 'khong-co');
    return c.json({ dauVet: dv, mau: results });
  });
}
