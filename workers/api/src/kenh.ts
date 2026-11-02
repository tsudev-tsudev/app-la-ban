// S3 (SEC-NET) - route của kênh app:
//   GET  /v1/config  (công khai)        gói Remote Config ký Ed25519 nằm sẵn ở KV; app tự kiểm chữ ký (pin, cập nhật, cờ)
//   GET  /v1/status  (phiên + chữ ký)   trạng thái thiết bị + mã REF + bản APK mới nhất (R0 latest.json)
//   POST /v1/events  (phiên + chữ ký)   lô sự kiện bảo mật -> Threat Engine
import type { Hono } from 'hono';
import { z } from 'zod';
import type { Env, MoiTruongHono } from './moi-truong';
import { traVanDe } from './mw/co-ban';
import { asnCua, nen } from './mw/dich-vu';
import { gioiHanRoute } from './mw/gioi-han';
import { dongBoLists } from './threat/dong-bo-lists';
import { xuLySuKien } from './threat/dong-co';
import { docLatest, docPhienBanApp, GOI_APP_TOI_DA, GOP_LOAI_MS, KHOA_KV_APP, LOAI_CHI_SERVER, refChoTrangThai, type BanMoi } from './thuan/kenh';
import { goiCauHinhHopLe } from './thuan/khien-web';
import { LoiApi } from './thuan/loi';
import { schemaLoSuKien, tinHieuLuu, LO_TOI_DA } from './thuan/su-kien';
import type { BoTuyen } from './tuyen';

const LATEST_DEM_MS = 5 * 60 * 1000;
let demLatest: { luc: number; ban: BanMoi | null } | null = null;

/** Bản APK mới nhất (R2 `android/latest.json`), đệm 5 phút theo isolate. Lỗi R2 -> null (không chặn /v1/status). */
async function banMoiNhat(env: Env, bayGio: number): Promise<BanMoi | null> {
  if (demLatest && bayGio - demLatest.luc < LATEST_DEM_MS) return demLatest.ban;
  let ban: BanMoi | null;
  try {
    const vat = await env.CDN?.get('android/latest.json');
    ban = vat ? docLatest(await vat.text()) : null;
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
    gioiHanRoute([{ chieu: 'ip', gioiHan: 60, cuaSoMs: 60_000 }]),
    async (c) => {
      const goi = goiCauHinhHopLe((await c.env.CAU_HINH?.get(KHOA_KV_APP, { cacheTtl: 60 })) ?? null, GOI_APP_TOI_DA);
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
        banMoi: await banMoiNhat(c.env, Date.now()),
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
      const kq = await xuLySuKien(
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
      );
      if (kq.canDongBo) nen(c, dongBoLists(c.env), 'dong-bo-lists');
      return c.json({ nhan: kq.nhan, trung: kq.trung }, 202);
    },
  );
}
