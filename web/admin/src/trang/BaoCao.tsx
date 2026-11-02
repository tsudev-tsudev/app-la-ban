// Báo cáo SOC (S7c2, Spec §8.2-8): tổng hợp theo khoảng (không PII) -> In / lưu PDF bằng trình duyệt (CSS in, thuỷ vân
// in kèm, không thư viện PDF) + xuất CSV có kiểm soát (passkey + audit ở server, che PII theo vai trò ở server).
import { useState } from 'react';
import { LoiSoc, maLoiPasskey, xuatCsv, type TongHop } from '../api';
import { useThongBao } from '../giao-dien/ThongBao';
import { MucDo, NhanTrangThai, ThanhXepHang, ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo } from '../i18n';
import { useSoc } from '../ngu-canh';
import { khoangGanNhat, khoangTuO, tiLe } from './s7c2';

const LOAI = ['su-kien', 'thuc-thi', 'khieu-nai', 'thiet-bi'] as const;

function thoiLuong(ms: number | null, nn: string): string {
  if (ms === null) return '-';
  const gio = ms / 3_600_000;
  return gio < 1 ? `${Math.max(1, Math.round(ms / 60_000))} ${nn === 'en' ? 'min' : 'phút'}` : `${gio.toFixed(1)} ${nn === 'en' ? 'h' : 'giờ'}`;
}

