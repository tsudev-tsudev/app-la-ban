// S2 - định danh thiết bị + attestation + phiên (SEC-ID). Luồng:
//   1. POST /v1/device/challenge {installationId}        -> thách thức 5 phút (DO KhoNonce, dùng một lần)
//   2. POST /v1/device/register  {khoá, chữ ký, token}    -> thiết bị + mức tin cậy + phiên (JWT 15 phút + refresh)
//   3. POST /v1/session/refresh  {refresh, ts, nonce, ký}  -> xoay refresh; dùng lại token đã xoay -> thu hồi cả chuỗi
//   4. POST /v1/device/attest    (phiên) {thách thức mới}  -> xác minh lại định kỳ / trước thao tác nhạy cảm
import type { Hono } from 'hono';
import { z } from 'zod';
import { giaiMaToken, LoiDichVu } from './attest/google';
import { kiemChuKyThietBi, kyJwt, napKhoaPhien, ngauNhienB64url, nhapKhoaThietBi, sha256B64url, type KhoaPhien } from './attest/khoa';
import type { Env, MoiTruongHono, Ngu } from './moi-truong';
import { baoSuKien, goiNonce, nen } from './mw/dich-vu';
import { ghiLog } from './mw/ghi-log';
import { lienKetThietBi } from './threat/lien-ket';
import { sha256Hex } from './thuan/bam';
import { taoUlid } from './thuan/dinh-danh';
import { LoiApi } from './thuan/loi';
import { chuoiDangKy, chuoiLamMoi, chuoiXacThuc } from './thuan/ma-hoa';
import { laNonceHopLe } from './thuan/nonce';
import { ACCESS_TTL_MS, LECH_TS_MS, quyetDinhLamMoi, REFRESH_TTL_MS, taoClaim, type DongPhien } from './thuan/phien';
import { danhGiaPhanQuyet, MUC_TIN, type KetQuaDanhGia, type MucTin } from './thuan/play-integrity';
import type { BoTuyen } from './tuyen';

export const THACH_THUC_TTL_MS = 5 * 60 * 1000;

const b64url = (min: number, max: number) => z.string().min(min).max(max).regex(/^[A-Za-z0-9_-]+$/);
const installationId = z.uuid();
const thachThuc = z.string().refine(laNonceHopLe, 'thach-thuc');
const goi = z.string().max(100).regex(/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/);
const tokenIntegrity = z.string().min(16).max(12_000).regex(/^[A-Za-z0-9_.=-]+$/).nullable();

const schemaPhien = z.object({ accessToken: z.string(), hetHan: z.number().int(), refreshToken: z.string() });
const schemaMuc = z.enum(MUC_TIN);
const schemaTrangThai = z.enum(['clean', 'suspicious', 'restricted', 'banned']);

function canDb(env: Env): D1Database {
  if (!env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return env.DB;
}

async function canKhoaPhien(env: Env): Promise<KhoaPhien> {
  if (!env.KHOA_PHIEN) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'KHOA_PHIEN' });
  return napKhoaPhien(env.KHOA_PHIEN);
}

const tenThach = (bamCaiDat: string) => `thach:${bamCaiDat}`;

const dsCauHinh = (s: string | undefined) =>
  (s ?? '')
    .split(',')
    .map((x) => x.trim().toLowerCase())
    .filter(Boolean);

/** Play Integrity -> mức tin cậy. Không token / dịch vụ lỗi -> 'unverified' (ID-05). */
async function danhGiaAttest(c: Ngu, goiApp: string, token: string | null, chuoi: string): Promise<KetQuaDanhGia> {
  const dsGoi = dsCauHinh(c.env.PI_GOI);
  if (!dsGoi.includes(goiApp)) return { loai: 'tu-choi', lyDo: 'goi' };
  if (!token) return { loai: 'muc', muc: 'unverified', lyDo: ['khong-token'], tinHieu: {} };
  const bayGio = Date.now();
  try {
    const pq = await giaiMaToken(c.env, goiApp, token, bayGio);
    if (!pq) return { loai: 'muc', muc: 'failed', lyDo: ['token-hong'], tinHieu: {} };
    return danhGiaPhanQuyet(pq, { dsGoi, dsChungChi: dsCauHinh(c.env.PI_CHUNG_CHI), requestHash: await sha256B64url(chuoi), bayGio });
  } catch (e) {
    const lyDo = e instanceof LoiDichVu ? e.lyDo : 'loi-khac';
    ghiLog('warn', 'play-integrity-khong-kiem-duoc', { lyDo });
    c.env.SU_KIEN?.writeDataPoint({ indexes: ['attest'], blobs: ['attest-loi', lyDo], doubles: [1] });
    return { loai: 'muc', muc: 'unverified', lyDo: [lyDo], tinHieu: {} };
  }
}

