// Tiện ích dùng chung cho route cần DO KhoNonce / Threat Engine (S2, S3).
import type { Env, Ngu } from '../moi-truong';
import { dongBoLists } from '../threat/dong-bo-lists';
import { xuLySuKien, type SuKienVao } from '../threat/dong-co';
import { cauCapThach, cauDungThach, cauNonce, thachConHan } from '../thuan/dem-d1';
import { taoUlid } from '../thuan/dinh-danh';
import { laNonceHopLe, NONCE_TTL_MAC_DINH_MS } from '../thuan/nonce';
import { LoiApi } from '../thuan/loi';
import { ghiLog } from './ghi-log';

/**
 * Kho nonce trên D1 (R3c, Q52 - trước là DO KhoNonce, cùng ngữ nghĩa): '/nonce' {nonce, ttlMs} dùng một lần trong hạn;
 * '/cap' {nonce, ttlMs} lưu thách thức server cấp; '/dung' {nonce} thách thức còn hạn -> xoá, true. Nonce sai dạng -> false
 * (bị từ chối như phát lại). Lỗi D1 -> 503 (không đoán: không bao giờ cho qua khi không kiểm được).
 */
export async function goiNonce(env: Env, ten: string, duong: '/nonce' | '/cap' | '/dung', du: { nonce: unknown; ttlMs?: number }, bayGio = Date.now()): Promise<boolean> {
  const db = env.DB;
  if (!db) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  if (!laNonceHopLe(du.nonce)) return false;
  const ttl = typeof du.ttlMs === 'number' && Number.isFinite(du.ttlMs) && du.ttlMs > 0 ? du.ttlMs : NONCE_TTL_MAC_DINH_MS;
  try {
    if (duong === '/dung') {
      const c = cauDungThach(ten, du.nonce);
      return thachConHan(await db.prepare(c.sql).bind(...c.thamSo).first<{ het_han: number }>(), bayGio);
    }
    const c = duong === '/cap' ? cauCapThach(ten, du.nonce, bayGio, ttl) : cauNonce(ten, du.nonce, bayGio, ttl);
    const kq = await db.prepare(c.sql).bind(...c.thamSo).run();
    return duong === '/cap' || kq.meta.changes === 1;
  } catch (e) {
    throw new LoiApi(503, 'nonce-loi', { loi: String(e).slice(0, 120) });
  }
}

/** Việc nền sau phản hồi (waitUntil); lỗi chỉ ghi log. */
export function nen(c: Ngu, viec: Promise<unknown>, ten: string): void {
  const p = viec.catch((e: unknown) => ghiLog('error', `${ten}-loi`, { loi: String(e) }));
  try {
    c.executionCtx.waitUntil(p);
  } catch {
    // Ngoài workerd (test đơn vị) không có executionCtx.
  }
}

/** ASN của kết nối (request.cf của Cloudflare) - cho allow-list theo ASN (thiết bị duyệt store, R2). Không có -> null. */
export function asnCua(c: { req: { raw: Request } }): number | null {
  const asn = (c.req.raw as { cf?: { asn?: unknown } }).cf?.asn;
  return typeof asn === 'number' && Number.isInteger(asn) && asn > 0 ? asn : null;
}

/** Sự kiện do server sinh -> Threat Engine (chạy nền, không làm chậm phản hồi). */
export function baoSuKien(c: Ngu, thietBi: string | null, loai: string, muc: SuKienVao['severity'], tinHieu: Record<string, unknown>): void {
  if (!c.env.DB) return;
  nen(
    c,
    xuLySuKien(c.env, { thietBi, ip: c.get('ip') || null, asn: asnCua(c), country: c.req.header('cf-ipcountry') ?? null }, [
      { id: taoUlid(), type: loai, severity: muc, signals: tinHieu },
    ]).then(async (kq) => {
      if (kq.canDongBo) await dongBoLists(c.env);
    }),
    'su-kien',
  );
}