export function BaoCao() {
  const { t, nn, toi, coQuyen, hetPhien } = useSoc();
  const bao = useThongBao();
  const [o, datO] = useState(() => khoangGanNhat(7, Date.now()));
  const [khoang, datKhoang] = useState(() => khoangTuO(o.tu, o.den));
  const [loai, datLoai] = useState<(typeof LOAI)[number]>('su-kien');
  const [dangXuat, datDangXuat] = useState(false);
  const { duLieu: d, loi, tai, napLai } = useTai<TongHop>(khoang ? `/bao-cao/tong-hop?tu=${khoang.tu}&den=${khoang.den}` : null);
  const ngay = (ms: number) => new Intl.DateTimeFormat(nn === 'en' ? 'en-GB' : 'vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric' }).format(ms);

  const xem = (tu: string, den: string) => {
    datO({ tu, den });
    const k = khoangTuO(tu, den);
    if (!k) bao(t.bcKhoangSai, 'loi');
    else datKhoang(k);
  };

  const xuat = async () => {
    if (!khoang) return;
    datDangXuat(true);
    try {
      const kq = await xuatCsv({ loai, tu: khoang.tu, den: khoang.den }, () => bao(t.canStepUp, 'tin'));
      const url = URL.createObjectURL(kq.blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = kq.ten;
      document.body.append(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 10_000);
      bao(kq.biCat ? t.bcBiCat(kq.soDong) : t.bcDaXuat(kq.soDong), kq.biCat ? 'loi' : 'tin');
    } catch (e) {
      if (e instanceof LoiSoc && e.status === 401 && e.ma !== 'can-step-up') hetPhien();
      const ma = e instanceof LoiSoc ? e.ma : null;
      bao(ma && t.loiMa[ma] ? t.loiMa[ma] : maLoiPasskey(e) === 'huy' ? t.passkeyHuy : t.loiChung, 'loi');
    } finally {
      datDangXuat(false);
    }
  };

  const lonNgay = Math.max(1, ...(d?.suKien.theoNgay.map((x) => x.n) ?? [1]));
  const nhanNguon = (s: string) => (s === 'auto' ? t.nguonTuDong : t.nguonThuCong);

  return (
    <div className="trang-chinh bao-cao">
      <p className="mo-ta-trang khong-in">{t.bcMoTa}</p>
      <form
        className="bo-loc khong-in"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          xem(String(f.get('tu') ?? ''), String(f.get('den') ?? ''));
        }}
      >
        <label>
          <span>{t.bcTu}</span>
          <input type="date" name="tu" value={o.tu} onChange={(e) => datO({ ...o, tu: e.target.value })} required />
        </label>
        <label>
          <span>{t.bcDen}</span>
          <input type="date" name="den" value={o.den} onChange={(e) => datO({ ...o, den: e.target.value })} required />
        </label>
        <button type="submit" className="nut nut-chinh">
          {t.bcXem}
        </button>
        {(['7', '30', '90'] as const).map((n) => (
          <button
            key={n}
            type="button"
            className="nut nut-phu"
            onClick={() => {
              const k = khoangGanNhat(Number(n), Date.now());
              xem(k.tu, k.den);
            }}
          >
            {t.bcNhanh[n]}
          </button>
        ))}
        <button type="button" className="nut nut-phu" disabled={!d} onClick={() => window.print()}>
          {t.bcIn}
        </button>
      </form>

      {loi && <ThongBaoLoi loi={loi} napLai={napLai} />}

      {d && (
        <article className="bao-cao-noi-dung" aria-busy={tai}>
          <header className="bao-cao-dau">
            <h2>{t.bcTieuDeIn}</h2>
            <p>{t.bcKhoang(ngay(d.khoang.tu), ngay(d.khoang.den - 1))}</p>
            <p className="o-so-phu">{t.bcTaoBoi(toi.email, dinhDangLuc(d.taoLuc, nn), d.moiTruong)}</p>
          </header>

          <section className="hang-o-so" aria-label={t.bcThietBi}>
            <div className="o-so">
              <span className="o-so-nhan">{t.bcThietBi} · {t.bcTong}</span>
              <span className="o-so-gia-tri">{dinhDangSo(d.thietBi.tong, nn)}</span>
            </div>
            <div className="o-so">
              <span className="o-so-nhan">{t.bcMoi}</span>
              <span className="o-so-gia-tri">{dinhDangSo(d.thietBi.moi, nn)}</span>
            </div>
            <div className="o-so">
              <span className="o-so-nhan">{t.bcHoatDong}</span>
              <span className="o-so-gia-tri">{dinhDangSo(d.thietBi.hoatDong, nn)}</span>
            </div>
            <div className="o-so">
              <span className="o-so-nhan">{t.bcSuKien}</span>
              <span className="o-so-gia-tri">{dinhDangSo(d.suKien.mucDo.reduce((a, x) => a + x.n, 0), nn)}</span>
            </div>
          </section>

          <section className="the">
            <h3>{t.bcSuKien} · {t.bcTheoNgay}</h3>
            <ol className="cot-ngay" aria-label={t.bcTheoNgay}>
              {d.suKien.theoNgay.map((x) => {
                const nhan = x.k.slice(8, 10) + '/' + x.k.slice(5, 7);
                return (
                  <li key={x.k} title={`${nhan}: ${dinhDangSo(x.n, nn)}`}>
                    <span className="cot-ngay-thanh" style={{ blockSize: `${tiLe(x.n, lonNgay)}%` }} />
                    {d.suKien.theoNgay.length <= 31 && <span className="cot-ngay-so">{x.n}</span>}
                    <span className="cot-ngay-nhan">{nhan}</span>
                  </li>
                );
              })}
            </ol>
          </section>

          <div className="luoi-bao-cao">
            <section className="the">
              <h3>{t.bcTheoMucDo}</h3>
              {d.suKien.mucDo.length === 0 ? (
                <p className="trong">{t.bcKhongDuLieu}</p>
              ) : (
                <table className="bang">
                  <tbody>
                    {d.suKien.mucDo.map((x) => (
                      <tr key={String(x.k)}>
                        <td>
                          <MucDo muc={String(x.k)} />
                        </td>
                        <td className="so">{dinhDangSo(x.n, nn)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </section>
            <section className="the">
              <h3>{t.bcTheoLoai}</h3>
              <ThanhXepHang ds={d.suKien.loai} />
            </section>
            <section className="the">
              <h3>{t.bcThietBi}</h3>
              <table className="bang">
                <tbody>
                  {d.thietBi.trangThai.map((x) => (
                    <tr key={String(x.k)}>
                      <td>
                        <NhanTrangThai tt={String(x.k)} />
                      </td>
                      <td className="so">{dinhDangSo(x.n, nn)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
            <section className="the">
              <h3>{t.bcThucThi}</h3>
              {d.thucThi.theoLoai.length === 0 ? (
                <p className="trong">{t.bcKhongDuLieu}</p>
              ) : (
                <table className="bang">
                  <tbody>
                    {d.thucThi.theoLoai.map((x) => (
                      <tr key={`${x.hanhDong}-${x.nguon}`}>
                        <td>
                          {t.tenHanhDongChan[x.hanhDong] ?? x.hanhDong} · {nhanNguon(x.nguon)}
                        </td>
                        <td className="so">{dinhDangSo(x.n, nn)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
              <p className="o-so-phu">
                {t.bcGoTrongKy}: {dinhDangSo(d.thucThi.goTrongKy, nn)} · {t.bcHieuLuc}: {dinhDangSo(d.thucThi.hieuLuc, nn)}
              </p>
            </section>
            <section className="the">
              <h3>{t.bcKhieuNai}</h3>
              {d.khieuNai.length === 0 ? (
                <p className="trong">{t.bcKhongDuLieu}</p>
              ) : (
                <table className="bang">
                  <thead>
                    <tr>
                      <th scope="col">{t.bcKhieuNai}</th>
                      <th scope="col" className="so">{t.bcSoLan}</th>
                      <th scope="col" className="so">{t.bcTbXuLy}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {d.khieuNai.map((x) => (
                      <tr key={x.k}>
                        <td>{t.ttKhieuNai[x.k] ?? x.k}</td>
                        <td className="so">{dinhDangSo(x.n, nn)}</td>
                        <td className="so">{thoiLuong(x.tbXuLyMs, nn)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </section>
            <section className="the">
              <h3>{t.bcCanhBao}</h3>
              <ThanhXepHang ds={d.canhBao.mucDo} nhan={(k) => t.mucDo[k] ?? k} />
              <h4>{t.ketLuanNhan}</h4>
              <ThanhXepHang ds={d.canhBao.ketLuan} nhan={(k) => t.ketLuan[k] ?? t.ttCb[k] ?? k} />
            </section>
            <section className="the">
              <h3>{t.bcRule}</h3>
              <ThanhXepHang ds={d.rule} />
            </section>
            <section className="the">
              <h3>{t.bcAudit}</h3>
              <ThanhXepHang ds={d.audit} />
              <p className="o-so-phu">
                {t.bcCauHinh}: {d.cauHinh.length ? d.cauHinh.map((x) => `${String(x.k)} ${x.n}`).join(' · ') : '0'}
              </p>
            </section>
          </div>
        </article>
      )}

      <section className="the khong-in">
        <h2>{t.bcXuatTieuDe}</h2>
        <p className="o-so-phu">{t.bcXuatMoTa}</p>
        {coQuyen('bao-cao:xuat') ? (
          <div className="bo-loc">
            <label>
              <span>{t.bcXuatTieuDe}</span>
              <select value={loai} onChange={(e) => datLoai(e.target.value as (typeof LOAI)[number])}>
                {LOAI.map((l) => (
                  <option key={l} value={l}>
                    {t.bcLoai[l]}
                  </option>
                ))}
              </select>
            </label>
            <button type="button" className="nut nut-chinh" disabled={!khoang || dangXuat} onClick={() => void xuat()}>
              {t.bcXuat}
            </button>
          </div>
        ) : (
          <p className="ghi-chu-vai-tro">{t.bcChiXem}</p>
        )}
      </section>
    </div>
  );
}
