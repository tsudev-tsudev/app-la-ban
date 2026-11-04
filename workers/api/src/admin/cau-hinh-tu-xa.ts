// Remote Config ký số từ SOC (S7c2, Spec §8.2-7): xem gói đang phục vụ (app + khiên web) -> đề xuất (lý do + passkey) ->
// người THỨ HAI duyệt (passkey) -> Worker ký Ed25519 bằng khoá secret -> ghi KV CAU_HINH + lịch sử + audit. Gói đã đổi giữa
// lúc đề xuất và lúc duyệt -> 409 (đề xuất lại trên gói mới). App / web tự kiểm chữ ký: KV bị ghi bậy chỉ làm client giữ
// cấu hình cũ.
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import {
  deXuatTuGoi,
  giaiMaGoi,
  GOC_DONG_GOI,
  kiemDeXuatApp,
  kiemGoi,
  KID_APP,
  KID_WEB,
  kyGoi,
  napKhoaKy,
  phatHanhMoi,
  SchemaDeXuatApp,
  SchemaDeXuatWeb,
  SchemaHuyCauHinh,
  SchemaQuyetCauHinh,
  SchemaYeuCauCauHinh,
  taoNoiDungApp,
  taoNoiDungWeb,
  TINH_NANG,
  YEU_CAU_CAU_HINH_HAN_MS,
  type NoiDungApp,
} from '../thuan/cau-hinh-tu-xa';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { docLatest, GOI_APP_TOI_DA, KHOA_KV_APP } from '../thuan/kenh';
import { goiCauHinhHopLe, KHOA_KV_KHIEN } from '../thuan/khien-web';
import { LoiApi } from '../thuan/loi';
import { canQuyen, canStepUp } from './xac-thuc';

type Dich = 'app' | 'web';
const KHOA_KV: Record<Dich, string> = { app: KHOA_KV_APP, web: KHOA_KV_KHIEN };
const KID: Record<Dich, string> = { app: KID_APP, web: KID_WEB };
const TOI_DA: Record<Dich, number> = { app: GOI_APP_TOI_DA, web: 4096 };

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function kv(c: Ngu): KVNamespace {
  if (!c.env.CAU_HINH) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'CAU_HINH' });
  return c.env.CAU_HINH;
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

const email = (c: Ngu) => (c.get('quanTri') as { email: string }).email;

/** Gói đang ở KV (đọc thẳng, không cacheTtl - SOC cần bản mới nhất), đã kiểm chữ ký. */
async function goiHienTai(c: Ngu, dich: Dich): Promise<{ raw: string | null; nd: Record<string, unknown> | null; chuKyDung: boolean }> {
  const raw = goiCauHinhHopLe((await kv(c).get(KHOA_KV[dich])) ?? null, TOI_DA[dich]);
  if (!raw) return { raw: null, nd: null, chuKyDung: false };
  const g = giaiMaGoi(raw);
  return { raw, nd: g?.noiDung ?? null, chuKyDung: await kiemGoi(raw) };
}

const phatHanhCua = (nd: Record<string, unknown> | null): number | null => (typeof nd?.phatHanh === 'number' ? nd.phatHanh : null);

async function banMoiNhat(c: Ngu): Promise<number | null> {
  try {
    const vat = await c.env.CDN?.get('android/latest.json');
    return vat ? (docLatest(await vat.text())?.maPhienBan ?? null) : null;
  } catch {
    return null;
  }
}

type DongYeuCau = {
  id: string;
  target: Dich;
  payload: string;
  base_issued: number | null;
  reason: string;
  created_by: string;
  created_at: number;
  expires_at: number;
  status: string;
  decided_by: string | null;
  decided_at: number | null;
  decision_note: string | null;
};

