// Chi tiết thiết bị (Spec §8.2 mục 2): thông tin, dòng thời gian sự kiện, lịch sử IP / ASN, thiết bị liên quan, lịch sử
// chặn, khiếu nại. Chỉ Analyst trở lên (server trả 403 cho Viewer). Mỗi lần xem được ghi audit phía server. S7b: Responder
// trở lên chặn / hạn chế thiết bị, gỡ chặn, thu hồi phiên ngay tại đây (lý do + passkey).
import { useState } from 'react';
import { useThongBao } from '../giao-dien/ThongBao';
import { MucDo, NhanTrangThai, ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiChan } from './CanThiep';
import { HopThoaiLyDo } from './Luat';

type ChiTietTb = {
  thietBi: Record<string, unknown> & { id: string; status: string; risk_score: number; attest_signals: unknown };
  ips: { ip: string; asn: number | null; country: string | null; first_seen: number; last_seen: number; count: number; ip_masked: number }[];
  suKien: { id: string; type: string; severity: string; signals: unknown; ip: string | null; ts: number; rule_id: string | null; risk_delta: number }[];
  lienQuan: { id: string; score: number; signals: unknown; ts: number; status: string; model: string | null }[];
  thucThi: { id: string; target_type: string; target_value: string; action: string; reason: string; created_by: string; created_at: number; expires_at: number; revoked_at: number | null; pending_approval: number; level: number }[];
  khieuNai: { id: string; message: string; status: string; reviewed_by: string | null; ts: number }[];
  phienHoatDong: number;
};

const TRUONG = ['platform', 'model', 'os_version', 'app_version', 'build', 'locale', 'attestation_level', 'country', 'first_seen', 'last_seen', 'attested_at', 'last_violation_at'];

