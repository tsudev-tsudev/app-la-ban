// Quyền lợi Pro (M1a bước 4 - 5, SEC-IAP): số liệu + doanh thu ước tính (viewer, không PII), tra cứu theo thiết bị / băm
// token / mã đơn (analyst), gỡ thiết bị khỏi quyền lợi + đề xuất thu hồi (responder, lý do + passkey), duyệt thu hồi
// four-eyes (Security Admin, người khác người đề xuất). Server kiểm lại mọi quyền.
import { useState } from 'react';
import { useThongBao } from '../giao-dien/ThongBao';
import { OSo, ThongBaoLoi, useGhi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';
import { HopThoaiLyDo } from './Luat';

type SoLieu = {
  ngay: number;
  theoSanPham: { source: string; product_id: string; tong: number; hieu_luc: number; thu_hoi: number; mua_thu: number }[];
  suKien: { kind: string; n: number }[];
  choDuyet: number;
  toiDa: number;
  doanhThu: { theoSanPham: { sanPham: string; muaMoi: number; giaHan: number; hoan: number; vnd: number }[]; tongVnd: number; soMuaThu: number } | null;
  doanhThuLyDo: string | null;
};
type DongQl = {
  id: string;
  source: string;
  product_id: string;
  state: string;
  expires_at: number | null;
  token_hash: string | null;
  order_id: string | null;
  account_hash: string | null;
  auto_renew: number | null;
  acknowledged: number;
  test_purchase: number;
  reason: string | null;
  created_at: number;
  updated_at: number;
  so_thiet_bi?: number;
};
type ChiTietQl = {
  quyenLoi: DongQl;
  thietBi: { device_id: string; linked_at: number; seen_at: number; model: string | null; app_version: string | null; status: string | null; hoat_dong: number }[];
  suKien: { id: string; kind: string; detail: unknown; ts: number }[];
  yeuCau: { id: string; kind: string; reason: string; created_by: string; created_at: number; status: string; decided_by: string | null; decision_note: string | null }[];
  toiDa: number;
  toi: string;
};
type YeuCau = { id: string; entitlement_id: string; reason: string; created_by: string; created_at: number; expires_at: number; product_id: string; source: string; state: string };

const NGAY = [7, 30, 90] as const;
const TRANG_THAI = ['', 'hieu-luc', 'active', 'grace', 'canceled', 'on_hold', 'paused', 'pending', 'expired', 'revoked'] as const;
const NGUON = ['', 'play_sub', 'play_inapp', 'pro_app', 'manual'] as const;

export function QuyenLoi() {
  const { t, nn, coQuyen } = useSoc();
  const bao = useThongBao();
  const ghi = useGhi();
  const xem = coQuyen('quyen-loi:xem');
  const xuLy = coQuyen('quyen-loi:xu-ly');
  const duyet = coQuyen('quyen-loi:duyet');
  const [ngay, datNgay] = useState<(typeof NGAY)[number]>(30);
  const sl = useTai<SoLieu>(`/quyen-loi/so-lieu?ngay=${ngay}`);
  const yc = useTai<{ ds: YeuCau[]; toi: string }>(xem ? '/quyen-loi/yeu-cau' : null);
  const [q, datQ] = useState('');
  const [tt, datTt] = useState<(typeof TRANG_THAI)[number]>('');
  const [nguon, datNguon] = useState<(typeof NGUON)[number]>('');
  const [loc, datLoc] = useState('');
  const ds = useTai<{ ds: DongQl[]; tiepTheo: string | null }>(xem ? `/quyen-loi${loc}` : null);
  const [chon, datChon] = useState<string | null>(null);
  const ct = useTai<ChiTietQl>(chon ? `/quyen-loi/chi-tiet?id=${encodeURIComponent(chon)}` : null);
  const [hop, datHop] = useState<{ loai: 'go'; thietBi: string } | { loai: 'thu-hoi' } | { loai: 'quyet'; id: string; dongY: boolean } | null>(null);

  const napHet = () => {
    sl.napLai();
    yc.napLai();
    ds.napLai();
    ct.napLai();
  };
  const timKiem = () => {
    const p = new URLSearchParams();
    if (q.trim()) p.set('q', q.trim());
    if (tt) p.set('trangThai', tt);
    if (nguon) p.set('nguon', nguon);
    const s = p.toString();
    datLoc(s ? `?${s}` : '');
  };
  const tenTt = (s: string) => t.qlTrangThai[s] ?? s;
  const tenNguon = (s: string) => t.qlNguon[s] ?? s;

  return (
    <div className="trang-chinh">
      <p className="mo-ta-trang">{t.qlMoTa}</p>

      <section className="the">
        <div className="tieu-de-the">
          <h2>{t.qlSoLieu}</h2>
          <div className="nhom-nut" role="group" aria-label={t.qlKy}>
            {NGAY.map((n) => (
              <button key={n} type="button" className="nut nut-nho" aria-pressed={ngay === n} onClick={() => datNgay(n)}>
                {t.qlNgay(n)}
              </button>
            ))}
          </div>
        </div>
        {sl.loi && <ThongBaoLoi loi={sl.loi} napLai={sl.napLai} />}
        {sl.duLieu && (
          <>
            <div className="hang-o-so">
              <OSo nhan={t.qlHieuLuc} giaTri={sl.duLieu.theoSanPham.reduce((a, x) => a + x.hieu_luc, 0)} />
              <OSo nhan={t.qlThuHoi} giaTri={sl.duLieu.theoSanPham.reduce((a, x) => a + x.thu_hoi, 0)} />
              <OSo nhan={t.qlChoDuyet} giaTri={sl.duLieu.choDuyet} />
              <OSo nhan={t.qlToiDa} giaTri={sl.duLieu.toiDa} nhan2={t.qlToiDaPhu} />
            </div>
            <h3>{t.qlDoanhThu}</h3>
            {sl.duLieu.doanhThu ? (
              <div className="cuon-ngang">
                <table className="bang">
                  <thead>
                    <tr>
                      <th scope="col">{t.qlSanPham}</th>
                      <th scope="col" className="so">{t.qlMuaMoi}</th>
                      <th scope="col" className="so">{t.qlGiaHan}</th>
                      <th scope="col" className="so">{t.qlHoan}</th>
                      <th scope="col" className="so">{t.qlVnd}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sl.duLieu.doanhThu.theoSanPham.map((x) => (
                      <tr key={x.sanPham}>
                        <td className="ma">{x.sanPham}</td>
                        <td className="so">{dinhDangSo(x.muaMoi, nn)}</td>
                        <td className="so">{dinhDangSo(x.giaHan, nn)}</td>
                        <td className="so">{dinhDangSo(x.hoan, nn)}</td>
                        <td className="so">{dinhDangSo(x.vnd, nn)}</td>
                      </tr>
                    ))}
                    <tr>
                      <th scope="row" colSpan={4}>
                        {t.qlTong}
                      </th>
                      <td className="so">
                        <strong>{dinhDangSo(sl.duLieu.doanhThu.tongVnd, nn)}</strong>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="trong">{t.qlDoanhThuChua(sl.duLieu.doanhThuLyDo ?? '-')}</p>
            )}
            <p className="ghi-chu">{t.qlDoanhThuGhiChu(sl.duLieu.doanhThu?.soMuaThu ?? 0)}</p>
            {sl.duLieu.suKien.length > 0 && (
              <p className="o-so-phu">
                {t.qlSuKienKy}: {sl.duLieu.suKien.map((x) => `${t.qlLoaiSuKien[x.kind] ?? x.kind} ${dinhDangSo(x.n, nn)}`).join(' · ')}
              </p>
            )}
          </>
        )}
      </section>

      {!xem && <p className="ghi-chu-vai-tro">{t.qlChiSoLieu}</p>}

      {xem && yc.duLieu && yc.duLieu.ds.length > 0 && (
        <section className="the">
          <h2>{t.qlYeuCauCho}</h2>
          <ul className="ds-yeu-cau">
            {yc.duLieu.ds.map((y) => {
              const cuaToi = y.created_by.toLowerCase() === yc.duLieu?.toi.toLowerCase();
              return (
                <li key={y.id} className="the-con">
                  <p>
                    <strong>{t.qlThuHoiTieuDe}</strong> ·{' '}
                    <button type="button" className="nut-chu ma" onClick={() => datChon(y.entitlement_id)}>
                      {y.product_id}
                    </button>{' '}
                    · {tenTt(y.state)} · <span title={dinhDangLuc(y.created_at, nn)}>{truocDay(y.created_at, nn)}</span>
                  </p>
                  <p className="o-so-phu">
                    {t.qlTaoBoi}: {y.created_by} · {y.reason} · {t.qlHetHan} {truocDay(y.expires_at, nn)}
                  </p>
                  <div className="hang-nut trai">
                    {cuaToi ? (
                      <>
                        <span className="o-so-phu">{t.qlChoNguoiKhac}</span>
                        <button
                          type="button"
                          className="nut nut-phu"
                          onClick={() =>
                            void ghi('/quyen-loi/yeu-cau/huy', { id: y.id }).then((kq) => {
                              if (!kq) return;
                              bao(t.qlDaHuy);
                              napHet();
                            })
                          }
                        >
                          {t.qlHuy}
                        </button>
                      </>
                    ) : duyet ? (
                      <>
                        <button type="button" className="nut nut-nguy" onClick={() => datHop({ loai: 'quyet', id: y.id, dongY: true })}>
                          {t.qlDuyet}
                        </button>
                        <button type="button" className="nut nut-phu" onClick={() => datHop({ loai: 'quyet', id: y.id, dongY: false })}>
                          {t.qlBac}
                        </button>
                      </>
                    ) : (
                      <span className="o-so-phu">{t.qlCanSecAdmin}</span>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {xem && (
        <section className="the">
          <h2>{t.qlTraCuu}</h2>
          <form
            className="bo-loc"
            onSubmit={(e) => {
              e.preventDefault();
              timKiem();
            }}
          >
            <label>
              <span>{t.qlO}</span>
              <input value={q} maxLength={80} onChange={(e) => datQ(e.target.value)} placeholder={t.qlGoiY} />
            </label>
            <label>
              <span>{t.qlCotTrangThai}</span>
              <select value={tt} onChange={(e) => datTt(e.target.value as (typeof TRANG_THAI)[number])}>
                {TRANG_THAI.map((s) => (
                  <option key={s} value={s}>
                    {s ? tenTt(s) : t.qlTatCa}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>{t.qlCotNguon}</span>
              <select value={nguon} onChange={(e) => datNguon(e.target.value as (typeof NGUON)[number])}>
                {NGUON.map((s) => (
                  <option key={s} value={s}>
                    {s ? tenNguon(s) : t.qlTatCa}
                  </option>
                ))}
              </select>
            </label>
            <button type="submit" className="nut nut-chinh">
              {t.qlTim}
            </button>
          </form>
          {ds.loi && <ThongBaoLoi loi={ds.loi} napLai={ds.napLai} />}
          {ds.duLieu && ds.duLieu.ds.length === 0 && <p className="trong">{t.qlTrong}</p>}
          {ds.duLieu && ds.duLieu.ds.length > 0 && (
            <div className="cuon-ngang">
              <table className="bang">
                <thead>
                  <tr>
                    <th scope="col">{t.qlSanPham}</th>
                    <th scope="col">{t.qlCotNguon}</th>
                    <th scope="col">{t.qlCotTrangThai}</th>
                    <th scope="col">{t.qlHetHan}</th>
                    <th scope="col" className="so">{t.qlSoThietBi}</th>
                    <th scope="col">{t.qlCapNhat}</th>
                  </tr>
                </thead>
                <tbody>
                  {ds.duLieu.ds.map((x) => (
                    <tr key={x.id} aria-selected={chon === x.id}>
                      <td>
                        <button type="button" className="nut-chu ma" onClick={() => datChon(x.id)}>
                          {x.product_id}
                        </button>
                        {x.test_purchase === 1 && <span className="o-so-phu"> · {t.qlMuaThu}</span>}
                      </td>
                      <td>{tenNguon(x.source)}</td>
                      <td>{tenTt(x.state)}</td>
                      <td title={dinhDangLuc(x.expires_at, nn)}>{x.expires_at ? truocDay(x.expires_at, nn) : t.qlVinhVien}</td>
                      <td className="so">{dinhDangSo(x.so_thiet_bi ?? 0, nn)}</td>
                      <td title={dinhDangLuc(x.updated_at, nn)}>{truocDay(x.updated_at, nn)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {chon && ct.loi && <ThongBaoLoi loi={ct.loi} napLai={ct.napLai} />}
      {chon && ct.duLieu && (
        <section className="the" aria-label={t.qlChiTiet}>
          <div className="tieu-de-the">
            <h2 className="ma">{ct.duLieu.quyenLoi.id}</h2>
            <div className="hang-nut trai day-phai">
              {xuLy && ct.duLieu.quyenLoi.state !== 'revoked' && (
                <button type="button" className="nut nut-nguy" onClick={() => datHop({ loai: 'thu-hoi' })}>
                  {t.qlDeXuatThuHoi}
                </button>
              )}
              <button type="button" className="nut nut-phu" onClick={() => datChon(null)}>
                {t.qlDong}
              </button>
            </div>
          </div>
          <dl className="dl">
            {(
              [
                [t.qlSanPham, `${ct.duLieu.quyenLoi.product_id} (${ct.duLieu.quyenLoi.source})`],
                [t.qlCotTrangThai, `${tenTt(ct.duLieu.quyenLoi.state)}${ct.duLieu.quyenLoi.reason ? ` - ${ct.duLieu.quyenLoi.reason}` : ''}`],
                [t.qlHetHan, ct.duLieu.quyenLoi.expires_at ? dinhDangLuc(ct.duLieu.quyenLoi.expires_at, nn) : t.qlVinhVien],
                [t.qlMaDon, ct.duLieu.quyenLoi.order_id ?? '-'],
                [t.qlBamToken, ct.duLieu.quyenLoi.token_hash ?? '-'],
                [t.qlBamTaiKhoan, ct.duLieu.quyenLoi.account_hash ?? '-'],
                [t.qlTuGiaHan, ct.duLieu.quyenLoi.auto_renew === null ? '-' : ct.duLieu.quyenLoi.auto_renew ? t.qlCo : t.qlKhong],
                [t.qlDaXacNhan, ct.duLieu.quyenLoi.acknowledged ? t.qlCo : t.qlKhong],
                [t.qlMuaThu, ct.duLieu.quyenLoi.test_purchase ? t.qlCo : t.qlKhong],
                [t.qlTao, dinhDangLuc(ct.duLieu.quyenLoi.created_at, nn)],
              ] as const
            ).map(([k, v]) => (
              <div key={k} className="dl-dong">
                <dt>{k}</dt>
                <dd className="ma">{v}</dd>
              </div>
            ))}
          </dl>

          <h3>{t.qlThietBiGan(ct.duLieu.thietBi.filter((x) => x.hoat_dong).length, ct.duLieu.toiDa)}</h3>
          {ct.duLieu.thietBi.length === 0 ? (
            <p className="trong">{t.qlKhongThietBi}</p>
          ) : (
            <div className="cuon-ngang">
              <table className="bang">
                <thead>
                  <tr>
                    <th scope="col">{t.thietBi}</th>
                    <th scope="col">{t.qlGanLuc}</th>
                    <th scope="col">{t.qlThayLuc}</th>
                    {xuLy && <th scope="col">{t.qlThaoTac}</th>}
                  </tr>
                </thead>
                <tbody>
                  {ct.duLieu.thietBi.map((x) => (
                    <tr key={x.device_id}>
                      <td>
                        <a className="ma" href={`#/thiet-bi/${x.device_id}`}>
                          {x.model ?? x.device_id}
                        </a>
                        {x.app_version && <span className="o-so-phu"> · {x.app_version}</span>}
                        {!x.hoat_dong && <span className="o-so-phu"> · {t.qlKhongHoatDong}</span>}
                      </td>
                      <td title={dinhDangLuc(x.linked_at, nn)}>{truocDay(x.linked_at, nn)}</td>
                      <td title={dinhDangLuc(x.seen_at, nn)}>{truocDay(x.seen_at, nn)}</td>
                      {xuLy && (
                        <td>
                          <button type="button" className="nut nut-phu nut-nho" onClick={() => datHop({ loai: 'go', thietBi: x.device_id })}>
                            {t.qlGoThietBi}
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <h3>{t.qlLichSu}</h3>
          {ct.duLieu.suKien.length === 0 ? (
            <p className="trong">{t.qlKhongSuKien}</p>
          ) : (
            <ul className="ds-gon">
              {ct.duLieu.suKien.map((x) => (
                <li key={x.id}>
                  <span title={dinhDangLuc(x.ts, nn)}>{truocDay(x.ts, nn)}</span> · <strong>{t.qlLoaiSuKien[x.kind] ?? x.kind}</strong>
                  {x.detail !== null && <span className="ma o-so-phu"> {JSON.stringify(x.detail)}</span>}
                </li>
              ))}
            </ul>
          )}
          {ct.duLieu.yeuCau.length > 0 && (
            <>
              <h3>{t.qlYeuCauDaCo}</h3>
              <ul className="ds-gon">
                {ct.duLieu.yeuCau.map((y) => (
                  <li key={y.id}>
                    {truocDay(y.created_at, nn)} · {t.qlTtYeuCau[y.status] ?? y.status} · {y.created_by}: {y.reason}
                    {y.decided_by && y.status !== 'cancelled' && ` · ${y.decided_by}${y.decision_note ? ` (${y.decision_note})` : ''}`}
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>
      )}

      <HopThoaiLyDo
        mo={hop !== null}
        tieuDe={hop?.loai === 'go' ? t.qlGoThietBi : hop?.loai === 'thu-hoi' ? t.qlDeXuatThuHoi : hop?.loai === 'quyet' && hop.dongY ? t.qlDuyet : t.qlBac}
        canhBao={hop?.loai === 'go' ? t.qlGoCanhBao : hop?.loai === 'thu-hoi' ? t.qlThuHoiCanhBao : hop?.loai === 'quyet' && hop.dongY ? t.qlDuyetCanhBao : null}
        nhanXacNhan={hop?.loai === 'go' ? t.qlGoThietBi : hop?.loai === 'thu-hoi' ? t.qlDeXuatThuHoi : hop?.loai === 'quyet' && hop.dongY ? t.qlDuyet : t.qlBac}
        dong={() => datHop(null)}
        xong={async (lyDo) => {
          if (!hop) return;
          if (hop.loai === 'go') {
            if (!chon || !(await ghi('/quyen-loi/go-thiet-bi', { id: chon, thietBi: hop.thietBi, lyDo }))) return;
            bao(t.qlDaGo);
          } else if (hop.loai === 'thu-hoi') {
            if (!chon || !(await ghi('/quyen-loi/thu-hoi', { id: chon, lyDo }))) return;
            bao(t.qlDaDeXuat);
          } else {
            if (!(await ghi('/quyen-loi/yeu-cau/quyet', { id: hop.id, dongY: hop.dongY, ghiChu: lyDo }))) return;
            bao(hop.dongY ? t.qlDaThuHoi : t.qlDaBac);
          }
          datHop(null);
          napHet();
        }}
      />
    </div>
  );
}
