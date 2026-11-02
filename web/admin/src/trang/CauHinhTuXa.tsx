// Remote Config ký số (S7c2, Spec §8.2-7): gói đang phục vụ (app + khiên web) -> đề xuất (lý do + passkey) -> Security
// Admin THỨ HAI duyệt (passkey) -> Worker ký Ed25519 + đưa lên KV. Server kiểm lại mọi thứ; giao diện chỉ báo sớm.
import { useEffect, useState } from 'react';
import type { CauHinhTuXa as DuLieu, DeXuatApp, DeXuatWeb, YeuCauCauHinh } from '../api';
import { useThongBao } from '../giao-dien/ThongBao';
import { ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';
import { khacBietApp, khacBietWeb, loiDeXuatApp, type DongKhac } from './s7c2';

type Gui = { dich: 'app'; noiDung: DeXuatApp } | { dich: 'web'; noiDung: DeXuatWeb };

function BangKhac({ ds, nhan }: { ds: DongKhac[]; nhan: (truong: string) => string }) {
  const { t } = useSoc();
  if (ds.length === 0) return <p className="o-so-phu">{t.chKhongDoi}</p>;
  return (
    <table className="bang bang-khac">
      <caption>{t.chThayDoi}</caption>
      <tbody>
        {ds.map((x) => (
          <tr key={x.truong}>
            <th scope="row">{nhan(x.truong)}</th>
            <td>
              <del>{x.cu}</del>
            </td>
            <td>
              <ins>{x.moi}</ins>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export function CauHinhTuXa() {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const sua = coQuyen('cau-hinh-tu-xa:sua');
  const { duLieu: d, loi, napLai } = useTai<DuLieu>('/cau-hinh-tu-xa');
  const [app, datApp] = useState<DeXuatApp | null>(null);
  const [web, datWeb] = useState<DeXuatWeb | null>(null);
  const [gui, datGui] = useState<Gui | null>(null);
  const [quyet, datQuyet] = useState<{ y: YeuCauCauHinh; dongY: boolean } | null>(null);

  useEffect(() => {
    if (!d) return;
    datApp(d.app.deXuat);
    datWeb(d.web.deXuat);
  }, [d]);

  if (loi) return <ThongBaoLoi loi={loi} napLai={napLai} />;
  if (!d || !app || !web) return <p className="trong">{t.dangTai}</p>;

  const tenPin = (p: string) => d.gocDongGoi.find((g) => g.pin === p)?.ten ?? `${p.slice(0, 8)}…`;
  const nhanTruong = (k: string) =>
    ({ toiThieu: t.chToiThieu, khuyenNghi: t.chKhuyenNghi, tat: t.chTat, pin: t.chPin, landing: t.chLanding, admin: t.chAdmin })[k] ?? k;
  const khacApp = khacBietApp(d.app.deXuat, app, tenPin).map((x) => (x.truong === 'tat' ? { ...x, cu: x.cu.split(', ').map((f) => t.chTinhNang[f] ?? f).join(', '), moi: x.moi.split(', ').map((f) => t.chTinhNang[f] ?? f).join(', ') } : x));
  const khacWeb = khacBietWeb(d.web.deXuat, web).map((x) => ({ ...x, cu: t.chMuc[x.cu] ?? x.cu, moi: t.chMuc[x.moi] ?? x.moi }));
  const loiApp = loiDeXuatApp(app, d.banMoi);
  const choApp = d.yeuCau.some((y) => y.target === 'app' && y.status === 'pending' && !y.hetHan);
  const choWeb = d.yeuCau.some((y) => y.target === 'web' && y.status === 'pending' && !y.hetHan);
  const pinThem = (Array.isArray(d.app.noiDung?.gocThem) ? d.app.noiDung.gocThem : []).length;

  const TrangThaiGoi = ({ g }: { g: DuLieu['app'] | DuLieu['web'] }) =>
    !g.noiDung ? (
      <p className="o-so-phu">{t.chChuaCo}</p>
    ) : (
      <p className="o-so-phu">
        <span className={g.chuKyDung ? 'trang-thai tt-clean' : 'trang-thai tt-banned'}>{g.chuKyDung ? t.chChuKyDung : t.chChuKySai}</span> · {t.chPhatHanh}{' '}
        {dinhDangLuc(Number(g.noiDung.phatHanh), nn)} · {t.chHet} {dinhDangLuc(Number(g.noiDung.het), nn)}
      </p>
    );

  return (
    <div className="trang-chinh cau-hinh-tu-xa">
      <p className="mo-ta-trang">{t.chMoTa}</p>
      <p className="o-so-phu">{t.chLanTruyen}</p>
      {!sua && <p className="ghi-chu-vai-tro">{t.chChiXem}</p>}

      <div className="luoi-bao-cao">
        <section className="the">
          <h2>{t.chApp}</h2>
          <TrangThaiGoi g={d.app} />
          {!d.coKhoa.app && <p className="canh-bao-chu">{t.chThieuKhoa}</p>}
          <fieldset className="bo-loc doc" disabled={!sua || choApp}>
            <legend>{t.chDeXuat}</legend>
            <label>
              <span>
                {t.chToiThieu} <span className="o-so-phu">({t.chToiThieuMoTa})</span>
              </span>
              <input type="number" min={1} value={app.toiThieu} onChange={(e) => datApp({ ...app, toiThieu: Number(e.target.value) })} />
            </label>
            <label>
              <span>
                {t.chKhuyenNghi} <span className="o-so-phu">({t.chKhuyenNghiMoTa})</span>
              </span>
              <input type="number" min={1} value={app.khuyenNghi} onChange={(e) => datApp({ ...app, khuyenNghi: Number(e.target.value) })} />
            </label>
            {d.banMoi !== null && <p className="o-so-phu">{t.chBanMoi(d.banMoi)}</p>}
            <fieldset>
              <legend>{t.chTat}</legend>
              {d.tinhNang.map((f) => (
                <label key={f} className="hang">
                  <input
                    type="checkbox"
                    checked={app.tat.includes(f)}
                    onChange={(e) => datApp({ ...app, tat: e.target.checked ? [...app.tat, f] : app.tat.filter((x) => x !== f) })}
                  />
                  <span>{t.chTinhNang[f] ?? f}</span>
                </label>
              ))}
            </fieldset>
            <fieldset>
              <legend>{t.chPin}</legend>
              {d.gocDongGoi.map((g) => (
                <label key={g.pin} className="hang">
                  <input
                    type="checkbox"
                    checked={app.pin.includes(g.pin)}
                    onChange={(e) => datApp({ ...app, pin: e.target.checked ? [...app.pin, g.pin] : app.pin.filter((x) => x !== g.pin) })}
                  />
                  <span>
                    {g.ten} <span className="o-so-phu">({g.het})</span>
                  </span>
                </label>
              ))}
              {pinThem > 0 && <p className="o-so-phu">{t.chGocThem(pinThem)}</p>}
            </fieldset>
            <label>
              <span>{t.chNgay}</span>
              <input type="number" min={1} max={365} value={app.ngay} onChange={(e) => datApp({ ...app, ngay: Number(e.target.value) })} />
            </label>
            <BangKhac ds={khacApp} nhan={nhanTruong} />
            {app.toiThieu > d.app.deXuat.toiThieu && <p className="canh-bao-chu">{t.chCanhBaoToiThieu}</p>}
            {app.tat.some((f) => !d.app.deXuat.tat.includes(f)) && <p className="canh-bao-chu">{t.chCanhBaoTat}</p>}
            {loiApp && <p className="canh-bao-chu" role="alert">{t.loiMa[loiApp]}</p>}
            {sua && (
              <div className="hang-nut trai">
                <button type="button" className="nut nut-chinh" disabled={khacApp.length === 0 || loiApp !== null} onClick={() => datGui({ dich: 'app', noiDung: app })}>
                  {t.chDeXuat}
                </button>
              </div>
            )}
          </fieldset>
        </section>

        <section className="the">
          <h2>{t.chWeb}</h2>
          <TrangThaiGoi g={d.web} />
          {!d.coKhoa.web && <p className="canh-bao-chu">{t.chThieuKhoa}</p>}
          <fieldset className="bo-loc doc" disabled={!sua || choWeb}>
            <legend>{t.chDeXuat}</legend>
            {(['landing', 'admin'] as const).map((k) => (
              <label key={k}>
                <span>{k === 'landing' ? t.chLanding : t.chAdmin}</span>
                <select value={web[k]} onChange={(e) => datWeb({ ...web, [k]: e.target.value })}>
                  {['chat', 'nhe', 'tat'].map((m) => (
                    <option key={m} value={m}>
                      {t.chMuc[m]}
                    </option>
                  ))}
                </select>
              </label>
            ))}
            <label>
              <span>{t.chNgay}</span>
              <input type="number" min={1} max={365} value={web.ngay} onChange={(e) => datWeb({ ...web, ngay: Number(e.target.value) })} />
            </label>
            <BangKhac ds={khacWeb} nhan={nhanTruong} />
            {sua && (
              <div className="hang-nut trai">
                <button type="button" className="nut nut-chinh" disabled={khacWeb.length === 0} onClick={() => datGui({ dich: 'web', noiDung: web })}>
                  {t.chDeXuat}
                </button>
              </div>
            )}
          </fieldset>
        </section>
      </div>

      <section className="the">
        <h2>{t.chYeuCau}</h2>
        {d.yeuCau.length === 0 && <p className="trong">{t.chKhongYeuCau}</p>}
        <ul className="ds-yeu-cau">
          {d.yeuCau.map((y) => {
            const tt = y.status === 'pending' && y.hetHan ? 'het-han' : y.status;
            const cuaToi = y.created_by.toLowerCase() === d.toi.toLowerCase();
            const nd = y.payload as Partial<DeXuatApp & DeXuatWeb>;
            return (
              <li key={y.id} className="the-con">
                <p>
                  <strong>{y.target === 'app' ? t.chApp : t.chWeb}</strong> · <span className={`trang-thai tkn-${y.status}`}>{t.chTtYeuCau[tt]}</span> ·{' '}
                  <span title={dinhDangLuc(y.created_at, nn)}>{truocDay(y.created_at, nn)}</span>
                </p>
                <p className="o-so-phu">
                  {t.chTaoBoi}: {y.created_by} · {y.reason}
                  {y.decided_by && y.status !== 'cancelled' && ` · ${t.chDuyetBoi}: ${y.decided_by}${y.decision_note ? ` (${y.decision_note})` : ''}`}
                </p>
                <p className="ma">
                  {y.target === 'app'
                    ? `${t.chToiThieu} ${nd.toiThieu} · ${t.chKhuyenNghi} ${nd.khuyenNghi} · ${t.chTat}: ${(nd.tat ?? []).map((f) => t.chTinhNang[f] ?? f).join(', ') || '-'} · ${t.chPin}: ${(nd.pin ?? []).map(tenPin).join(', ')} · ${nd.ngay} ${t.chNgay}`
                    : `${t.chLanding} ${t.chMuc[nd.landing ?? ''] ?? '-'} · ${t.chAdmin} ${t.chMuc[nd.admin ?? ''] ?? '-'} · ${nd.ngay} ${t.chNgay}`}
                </p>
                {tt === 'pending' && sua && (
                  <div className="hang-nut trai">
                    {cuaToi ? (
                      <>
                        <span className="o-so-phu">{t.chChoNguoiKhac}</span>
                        <button
                          type="button"
                          className="nut nut-phu"
                          onClick={() =>
                            void ghi('/cau-hinh-tu-xa/huy', { id: y.id }).then((kq) => {
                              if (!kq) return;
                              bao(t.chDaHuy);
                              napLai();
                            })
                          }
                        >
                          {t.chHuy}
                        </button>
                      </>
                    ) : (
                      <>
                        <button type="button" className="nut nut-chinh" onClick={() => datQuyet({ y, dongY: true })}>
                          {t.chDuyet}
                        </button>
                        <button type="button" className="nut nut-phu" onClick={() => datQuyet({ y, dongY: false })}>
                          {t.chBac}
                        </button>
                      </>
                    )}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      </section>

      <section className="the">
        <h2>{t.chLichSu}</h2>
        {d.lichSu.length === 0 ? (
          <p className="trong">{t.khongCo}</p>
        ) : (
          <div className="cuon-ngang">
            <table className="bang">
              <thead>
                <tr>
                  <th scope="col">{t.chPhatHanh}</th>
                  <th scope="col">{t.chYeuCau}</th>
                  <th scope="col">{t.chTaoBoi}</th>
                  <th scope="col">{t.chDuyetBoi}</th>
                </tr>
              </thead>
              <tbody>
                {d.lichSu.map((x) => (
                  <tr key={x.id}>
                    <td>{dinhDangLuc(x.issued_at, nn)}</td>
                    <td>{x.target === 'app' ? t.chApp : t.chWeb}</td>
                    <td>{x.created_by}</td>
                    <td>{x.approved_by}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <HopThoaiLyDo
        mo={gui !== null}
        tieuDe={t.chDeXuat}
        canhBao={gui?.dich === 'app' && gui.noiDung.toiThieu > d.app.deXuat.toiThieu ? t.chCanhBaoToiThieu : null}
        nhanXacNhan={t.chDeXuat}
        dong={() => datGui(null)}
        xong={async (lyDo) => {
          if (!gui) return;
          const kq = await ghi<{ id: string }>('/cau-hinh-tu-xa/yeu-cau', { ...gui, lyDo });
          if (!kq) return;
          bao(t.chDaGui);
          datGui(null);
          napLai();
        }}
      />
      <HopThoaiLyDo
        mo={quyet !== null}
        tieuDe={quyet?.dongY ? t.chDuyet : t.chBac}
        canhBao={quyet?.dongY ? t.chMoTa : null}
        nhanXacNhan={quyet?.dongY ? t.chDuyet : t.chBac}
        dong={() => datQuyet(null)}
        xong={async (ghiChu) => {
          if (!quyet) return;
          const kq = await ghi('/cau-hinh-tu-xa/quyet', { id: quyet.y.id, dongY: quyet.dongY, ghiChu });
          if (!kq) return;
          bao(quyet.dongY ? t.chDaDuyet : t.chDaBac);
          datQuyet(null);
          napLai();
        }}
      />
    </div>
  );
}
