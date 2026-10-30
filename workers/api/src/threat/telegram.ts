// Báo cảnh báo SOC qua Telegram (S7a, MON-02): chỉ cảnh báo thật mức cao, MỘT lần / cảnh báo (giành quyền gửi bằng
// UPDATE notified_at ... WHERE notified_at IS NULL trước khi gọi API). Thiếu bí mật -> bỏ qua im lặng. Không bao giờ ném lỗi
// ra luồng xử lý sự kiện: Telegram chậm / lỗi không được làm hỏng Threat Engine.
import type { Env } from '../moi-truong';
import { canBaoTelegram, noiDungTelegram } from '../thuan/canh-bao';

export type CanhBaoMoi = { id: string; rule_id: string; severity: string; group_key: string; count: number; shadow: number; notified_at: number | null };

const HET_GIO_MS = 3_000;

export function coTelegram(env: Env): boolean {
  return !!env.TELEGRAM_BOT_TOKEN && !!env.TELEGRAM_CHAT_ID;
}

export async function guiTinTelegram(env: Env, vanBan: string): Promise<boolean> {
  if (!coTelegram(env)) return false;
  try {
    const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ chat_id: env.TELEGRAM_CHAT_ID, text: vanBan, disable_web_page_preview: true }),
      signal: AbortSignal.timeout(HET_GIO_MS),
    });
    return res.ok;
  } catch {
    return false;
  }
}

export async function baoCanhBao(env: Env, db: D1Database, a: CanhBaoMoi, bayGio: number): Promise<void> {
  if (!coTelegram(env) || !canBaoTelegram(a)) return;
  try {
    const gianh = await db.prepare('UPDATE alerts SET notified_at = ? WHERE id = ? AND notified_at IS NULL').bind(bayGio, a.id).run();
    if ((gianh.meta.changes ?? 0) === 0) return;
    const r = await db.prepare('SELECT name FROM rules WHERE id = ?').bind(a.rule_id).first<{ name: string }>();
    const goc = (env.SOC_NGUON ?? '').split(',')[0]?.trim() || 'https://compass-admin.tsudev.com';
    const ok = await guiTinTelegram(env, noiDungTelegram({ ...a, rule_name: r?.name ?? null }, env.MOI_TRUONG, goc));
    // Gửi hỏng -> trả quyền để lần gộp kế tiếp thử lại.
    if (!ok) await db.prepare('UPDATE alerts SET notified_at = NULL WHERE id = ? AND notified_at = ?').bind(a.id, bayGio).run();
  } catch {
    // Bỏ qua: cảnh báo vẫn nằm trong SOC.
  }
}