export function dangKyCauHinhTuXa(r: Hono<MoiTruongHono>): void {
  r.get('/cau-hinh-tu-xa', canQuyen('cau-hinh-tu-xa:xem'), async (c) => {
    const d = db(c);
    const bayGio = Date.now();
    const [app, web, banMoi, khoaApp, khoaWeb, yc, ls] = await Promise.all([
      goiHienTai(c, 'app'),
      goiHienTai(c, 'web'),
      banMoiNhat(c),
      napKhoaKy(c.env.KHOA_KY_APP, KID_APP),
      napKhoaKy(c.env.KHOA_KY_WEB, KID_WEB),
      d
        .prepare(
          "SELECT id, target, payload, base_issued, reason, created_by, created_at, expires_at, status, decided_by, decided_at, decision_note FROM config_requests WHERE status = 'pending' OR created_at > ? ORDER BY created_at DESC LIMIT 50",
        )
        .bind(bayGio - 30 * 86_400_000)
        .all<DongYeuCau>(),
      d.prepare('SELECT id, target, kid, issued_at, content, request_id, created_by, approved_by FROM config_versions ORDER BY issued_at DESC LIMIT 20').all<Record<string, unknown>>(),
    ]);
    const tom = (g: typeof app, dich: Dich) => ({ noiDung: g.nd, chuKyDung: g.chuKyDung, deXuat: deXuatTuGoi(g.nd, dich) });
    return c.json({
      app: tom(app, 'app'),
      web: tom(web, 'web'),
      coKhoa: { app: khoaApp !== null, web: khoaWeb !== null },
      banMoi,
      gocDongGoi: GOC_DONG_GOI,
      tinhNang: TINH_NANG,
      yeuCau: yc.results.map((x) => ({ ...x, payload: JSON.parse(x.payload) as unknown, hetHan: x.status === 'pending' && x.expires_at <= bayGio })),
      lichSu: ls.results.map((x) => ({ ...x, content: JSON.parse(String(x.content)) as unknown })),
      toi: email(c),
    });
  });

  r.post('/cau-hinh-tu-xa/yeu-cau', canQuyen('cau-hinh-tu-xa:sua'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaYeuCauCauHinh);
    const d = db(c);
    const bayGio = Date.now();
    const ht = await goiHienTai(c, b.dich);
    if (b.dich === 'app') {
      const loi = kiemDeXuatApp(b.noiDung, ht.nd as Partial<NoiDungApp> | null, await banMoiNhat(c));
      if (loi) throw new LoiApi(422, loi);
    }
    const dangCho = await d.prepare("SELECT COUNT(*) AS n FROM config_requests WHERE target = ? AND status = 'pending' AND expires_at > ?").bind(b.dich, bayGio).first<{ n: number }>();
    if ((dangCho?.n ?? 0) > 0) throw new LoiApi(409, 'dang-co-yeu-cau');
    const id = taoUlid(bayGio);
    await d
      .prepare('INSERT INTO config_requests (id, target, payload, base_issued, reason, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
      .bind(id, b.dich, JSON.stringify(b.noiDung), phatHanhCua(ht.nd), b.lyDo, email(c), bayGio, bayGio + YEU_CAU_CAU_HINH_HAN_MS)
      .run();
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: email(c),
      action: 'cau-hinh-tu-xa:de-xuat',
      target: `config:${b.dich}:${id}`,
      before: ht.nd,
      after: { deXuat: b.noiDung, lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, id }, 201);
  });

  r.post('/cau-hinh-tu-xa/quyet', canQuyen('cau-hinh-tu-xa:sua'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaQuyetCauHinh);
    const d = db(c);
    const bayGio = Date.now();
    const toi = email(c);
    const yc = await d
      .prepare('SELECT id, target, payload, base_issued, reason, created_by, created_at, expires_at, status FROM config_requests WHERE id = ?')
      .bind(b.id)
      .first<DongYeuCau>();
    if (!yc) throw new LoiApi(404, 'khong-thay');
    if (yc.status !== 'pending') throw new LoiApi(409, 'da-quyet');
    if (yc.expires_at <= bayGio) throw new LoiApi(409, 'het-han');
    if (yc.created_by.toLowerCase() === toi.toLowerCase()) throw new LoiApi(403, 'khong-tu-duyet');

    let noiDungMoi: Record<string, unknown> | null = null;
    let goiMoi: string | null = null;
    if (b.dongY) {
      // Chuẩn bị + ký TRƯỚC khi giành quyền quyết: thiếu khoá / gói đã đổi -> yêu cầu vẫn chờ, người duyệt biết lý do.
      const khoa = await napKhoaKy(yc.target === 'app' ? c.env.KHOA_KY_APP : c.env.KHOA_KY_WEB, KID[yc.target]);
      // 409 (không 503): 5xx bị bỏ `code` ở problem+json -> SOC chỉ thấy lỗi chung (E1 04/11).
      if (!khoa) throw new LoiApi(409, 'chua-co-khoa-ky');
      const ht = await goiHienTai(c, yc.target);
      if (phatHanhCua(ht.nd) !== yc.base_issued) throw new LoiApi(409, 'cau-hinh-da-doi');
      const phatHanh = phatHanhMoi(bayGio, phatHanhCua(ht.nd));
      if (yc.target === 'app') {
        const dx = SchemaDeXuatApp.parse(JSON.parse(yc.payload));
        const loi = kiemDeXuatApp(dx, ht.nd as Partial<NoiDungApp> | null, await banMoiNhat(c));
        if (loi) throw new LoiApi(422, loi);
        noiDungMoi = taoNoiDungApp(dx, ht.nd as Partial<NoiDungApp> | null, phatHanh);
      } else {
        noiDungMoi = taoNoiDungWeb(SchemaDeXuatWeb.parse(JSON.parse(yc.payload)), phatHanh);
      }
      goiMoi = JSON.stringify(await kyGoi(khoa, KID[yc.target], noiDungMoi as never));
      if (!goiCauHinhHopLe(goiMoi, TOI_DA[yc.target])) throw new LoiApi(422, 'goi-qua-lon');
    }
    // Giành quyền quyết bằng điều kiện status: hai người duyệt cùng lúc -> chỉ một người thắng (rồi mới ghi KV).
    const kq = await d
      .prepare("UPDATE config_requests SET status = ?, decided_by = ?, decided_at = ?, decision_note = ? WHERE id = ? AND status = 'pending' AND created_by <> ?")
      .bind(b.dongY ? 'approved' : 'rejected', toi, bayGio, b.ghiChu ?? null, b.id, toi)
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(409, 'da-quyet');
    if (goiMoi && noiDungMoi) {
      await kv(c).put(KHOA_KV[yc.target], goiMoi);
      await d
        .prepare('INSERT INTO config_versions (id, target, kid, issued_at, content, request_id, created_by, approved_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .bind(taoUlid(bayGio), yc.target, KID[yc.target], noiDungMoi.phatHanh as number, JSON.stringify(noiDungMoi), yc.id, yc.created_by, toi)
        .run();
    }
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: toi,
      action: b.dongY ? 'cau-hinh-tu-xa:duyet' : 'cau-hinh-tu-xa:bac',
      target: `config:${yc.target}:${yc.id}`,
      before: { taoBoi: yc.created_by, lyDo: yc.reason },
      after: noiDungMoi ? { noiDung: noiDungMoi, ghiChu: b.ghiChu ?? null } : { ghiChu: b.ghiChu ?? null },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, phatHanh: (noiDungMoi?.phatHanh as number | undefined) ?? null });
  });

  r.post('/cau-hinh-tu-xa/huy', canQuyen('cau-hinh-tu-xa:sua'), async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaHuyCauHinh);
    const d = db(c);
    const bayGio = Date.now();
    const kq = await d
      .prepare("UPDATE config_requests SET status = 'cancelled', decided_by = created_by, decided_at = ? WHERE id = ? AND status = 'pending' AND created_by = ?")
      .bind(bayGio, b.id, email(c))
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(404, 'khong-thay');
    await ghiAudit(d, { id: taoUlid(bayGio), actor: email(c), action: 'cau-hinh-tu-xa:huy', target: `config:${b.id}`, before: null, after: null, ip: c.get('ip') || null, ts: bayGio });
    return c.json({ ok: true });
  });
}