export function ChiTiet({ id }: { id: string }) {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const ct = useTai<ChiTietTb>(`/thiet-bi/${encodeURIComponent(id)}`);
  const [hop, datHop] = useState<'chan' | 'thu-hoi' | { go: string } | null>(null);
  const canThiep = coQuyen('can-thiep');
  const quayLai = (
    <a className="nut nut-phu" href="#/thiet-bi">
      ← {t.quayLai}
    </a>
  );
  if (ct.loi) {
    return (
      <div>
        {quayLai}
        {ct.loi.status === 403 ? <p role="alert">{t.chiTietCanQuyen}</p> : <ThongBaoLoi loi={ct.loi} napLai={ct.napLai} />}
      </div>
    );
  }
  const d = ct.duLieu;
  if (!d) return <p>{t.dangTai}</p>;
  const tb = d.thietBi;
  const gia = (k: string) => {
    const v = tb[k];
    if (v === null || v === undefined) return '-';
    return /_(seen|at)$/.test(k) ? dinhDangLuc(Number(v), nn) : String(v);
  };
  return (
    <div className="luoi-chi-tiet">
      <div className="tieu-de-trang">
        {quayLai}
        <h1 className="ma">{tb.id}</h1>
        <NhanTrangThai tt={tb.status} />
        <span className="the-diem">
          {t.cot.diem}: <strong>{tb.risk_score}</strong>
        </span>
        {canThiep && (
          <div className="hang-nut trai day-phai">
            <button type="button" className="nut nut-nguy" onClick={() => datHop('chan')}>
              {t.chanThietBi}
            </button>
            <button type="button" className="nut" disabled={d.phienHoatDong === 0} onClick={() => datHop('thu-hoi')}>
              {t.thuHoiPhien}
            </button>
          </div>
        )}
      </div>

      <section className="the">
        <h2>{t.thongTin}</h2>
        <dl className="dl">
          {TRUONG.map((k) => (
            <div key={k} className="dl-dong">
              <dt>{k}</dt>
              <dd>{gia(k)}</dd>
            </div>
          ))}
          <div className="dl-dong">
            <dt>{t.phienApp}</dt>
            <dd>{d.phienHoatDong}</dd>
          </div>
        </dl>
        {tb.attest_signals ? (
          <details>
            <summary>{t.tinHieuAttest}</summary>
            <pre className="json">{JSON.stringify(tb.attest_signals, null, 2)}</pre>
          </details>
        ) : null}
      </section>

      <section className="the rong-2 hang-2">
        <h2>{t.dongThoiGian}</h2>
        {d.suKien.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <ol className="dong-thoi-gian">
            {d.suKien.map((e) => (
              <li key={e.id}>
                <time>{dinhDangLuc(e.ts, nn)}</time>
                <span>
                  <MucDo muc={e.severity} /> <strong>{e.type}</strong>
                  {e.risk_delta > 0 && <span className="nhan-phu"> +{e.risk_delta}</span>}
                  {e.rule_id && <span className="nhan-phu"> {e.rule_id}</span>}
                </span>
                <span className="ma o-so-phu">{e.ip ?? '-'}</span>
                {e.signals && Object.keys(e.signals as object).length > 0 ? (
                  <details>
                    <summary>signals</summary>
                    <pre className="json">{JSON.stringify(e.signals, null, 2)}</pre>
                  </details>
                ) : null}
              </li>
            ))}
          </ol>
        )}
      </section>

      <section className="the">
        <h2>{t.lichSuIp}</h2>
        <div className="cuon-ngang">
          <table className="bang">
            <thead>
              <tr>
                <th>IP</th>
                <th>ASN</th>
                <th>{t.cot.quocGia}</th>
                <th>{t.lanDau}</th>
                <th>{t.cot.cuoi}</th>
                <th>#</th>
              </tr>
            </thead>
            <tbody>
              {d.ips.map((i) => (
                <tr key={i.ip}>
                  <td className="ma">
                    <a href={`#/thiet-bi?ip=${encodeURIComponent(i.ip)}`}>{i.ip}</a>
                  </td>
                  <td>{i.asn ?? '-'}</td>
                  <td>{i.country ?? '-'}</td>
                  <td>{dinhDangLuc(i.first_seen, nn)}</td>
                  <td>{dinhDangLuc(i.last_seen, nn)}</td>
                  <td className="so">{i.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="the">
        <h2>{t.lienQuan}</h2>
        {d.lienQuan.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <ul className="ds-gon">
            {d.lienQuan.map((l) => (
              <li key={l.id}>
                <a className="ma" href={`#/thiet-bi/${l.id}`}>
                  {l.id.slice(0, 12)}
                </a>{' '}
                {l.model ?? ''} <NhanTrangThai tt={l.status} />{' '}
                <span className="o-so-phu">
                  {t.diemSo} {l.score.toFixed(2)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="the">
        <h2>{t.thucThi}</h2>
        {d.thucThi.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <ul className="ds-gon">
            {d.thucThi.map((x) => (
              <li key={x.id}>
                <strong>{x.action}</strong> {x.target_type}:<span className="ma">{x.target_value}</span> · {x.reason}
                {x.pending_approval ? <span className="nhan-phu"> {t.choDuyetNhan}</span> : null}
                <br />
                <span className="o-so-phu">
                  {dinhDangLuc(x.created_at, nn)} · {x.revoked_at ? `${t.thuHoi} ${dinhDangLuc(x.revoked_at, nn)}` : `${t.hetHan} ${dinhDangLuc(x.expires_at, nn)}`} · {x.created_by}
                </span>
                {canThiep && !x.revoked_at && x.expires_at > Date.now() && (
                  <button type="button" className="nut nut-phu nut-nho" onClick={() => datHop({ go: x.id })}>
                    {t.goChan}
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="the">
        <h2>{t.khieuNai}</h2>
        {d.khieuNai.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <ul className="ds-gon">
            {d.khieuNai.map((k) => (
              <li key={k.id}>
                <span className="o-so-phu">
                  {dinhDangLuc(k.ts, nn)} · {k.status}
                </span>
                <p>{k.message}</p>
              </li>
            ))}
          </ul>
        )}
      </section>
      <HopThoaiChan
        mo={hop === 'chan'}
        dichSan={{ loai: 'device', giaTri: tb.id }}
        dong={() => datHop(null)}
        xong={() => {
          datHop(null);
          ct.napLai();
        }}
      />
      <HopThoaiLyDo
        mo={hop !== null && hop !== 'chan'}
        tieuDe={hop === 'thu-hoi' ? t.thuHoiPhien : t.goChan}
        dong={() => datHop(null)}
        xong={async (lyDo) => {
          const kq = hop === 'thu-hoi' ? await ghi('/thiet-bi/thu-hoi-phien', { thietBi: tb.id, lyDo }) : hop && hop !== 'chan' ? await ghi('/thuc-thi/go', { ids: [hop.go], lyDo }) : null;
          if (kq) {
            bao(t.daLuu);
            datHop(null);
            ct.napLai();
          }
        }}
      />
    </div>
  );
}
