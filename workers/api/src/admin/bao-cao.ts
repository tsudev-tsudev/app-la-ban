// Báo cáo SOC (S7c2, Spec §8.2-8). `/bao-cao/tong-hop`: số liệu gộp theo khoảng (không PII) cho trang báo cáo - in / lưu
// PDF bằng trình duyệt (không thêm thư viện, thuỷ vân in kèm). `/bao-cao/xuat`: CSV có kiểm soát - quyền analyst + passkey
// gần đây + audit mỗi lần (loại, khoảng, số dòng), che PII theo vai trò ở server, trần 10.000 dòng.
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { dayNgay, DINH_NGHIA, docKhoang, DONG_TOI_DA, kiemKhoang, LECH_VN_MS, SchemaXuat, taoCsv, tenTep } from '../thuan/bao-cao';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import type { VaiTro } from '../thuan/soc';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

type Dem = { k: string | number | null; n: number };

export function dangKyBaoCao(r: Hono<MoiTruongHono>): void {
  r.get('/bao-cao/tong-hop', canQuyen('bao-cao:xem'), async (c) => {
    const k = docKhoang(c.req.query(), Date.now());
    if (!k) throw new LoiApi(422, 'khoang-sai');
    const d = db(c);
    const batDau = Date.now();
    const ngay = `strftime('%Y-%m-%d', (ts + ${LECH_VN_MS}) / 1000, 'unixepoch')`;
    const kq = await d.batch([
      d.prepare('SELECT COUNT(*) AS tong, SUM(first_seen >= ?1 AND first_seen < ?2) AS moi, SUM(last_seen >= ?1 AND last_seen < ?2) AS hoatDong FROM devices').bind(k.tu, k.den),
      d.prepare('SELECT status AS k, COUNT(*) AS n FROM devices GROUP BY status'),
      d.prepare('SELECT severity AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? AND ts < ? GROUP BY severity').bind(k.tu, k.den),
      d.prepare('SELECT type AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? AND ts < ? GROUP BY type ORDER BY n DESC LIMIT 12').bind(k.tu, k.den),
      d.prepare(`SELECT ${ngay} AS k, COUNT(*) AS n FROM security_events WHERE ts >= ? AND ts < ? GROUP BY k ORDER BY k`).bind(k.tu, k.den),
      d.prepare("SELECT action || '|' || source AS k, COUNT(*) AS n FROM enforcements WHERE created_at >= ? AND created_at < ? GROUP BY k ORDER BY n DESC").bind(k.tu, k.den),
      d
        .prepare('SELECT SUM(revoked_at >= ?1 AND revoked_at < ?2) AS goTrongKy, SUM(revoked_at IS NULL AND expires_at > ?3 AND (pending_approval = 0 OR approved_by IS NOT NULL)) AS hieuLuc FROM enforcements')
        .bind(k.tu, k.den, Date.now()),
      d.prepare('SELECT status AS k, COUNT(*) AS n, AVG(reviewed_at - ts) AS tb FROM appeals WHERE ts >= ? AND ts < ? GROUP BY status').bind(k.tu, k.den),
      d.prepare('SELECT severity AS k, COUNT(*) AS n FROM alerts WHERE first_ts >= ? AND first_ts < ? GROUP BY severity').bind(k.tu, k.den),
      d.prepare("SELECT coalesce(resolution, status) AS k, COUNT(*) AS n FROM alerts WHERE first_ts >= ? AND first_ts < ? GROUP BY k").bind(k.tu, k.den),
      d.prepare('SELECT rule_id AS k, COUNT(*) AS n FROM rule_hits WHERE ts >= ? AND ts < ? AND shadow = 0 GROUP BY rule_id ORDER BY n DESC LIMIT 10').bind(k.tu, k.den),
      d.prepare("SELECT substr(action, 1, instr(action || ':', ':') - 1) AS k, COUNT(*) AS n FROM audit_logs WHERE ts >= ? AND ts < ? GROUP BY k ORDER BY n DESC LIMIT 12").bind(k.tu, k.den),
      d.prepare('SELECT target AS k, COUNT(*) AS n FROM config_versions WHERE issued_at >= ? AND issued_at < ? GROUP BY target').bind(k.tu, k.den),
    ]);
    const ds = (i: number) => (kq[i]?.results ?? []) as Dem[];
    const tb = kq[0]?.results[0] as { tong: number; moi: number | null; hoatDong: number | null } | undefined;
    const tt = kq[6]?.results[0] as { goTrongKy: number | null; hieuLuc: number | null } | undefined;
    return c.json({
      khoang: k,
      taoLuc: Date.now(),
      moiTruong: c.env.MOI_TRUONG,
      thietBi: { tong: tb?.tong ?? 0, moi: tb?.moi ?? 0, hoatDong: tb?.hoatDong ?? 0, trangThai: ds(1) },
      suKien: { mucDo: ds(2), loai: ds(3), theoNgay: dayNgay(k, ds(4) as { k: string; n: number }[]) },
      thucThi: {
        theoLoai: ds(5).map((x) => {
          const [hanhDong, nguon] = String(x.k).split('|');
          return { hanhDong, nguon, n: x.n };
        }),
        goTrongKy: tt?.goTrongKy ?? 0,
        hieuLuc: tt?.hieuLuc ?? 0,
      },
      khieuNai: (kq[7]?.results ?? []).map((x) => {
        const y = x as { k: string; n: number; tb: number | null };
        return { k: y.k, n: y.n, tbXuLyMs: y.tb === null ? null : Math.round(y.tb) };
      }),
      canhBao: { mucDo: ds(8), ketLuan: ds(9) },
      rule: ds(10),
      audit: ds(11),
      cauHinh: ds(12),
      d1Ms: Date.now() - batDau,
    });
  });

  r.post('/bao-cao/xuat', canQuyen('bao-cao:xuat'), canStepUp, async (c) => {
    if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
    const b = phanTichBody(await c.req.text(), SchemaXuat);
    const bayGio = Date.now();
    const k = kiemKhoang(b.tu, b.den, bayGio);
    if (!k) throw new LoiApi(422, 'khoang-sai');
    const d = db(c);
    const qt = c.get('quanTri') as { email: string; vaiTro: VaiTro };
    const dn = DINH_NGHIA[b.loai];
    const { results } = await d.prepare(dn.sql).bind(k.tu, k.den, DONG_TOI_DA + 1).all<Record<string, unknown>>();
    const cat = results.length > DONG_TOI_DA;
    const dong = results.slice(0, DONG_TOI_DA).map((x) => dn.dong(x, qt.vaiTro));
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: qt.email,
      action: 'bao-cao:xuat',
      target: `bao-cao:${b.loai}`,
      before: null,
      after: { tu: k.tu, den: k.den, soDong: dong.length, cat, vaiTro: qt.vaiTro },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.body(taoCsv(dn.cot, dong), 200, {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': `attachment; filename="${tenTep(b.loai, k)}"`,
      'cache-control': 'no-store',
      'x-so-dong': String(dong.length),
      'x-bi-cat': cat ? '1' : '0',
    });
  });
}
