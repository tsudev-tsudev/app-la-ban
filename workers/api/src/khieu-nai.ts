// S7c1 - form khiếu nại công khai của landing (Spec §8.2-6): mã REF trên màn khoá app + nội dung + email tuỳ chọn, chống
// bot bằng Turnstile (siteverify ở ĐÂY - token phía trình duyệt chỉ là tín hiệu). Chỉ nhận cho thiết bị đang bị hạn chế /
// cấm; mỗi thiết bị một khiếu nại đang mở. SOC duyệt ở src/admin/khieu-nai.ts.
import type { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import type { MoiTruongHono } from './moi-truong';
import { traVanDe } from './mw/co-ban';
import { ghiLog } from './mw/ghi-log';
import { NGUON_WEB, nguonChoPhep } from './thuan/cors';
import { taoUlid } from './thuan/dinh-danh';
import { duoiTuRef, dsTenMien, kiemTurnstile, SchemaGuiKhieuNai } from './thuan/khieu-nai';
import { LoiApi } from './thuan/loi';
import type { BoTuyen } from './tuyen';

const SITEVERIFY = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

async function siteverify(biMat: string, token: string, ip: string): Promise<unknown> {
  const form = new FormData();
  form.append('secret', biMat);
  form.append('response', token);
  if (ip) form.append('remoteip', ip);
  const res = await fetch(SITEVERIFY, { method: 'POST', body: form, signal: AbortSignal.timeout(5000) });
  return res.json();
}

export function dangKyKhieuNai(app: Hono<MoiTruongHono>, boTuyen: BoTuyen): void {
  app.use('/v1/khieu-nai', cors({ origin: (o) => nguonChoPhep(o, NGUON_WEB), allowMethods: ['POST'], allowHeaders: ['content-type'], maxAge: 86400 }));

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/khieu-nai',
      tomTat: 'Khiếu nại hạn chế thiết bị từ landing (mã REF + Turnstile)',
      body: SchemaGuiKhieuNai,
      phanHoi: z.object({ ok: z.literal(true) }),
      maThanhCong: 201,
      // Token Turnstile dùng một lần thay cho Idempotency-Key (trình duyệt không cần tự sinh khoá).
      idempotent: false,
      bodyToiDa: 8 * 1024,
      // Một luật / chiều (khoá DO theo chiều + route): 6 lần / giờ / IP đủ cho gõ sai REF vài lần.
      gioiHan: [{ chieu: 'ip', gioiHan: 6, cuaSoMs: 60 * 60_000 }],
    },
    async (c, b) => {
      if (!nguonChoPhep(c.req.header('origin'), NGUON_WEB)) return traVanDe(c, 403);
      const biMat = c.env.TURNSTILE_SECRET;
      const db = c.env.DB;
      if (!biMat || !db) throw new LoiApi(503, 'chua-cau-hinh');
      const ip = c.get('ip');
      let kq: { hopLe: boolean; loi: string[] };
      try {
        kq = kiemTurnstile(await siteverify(biMat, b.turnstile, ip), dsTenMien(c.env.TURNSTILE_TEN_MIEN));
      } catch (e) {
        ghiLog('error', 'turnstile-loi', { loi: String(e) });
        throw new LoiApi(503, 'turnstile-loi');
      }
      if (!kq.hopLe) throw new LoiApi(403, 'turnstile', { loi: kq.loi.join(',').slice(0, 80) });

      const duoi = duoiTuRef(b.ref);
      if (!duoi) throw new LoiApi(422, 'ref-loi');
      // Hậu tố 10 ký tự ngẫu nhiên (50 bit) + Turnstile + giới hạn IP -> dò mã REF không khả thi. Thiết bị không bị hạn
      // chế trả giống mã sai (không lộ mã nào đang tồn tại).
      const tb = await db
        .prepare("SELECT id FROM devices WHERE substr(id, 17) = ? AND status IN ('restricted', 'banned') LIMIT 1")
        .bind(duoi)
        .first<{ id: string }>();
      if (!tb) throw new LoiApi(404, 'ref-khong-thay');
      const bayGio = Date.now();
      const thucThi = await db
        .prepare("SELECT id FROM enforcements WHERE target_type = 'device' AND target_value = ? AND revoked_at IS NULL AND expires_at > ? ORDER BY created_at DESC LIMIT 1")
        .bind(tb.id, bayGio)
        .first<{ id: string }>();
      try {
        await db
          .prepare('INSERT INTO appeals (id, device_id, enforcement_id, message, status, ts, contact, lang, ip) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
          .bind(taoUlid(bayGio), tb.id, thucThi?.id ?? null, b.noiDung, 'open', bayGio, b.lienHe || null, b.ngonNgu, ip || null)
          .run();
      } catch (e) {
        if (/UNIQUE/i.test(String(e))) throw new LoiApi(409, 'da-co-khieu-nai');
        throw e;
      }
      return c.json({ ok: true as const }, 201);
    },
  );
}
