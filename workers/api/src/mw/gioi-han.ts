import { asnCua } from './dich-vu';
import type { MiddlewareHandler } from 'hono';
import { xuLySuKien } from '../threat/dong-co';
import { dongBoLists } from '../threat/dong-bo-lists';
import { rutGonIp } from '../thuan/che-pii';
import { taoUlid } from '../thuan/dinh-danh';
import { cauDem, quyetDinhDem, type DongDem, type QuyetDinhDem } from '../thuan/dem-d1';
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

/**
 * Giới hạn nhiều chiều theo route (SEC-API API-01): mọi luật của yêu cầu đếm trong MỘT batch D1 (R3c, Q52 - trước là
 * DO GioiHanToc: ~485 ms mỗi lần isolate chạm DO lần đầu). Vượt bất kỳ chiều nào -> 429 + Retry-After. Lỗi D1 -> cho qua
 * (ưu tiên sẵn sàng; lớp RL_IP + WAF vẫn chặn lũ) và ghi log.
 */
export function gioiHanRoute(dsLuat: LuatGioiHan[]): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    const db = c.env.DB;
    if (db && dsLuat.length) {
      const bayGio = Date.now();
      const apDung = dsLuat.flatMap((l) => {
        const gt = giaTriChieu(c, l.chieu);
        return gt === null ? [] : [{ l, lenh: cauDem(khoaGioiHan(l.chieu, gt, `${c.req.method} ${c.get('tuyen') ?? c.req.path}`), bayGio, l.cuaSoMs) }];
      });
      let kq: (QuyetDinhDem | null)[] = [];
      if (apDung.length) {
        try {
          const ds = await doBuoc(c.get('dongHo'), 'gioiHan', () => db.batch<DongDem>(apDung.map((a) => db.prepare(a.lenh.sql).bind(...a.lenh.thamSo))));
          kq = apDung.map((a, i) => {
            const dong = ds[i]?.results[0];
            return dong ? quyetDinhDem(dong, bayGio, a.l.gioiHan, a.l.cuaSoMs) : null;
          });
        } catch (e) {
          ghiLog('error', 'gioi-han-d1-loi', { loi: String(e) });
        }
      }
      const bi = kq.filter((k): k is QuyetDinhDem => !!k && !k.choPhep);
      if (bi.length) {
        if (bi.some((k) => k.lanDauVuot)) baoLamDung(c);
        const cho = Math.max(...bi.map((k) => k.thuLaiSau));
        throw new LoiApi(429, 'qua-nhieu-yeu-cau', { ip: rutGonIp(c.get('ip')) }, { 'retry-after': String(cho) });
      }
    }
    await next();
  };
}

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
