import { asnCua } from './dich-vu';
import type { MiddlewareHandler } from 'hono';
import { xuLySuKien } from '../threat/dong-co';
import { dongBoLists } from '../threat/dong-bo-lists';
import { rutGonIp } from '../thuan/che-pii';
import { taoUlid } from '../thuan/dinh-danh';
import { nenBao } from '../thuan/bay';
import { cauDem, quyetDinhDem, type DongDem } from '../thuan/dem-d1';
import type { CauLenh } from '../thuan/don-dep';
import { doBuoc } from '../thuan/do-tre';
import { khoaGioiHan, type LuatGioiHan } from '../thuan/gioi-han';
import { LoiApi } from '../thuan/loi';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from './ghi-log';

/** Lớp thô: Rate Limiting binding theo IP cho MỌI route (thiếu binding -> bỏ qua, ghi log một lần mỗi isolate). */
let daBaoThieuRl = false;
export const gioiHanThoIp: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const rl = c.env.RL_IP;
  if (!rl) {
    if (!daBaoThieuRl && c.env.MOI_TRUONG !== 'test') ghiLog('warn', 'thieu-binding-RL_IP');
    daBaoThieuRl = true;
  } else if (c.get('ip')) {
    const { success } = await doBuoc(c.get('dongHo'), 'rlIp', () => rl.limit({ key: c.get('ip') }));
    if (!success) throw new LoiApi(429, 'qua-nhieu-yeu-cau', { lop: 'RL_IP' }, { 'retry-after': '60' });
  }
  await next();
};

/** Giá trị của một chiều cho yêu cầu hiện tại (null = không áp dụng, vd. chưa có phiên). */
function giaTriChieu(c: Ngu, chieu: LuatGioiHan['chieu']): string | null {
  switch (chieu) {
    case 'ip':
      return c.get('ip') || null;
    case 'endpoint':
      return 'tat-ca';
    // Thiết bị / phiên chỉ có sau xác thực (S2) - middleware xác thực đặt phamViIdem = 'thiet-bi:<id>' / 'phien:<id>'.
    case 'thiet-bi':
    case 'phien': {
      const p = c.get('phamViIdem');
      return p?.startsWith(`${chieu}:`) ? p.slice(chieu.length + 1) : null;
    }
  }
}

export type DemApDung = { l: LuatGioiHan; lenh: CauLenh };

/** Câu đếm cho các luật áp được vào yêu cầu hiện tại (chiều chưa có giá trị - vd. chưa có phiên - bị bỏ). */
export function lenhGioiHan(c: Ngu, dsLuat: readonly LuatGioiHan[], bayGio: number): DemApDung[] {
  return dsLuat.flatMap((l) => {
    const gt = giaTriChieu(c, l.chieu);
    return gt === null ? [] : [{ l, lenh: cauDem(khoaGioiHan(l.chieu, gt, `${c.req.method} ${c.get('tuyen') ?? c.req.path}`), bayGio, l.cuaSoMs) }];
  });
}

/** Từ dòng RETURNING của từng câu đếm: vượt bất kỳ chiều nào -> RATE_ABUSE (lần đầu) + 429 + Retry-After. */
export function apKetQuaGioiHan(c: Ngu, apDung: readonly DemApDung[], dong: readonly (DongDem | undefined)[], bayGio: number): void {
  const bi = apDung.flatMap((a, i) => {
    const d = dong[i];
    const q = d ? quyetDinhDem(d, bayGio, a.l.gioiHan, a.l.cuaSoMs) : null;
    return q && !q.choPhep ? [q] : [];
  });
  if (!bi.length) return;
  if (bi.some((k) => k.lanDauVuot)) baoLamDung(c);
  const cho = Math.max(...bi.map((k) => k.thuLaiSau));
  throw new LoiApi(429, 'qua-nhieu-yeu-cau', { ip: rutGonIp(c.get('ip')) }, { 'retry-after': String(cho) });
}

/**
 * Giới hạn nhiều chiều theo route (SEC-API API-01): mọi luật của yêu cầu đếm trong MỘT batch D1 (R3c, Q52 - trước là
 * DO GioiHanToc: ~485 ms mỗi lần isolate chạm DO lần đầu). Luật theo thiết bị của route có xác thực được đếm ngay trong
 * batch nonce (mw/xac-thuc.ts) - BoTuyen không đưa chúng vào đây. Lỗi D1 -> cho qua (ưu tiên sẵn sàng; lớp RL_IP + WAF
 * vẫn chặn lũ) và ghi log.
 */
export function gioiHanRoute(dsLuat: LuatGioiHan[]): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    const db = c.env.DB;
    if (db && dsLuat.length) {
      const bayGio = Date.now();
      const apDung = lenhGioiHan(c, dsLuat, bayGio);
      if (apDung.length) {
        let dong: (DongDem | undefined)[] = [];
        try {
          const ds = await doBuoc(c.get('dongHo'), 'gioiHan', () => db.batch<DongDem>(apDung.map((a) => db.prepare(a.lenh.sql).bind(...a.lenh.thamSo))));
          dong = ds.map((r) => r.results[0]);
        } catch (e) {
          ghiLog('error', 'gioi-han-d1-loi', { loi: String(e) });
        }
        apKetQuaGioiHan(c, apDung, dong, bayGio);
      }
    }
    await next();
  };
}

/** Route công khai chỉ đọc 60 / phút / IP: Rate Limiting binding (đếm theo colo, không ghi D1). Thiếu binding -> D1. */
const LUAT_DOC_CONG_KHAI: LuatGioiHan[] = [{ chieu: 'ip', gioiHan: 60, cuaSoMs: 60_000 }];
const gioiHanDocD1 = gioiHanRoute(LUAT_DOC_CONG_KHAI);
const daBaoDoc = new Map<string, number>();
export const gioiHanDocCongKhai: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const rl = c.env.RL_DOC_CONG_KHAI;
  if (!rl) return gioiHanDocD1(c, next);
  const ip = c.get('ip');
  if (ip) {
    const { success } = await doBuoc(c.get('dongHo'), 'gioiHan', () => rl.limit({ key: `${c.get('tuyen') ?? c.req.path}:${ip}` }));
    if (!success) {
      if (nenBao(daBaoDoc, ip, Date.now(), 60_000)) baoLamDung(c);
      throw new LoiApi(429, 'qua-nhieu-yeu-cau', { ip: rutGonIp(ip) }, { 'retry-after': '60' });
    }
  }
  await next();
};

/** Lần đầu vượt giới hạn trong cửa sổ -> sự kiện RATE_ABUSE cho Threat Engine (rule R-001), chạy nền sau phản hồi. */
function baoLamDung(c: Ngu): void {
  if (!c.env.DB) return;
  const p = c.get('phamViIdem');
  const thietBi = p?.startsWith('thiet-bi:') ? p.slice(9) : null;
  const viec = xuLySuKien(c.env, { thietBi, ip: c.get('ip') || null, asn: asnCua(c), country: c.req.header('cf-ipcountry') ?? null }, [
    { id: taoUlid(), type: 'RATE_ABUSE', severity: 'medium', signals: { route: c.get('tuyen') ?? '' } },
  ]).then(
    async (kq) => {
      if (kq.canDongBo) await dongBoLists(c.env);
    },
    (e: unknown) => ghiLog('error', 'rate-abuse-loi', { loi: String(e) }),
  );
  try {
    c.executionCtx.waitUntil(viec);
  } catch {
    // Ngoài workerd (test đơn vị) không có executionCtx: để promise tự chạy.
  }
}
