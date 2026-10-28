// Việc định kỳ của Threat Engine (cron 5 phút): tính lại trạng thái khi enforcement hết hạn, hồi phục uy tín theo tuần.
import type { Env } from '../moi-truong';
import { hoiPhuc, trangThaiHieuLuc, type TrangThai } from '../thuan/nguy-co';
import { napCauHinh } from './nap';

const LO = 500;

type Dong = {
  id: string;
  risk_score: number;
  status: TrangThai;
  first_seen: number;
  last_violation_at: number | null;
  risk_decayed_at: number | null;
};

/**
 * Xét thiết bị đang có điểm hoặc trạng thái khác clean: trừ điểm nếu đủ tuần không vi phạm, rồi tính lại trạng thái
 * từ điểm + enforcement còn hiệu lực (enforcement hết hạn -> tự hạ trạng thái).
 */
export async function capNhatNguyCo(env: Env, bayGio = Date.now()): Promise<{ xet: number; doi: number }> {
  const db = env.DB;
  if (!db) return { xet: 0, doi: 0 };
  const cfg = await napCauHinh(db, bayGio);
  const { results } = await db
    .prepare(
      `SELECT id, risk_score, status, first_seen, last_violation_at, risk_decayed_at FROM devices WHERE risk_score > ? OR status <> 'clean' ORDER BY coalesce(risk_decayed_at, first_seen) LIMIT ${LO}`,
    )
    .bind(cfg.hoiPhuc.san)
    .all<Dong>();
  if (!results.length) return { xet: 0, doi: 0 };
  const { results: thucThi } = await db
    .prepare(
      `SELECT target_value, action FROM enforcements WHERE target_type = 'device' AND revoked_at IS NULL AND expires_at > ? AND target_value IN (${results
        .map(() => '?')
        .join(', ')})`,
    )
    .bind(bayGio, ...results.map((r) => r.id))
    .all<{ target_value: string; action: string }>();

  const capNhat: D1PreparedStatement[] = [];
  for (const d of results) {
    const hp = hoiPhuc(cfg, { diem: d.risk_score, viPhamCuoi: d.last_violation_at, truCuoi: d.risk_decayed_at, lanDau: d.first_seen }, bayGio);
    const diem = hp?.diem ?? d.risk_score;
    const tt = trangThaiHieuLuc(
      cfg,
      diem,
      thucThi.filter((t) => t.target_value === d.id).map((t) => t.action),
    );
    if (diem === d.risk_score && tt === d.status) continue;
    capNhat.push(
      db
        .prepare('UPDATE devices SET risk_score = ?, status = ?, risk_decayed_at = coalesce(?, risk_decayed_at) WHERE id = ?')
        .bind(diem, tt, hp?.truLuc ?? null, d.id),
    );
    env.SU_KIEN?.writeDataPoint({ indexes: ['trang-thai'], blobs: ['dinh-ky', d.status, tt], doubles: [diem] });
  }
  if (capNhat.length) await db.batch(capNhat);
  return { xet: results.length, doi: capNhat.length };
}
