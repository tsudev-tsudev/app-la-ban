// Đồng bộ IP / dải bị chặn lên Cloudflare List (Spec §7.6a, SEC-DET <= 30 s): gọi ngay khi có enforcement mạng mới
// (waitUntil) + mỗi lượt cron để gỡ cái hết hạn / bị thu hồi. Tài khoản Free chỉ có 1 List -> chỉ prod đồng bộ; staging
// vẫn chặn ở tầng Worker (mw/chan.ts). Thiếu token / id -> bỏ qua.
import { ghiLog } from '../mw/ghi-log';
import type { Env } from '../moi-truong';
import { chenhLechLists, khopQuyTac, type CanChan, type ItemLists } from '../thuan/thuc-thi';
import { napChoPhep, SQL_CHAN_HIEU_LUC } from './nap';

const API = 'https://api.cloudflare.com/client/v4';

type PhanHoiCf<T> = { success: boolean; result: T; errors?: { code: number; message: string }[]; result_info?: { cursors?: { after?: string } } };

export async function dongBoLists(
  env: Env,
  bayGio = Date.now(),
  goi: typeof fetch = fetch,
): Promise<{ them: number; xoa: number } | null> {
  const { DB: db, CF_LISTS_TOKEN: token, CF_ACCOUNT_ID: acc, CF_LIST_ID: list } = env;
  if (!db || !token || !acc || !list) return null;
  const duongDan = `${API}/accounts/${acc}/rules/lists/${list}/items`;
  const cf = async <T>(method: string, url: string, body?: unknown): Promise<PhanHoiCf<T>> => {
    const res = await goi(url, {
      method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: body === undefined ? null : JSON.stringify(body),
    });
    const j = (await res.json()) as PhanHoiCf<T>;
    if (!j.success) throw new Error(`cloudflare ${method} ${res.status} ${JSON.stringify(j.errors ?? [])}`);
    return j;
  };

  const [{ results }, choPhep] = await Promise.all([
    db
      .prepare(`SELECT id, target_value FROM enforcements WHERE target_type IN ('ip', 'cidr') AND ${SQL_CHAN_HIEU_LUC} ORDER BY created_at`)
      .bind(bayGio)
      .all<{ id: string; target_value: string }>(),
    napChoPhep(db, bayGio),
  ]);
  const canChan: CanChan[] = results
    .filter((r) => !khopQuyTac(choPhep, { ip: r.target_value.includes('/') ? null : r.target_value }))
    .map((r) => ({ enforcementId: r.id, giaTri: r.target_value }));

  const hienCo: ItemLists[] = [];
  let sau: string | undefined;
  do {
    const j = await cf<ItemLists[]>('GET', `${duongDan}?per_page=500${sau ? `&cursor=${encodeURIComponent(sau)}` : ''}`);
    hienCo.push(...j.result);
    sau = j.result_info?.cursors?.after;
  } while (sau);

  const { them, xoa } = chenhLechLists(env.MOI_TRUONG, canChan, hienCo);
  if (them.length) await cf('POST', duongDan, them);
  if (xoa.length) await cf('DELETE', duongDan, { items: xoa.map((id) => ({ id })) });
  if (them.length || xoa.length) ghiLog('info', 'dong-bo-lists', { them: them.length, xoa: xoa.length });
  return { them: them.length, xoa: xoa.length };
}
