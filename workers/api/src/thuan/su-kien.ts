// Lô sự kiện bảo mật từ app (Spec §7.6b). Chữ ký lô (khoá thiết bị) kiểm ở middleware xác thực (S2-S3); ở đây chỉ
// kiểm hình dạng + chuẩn hoá. Thời điểm dùng cho cửa sổ rule là giờ SERVER nhận (client không dời được sự kiện).
import { z } from 'zod';
import { laIdHopLe } from './dinh-danh';
import { MAU_LOAI_SU_KIEN } from './nguy-co';

export const LO_TOI_DA = 50;
const LECH_TOI_DA_MS = 7 * 24 * 60 * 60 * 1000;

const giaTriTinHieu = z.union([z.boolean(), z.number().finite(), z.string().max(128), z.null()]);

export const schemaSuKien = z.strictObject({
  event_id: z.string().refine(laIdHopLe, 'id'),
  ts: z.iso.datetime({ offset: true }),
  type: z.string().regex(MAU_LOAI_SU_KIEN),
  severity: z.enum(['info', 'low', 'medium', 'high', 'critical']),
  signals: z.record(z.string().regex(/^[a-z][a-z0-9_]{0,39}$/), giaTriTinHieu).refine((o) => Object.keys(o).length <= 32, 'qua-nhieu'),
  app: z.strictObject({
    version: z.string().regex(/^\d+\.\d+\.\d+$/),
    build: z.number().int().min(1).max(1_000_000_000),
    install_source: z.string().max(64).nullable(),
  }),
  env: z.strictObject({
    os: z.enum(['android', 'ios']),
    os_ver: z.string().max(32),
    model: z.string().max(64),
    emulator: z.boolean(),
    root: z.enum(['no', 'suspected', 'confirmed']),
  }),
});
export type SuKien = z.infer<typeof schemaSuKien>;

export const schemaLoSuKien = z.strictObject({ events: z.array(schemaSuKien).min(1).max(LO_TOI_DA) });

/** Tín hiệu lưu D1: tín hiệu gốc + phiên bản app + giờ client (đã kẹp) - KHÔNG chứa PII (schema đã giới hạn). */
export function tinHieuLuu(e: SuKien, bayGio: number): Record<string, unknown> {
  const tsClient = Date.parse(e.ts);
  const lech = Math.abs(bayGio - tsClient);
  return {
    ...e.signals,
    _app: `${e.app.version}+${e.app.build}`,
    _src: e.app.install_source,
    _env: { root: e.env.root, emulator: e.env.emulator },
    _ts_client: lech <= LECH_TOI_DA_MS ? tsClient : null,
  };
}
