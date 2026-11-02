// S3 (SEC-NET) - route của kênh app:
//   GET  /v1/config  (công khai)        gói Remote Config ký Ed25519 nằm sẵn ở KV; app tự kiểm chữ ký (pin, cập nhật, cờ)
//   GET  /v1/status  (phiên + chữ ký)   trạng thái thiết bị + mã REF + bản APK mới nhất (R0 latest.json)
//   POST /v1/events  (phiên + chữ ký)   lô sự kiện bảo mật -> Threat Engine
import type { Hono } from 'hono';
import { z } from 'zod';
import type { MoiTruongHono, Ngu } from './moi-truong';
import { traVanDe } from './mw/co-ban';
import { asnCua, docQuaColo, nen } from './mw/dich-vu';
import { gioiHanDocCongKhai } from './mw/gioi-han';
import { dongBoLists } from './threat/dong-bo-lists';
import { ghiSuKien } from './threat/dong-co';
import { docLatest, docPhienBanApp, GOI_APP_TOI_DA, GOP_LOAI_MS, KHOA_KV_APP, LOAI_CHI_SERVER, refChoTrangThai, type BanMoi } from './thuan/kenh';
import { doBuoc } from './thuan/do-tre';
import { goiCauHinhHopLe } from './thuan/khien-web';
import { LoiApi } from './thuan/loi';
import { schemaLoSuKien, tinHieuLuu, LO_TOI_DA } from './thuan/su-kien';
import type { BoTuyen } from './tuyen';

const LATEST_DEM_MS = 5 * 60 * 1000;
let demLatest: { luc: number; ban: BanMoi | null } | null = null;

/**
 * Bản APK mới nhất (R2 `android/latest.json`), đệm 5 phút theo isolate + Cache API của colo (R3c: isolate mới trong colo
 * đọc ~1 ms thay vì R2 ~200 ms). Khoá cache theo host của Worker nên prod / staging không lẫn. Lỗi -> null (không chặn
 * /v1/status).
 */
async function banMoiNhat(c: Ngu, bayGio: number): Promise<BanMoi | null> {
  if (demLatest && bayGio - demLatest.luc < LATEST_DEM_MS) return demLatest.ban;
  let ban: BanMoi | null;
  try {
    const tho = await docQuaColo(c, 'android/latest.json', LATEST_DEM_MS / 1000, async () => {
      const vat = await c.env.CDN?.get('android/latest.json');
      return vat ? vat.text() : null;
    });
    ban = tho === null ? null : docLatest(tho);
  } catch {
    ban = null;
  }
  demLatest = { luc: bayGio, ban };
  return ban;
}

const schemaTrangThai = z.enum(['clean', 'suspicious', 'restricted', 'banned']);

export function dangKyKenh(app: Hono<MoiTruongHono>, boTuyen: BoTuyen): void {
  // Gói đã ký nằm ở KV; Worker chỉ kiểm hình dạng rồi trả nguyên văn. KV bị ghi bậy -> app từ chối chữ ký, giữ cấu hình cũ.
  app.get(
    '/v1/config',
    async (c, next) => {
      c.set('tuyen', '/v1/config');
      await next();
    },
    gioiHanDocCongKhai,
    async (c) => {
      const tho = await doBuoc(c.get('dongHo'), 'luuTru', () =>
        docQuaColo(c, 'cau-hinh/app', 60, async () => (await c.env.CAU_HINH?.get(KHOA_KV_APP, { cacheTtl: 60 })) ?? null),
      );
      const goi = goiCauHinhHopLe(tho, GOI_APP_TOI_DA);
      if (!goi) return traVanDe(c, 404);
      return c.body(goi, 200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=60' });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'get',
      duongDan: '/v1/status',
      tomTat: 'Trạng thái thiết bị (kể cả bị cấm) + mã REF khiếu nại + bản APK mới nhất',
      phanHoi: z.object({
        trangThai: schemaTrangThai,
        mucTin: z.string(),
        ref: z.string().nullable(),
        banMoi: z.object({ phienBan: z.string(), maPhienBan: z.number().int() }).nullable(),
      }),
      xacThuc: 'ke-ca-bi-cam',
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 30, cuaSoMs: 60_000 }],
    },
    async (c) => {
      const thietBi = c.get('thietBi') as string;
      const trangThai = schemaTrangThai.catch('clean').parse(c.get('trangThai'));
      // App gọi khi mở / quay lại (<= 15 phút / lần): cập nhật lần thấy cuối (mẫu số tỷ lệ không lỗi ở SOC) + phiên bản
      // sau nâng cấp. Ghi nền - không làm chậm phản hồi.
      const pb = docPhienBanApp(c.req.header('x-app-version'));
      const db = c.env.DB;
      if (db) {
        nen(
          c,
          db
            .prepare('UPDATE devices SET last_seen = ?, app_version = coalesce(?, app_version), build = coalesce(?, build) WHERE id = ?')
            .bind(Date.now(), pb?.phienBan ?? null, pb?.build ?? null, thietBi)
            .run(),
          'thiet-bi-thay',
        );
      }
      return c.json({
        trangThai,
        mucTin: c.get('mucTin') ?? 'unverified',
        ref: refChoTrangThai(trangThai, thietBi),
        banMoi: await doBuoc(c.get('dongHo'), 'luuTru', () => banMoiNhat(c, Date.now())),
      });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/events',
      tomTat: `Lô sự kiện bảo mật (<= ${LO_TOI_DA}) đã ký bằng khoá thiết bị -> Threat Engine (chống trùng event_id)`,
      body: schemaLoSuKien,
      phanHoi: z.object({ nhan: z.number().int(), trung: z.number().int() }),
      maThanhCong: 202,
      idempotent: false,
      bodyToiDa: 64 * 1024,
      xacThuc: true,
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 20, cuaSoMs: 60_000 }],
    },
    async (c, body) => {
      if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
      if (body.events.some((e) => LOAI_CHI_SERVER.has(e.type))) throw new LoiApi(422, 'loai-chi-server');
      const bayGio = Date.now();
      const lo = await doBuoc(c.get('dongHo'), 'd1', () =>
        ghiSuKien(
          c.env,
          {
            thietBi: c.get('thietBi') as string,
            ip: c.get('ip') || null,
            asn: asnCua(c),
            country: c.req.header('cf-ipcountry') ?? null,
            gopLoaiMs: GOP_LOAI_MS,
          },
          body.events.map((e) => ({ id: e.event_id, type: e.type, severity: e.severity, signals: tinHieuLuu(e, bayGio) })),
          bayGio,
        ),
      );
      // Rule + điểm + SOC realtime chạy sau phản hồi (R3c) - lỗi chỉ ghi log, sự kiện đã nằm trong D1.
      nen(c, lo.tiep().then((kq) => (kq.canDongBo ? dongBoLists(c.env) : undefined)), 'threat-nen');
      return c.json({ nhan: lo.nhan, trung: lo.trung }, 202);
    },
  );
}
