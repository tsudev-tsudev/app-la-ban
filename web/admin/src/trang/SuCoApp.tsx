// Sự cố app (S10b, QUYET_DINH Q49): báo cáo lỗi tự xây (không Sentry / Crashlytics). Nhóm theo dấu vết + tỷ lệ thiết bị
// không gặp sự cố (viewer); mở nhóm xem mẫu kèm ngăn xếp đã che mã (analyst) - giải mã bằng tools/build/giai-ngan-xep.sh.
import { useState } from 'react';
import { ThongBaoLoi, useTai } from '../dung-chung';
import { dinhDangLuc, dinhDangSo, truocDay } from '../i18n';
import { useSoc } from '../ngu-canh';

type Nhom = {
  fingerprint: string;
  kind: string;
  type: string;
  so_lan: number;
  so_thiet_bi: number;
  dau: number;
  cuoi: number;
  phien_ban: string | null;
};
type DsSuCo = {
  ngay: number;
  thietBiHoatDong: number;
  thietBiCoLoi: number;
  tyLeKhongLoi: number | null;
  nhom: Nhom[];
};
type Mau = {
  id: string;
  device_id: string | null;
  kind: string;
  type: string;
  message: string;
  stack: string;
  app_version: string;
  occurred_at: number;
};

const KY = [1, 7, 30, 90] as const;

export function SuCoApp() {
  const { t, nn, coQuyen } = useSoc();
  const [ngay, datNgay] = useState<(typeof KY)[number]>(7);
  const [mo, datMo] = useState<string | null>(null);
  const ds = useTai<DsSuCo>(`/su-co-app?ngay=${ngay}`);
  const chiTiet = coQuyen('su-co:chi-tiet');
  const mau = useTai<{ mau: Mau[] }>(mo && chiTiet ? `/su-co-app/${mo}` : null);
  const d = ds.duLieu;

  return (
    <div className="trang-chinh">
      <div className="hang-o-dem">
        {KY.map((k) => (
          <button
            key={k}
            type="button"
            className="o-dem"
            aria-pressed={ngay === k}
            onClick={() => datNgay(k)}
          >
            <span className="o-so-nhan">{t.scKy(k)}</span>
          </button>
        ))}
      </div>
      {ds.loi && <ThongBaoLoi loi={ds.loi} napLai={ds.napLai} />}
      {d && (
        <div className="hang-o-dem">
          <div className="o-dem">
            <span className="o-so-nhan">{t.scTyLe}</span>
            <span className="o-so-gia-tri">
              {d.tyLeKhongLoi === null ? '-' : `${d.tyLeKhongLoi.toLocaleString(nn)} %`}
            </span>
          </div>
          <div className="o-dem">
            <span className="o-so-nhan">{t.scHoatDong}</span>
            <span className="o-so-gia-tri">{dinhDangSo(d.thietBiHoatDong, nn)}</span>
          </div>
          <div className="o-dem">
            <span className="o-so-nhan">{t.scCoLoi}</span>
            <span className="o-so-gia-tri">{dinhDangSo(d.thietBiCoLoi, nn)}</span>
          </div>
        </div>
      )}
      <p className="ghi-chu-vai-tro">{t.scGhiChu}</p>
      <div aria-busy={ds.tai}>
        {d && d.nhom.length === 0 && <p className="trong">{t.scTrong}</p>}
        {d?.nhom.map((n) => (
          <article key={n.fingerprint} className="the">
            <header className="tieu-de-the">
              <h2>
                <span className="ma">{n.type}</span> <span className="o-so-phu">{n.kind}</span>
              </h2>
              <span className="ma">{n.fingerprint}</span>
            </header>
            <p className="o-so-phu" title={dinhDangLuc(n.cuoi, nn)}>
              {t.scDong(n.so_lan, n.so_thiet_bi)} · {t.scCuoi} {truocDay(n.cuoi, nn)} · {n.phien_ban ?? '-'}
            </p>
            {chiTiet && (
              <button
                type="button"
                className="nut nut-phu"
                aria-expanded={mo === n.fingerprint}
                onClick={() => datMo(mo === n.fingerprint ? null : n.fingerprint)}
              >
                {mo === n.fingerprint ? t.scAn : t.scXemMau}
              </button>
            )}
            {mo === n.fingerprint && mau.loi && <ThongBaoLoi loi={mau.loi} napLai={mau.napLai} />}
            {mo === n.fingerprint &&
              mau.duLieu?.mau.map((m) => (
                <details key={m.id} className="sc-mau">
                  <summary>
                    {dinhDangLuc(m.occurred_at, nn)} · {m.app_version} ·{' '}
                    {m.device_id ? (
                      <a className="ma" href={`#/thiet-bi/${m.device_id}`}>
                        {m.device_id.slice(-8)}
                      </a>
                    ) : (
                      '-'
                    )}
                  </summary>
                  <p>{m.message}</p>
                  <pre className="sc-ngan-xep">{m.stack}</pre>
                </details>
              ))}
          </article>
        ))}
      </div>
    </div>
  );
}