async function ghiIp(c: Ngu, db: D1Database, thietBi: string, bayGio: number): Promise<void> {
  const ip = c.get('ip');
  if (!ip) return;
  const asn = (c.req.raw as { cf?: { asn?: number } }).cf?.asn ?? null;
  await db
    .prepare(
      'INSERT INTO device_ips (device_id, ip, asn, country, first_seen, last_seen) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT (device_id, ip) DO UPDATE SET last_seen = excluded.last_seen, count = count + 1, asn = excluded.asn',
    )
    .bind(thietBi, ip, asn, c.req.header('cf-ipcountry') ?? null, bayGio, bayGio)
    .run();
}

async function capPhien(env: Env, k: KhoaPhien, db: D1Database, p: { thietBi: string; jkt: string; muc: string; bayGio: number; chuoi?: string }) {
  const id = taoUlid(p.bayGio);
  const refreshToken = ngauNhienB64url(32);
  const lenh = db
    .prepare('INSERT INTO sessions (id, device_id, issued_at, expires_at, refresh_hash, chuoi) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(id, p.thietBi, p.bayGio, p.bayGio + REFRESH_TTL_MS, await sha256Hex(refreshToken), p.chuoi ?? id);
  const accessToken = await kyJwt(k, taoClaim({ moiTruong: env.MOI_TRUONG, thietBi: p.thietBi, phien: id, jkt: p.jkt, muc: p.muc, bayGio: p.bayGio }));
  return { id, lenh, phien: { accessToken, hetHan: p.bayGio + ACCESS_TTL_MS, refreshToken } };
}

export function dangKyDinhDanh(_app: Hono<MoiTruongHono>, boTuyen: BoTuyen): void {
  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/device/challenge',
      tomTat: 'Cấp thách thức dùng một lần (5 phút) cho đăng ký / xác minh lại thiết bị',
      body: z.strictObject({ installationId }),
      phanHoi: z.object({ thachThuc: z.string(), hetHanMs: z.number().int() }),
      idempotent: false,
      bodyToiDa: 256,
      gioiHan: [{ chieu: 'ip', gioiHan: 30, cuaSoMs: 60_000 }],
    },
    async (c, body) => {
      const thach = ngauNhienB64url(32);
      await goiNonce(c.env, tenThach(await sha256Hex(body.installationId)), '/cap', { nonce: thach, ttlMs: THACH_THUC_TTL_MS });
      return c.json({ thachThuc: thach, hetHanMs: THACH_THUC_TTL_MS });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/device/register',
      tomTat: 'Đăng ký thiết bị: khoá P-256 phần cứng + chữ ký thách thức + Play Integrity -> phiên',
      body: z.strictObject({
        installationId,
        khoaCongKhai: b64url(100, 140),
        thachThuc,
        chuKy: b64url(80, 100),
        nenTang: z.enum(['android', 'ios']),
        goi,
        integrityToken: tokenIntegrity,
        thongTin: z.strictObject({
          heDieuHanh: z.string().max(32),
          model: z.string().max(64),
          phienBan: z.string().max(32),
          build: z.number().int().min(1).max(1_000_000_000),
          ngonNgu: z.string().max(16),
        }),
      }),
      phanHoi: z.object({ thietBiId: z.string(), trangThai: schemaTrangThai, mucTin: schemaMuc, phien: schemaPhien }),
      maThanhCong: 201,
      idempotent: false,
      gioiHan: [{ chieu: 'ip', gioiHan: 10, cuaSoMs: 60_000 }],
    },
    async (c, b) => {
      const db = canDb(c.env);
      const k = await canKhoaPhien(c.env);
      const bamCaiDat = await sha256Hex(b.installationId);
      if (!(await goiNonce(c.env, tenThach(bamCaiDat), '/dung', { nonce: b.thachThuc }))) throw new LoiApi(401, 'thach-thuc');
      const khoa = await nhapKhoaThietBi(b.khoaCongKhai);
      if (!khoa) throw new LoiApi(422, 'khoa-sai');
      const chuoi = chuoiDangKy(b.thachThuc, b.installationId, b.khoaCongKhai);
      if (!(await kiemChuKyThietBi(khoa.khoa, chuoi, b.chuKy))) throw new LoiApi(401, 'chu-ky');

      const cu = await db.prepare('SELECT id, status FROM devices WHERE installation_id_hash = ?').bind(bamCaiDat).first<{ id: string; status: string }>();
      if (cu?.status === 'banned') throw new LoiApi(403, 'thiet-bi-bi-cam');

      // iOS: App Attest làm ở I1 (Q33) -> chưa xác minh.
      const dg = b.nenTang === 'android' ? await danhGiaAttest(c, b.goi, b.integrityToken, chuoi) : ({ loai: 'muc', muc: 'unverified', lyDo: ['ios-i1'], tinHieu: {} } as const);
      if (dg.loai === 'tu-choi') {
        baoSuKien(c, cu?.id ?? null, 'ATTEST_FAIL', 'high', { ly_do: dg.lyDo, buoc: 'dang-ky' });
        throw new LoiApi(403, 'attest-sai', { lyDo: dg.lyDo });
      }

      const bayGio = Date.now();
      const t = b.thongTin;
      const tinHieu = JSON.stringify({ ...dg.tinHieu, ly_do: dg.lyDo.join(',') || null });
      const dong = await db
        .prepare(
          `INSERT INTO devices (id, installation_id_hash, public_key, platform, os_version, model, app_version, build, locale, first_seen, last_seen,
             attestation_level, attested_at, attest_signals, country)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT (installation_id_hash) DO UPDATE SET public_key = excluded.public_key, os_version = excluded.os_version,
             model = excluded.model, app_version = excluded.app_version, build = excluded.build, locale = excluded.locale,
             last_seen = excluded.last_seen, attestation_level = excluded.attestation_level, attested_at = excluded.attested_at,
             attest_signals = excluded.attest_signals, country = excluded.country
           RETURNING id, status`,
        )
        .bind(taoUlid(bayGio), bamCaiDat, b.khoaCongKhai, b.nenTang, t.heDieuHanh, t.model, t.phienBan, t.build, t.ngonNgu, bayGio, bayGio,
          dg.muc, bayGio, tinHieu, c.req.header('cf-ipcountry') ?? null)
        .first<{ id: string; status: 'clean' | 'suspicious' | 'restricted' | 'banned' }>();
      if (!dong) throw new Error('không ghi được thiết bị');
      // Khoá đổi trên cùng bản cài (Keystore bị xoá / khôi phục máy): mọi phiên cũ của thiết bị bị thu hồi.
      if (cu) {
        await db.prepare("UPDATE sessions SET revoked_at = ?, ly_do_thu_hoi = 'dang-ky-lai' WHERE device_id = ? AND revoked_at IS NULL").bind(bayGio, dong.id).run();
      }
      const ph = await capPhien(c.env, k, db, { thietBi: dong.id, jkt: khoa.jkt, muc: dg.muc, bayGio });
      await ph.lenh.run();
      await ghiIp(c, db, dong.id, bayGio);
      if (dg.muc === 'failed') baoSuKien(c, dong.id, 'ATTEST_FAIL', 'high', { ly_do: dg.lyDo.join(','), buoc: 'dang-ky', ...dg.tinHieu });
      nen(c, lienKetThietBi(db, dong.id, bayGio), 'lien-ket');
      return c.json({ thietBiId: dong.id, trangThai: dong.status, mucTin: dg.muc, phien: ph.phien }, 201);
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/session/refresh',
      tomTat: 'Xoay refresh token (ký bằng khoá thiết bị); dùng lại token đã xoay -> thu hồi cả chuỗi',
      body: z.strictObject({ refreshToken: b64url(43, 43), ts: z.number().int(), nonce: z.string().refine(laNonceHopLe, 'nonce'), chuKy: b64url(80, 100) }),
      phanHoi: z.object({ mucTin: schemaMuc, phien: schemaPhien }),
      idempotent: false,
      bodyToiDa: 1024,
      gioiHan: [{ chieu: 'ip', gioiHan: 30, cuaSoMs: 60_000 }],
    },
    async (c, b) => {
      const db = canDb(c.env);
      const k = await canKhoaPhien(c.env);
      const bayGio = Date.now();
      if (Math.abs(bayGio - b.ts) > LECH_TS_MS) throw new LoiApi(401, 'lech-gio');
      const d = await db
        .prepare(
          `SELECT s.id, s.device_id, s.chuoi, s.expires_at, s.revoked_at, s.thay_boi, s.xoay_luc, d.public_key, d.status, d.attestation_level
           FROM sessions s JOIN devices d ON d.id = s.device_id WHERE s.refresh_hash = ?`,
        )
        .bind(await sha256Hex(b.refreshToken))
        .first<DongPhien & { public_key: string | null; status: string; attestation_level: MucTin }>();
      if (!d) throw new LoiApi(401, 'refresh-sai');
      const khoa = d.public_key ? await nhapKhoaThietBi(d.public_key) : null;
      // Chữ ký trước phát hiện dùng lại: kẻ chỉ lấy được refresh token (không có khoá phần cứng) không kích hoạt thu hồi.
      if (!khoa || !(await kiemChuKyThietBi(khoa.khoa, chuoiLamMoi(b.refreshToken, b.ts, b.nonce), b.chuKy))) {
        baoSuKien(c, d.device_id, 'SIGNATURE_MISMATCH', 'medium', { buoc: 'lam-moi' });
        throw new LoiApi(401, 'chu-ky');
      }
      if (!(await goiNonce(c.env, `thiet-bi:${d.device_id}`, '/nonce', { nonce: b.nonce, ttlMs: 2 * LECH_TS_MS }))) throw new LoiApi(401, 'nonce');
      if (d.status === 'banned') throw new LoiApi(403, 'thiet-bi-bi-cam');

      const qd = quyetDinhLamMoi(d, bayGio);
      switch (qd.loai) {
        case 'khong-co':
          throw new LoiApi(401, 'refresh-sai');
        case 'het-han':
          throw new LoiApi(401, 'refresh-het-han');
        case 'thu-hoi':
          throw new LoiApi(401, 'phien-thu-hoi');
        case 'an-han':
          throw new LoiApi(409, 'dang-xoay');
        case 'dung-lai': {
          await db
            .prepare("UPDATE sessions SET revoked_at = ?, ly_do_thu_hoi = 'dung-lai' WHERE (chuoi = ? OR id = ?) AND revoked_at IS NULL")
            .bind(bayGio, qd.chuoi, qd.chuoi)
            .run();
          baoSuKien(c, d.device_id, 'TOKEN_REUSE', 'high', { buoc: 'lam-moi' });
          throw new LoiApi(401, 'phien-thu-hoi');
        }
        case 'xoay':
          break;
      }
      const ph = await capPhien(c.env, k, db, { thietBi: d.device_id, jkt: khoa.jkt, muc: d.attestation_level, bayGio, chuoi: d.chuoi ?? d.id });
      // Một giao dịch: chỉ dòng chưa xoay mới được xoay; dòng mới chỉ chèn khi chính lệnh này xoay được (chống đua).
      const [xoay] = await db.batch([
        db.prepare('UPDATE sessions SET revoked_at = ?, thay_boi = ?, xoay_luc = ? WHERE id = ? AND thay_boi IS NULL AND revoked_at IS NULL').bind(bayGio, ph.id, bayGio, d.id),
        ph.lenh,
        db.prepare('DELETE FROM sessions WHERE id = ? AND NOT EXISTS (SELECT 1 FROM sessions WHERE id = ? AND thay_boi = ?)').bind(ph.id, d.id, ph.id),
        db.prepare('UPDATE devices SET last_seen = ? WHERE id = ?').bind(bayGio, d.device_id),
      ]);
      if (!xoay?.meta.changes) throw new LoiApi(409, 'dang-xoay');
      await ghiIp(c, db, d.device_id, bayGio);
      return c.json({ mucTin: d.attestation_level, phien: ph.phien });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/device/attest',
      tomTat: 'Xác minh lại thiết bị (Play Integrity mới, thách thức mới) - cập nhật mức tin cậy',
      body: z.strictObject({ thachThuc, chuKy: b64url(80, 100), goi, integrityToken: tokenIntegrity }),
      phanHoi: z.object({ mucTin: schemaMuc }),
      idempotent: false,
      xacThuc: true,
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 10, cuaSoMs: 3_600_000 }],
    },
    async (c, b) => {
      const db = canDb(c.env);
      const thietBi = c.get('thietBi') as string;
      const tb = await db
        .prepare('SELECT installation_id_hash, public_key, platform FROM devices WHERE id = ?')
        .bind(thietBi)
        .first<{ installation_id_hash: string; public_key: string | null; platform: string }>();
      if (!tb?.public_key) throw new LoiApi(401, 'phien-thu-hoi');
      if (!(await goiNonce(c.env, tenThach(tb.installation_id_hash), '/dung', { nonce: b.thachThuc }))) throw new LoiApi(401, 'thach-thuc');
      const khoa = await nhapKhoaThietBi(tb.public_key);
      const chuoi = chuoiXacThuc(b.thachThuc, thietBi);
      if (!khoa || !(await kiemChuKyThietBi(khoa.khoa, chuoi, b.chuKy))) {
        baoSuKien(c, thietBi, 'SIGNATURE_MISMATCH', 'medium', { buoc: 'xac-thuc' });
        throw new LoiApi(401, 'chu-ky');
      }
      const dg = tb.platform === 'android' ? await danhGiaAttest(c, b.goi, b.integrityToken, chuoi) : ({ loai: 'muc', muc: 'unverified', lyDo: ['ios-i1'], tinHieu: {} } as const);
      if (dg.loai === 'tu-choi') {
        baoSuKien(c, thietBi, 'ATTEST_FAIL', 'high', { ly_do: dg.lyDo, buoc: 'xac-thuc' });
        throw new LoiApi(403, 'attest-sai', { lyDo: dg.lyDo });
      }
      const bayGio = Date.now();
      await db
        .prepare('UPDATE devices SET attestation_level = ?, attested_at = ?, attest_signals = ?, last_seen = ? WHERE id = ?')
        .bind(dg.muc, bayGio, JSON.stringify({ ...dg.tinHieu, ly_do: dg.lyDo.join(',') || null }), bayGio, thietBi)
        .run();
      if (dg.muc === 'failed') baoSuKien(c, thietBi, 'ATTEST_FAIL', 'high', { ly_do: dg.lyDo.join(','), buoc: 'xac-thuc', ...dg.tinHieu });
      return c.json({ mucTin: dg.muc });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'get',
      duongDan: '/v1/device/me',
      tomTat: 'Trạng thái + mức tin cậy của thiết bị đang đăng nhập',
      phanHoi: z.object({ thietBiId: z.string(), trangThai: schemaTrangThai, mucTin: schemaMuc }),
      xacThuc: true,
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 60, cuaSoMs: 60_000 }],
    },
    async (c) => {
      const d = await canDb(c.env)
        .prepare('SELECT id, status, attestation_level FROM devices WHERE id = ?')
        .bind(c.get('thietBi') as string)
        .first<{ id: string; status: z.infer<typeof schemaTrangThai>; attestation_level: MucTin }>();
      if (!d) throw new LoiApi(401, 'phien-thu-hoi');
      return c.json({ thietBiId: d.id, trangThai: d.status, mucTin: d.attestation_level });
    },
  );
}
