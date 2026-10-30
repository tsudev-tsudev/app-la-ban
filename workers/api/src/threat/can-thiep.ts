// Thực thi can thiệp thủ công của SOC (S7b): ghi enforcement nguồn 'manual', tính lại trạng thái thiết bị, thu hồi phiên
// khi bị cấm, gỡ chặn, audit chuỗi băm. Quyết định (hợp lệ, cần duyệt, TTL) ở thuan/can-thiep.ts.
import { ghiAudit } from '../d1/audit';
import { taoUlid } from '../thuan/dinh-danh';
import { moTaDich, ttlCanThiep, type YeuCauChan } from '../thuan/can-thiep';
import { trangThaiHieuLuc, type CauHinhNguyCo, type TrangThai } from '../thuan/nguy-co';
import { xoaDem } from './nap';

export type KetQuaChan = { tao: string[]; boQua: string[]; canDongBo: boolean };

/** Tính lại trạng thái các thiết bị theo điểm + enforcement còn hiệu lực; vừa thành banned -> thu hồi mọi phiên. */
export async function tinhLaiThietBi(db: D1Database, cfg: CauHinhNguyCo, ids: readonly string[], bayGio: number): Promise<void> {
  if (ids.length === 0) return;
  const dau = ids.map(() => '?').join(', ');
  const [tb, tt] = await db.batch([
    db.prepare(`SELECT id, risk_score, status FROM devices WHERE id IN (${dau})`).bind(...ids),
    db
      .prepare(`SELECT target_value, action FROM enforcements WHERE target_type = 'device' AND revoked_at IS NULL AND expires_at > ? AND target_value IN (${dau})`)
      .bind(bayGio, ...ids),
  ]);
  const thucThi = (tt?.results ?? []) as { target_value: string; action: string }[];
  const lenh: D1PreparedStatement[] = [];
  for (const d of (tb?.results ?? []) as { id: string; risk_score: number; status: TrangThai }[]) {
    const moi = trangThaiHieuLuc(
      cfg,
      d.risk_score,
      thucThi.filter((x) => x.target_value === d.id).map((x) => x.action),
    );
    if (moi === d.status) continue;
    lenh.push(db.prepare('UPDATE devices SET status = ? WHERE id = ?').bind(moi, d.id));
    if (moi === 'banned') lenh.push(db.prepare('UPDATE sessions SET revoked_at = ? WHERE device_id = ? AND revoked_at IS NULL').bind(bayGio, d.id));
  }
  if (lenh.length) await db.batch(lenh);
}

/**
 * Ghi chặn cho mọi đích của [yc]: bỏ qua đích đã có chặn tương đương còn hiệu lực; [choDuyet] = đề xuất (chưa hiệu lực
 * tới khi người khác duyệt); [duyetBoi] = người duyệt four-eyes (khác người tạo - CHECK D1).
 */
