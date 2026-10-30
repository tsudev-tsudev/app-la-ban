// Threat Engine (S5, SEC-DET): nhận sự kiện -> chấm điểm -> chạy rule (shadow / active) -> enforcement TTL leo thang ->
// cập nhật trạng thái thiết bị -> audit + Analytics Engine. Quyết định nằm ở đây (server), client chỉ gửi tín hiệu.
import { ghiAudit } from '../d1/audit';
import type { Env } from '../moi-truong';
import { rutGonIp } from '../thuan/che-pii';
import { taoUlid } from '../thuan/dinh-danh';
import { cauDem, khoaNhom, luatQuanTam, nenKichHoat, phanTichHanhDong, type Luat } from '../thuan/luat';
import { congDiem, diemSuKien, diemTheoLo, trangThaiHieuLuc, ttlLeoThang, type CauHinhNguyCo, type TrangThai } from '../thuan/nguy-co';
import { canDuyet, khopQuyTac, type LoaiDich } from '../thuan/thuc-thi';
import { phatSoc } from '../do/phong-soc';
import { lienKetThietBi } from './lien-ket';
import { napCauHinh, napChoPhep, napLuat, xoaDem } from './nap';

export const TAC_NHAN = 'he-thong:threat-engine';

export type NguCanhSuKien = {
  thietBi: string | null;
  ip: string | null;
  asn?: number | null;
  country?: string | null;
  /** Lô do app gửi (S4): mỗi loại chỉ tính điểm một lần / thiết bị trong cửa sổ này (ms) - xem `diemTheoLo`. */
  gopLoaiMs?: number;
};
export type SuKienVao = { id: string; type: string; severity: string; signals: Record<string, unknown> };

export type KetQuaXuLy = {
  nhan: number;
  trung: number;
  diem: number | null;
  trangThai: TrangThai | null;
  /** id rule đã kích hoạt (kể cả shadow). */
  kichHoat: string[];
  /** Có enforcement IP / dải mới -> người gọi nên đồng bộ Cloudflare Lists (waitUntil). */
  canDongBo: boolean;
};

type ThietBi = { id: string; risk_score: number; status: TrangThai; platform: string };

function canDb(env: Env): D1Database {
  if (!env.DB) throw new Error('thiếu binding DB');
  return env.DB;
}

