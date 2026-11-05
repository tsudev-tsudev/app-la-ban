// Dữ liệu SOC (S6, Spec §8.2 mục 1-2): tổng quan, danh sách + chi tiết thiết bị, kênh realtime (cảnh báo: canh-bao.ts).
// Che PII theo vai trò ở ĐÂY (server) - viewer không bao giờ nhận IP đầy đủ, kể cả khi giao diện bị sửa.
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import { vaoPhongSoc } from '../do/phong-soc';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { maHoaCursor } from '../thuan/cursor';
import { laIdHopLe, taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { tachDs } from '../thuan/access-jwt';
import { cheIp, docLocThietBi, giaTriCursor, truyVanThietBi, type VaiTro } from '../thuan/soc';
import { canQuyen } from './xac-thuc';

const NGAY = 24 * 60 * 60_000;

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function vaiTro(c: Ngu): VaiTro {
  return (c.get('quanTri') as { vaiTro: VaiTro }).vaiTro;
}

type Dem = { k: string | number | null; n: number };

function json(s: string | null): unknown {
  if (!s) return null;
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

export function dangKyDuLieu(r: Hono<MoiTruongHono>): void {
  r.get('/tong-quan', canQuyen('tong-quan'), async (c) => {
    const d = db(c);
    const bayGio = Date.now();
    const ngay = bayGio - NGAY;
    const thang = bayGio - 30 * NGAY;
    const batDau = Date.now();
    const kq = await d.batch([
      d.prepare('SELECT status AS k, COUNT(*) AS n FROM devices GROUP BY status'),
      d.prepare('SELECT COUNT(*) AS n, SUM(last_seen >= ?) AS dau, SUM(last_seen >= ?) AS mau FROM devices').bind(ngay, thang),
      d.prepare("SELECT platform || ' ' || coalesce(os_version, '?') AS k, COUNT(*) AS n FROM devices WHERE last_seen >= ? GROUP BY k ORDER BY n DESC LIMIT 8").bind(thang),
      d.prepare("SELECT coalesce(app_version, '?') AS k, COUNT(*) AS n FROM devices WHERE last_seen >= ? GROUP BY k ORDER BY n DESC LIMIT 8").bind(thang),
      d.prepare("SELECT coalesce(country, '??') AS k, COUNT(*) AS n FROM devices WHERE last_seen >= ? GROUP BY k ORDER BY n DESC LIMIT 12").bind(thang),
      d.prepare('SELECT type AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? GROUP BY type ORDER BY n DESC LIMIT 8').bind(ngay),
      d.prepare('SELECT ts / 3600000 AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? GROUP BY k ORDER BY k').bind(ngay),
      d.prepare("SELECT ip AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? AND ip IS NOT NULL AND severity IN ('medium', 'high', 'critical') GROUP BY ip ORDER BY n DESC LIMIT 8").bind(ngay),
      d.prepare(
        "SELECT i.asn AS k, COUNT(*) AS n FROM security_events e JOIN device_ips i ON i.device_id = e.device_id AND i.ip = e.ip WHERE e.ts >= ? AND e.severity IN ('medium', 'high', 'critical') AND i.asn IS NOT NULL GROUP BY i.asn ORDER BY n DESC LIMIT 8",
      ).bind(ngay),
      d.prepare(
        "SELECT (SELECT COUNT(*) FROM alerts WHERE status = 'open') AS canhBao, (SELECT COUNT(*) FROM enforcements WHERE revoked_at IS NULL AND expires_at > ? AND pending_approval = 0) AS thucThi, (SELECT COUNT(*) FROM enforcements WHERE revoked_at IS NULL AND expires_at > ? AND pending_approval = 1) AS choDuyet, (SELECT COUNT(*) FROM appeals WHERE status = 'open') AS khieuNai",
      ).bind(bayGio, bayGio),
      // M2 (Q56): thiết bị hoạt động 30 ngày theo gói (NULL = đăng ký trước M2 = app miễn phí).
      d.prepare("SELECT coalesce(package_name, '?') AS k, COUNT(*) AS n FROM devices WHERE last_seen >= ? GROUP BY k ORDER BY n DESC LIMIT 8").bind(thang),
    ]);
    const ds = (i: number) => (kq[i]?.results ?? []) as Dem[];
    const tong = (kq[1]?.results[0] ?? { n: 0, dau: 0, mau: 0 }) as { n: number; dau: number | null; mau: number | null };
    const vt = vaiTro(c);
    return c.json({
      luc: bayGio,
      thietBi: { tong: tong.n, dau: tong.dau ?? 0, mau: tong.mau ?? 0, trangThai: ds(0) },
      heDieuHanh: ds(2),
      phienBan: ds(3),
      quocGia: ds(4),
      suKien24h: { loai: ds(5), theoGio: ds(6).map((x) => ({ k: Number(x.k) * 3600000, n: x.n })) },
      topIp: ds(7).map((x) => ({ k: cheIp(String(x.k), vt), n: x.n })),
      topAsn: ds(8),
      dem: kq[9]?.results[0] ?? {},
      ungDung: ds(10),
      haTang: { moiTruong: c.env.MOI_TRUONG, build: c.env.BAN_BUILD ?? 'dev', d1Ms: Date.now() - batDau },
    });
  });

  r.get('/thiet-bi', canQuyen('thiet-bi:ds'), async (c) => {
    const loc = docLocThietBi(c.req.query());
    const tv = truyVanThietBi(loc, Date.now(), tachDs(c.env.PI_GOI_PRO));
    const batDau = Date.now();
    const { results } = await db(c)
      .prepare(tv.sql)
      .bind(...tv.thamSo)
      .all<{ id: string; last_seen: number; risk_score: number; ip: string | null } & Record<string, unknown>>();
    const conNua = results.length > tv.gioiHan;
    const trang = results.slice(0, tv.gioiHan);
    const cuoi = trang.at(-1);
    const vt = vaiTro(c);
    return c.json({
      ds: trang.map((d) => ({ ...d, ip: cheIp(d.ip, vt) })),
      tiepTheo: conNua && cuoi ? maHoaCursor(giaTriCursor(cuoi, loc)) : null,
      ms: Date.now() - batDau,
    });
  });

  r.get('/thiet-bi/:id', canQuyen('thiet-bi:chi-tiet'), async (c) => {
    const id = c.req.param('id');
    if (!laIdHopLe(id)) throw new LoiApi(400, 'id-loi');
    const d = db(c);
    const tb = await d
      .prepare(
        'SELECT id, platform, package_name, model, os_version, app_version, build, locale, status, risk_score, attestation_level, attested_at, attest_signals, country, first_seen, last_seen, last_violation_at FROM devices WHERE id = ?',
      )
      .bind(id)
      .first<Record<string, unknown> & { attest_signals: string | null }>();
    if (!tb) throw new LoiApi(404, 'khong-thay');
    const [ips, suKien, lienQuan, thucThi, khieuNai, phien] = await d.batch([
      d.prepare('SELECT ip, asn, country, first_seen, last_seen, count, ip_masked FROM device_ips WHERE device_id = ? ORDER BY last_seen DESC LIMIT 50').bind(id),
      d.prepare('SELECT id, type, severity, signals, ip, ts, rule_id, risk_delta FROM security_events WHERE device_id = ? ORDER BY ts DESC LIMIT 200').bind(id),
      d
        .prepare(
          'SELECT l.linked_device_id AS id, l.score, l.signals, l.ts, x.status, x.model FROM device_links l JOIN devices x ON x.id = l.linked_device_id WHERE l.device_id = ? UNION ALL SELECT l.device_id AS id, l.score, l.signals, l.ts, x.status, x.model FROM device_links l JOIN devices x ON x.id = l.device_id WHERE l.linked_device_id = ? ORDER BY score DESC LIMIT 50',
        )
        .bind(id, id),
      d
        .prepare(
          "SELECT id, target_type, target_value, action, reason, created_by, approved_by, created_at, expires_at, revoked_at, source, pending_approval, rule_id, level FROM enforcements WHERE (target_type = 'device' AND target_value = ?) OR (target_type = 'ip' AND target_value IN (SELECT ip FROM device_ips WHERE device_id = ?)) ORDER BY created_at DESC LIMIT 50",
        )
        .bind(id, id),
      d.prepare('SELECT id, enforcement_id, message, status, reviewed_by, ts FROM appeals WHERE device_id = ? ORDER BY ts DESC LIMIT 20').bind(id),
      d.prepare('SELECT COUNT(*) AS n FROM sessions WHERE device_id = ? AND revoked_at IS NULL AND expires_at > ?').bind(id, Date.now()),
    ]);
    const qt = c.get('quanTri') as { email: string };
    const bayGio = Date.now();
    // Xem chi tiết = truy cập dữ liệu cá nhân (IP đầy đủ, timeline) -> có dấu vết audit.
    c.executionCtx.waitUntil(
      ghiAudit(d, { id: taoUlid(bayGio), actor: qt.email, action: 'xem:thiet-bi', target: `device:${id}`, before: null, after: null, ip: c.get('ip') || null, ts: bayGio }),
    );
    const voiTinHieu = <T extends { signals?: string | null }>(ds: T[]) => ds.map((x) => ({ ...x, signals: json(x.signals ?? null) }));
    return c.json({
      thietBi: { ...tb, attest_signals: json(tb.attest_signals) },
      ips: ips?.results ?? [],
      suKien: voiTinHieu((suKien?.results ?? []) as { signals: string }[]),
      lienQuan: voiTinHieu((lienQuan?.results ?? []) as { signals: string }[]),
      thucThi: thucThi?.results ?? [],
      khieuNai: khieuNai?.results ?? [],
      phienHoatDong: (phien?.results[0] as { n: number } | undefined)?.n ?? 0,
    });
  });

  r.get('/ws', canQuyen('tong-quan'), async (c) => {
    if (c.req.header('upgrade')?.toLowerCase() !== 'websocket') throw new LoiApi(426, 'can-websocket');
    const p = c.get('phienSoc') as { expiresAt: number };
    return vaoPhongSoc(c.env, c.req.raw, vaiTro(c), p.expiresAt);
  });
}
