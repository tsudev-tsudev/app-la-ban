// POST /v1/app/su-co (S10b, QUYET_DINH Q49): app gửi lô báo cáo sự cố bằng yêu cầu ký thiết bị (chỉ khi người dùng bật
// "Gửi báo cáo sự cố"). Không đi vào Threat Engine - chỉ lưu D1 90 ngày + điểm Analytics Engine để đếm.
import type { Hono } from 'hono';
import { z } from 'zod';
import type { MoiTruongHono } from './moi-truong';
import { taoUlid } from './thuan/dinh-danh';
import { LoiApi } from './thuan/loi';
import { cheThongDiep, dauVetSuCo, LO_SU_CO_TOI_DA, schemaLoSuCo } from './thuan/su-co-app';
import type { BoTuyen } from './tuyen';

export function dangKySuCoApp(_app: Hono<MoiTruongHono>, boTuyen: BoTuyen): void {
  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/app/su-co',
      tomTat: `Lô báo cáo sự cố app (<= ${LO_SU_CO_TOI_DA}) đã ký bằng khoá thiết bị - chỉ khi người dùng bật`,
      body: schemaLoSuCo,
      phanHoi: z.object({ nhan: z.number().int() }),
      maThanhCong: 202,
      idempotent: false,
      bodyToiDa: 96 * 1024,
      xacThuc: true,
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 10, cuaSoMs: 3_600_000 }],
    },
    async (c, body) => {
      const db = c.env.DB;
      if (!db) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
      const thietBi = c.get('thietBi') as string;
      const bayGio = Date.now();
      const lenh: D1PreparedStatement[] = [];
      for (const s of body.suCo) {
        const dv = await dauVetSuCo(s.kieu, s.nganXep);
        lenh.push(
          db
            .prepare(
              'INSERT INTO app_crashes (id, device_id, fingerprint, kind, type, message, stack, app_version, occurred_at, ts) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            )
            .bind(
              taoUlid(),
              thietBi,
              dv,
              s.loai,
              s.kieu,
              cheThongDiep(s.thongDiep),
              s.nganXep,
              s.phienBan,
              Math.min(s.luc, bayGio),
              bayGio,
            ),
        );
        c.env.SU_KIEN?.writeDataPoint({
          indexes: ['su-co-app'],
          blobs: ['su-co-app', s.loai, s.phienBan, dv],
          doubles: [1],
        });
      }
      await db.batch(lenh);
      return c.json({ nhan: lenh.length }, 202);
    },
  );
}
