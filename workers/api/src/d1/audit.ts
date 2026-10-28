// Ghi audit log chuỗi băm (DAT-02). hash_prev UNIQUE trong D1: hai lệnh ghi đồng thời cùng nối vào một mắt xích ->
// lệnh sau lỗi UNIQUE -> đọc lại mắt xích cuối và thử lại.
import { HASH_GOC, taoDongAudit, type DongAudit, type NoiDungAudit } from '../thuan/audit';

export async function ghiAudit(db: D1Database, noiDung: NoiDungAudit, soLanThu = 3): Promise<DongAudit> {
  for (let lan = 1; ; lan++) {
    const cuoi = await db.prepare('SELECT hash_self FROM audit_logs ORDER BY rowid DESC LIMIT 1').first<{ hash_self: string }>();
    const dong = await taoDongAudit(noiDung, cuoi?.hash_self ?? HASH_GOC);
    try {
      await db
        .prepare(
          'INSERT INTO audit_logs (id, actor, action, target, before, after, ip, ts, hash_prev, hash_self) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        )
        .bind(dong.id, dong.actor, dong.action, dong.target, dong.before, dong.after, dong.ip, dong.ts, dong.hash_prev, dong.hash_self)
        .run();
      return dong;
    } catch (e) {
      if (lan >= soLanThu || !/UNIQUE/i.test(String(e))) throw e;
    }
  }
}

/** Toàn bộ chuỗi theo thứ tự ghi (dùng cho kiểm định kỳ / SOC). */
export async function docChuoiAudit(db: D1Database): Promise<DongAudit[]> {
  const { results } = await db
    .prepare('SELECT id, actor, action, target, before, after, ip, ts, hash_prev, hash_self FROM audit_logs ORDER BY rowid')
    .all<DongAudit>();
  return results;
}