export async function apDungChan(
  db: D1Database,
  cfg: CauHinhNguyCo,
  yc: YeuCauChan,
  p: { tacNhan: string; duyetBoi: string | null; choDuyet: boolean; ip: string | null; bayGio: number; yeuCauId?: string },
): Promise<KetQuaChan> {
  const { bayGio } = p;
  const kq: KetQuaChan = { tao: [], boQua: [], canDongBo: false };
  const thietBi: string[] = [];
  const ghi: Record<string, unknown>[] = [];
  for (const [i, d] of yc.dich.entries()) {
    const [dangCo, truoc] = await db.batch([
      db
        .prepare(
          "SELECT COUNT(*) AS n FROM enforcements WHERE target_type = ? AND target_value = ? AND revoked_at IS NULL AND expires_at > ? AND (action = ? OR action = 'ban')",
        )
        .bind(d.loai, d.giaTri, bayGio, yc.hanhDong),
      db.prepare('SELECT COUNT(*) AS n FROM enforcements WHERE target_type = ? AND target_value = ? AND action = ? AND revoked_at IS NULL').bind(d.loai, d.giaTri, yc.hanhDong),
    ]);
    if (((dangCo?.results[0] as { n: number } | undefined)?.n ?? 0) > 0) {
      kq.boQua.push(moTaDich(d));
      continue;
    }
    const { bac, ttlMs } = ttlCanThiep(cfg, yc.thoiHan, (truoc?.results[0] as { n: number } | undefined)?.n ?? 0);
    const id = taoUlid(bayGio + i);
    await db
      .prepare(
        "INSERT INTO enforcements (id, target_type, target_value, action, reason, created_by, approved_by, created_at, expires_at, source, pending_approval, level) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'manual', ?, ?)",
      )
      .bind(id, d.loai, d.giaTri, yc.hanhDong, yc.lyDo, p.tacNhan, p.duyetBoi, bayGio, bayGio + ttlMs, p.choDuyet ? 1 : 0, bac)
      .run();
    kq.tao.push(id);
    ghi.push({ id, dich: moTaDich(d), hanhDong: yc.hanhDong, het: bayGio + ttlMs, bac });
    if (d.loai === 'device') thietBi.push(d.giaTri);
    else if (!p.choDuyet && (d.loai === 'ip' || d.loai === 'cidr')) kq.canDongBo = true;
  }
  if (kq.tao.length) {
    if (!p.choDuyet) await tinhLaiThietBi(db, cfg, thietBi, bayGio);
    if (yc.dich.some((d) => d.loai !== 'device')) xoaDem();
    await ghiAudit(db, {
      id: taoUlid(bayGio),
      actor: p.tacNhan,
      action: p.choDuyet ? 'can-thiep:de-xuat' : 'can-thiep:chan',
      target: kq.tao.length === 1 ? String(ghi[0]?.dich) : `enforcements:${kq.tao.length}`,
      before: null,
      after: { lyDo: yc.lyDo, thoiHan: yc.thoiHan, duyetBoi: p.duyetBoi, yeuCau: p.yeuCauId ?? null, ds: ghi },
      ip: p.ip,
      ts: bayGio,
    });
  }
  return kq;
}

/** Gỡ chặn (thu hồi) các enforcement còn hiệu lực hoặc đang chờ duyệt; trả số đã gỡ + có cần đồng bộ Lists. */
export async function goChan(
  db: D1Database,
  cfg: CauHinhNguyCo,
  ids: readonly string[],
  p: { tacNhan: string; duyetBoi: string | null; lyDo: string; ip: string | null; bayGio: number; yeuCauId?: string },
): Promise<{ go: number; canDongBo: boolean }> {
  const { bayGio } = p;
  const { results } = await db
    .prepare(`SELECT id, target_type, target_value, action, expires_at FROM enforcements WHERE revoked_at IS NULL AND expires_at > ? AND id IN (${ids.map(() => '?').join(', ')})`)
    .bind(bayGio, ...ids)
    .all<{ id: string; target_type: string; target_value: string; action: string; expires_at: number }>();
  if (results.length === 0) return { go: 0, canDongBo: false };
  await db.batch(results.map((r) => db.prepare('UPDATE enforcements SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL').bind(bayGio, r.id)));
  await tinhLaiThietBi(
    db,
    cfg,
    results.filter((r) => r.target_type === 'device').map((r) => r.target_value),
    bayGio,
  );
  const mang = results.some((r) => r.target_type !== 'device');
  if (mang) xoaDem();
  await ghiAudit(db, {
    id: taoUlid(bayGio),
    actor: p.tacNhan,
    action: 'can-thiep:go-chan',
    target: results.length === 1 ? `${results[0]?.target_type}:${results[0]?.target_value}` : `enforcements:${results.length}`,
    before: results.map((r) => ({ id: r.id, dich: `${r.target_type}:${r.target_value}`, hanhDong: r.action, het: r.expires_at })),
    after: { lyDo: p.lyDo, duyetBoi: p.duyetBoi, yeuCau: p.yeuCauId ?? null },
    ip: p.ip,
    ts: bayGio,
  });
  return { go: results.length, canDongBo: results.some((r) => r.target_type === 'ip' || r.target_type === 'cidr') };
}
