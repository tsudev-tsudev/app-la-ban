import type { MiddlewareHandler } from 'hono';
import { rutGonIp } from '../thuan/che-pii';
import { laIdHopLe } from '../thuan/dinh-danh';
import { bamYeuCau, IDEM_DANG_TOI_DA_MS, IDEM_THOI_HAN_MS, nenLuuPhanHoi, quyetDinhIdem, type BanGhiIdem } from '../thuan/idempotency';
import { LoiApi } from '../thuan/loi';
import type { MoiTruongHono } from '../moi-truong';

/**
 * SEC-API API-03: POST ghi dữ liệu BẮT BUỘC có `Idempotency-Key` (UUID / ULID). Chạy SAU middleware đọc body
 * (`c.get('body')` đã kiểm schema). Thiếu D1 -> 503 (không được âm thầm bỏ bảo đảm).
 */
export const idempotency: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const khoa = c.req.header('idempotency-key');
  if (!khoa) throw new LoiApi(428, 'thieu-idempotency-key');
  if (!laIdHopLe(khoa)) throw new LoiApi(400, 'idempotency-key-loi');
  const db = c.env.DB;
  if (!db) throw new LoiApi(503, 'chua-san-sang', { thieu: 'DB' });

  const phamVi = c.get('phamViIdem') ?? `ip:${rutGonIp(c.get('ip'))}`;
  const bam = await bamYeuCau(c.req.method, c.req.path, c.get('body') ?? null);
  const bayGio = Date.now();
  const cu = await db
    .prepare(
      'SELECT bam_yeu_cau, trang_thai, ma_http, noi_dung, loai_noi_dung, tao_luc, het_han FROM idempotency_keys WHERE pham_vi = ? AND khoa = ?',
    )
    .bind(phamVi, khoa)
    .first<BanGhiIdem>();
  const qd = quyetDinhIdem(cu, bam, bayGio);
  if (qd.loai === 'khac-noi-dung') throw new LoiApi(422, 'idempotency-key-da-dung');
  if (qd.loai === 'dang-xu-ly') throw new LoiApi(409, 'dang-xu-ly', undefined, { 'retry-after': '1' });
  if (qd.loai === 'phat-lai') {
    return c.newResponse(qd.noiDung, qd.ma as 200, { 'content-type': qd.loaiNoiDung, 'idempotent-replayed': 'true' });
  }

  // Giành khoá: chỉ ghi đè bản ghi đã hết hạn hoặc 'dang' bị bỏ dở; hai yêu cầu song song -> một bên changes = 0.
  const gianh = await db
    .prepare(
      "INSERT INTO idempotency_keys (pham_vi, khoa, bam_yeu_cau, trang_thai, tao_luc, het_han) VALUES (?, ?, ?, 'dang', ?, ?) " +
        'ON CONFLICT (pham_vi, khoa) DO UPDATE SET bam_yeu_cau = excluded.bam_yeu_cau, trang_thai = excluded.trang_thai, ' +
        'ma_http = NULL, noi_dung = NULL, loai_noi_dung = NULL, tao_luc = excluded.tao_luc, het_han = excluded.het_han ' +
        "WHERE idempotency_keys.het_han <= ? OR (idempotency_keys.trang_thai = 'dang' AND idempotency_keys.tao_luc < ?)",
    )
    .bind(phamVi, khoa, bam, bayGio, bayGio + IDEM_THOI_HAN_MS, bayGio, bayGio - IDEM_DANG_TOI_DA_MS)
    .run();
  if (!gianh.meta.changes) throw new LoiApi(409, 'dang-xu-ly', undefined, { 'retry-after': '1' });

  await next();

  const ma = c.res.status;
  if (nenLuuPhanHoi(ma)) {
    const noiDung = await c.res.clone().text();
    await db
      .prepare(
        "UPDATE idempotency_keys SET trang_thai = 'xong', ma_http = ?, noi_dung = ?, loai_noi_dung = ? WHERE pham_vi = ? AND khoa = ?",
      )
      .bind(ma, noiDung, c.res.headers.get('content-type') ?? 'application/json', phamVi, khoa)
      .run();
  } else {
    await db.prepare('DELETE FROM idempotency_keys WHERE pham_vi = ? AND khoa = ?').bind(phamVi, khoa).run();
  }
};
