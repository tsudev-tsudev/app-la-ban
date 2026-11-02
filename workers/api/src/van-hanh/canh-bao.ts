// Cảnh báo vận hành qua Telegram (S10a, MON-02): tăng đột biến từ Analytics Engine + việc định kỳ lỗi. Chống lặp bằng KV
// (mỗi loại tối đa 1 tin / giờ). Thiếu bí mật / binding -> bỏ qua im lặng; không bao giờ ném lỗi ra cron.
import type { Env } from '../moi-truong';
import { danhGiaDotBien, khungVuaDong, noiDungDotBien, noiDungViecLoi, sqlDotBien, type DongAe } from '../thuan/dot-bien';
import { coTelegram, guiTinTelegram } from '../threat/telegram';

const CHONG_LAP_S = 3600;
const HET_GIO_MS = 5_000;

/** Giành quyền gửi cho [khoa] trong 1 giờ (KV nhất quán cuối - chấp nhận hiếm khi trùng 1 tin). */
async function duocGui(env: Env, khoa: string): Promise<boolean> {
  const kv = env.CAU_HINH;
  if (!kv) return true;
  const k = `van-hanh:${khoa}`;
  if (await kv.get(k)) return false;
  await kv.put(k, '1', { expirationTtl: CHONG_LAP_S });
  return true;
}

export async function baoVanHanh(env: Env, ten: string, loi: string): Promise<void> {
  try {
    if (!coTelegram(env) || !(await duocGui(env, `viec:${ten}`))) return;
    await guiTinTelegram(env, noiDungViecLoi(ten, loi, env.MOI_TRUONG));
  } catch {
    // Bỏ qua: lỗi đã có trong Workers Logs.
  }
}

export async function kiemDotBien(env: Env, bayGio = Date.now()): Promise<{ dotBien: string[] } | { bo: string }> {
  if (!env.CF_AE_TOKEN || !env.CF_ACCOUNT_ID || !env.AE_BANG) return { bo: 'thieu-cau-hinh' };
  const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${env.CF_ACCOUNT_ID}/analytics_engine/sql`, {
    method: 'POST',
    headers: { authorization: `Bearer ${env.CF_AE_TOKEN}` },
    body: sqlDotBien(env.AE_BANG),
    signal: AbortSignal.timeout(HET_GIO_MS),
  });
  if (!res.ok) throw new Error(`ae-${res.status}`);
  const { data } = (await res.json()) as { data: DongAe[] };
  const khung = khungVuaDong(bayGio);
  const ds = danhGiaDotBien(data, khung);
  const moi = [];
  for (const d of ds) if (await duocGui(env, `dot-bien:${d.chiSo}`)) moi.push(d);
  if (moi.length && coTelegram(env)) await guiTinTelegram(env, noiDungDotBien(moi, env.MOI_TRUONG, khung));
  return { dotBien: ds.map((d) => d.chiSo) };
}
