// Tiện ích dùng chung cho route cần DO KhoNonce / Threat Engine (S2, S3).
import type { Env, Ngu } from '../moi-truong';
import { dongBoLists } from '../threat/dong-bo-lists';
import { xuLySuKien, type SuKienVao } from '../threat/dong-co';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { ghiLog } from './ghi-log';

function doNonce(env: Env, ten: string): DurableObjectStub {
  const ns = env.KHO_NONCE;
  if (!ns) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'KHO_NONCE' });
  return ns.get(ns.idFromName(ten));
}

/** POST tới DO: 200 -> true, 409 -> false, khác -> lỗi 503 (không đoán). */
export async function goiNonce(env: Env, ten: string, duong: string, du: unknown): Promise<boolean> {
  const res = await doNonce(env, ten).fetch(`https://do${duong}`, { method: 'POST', body: JSON.stringify(du) });
  if (res.status === 200) return true;
  if (res.status === 409) return false;
  throw new LoiApi(503, 'nonce-loi', { status: res.status });
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