/** Lô sự kiện (từ app - đã kiểm chữ ký ở tầng xác thực - hoặc do server sinh: RATE_ABUSE, SIGNATURE_MISMATCH...). */
export async function xuLySuKien(env: Env, n: NguCanhSuKien, ds: readonly SuKienVao[], bayGio = Date.now()): Promise<KetQuaXuLy> {
  const db = canDb(env);
  const [cfg, dsLuat, choPhep] = await Promise.all([napCauHinh(db, bayGio), napLuat(db, bayGio), napChoPhep(db, bayGio)]);
  const mien = khopQuyTac(choPhep, { thietBi: n.thietBi, ip: n.ip, asn: n.asn ?? null }) !== null;
  const tb = n.thietBi
    ? await db.prepare('SELECT id, risk_score, status, platform FROM devices WHERE id = ?').bind(n.thietBi).first<ThietBi>()
    : null;
  if (n.thietBi && !tb) throw new Error('thiết bị không tồn tại');

  const ipPrefix = n.ip ? rutGonIp(n.ip) : null;
  const dsLoai = ds.map((e) => e.type);
  const diem = mien
    ? ds.map(() => 0)
    : n.gopLoaiMs && n.thietBi
      ? diemTheoLo(cfg, dsLoai, await loaiDaTinh(db, n.thietBi, dsLoai, bayGio - n.gopLoaiMs))
      : dsLoai.map((l) => diemSuKien(cfg, l));
  const kqChen = await db.batch(
    ds.map((e, i) =>
      db
        .prepare(
          'INSERT OR IGNORE INTO security_events (id, device_id, type, severity, signals, ip, ip_prefix, ts, risk_delta) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        )
        .bind(e.id, n.thietBi, e.type, e.severity, JSON.stringify(e.signals), n.ip, ipPrefix, bayGio, diem[i] ?? 0),
    ),
  );
  const moiChiSo = ds.flatMap((_, i) => ((kqChen[i]?.meta.changes ?? 0) > 0 ? [i] : []));
  const moi = moiChiSo.map((i) => ds[i] as SuKienVao);
  const ctx = new PhienXuLy(env, db, cfg, n, tb, mien, bayGio);
  for (const i of moiChiSo) ctx.themDiem(diem[i] ?? 0);
  for (const i of moiChiSo) {
    const e = ds[i] as SuKienVao;
    env.SU_KIEN?.writeDataPoint({
      indexes: [e.type],
      blobs: ['su-kien', e.type, e.severity, tb?.platform ?? '', n.country ?? ''],
      doubles: [diem[i] ?? 0],
    });
  }
  await ctx.chayLuat(dsLuat, [...new Set(moi.map((e) => e.type))]);
  await ctx.ketThuc(dsLuat);
  if (moi.length > 0) {
    await phatSoc(env, {
      loai: 'su-kien',
      nhanLuc: bayGio,
      thietBi: n.thietBi,
      ip: n.ip,
      quocGia: n.country ?? null,
      ds: moi.map((e) => ({ type: e.type, severity: e.severity })),
      kichHoat: ctx.kichHoat,
      trangThai: ctx.trangThai,
    });
  }
  return { nhan: moi.length, trung: ds.length - moi.length, diem: ctx.diem, trangThai: ctx.trangThai, kichHoat: ctx.kichHoat, canDongBo: ctx.canDongBo };
}

/** Loại (trong [dsLoai]) đã có điểm cho thiết bị từ mốc [tu]. */
async function loaiDaTinh(db: D1Database, thietBi: string, dsLoai: readonly string[], tu: number): Promise<Set<string>> {
  const loai = [...new Set(dsLoai)];
  if (loai.length === 0) return new Set();
  const { results } = await db
    .prepare(
      `SELECT DISTINCT type FROM security_events WHERE device_id = ? AND ts >= ? AND risk_delta > 0 AND type IN (${loai.map(() => '?').join(', ')})`,
    )
    .bind(thietBi, tu, ...loai)
    .all<{ type: string }>();
  return new Set(results.map((r) => r.type));
}

class PhienXuLy {
  diem: number | null;
  trangThai: TrangThai | null;
  readonly kichHoat: string[] = [];
  canDongBo = false;
  private viPham = false;
  private readonly trangThaiDau: TrangThai | null;

  constructor(
    private readonly env: Env,
    private readonly db: D1Database,
    private readonly cfg: CauHinhNguyCo,
    private readonly n: NguCanhSuKien,
    private readonly tb: ThietBi | null,
    private readonly mien: boolean,
    private readonly bayGio: number,
  ) {
    this.diem = tb?.risk_score ?? null;
    this.trangThai = tb?.status ?? null;
    this.trangThaiDau = this.trangThai;
  }

  themDiem(d: number): void {
    if (this.diem === null || d <= 0) return;
    this.diem = congDiem(this.cfg, this.diem, d);
    this.viPham = true;
  }

  /** Chạy mọi rule quan tâm tới [loai]; mỗi cặp (rule, nhóm) chỉ đếm một lần mỗi lô. */
  async chayLuat(dsLuat: readonly Luat[], loai: readonly string[]): Promise<void> {
    const daXet = new Set<string>();
    for (const l of dsLuat) {
      if (!loai.some((t) => luatQuanTam(l, t))) continue;
      const khoa = khoaNhom(l, this.n);
      if (!khoa || daXet.has(`${l.id}|${khoa}`)) continue;
      daXet.add(`${l.id}|${khoa}`);
      const c = cauDem(l, khoa, this.bayGio);
      const [dem, cuoi] = await Promise.all([
        this.db.prepare(c.sql).bind(...c.thamSo).first<{ n: number }>(),
        this.db.prepare('SELECT MAX(ts) AS ts FROM rule_hits WHERE rule_id = ? AND group_key = ?').bind(l.id, khoa).first<{ ts: number | null }>(),
      ]);
      if (!nenKichHoat(l, dem?.n ?? 0, cuoi?.ts ?? null, this.bayGio)) continue;
      const shadow = l.cheDo === 'shadow' || this.mien;
      this.kichHoat.push(l.id);
      await this.db
        .prepare('INSERT INTO rule_hits (rule_id, rule_version, group_key, ts, shadow, actions) VALUES (?, ?, ?, ?, ?, ?)')
        .bind(l.id, l.phienBan, khoa, this.bayGio, shadow ? 1 : 0, JSON.stringify(l.hanhDong))
        .run();
      this.env.SU_KIEN?.writeDataPoint({ indexes: [l.id], blobs: ['rule', l.id, shadow ? 'shadow' : 'active', khoa.split(':')[0] ?? ''], doubles: [dem?.n ?? 0] });
      for (const h of l.hanhDong) await this.thucHien(l, h, khoa, shadow);
    }
  }

  private async thucHien(l: Luat, h: string, khoa: string, shadow: boolean): Promise<void> {
    const hd = phanTichHanhDong(h);
    if (!hd) return;
    // Cảnh báo vẫn ghi ở shadow (đánh dấu) để SOC đánh giá rule trước khi bật.
    if (hd.loai === 'alert') return this.canhBao(l.id, hd.muc, khoa, shadow);
    if (shadow) return;
    switch (hd.loai) {
      case 'add_risk':
        return this.themDiem(hd.diem);
      case 'restrict_device':
      case 'ban_device':
        if (this.n.thietBi) await this.taoThucThi('device', this.n.thietBi, hd.loai === 'ban_device' ? 'ban' : 'restrict', `rule ${l.id}`, l.id);
        return;
      case 'block_ip':
        if (this.n.ip) await this.taoThucThi('ip', this.n.ip, 'block', `rule ${l.id}`, l.id);
        return;
      case 'propose_cidr_block': {
        const dai = khoa.startsWith('cidr24:') ? khoa.slice(7) : this.n.ip ? rutGonIp(this.n.ip) : 'khong-ro';
        if (dai !== 'khong-ro') await this.taoThucThi('cidr', dai, 'block', `rule ${l.id}`, l.id);
        return;
      }
    }
  }

  private async canhBao(ruleId: string, muc: string, khoa: string, shadow: boolean): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO alerts (id, rule_id, severity, group_key, shadow, first_ts, last_ts) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT (rule_id, group_key) WHERE status = 'open' DO UPDATE SET count = count + 1, last_ts = excluded.last_ts, shadow = min(shadow, excluded.shadow)",
      )
      .bind(taoUlid(this.bayGio), ruleId, muc, khoa, shadow ? 1 : 0, this.bayGio, this.bayGio)
      .run();
  }

  /** Enforcement tự động: bỏ qua khi đã có cái tương đương còn hiệu lực; TTL theo số lần bị chặn trước (không tính đã thu hồi). */
  async taoThucThi(loai: LoaiDich, giaTri: string, hanhDong: string, lyDo: string, ruleId: string | null): Promise<void> {
    const dangCo = await this.db
      .prepare(
        "SELECT COUNT(*) AS n FROM enforcements WHERE target_type = ? AND target_value = ? AND revoked_at IS NULL AND expires_at > ? AND (action = ? OR action = 'ban')",
      )
      .bind(loai, giaTri, this.bayGio, hanhDong)
      .first<{ n: number }>();
    if ((dangCo?.n ?? 0) > 0) return;
    const truoc = await this.db
      .prepare('SELECT COUNT(*) AS n FROM enforcements WHERE target_type = ? AND target_value = ? AND action = ? AND revoked_at IS NULL')
      .bind(loai, giaTri, hanhDong)
      .first<{ n: number }>();
    const { bac, ttlMs } = ttlLeoThang(this.cfg, truoc?.n ?? 0);
    const choDuyet = canDuyet(loai, this.cfg.underAttack);
    const id = taoUlid(this.bayGio);
    const dong = {
      id,
      target_type: loai,
      target_value: giaTri,
      action: hanhDong,
      reason: lyDo,
      created_at: this.bayGio,
      expires_at: this.bayGio + ttlMs,
      pending_approval: choDuyet ? 1 : 0,
      rule_id: ruleId,
      level: bac,
    };
    await this.db
      .prepare(
        "INSERT INTO enforcements (id, target_type, target_value, action, reason, created_by, created_at, expires_at, source, pending_approval, rule_id, level) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'auto', ?, ?, ?)",
      )
      .bind(id, loai, giaTri, hanhDong, lyDo, TAC_NHAN, dong.created_at, dong.expires_at, dong.pending_approval, ruleId, bac)
      .run();
    await ghiAudit(this.db, {
      id: taoUlid(this.bayGio),
      actor: TAC_NHAN,
      action: choDuyet ? 'enforcement.propose' : 'enforcement.create',
      target: `${loai}:${loai === 'ip' ? rutGonIp(giaTri) : giaTri}`,
      before: null,
      after: { ...dong, target_value: loai === 'ip' ? rutGonIp(giaTri) : giaTri },
      ip: null,
      ts: this.bayGio,
    });
    if ((loai === 'ip' || loai === 'cidr') && !choDuyet) this.canDongBo = true;
    if (loai !== 'device') xoaDem();
  }

  /** Cập nhật điểm + trạng thái; vừa bị cấm -> thu hồi phiên, ghi DEVICE_BANNED (cho rule theo dải), liên kết thiết bị. */
  async ketThuc(dsLuat: readonly Luat[]): Promise<void> {
    const tb = this.tb;
    if (!tb || this.diem === null) return;
    const dangApDung = async () =>
      (
        await this.db
          .prepare("SELECT action FROM enforcements WHERE target_type = 'device' AND target_value = ? AND revoked_at IS NULL AND expires_at > ?")
          .bind(tb.id, this.bayGio)
          .all<{ action: string }>()
      ).results.map((r) => r.action);
    let hanhDong = await dangApDung();
    // Điểm vượt ngưỡng banned -> enforcement ban có TTL (giữ cấm dù điểm hồi phục dần) - chỉ khi không thuộc allow-list.
    if (!this.mien && this.diem >= this.cfg.nguong.banned && !hanhDong.includes('ban')) {
      await this.taoThucThi('device', tb.id, 'ban', 'diem-nguy-co', null);
      hanhDong = await dangApDung();
    }
    this.trangThai = trangThaiHieuLuc(this.cfg, this.diem, hanhDong);
    await this.db
      .prepare('UPDATE devices SET risk_score = ?, status = ?, last_violation_at = CASE WHEN ? THEN ? ELSE last_violation_at END WHERE id = ?')
      .bind(this.diem, this.trangThai, this.viPham ? 1 : 0, this.bayGio, tb.id)
      .run();
    if (this.trangThai === 'banned' && this.trangThaiDau !== 'banned') {
      await this.db.prepare('UPDATE sessions SET revoked_at = ? WHERE device_id = ? AND revoked_at IS NULL').bind(this.bayGio, tb.id).run();
      await this.db
        .prepare(
          "INSERT INTO security_events (id, device_id, type, severity, signals, ip, ip_prefix, ts, risk_delta) VALUES (?, ?, 'DEVICE_BANNED', 'high', '{}', ?, ?, ?, 0)",
        )
        .bind(taoUlid(this.bayGio), tb.id, this.n.ip, this.n.ip ? rutGonIp(this.n.ip) : null, this.bayGio)
        .run();
      await this.chayLuat(dsLuat, ['DEVICE_BANNED']);
      await lienKetThietBi(this.db, tb.id, this.bayGio);
    }
    if (this.trangThai !== this.trangThaiDau) {
      this.env.SU_KIEN?.writeDataPoint({ indexes: ['trang-thai'], blobs: ['trang-thai', this.trangThaiDau ?? '', this.trangThai], doubles: [this.diem] });
    }
  }
}
