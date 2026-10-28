// Liên kết thiết bị (Spec §7.6d): tìm thiết bị khác chung dải IP 30 ngày gần đây, chấm điểm tín hiệu mềm, ghi device_links
// khi >= NGUONG_LIEN_KET. Chỉ để SOC xem "thiết bị liên quan" - không tự động chặn theo liên kết (CGNAT).
import { rutGonIp } from '../thuan/che-pii';
import { diemLienKet, NGUONG_LIEN_KET, type DauVetThietBi } from '../thuan/thuc-thi';

const CUA_SO_MS = 30 * 24 * 60 * 60 * 1000;
const UNG_VIEN_TOI_DA = 50;

type DongTb = {
  id: string;
  platform: string;
  model: string | null;
  os_version: string | null;
  build: number | null;
  locale: string | null;
  country: string | null;
  public_key: string | null;
};

async function dauVet(db: D1Database, ds: DongTb[], tu: number): Promise<DauVetThietBi[]> {
  if (!ds.length) return [];
  const { results } = await db
    .prepare(`SELECT device_id, ip, asn FROM device_ips WHERE last_seen > ? AND device_id IN (${ds.map(() => '?').join(', ')})`)
    .bind(tu, ...ds.map((d) => d.id))
    .all<{ device_id: string; ip: string; asn: number | null }>();
  return ds.map((d) => {
    const ips = results.filter((r) => r.device_id === d.id);
    return {
      id: d.id,
      platform: d.platform,
      model: d.model,
      osVersion: d.os_version,
      build: d.build,
      locale: d.locale,
      country: d.country,
      publicKey: d.public_key,
      daiIp: [...new Set(ips.map((r) => (r.ip.includes('/') ? r.ip : rutGonIp(r.ip))))],
      asn: [...new Set(ips.flatMap((r) => (r.asn === null ? [] : [r.asn])))],
    };
  });
}

const COT = 'id, platform, model, os_version, build, locale, country, public_key';

export async function lienKetThietBi(db: D1Database, thietBi: string, bayGio: number): Promise<number> {
  const tu = bayGio - CUA_SO_MS;
  const goc = await db.prepare(`SELECT ${COT} FROM devices WHERE id = ?`).bind(thietBi).first<DongTb>();
  if (!goc) return 0;
  const [a] = await dauVet(db, [goc], tu);
  if (!a || !a.daiIp.length) return 0;
  // Ứng viên: thiết bị cùng nền tảng có IP chi tiết cùng dải (/24) - lọc thô bằng tiền tố chuỗi IPv4, IPv6 so ở JS.
  const tienTo = a.daiIp.filter((d) => d.endsWith('.0/24')).map((d) => `${d.slice(0, -4)}%`);
  if (!tienTo.length) return 0;
  const { results: ungVien } = await db
    .prepare(
      `SELECT ${COT} FROM devices WHERE platform = ? AND id <> ? AND id IN (SELECT device_id FROM device_ips WHERE last_seen > ? AND (${tienTo
        .map(() => 'ip LIKE ?')
        .join(' OR ')})) LIMIT ${UNG_VIEN_TOI_DA}`,
    )
    .bind(goc.platform, thietBi, tu, ...tienTo)
    .all<DongTb>();
  const lienKet = (await dauVet(db, ungVien, tu))
    .map((b) => ({ b, ...diemLienKet(a, b) }))
    .filter((k) => k.diem >= NGUONG_LIEN_KET);
  if (lienKet.length) {
    await db.batch(
      lienKet.map((k) =>
        db
          .prepare(
            'INSERT INTO device_links (device_id, linked_device_id, score, signals, ts) VALUES (?, ?, ?, ?, ?) ON CONFLICT (device_id, linked_device_id) DO UPDATE SET score = excluded.score, signals = excluded.signals, ts = excluded.ts',
          )
          .bind(thietBi, k.b.id, k.diem, JSON.stringify(k.tinHieu), bayGio),
      ),
    );
  }
  return lienKet.length;
}
