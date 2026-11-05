// Tổng quan realtime (Spec §8.2 mục 1): ô số liệu, phân bố trạng thái, sự kiện 24 giờ theo giờ, xếp hạng, luồng sự kiện
// trực tiếp qua WebSocket (đo độ trễ server nhận -> màn hình), cảnh báo gần đây, hạ tầng.
import { useEffect, useRef, useState } from 'react';
import type { CanhBao, TinSoc, TongQuan as DuLieuTongQuan } from '../api';
import { useSoc } from '../ngu-canh';
import { MucDo, NhanTrangThai, OSo, ThanhXepHang, ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';

const TRANG_THAI = ['clean', 'suspicious', 'restricted', 'banned'] as const;
const TOI_DA_TIN = 50;

type TinHien = TinSoc & { den: number };

function useLuongSoc(): { ds: TinHien[]; ketNoi: boolean } {
  const { hetPhien } = useSoc();
  const [ds, datDs] = useState<TinHien[]>([]);
  const [ketNoi, datKetNoi] = useState(false);
  useEffect(() => {
    let ws: WebSocket | null = null;
    let lanThu = 0;
    let hen = 0;
    let ping = 0;
    let dung = false;
    const mo = () => {
      ws = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/api/ws`);
      ws.onopen = () => {
        lanThu = 0;
        datKetNoi(true);
        ping = window.setInterval(() => ws?.readyState === WebSocket.OPEN && ws.send('ping'), 30_000);
      };
      ws.onmessage = (e) => {
        if (e.data === 'pong') return;
        try {
          const tin = JSON.parse(String(e.data)) as TinSoc;
          datDs((cu) => [{ ...tin, den: Date.now() }, ...cu].slice(0, TOI_DA_TIN));
        } catch {
          // Bỏ tin hỏng.
        }
      };
      ws.onclose = (e) => {
        clearInterval(ping);
        datKetNoi(false);
        if (dung) return;
        if (e.code === 4401) return hetPhien();
        hen = window.setTimeout(mo, Math.min(30_000, 1000 * 2 ** lanThu++));
      };
    };
    mo();
    return () => {
      dung = true;
      clearTimeout(hen);
      clearInterval(ping);
      ws?.close();
    };
  }, [hetPhien]);
  return { ds, ketNoi };
}

/** Đèn kết nối có trễ (A9c): nối lại chớp nhoáng (backoff 1-2 giây) không làm đèn nháy cam; chỉ báo mất khi rớt quá
 * [choMs]. Có kết nối thì xanh ngay. Chỉ ảnh hưởng HIỂN THỊ - luồng WebSocket giữ nguyên. */
function useKetNoiOnDinh(ketNoi: boolean, choMs = 3000): boolean {
  const [hien, datHien] = useState(true);
  useEffect(() => {
    if (ketNoi) {
      datHien(true);
      return;
    }
    const hen = setTimeout(() => datHien(false), choMs);
    return () => clearTimeout(hen);
  }, [ketNoi, choMs]);
  return hien;
}

function CotTheoGio({ ds }: { ds: { k: string | number | null; n: number }[] }) {
  const { t, nn } = useSoc();
  const gioHienTai = Math.floor(Date.now() / 3_600_000);
  const theoGio = new Map(ds.map((x) => [Math.floor(Number(x.k) / 3_600_000), x.n]));
  const cot = Array.from({ length: 24 }, (_, i) => {
    const gio = gioHienTai - 23 + i;
    return { gio, n: theoGio.get(gio) ?? 0 };
  });
  const lon = Math.max(1, ...cot.map((c) => c.n));
  const W = 24 * 14;
  const H = 120;
  return (
    <figure className="bieu-do">
      <svg viewBox={`0 0 ${W} ${H + 18}`} role="img" aria-label={t.suKienTheoGio} preserveAspectRatio="none">
        <line x1="0" x2={W} y1={H} y2={H} className="truc" />
        {cot.map((c, i) => {
          const cao = (c.n / lon) * (H - 8);
          return (
            <g key={c.gio}>
              <rect className="cot-nen" x={i * 14} y={0} width={14} height={H} />
              {c.n > 0 && <rect className="cot" x={i * 14 + 2} y={H - cao} width={10} height={cao} rx={2} />}
              <title>{`${dinhDangLuc(c.gio * 3_600_000, nn)}: ${dinhDangSo(c.n, nn)}`}</title>
              {i % 6 === 0 && (
                <text x={i * 14 + 7} y={H + 14} className="nhan-truc">
                  {new Intl.DateTimeFormat(nn === 'en' ? 'en-GB' : 'vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', hour: '2-digit', minute: '2-digit' }).format(c.gio * 3_600_000)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
      <figcaption className="o-so-phu">{dinhDangSo(lon, nn)} max</figcaption>
    </figure>
  );
}

function PhanBoTrangThai({ ds }: { ds: { k: string | number | null; n: number }[] }) {
  const { t, nn } = useSoc();
  const dem = new Map(ds.map((x) => [String(x.k), x.n]));
  const tong = Math.max(1, ds.reduce((a, x) => a + x.n, 0));
  return (
    <div>
      <div className="thanh-xep-chong" role="img" aria-label={t.phanBoTrangThai}>
        {TRANG_THAI.filter((k) => (dem.get(k) ?? 0) > 0).map((k) => (
          <span key={k} className={`doan tt-nen-${k}`} style={{ inlineSize: `${((dem.get(k) ?? 0) / tong) * 100}%` }} title={`${t.trangThai[k]}: ${dem.get(k)}`} />
        ))}
      </div>
      <ul className="chu-giai">
        {TRANG_THAI.map((k) => (
          <li key={k}>
            <NhanTrangThai tt={k} />
            <strong>{dinhDangSo(dem.get(k) ?? 0, nn)}</strong>
            <span className="o-so-phu">{(((dem.get(k) ?? 0) / tong) * 100).toFixed(1)}%</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function TongQuan() {
  const { t, nn } = useSoc();
  const tq = useTai<DuLieuTongQuan>('/tong-quan', 30_000);
  const cb = useTai<{ ds: CanhBao[] }>('/canh-bao?limit=12', 30_000);
  const luong = useLuongSoc();
  const ketNoi = useKetNoiOnDinh(luong.ketNoi);
  const soTinTruoc = useRef(0);
  const { napLai: napTq } = tq;
  const { napLai: napCb } = cb;
  // Có sự kiện mới -> làm mới số liệu (gộp: tối đa mỗi 3 giây).
  useEffect(() => {
    if (luong.ds.length === soTinTruoc.current) return;
    soTinTruoc.current = luong.ds.length;
    const hen = setTimeout(() => {
      napTq(true);
      napCb(true);
    }, 3000);
    return () => clearTimeout(hen);
  }, [luong.ds.length, napTq, napCb]);

  if (tq.loi && !tq.duLieu) return <ThongBaoLoi loi={tq.loi} napLai={tq.napLai} />;
  const d = tq.duLieu;
  if (!d) return <p>{t.dangTai}</p>;
  return (
    <div className="luoi-tong-quan">
      <section className="hang-o-so" aria-label={t.tongQuan}>
        <OSo nhan={t.tongThietBi} giaTri={d.thietBi.tong} />
        <OSo nhan={t.dau} giaTri={d.thietBi.dau} />
        <OSo nhan={t.mau} giaTri={d.thietBi.mau} />
        <OSo nhan={t.canhBaoMo} giaTri={d.dem.canhBao} />
        <OSo nhan={t.thucThiHieuLuc} giaTri={d.dem.thucThi} nhan2={`${t.choDuyet}: ${d.dem.choDuyet ?? 0}`} />
        <OSo nhan={t.khieuNaiMo} giaTri={d.dem.khieuNai} />
      </section>

      <section className="the rong-2">
        <h2>{t.phanBoTrangThai}</h2>
        <PhanBoTrangThai ds={d.thietBi.trangThai} />
      </section>

      <section className="the rong-2 hang-2">
        <div className="tieu-de-the">
          <h2>{t.realtime}</h2>
          <span className={ketNoi ? 'den-xanh' : 'den-cam'}>{ketNoi ? t.ketNoi : t.matKetNoi}</span>
        </div>
        {luong.ds.length === 0 ? (
          <p className="trong">{t.realtimeTrong}</p>
        ) : (
          <ol className="luong" aria-live="polite">
            {luong.ds.map((m, i) => (
              <li key={`${m.nhanLuc}-${i}`}>
                <time>{dinhDangLuc(m.nhanLuc, nn)}</time>
                <span className="luong-loai">
                  {m.ds.map((e, j) => (
                    <span key={j}>
                      <MucDo muc={e.severity} /> {e.type}
                    </span>
                  ))}
                </span>
                <span className="o-so-phu">
                  {m.thietBi ? <a href={`#/thiet-bi/${m.thietBi}`}>{m.thietBi.slice(0, 10)}</a> : m.ip} · {m.quocGia ?? '??'} · {t.doTre(Math.max(0, m.den - m.nhanLuc))}
                </span>
                {m.trangThai && <NhanTrangThai tt={m.trangThai} />}
              </li>
            ))}
          </ol>
        )}
      </section>

      <section className="the rong-2">
        <h2>{t.suKienTheoGio}</h2>
        <CotTheoGio ds={d.suKien24h.theoGio} />
      </section>
      <section className="the">
        <h2>{t.loaiSuKien}</h2>
        <ThanhXepHang ds={d.suKien24h.loai} />
      </section>
      <section className="the">
        <h2>{t.topIp}</h2>
        <ThanhXepHang ds={d.topIp} />
      </section>
      <section className="the">
        <h2>{t.topAsn}</h2>
        <ThanhXepHang ds={d.topAsn} nhan={(k) => `AS${k}`} />
      </section>
      <section className="the">
        <h2>{t.quocGia}</h2>
        <ThanhXepHang ds={d.quocGia} />
      </section>
      <section className="the">
        <h2>{t.heDieuHanh}</h2>
        <ThanhXepHang ds={d.heDieuHanh} />
      </section>
      <section className="the">
        <h2>{t.phienBanApp}</h2>
        <ThanhXepHang ds={d.phienBan} />
      </section>
      <section className="the">
        <h2>{t.ungDungTq}</h2>
        <ThanhXepHang ds={d.ungDung ?? []} nhan={(k) => (k === '?' ? t.goiCu : String(k))} />
      </section>

      <section className="the rong-3">
        <div className="tieu-de-the">
          <h2>{t.canhBaoGanDay}</h2>
          <a href="#/canh-bao">{t.moTrungTamCb}</a>
        </div>
        {!cb.duLieu || cb.duLieu.ds.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <div className="cuon-ngang">
            <table className="bang">
              <thead>
                <tr>
                  <th>{t.cotCb.muc}</th>
                  <th>{t.cotCb.rule}</th>
                  <th>{t.cotCb.nhom}</th>
                  <th className="so">{t.cotCb.lan}</th>
                  <th>{t.cotCb.trangThai}</th>
                  <th>{t.cotCb.nguoi}</th>
                  <th>{t.cotCb.cuoi}</th>
                </tr>
              </thead>
              <tbody>
                {cb.duLieu.ds.map((a) => (
                  <tr key={a.id}>
                    <td>
                      <MucDo muc={a.severity} />
                    </td>
                    <td>
                      <a href={`#/canh-bao/${a.id}`}>
                        <strong>{a.rule_id}</strong> {a.rule_name}
                      </a>
                      {a.shadow ? <span className="nhan-phu"> {t.shadow}</span> : null}
                    </td>
                    <td className="ma">{a.group_key}</td>
                    <td className="so">{t.lan(a.count)}</td>
                    <td>
                      <span className={`trang-thai cb-${a.status}`}>{t.ttCb[a.status] ?? a.status}</span>
                    </td>
                    <td>{a.assignee ?? '-'}</td>
                    <td title={dinhDangLuc(a.last_ts, nn)}>{truocDay(a.last_ts, nn)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="the">
        <h2>{t.haTang}</h2>
        <dl className="dl">
          <dt>{t.moiTruong}</dt>
          <dd>{d.haTang.moiTruong}</dd>
          <dt>{t.banBuild}</dt>
          <dd className="ma">{d.haTang.build}</dd>
          <dt>D1</dt>
          <dd>{t.d1(d.haTang.d1Ms)}</dd>
        </dl>
        <p className="o-so-phu">{t.capNhatLuc(dinhDangLuc(d.luc, nn))}</p>
      </section>
    </div>
  );
}
