// Khung SOC (S6): trạng thái đăng nhập (Access -> vai trò -> passkey), điều hướng hash, giao diện sáng / tối, vi / en,
// khoá khi nhàn rỗi 15 phút (server cũng tự hết hạn - đây chỉ để màn hình không còn hiện dữ liệu).
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { goi, LoiSoc, type Toi } from './api';
import { chuoi, ngonNgu, type NgonNgu } from './i18n';
import { Ctx, type NguCanh } from './ngu-canh';
import { VungDuLieu } from './khien/Watermark';
import { ChiTiet } from './trang/ChiTiet';
import { DangNhap } from './trang/DangNhap';
import { DsThietBi } from './trang/DsThietBi';
import { QuanTriVien } from './trang/QuanTriVien';
import { TongQuan } from './trang/TongQuan';

const NHAN_ROI_MS = 15 * 60_000;


function docKho(k: string): string | null {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
}
function ghiKho(k: string, v: string): void {
  try {
    localStorage.setItem(k, v);
  } catch {
    // Trình duyệt chặn lưu trữ - chỉ mất tuỳ chọn hiển thị.
  }
}

function useDuongDan(): string {
  const [hash, datHash] = useState(() => location.hash || '#/');
  useEffect(() => {
    const nghe = () => datHash(location.hash || '#/');
    addEventListener('hashchange', nghe);
    return () => removeEventListener('hashchange', nghe);
  }, []);
  return hash.slice(1).split('?')[0] ?? '/';
}

type TrangThai = { loai: 'tai' } | { loai: 'loi'; ma: 'vai-tro' | 'access' | 'chung' } | { loai: 'can-passkey'; toi: Toi; khoa: boolean } | { loai: 'vao'; toi: Toi };

export function App() {
  const [nn, datNn] = useState<NgonNgu>(() => ngonNgu(docKho('soc-nn') ?? document.documentElement.lang));
  const [chuDe, datChuDe] = useState<'light' | 'dark' | null>(() => (docKho('soc-chu-de') as 'light' | 'dark' | null) ?? null);
  const [tt, datTt] = useState<TrangThai>({ loai: 'tai' });
  const t = chuoi(nn);
  const duong = useDuongDan();

  useEffect(() => {
    document.documentElement.lang = nn;
    document.title = t.tieuDe;
  }, [nn, t.tieuDe]);
  useEffect(() => {
    if (chuDe) document.documentElement.dataset.theme = chuDe;
    else delete document.documentElement.dataset.theme;
  }, [chuDe]);

  const napToi = useCallback(async (khoa = false) => {
    try {
      const toi = await goi<Toi>('/toi');
      datTt(toi.phien && !khoa ? { loai: 'vao', toi } : { loai: 'can-passkey', toi, khoa });
    } catch (e) {
      const s = e instanceof LoiSoc ? e.status : 0;
      datTt({ loai: 'loi', ma: s === 403 ? 'vai-tro' : s === 401 ? 'access' : 'chung' });
    }
  }, []);
  useEffect(() => void napToi(), [napToi]);

  const hetPhien = useCallback(() => void napToi(true), [napToi]);

  // Nhàn rỗi: không chuột / phím / chạm trong 15 phút -> đăng xuất phía server + khoá màn hình.
  const dangVao = tt.loai === 'vao';
  useEffect(() => {
    if (!dangVao) return;
    let hen = 0;
    const datLai = () => {
      clearTimeout(hen);
      hen = window.setTimeout(() => {
        void goi('/phien/ket-thuc', { body: {} }).finally(() => napToi(true));
      }, NHAN_ROI_MS);
    };
    const suKien = ['pointerdown', 'keydown', 'wheel', 'touchstart'] as const;
    suKien.forEach((s) => addEventListener(s, datLai, { passive: true }));
    datLai();
    return () => {
      clearTimeout(hen);
      suKien.forEach((s) => removeEventListener(s, datLai));
    };
  }, [dangVao, napToi]);

  const laToi = chuDe ? chuDe === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  const doiChuDe = () => {
    const moi = laToi ? 'light' : 'dark';
    datChuDe(moi);
    ghiKho('soc-chu-de', moi);
  };
  const doiNn = () => {
    const moi = nn === 'vi' ? 'en' : 'vi';
    datNn(moi);
    ghiKho('soc-nn', moi);
  };

  const ctx = useMemo<NguCanh | null>(
    () => (tt.loai === 'vao' ? { t, nn, toi: tt.toi, coQuyen: (q) => tt.toi.quyen.includes(q), hetPhien } : null),
    [t, nn, tt, hetPhien],
  );

  const thanhCongCu = (
    <div className="cong-cu">
      <button type="button" className="nut nut-phu" onClick={doiNn} lang={nn === 'vi' ? 'en' : 'vi'}>
        {t.doiNgonNgu}
      </button>
      <button type="button" className="nut nut-phu" onClick={doiChuDe}>
        {laToi ? t.giaoDienSang : t.giaoDienToi}
      </button>
    </div>
  );

  if (tt.loai === 'tai') return <p className="giua">{t.dangTai}</p>;
  if (tt.loai === 'loi') {
    return (
      <main className="giua the-don" role="alert">
        <h1>{t.tieuDe}</h1>
        <p>{tt.ma === 'vai-tro' ? t.khongCoVaiTro : tt.ma === 'access' ? t.accessLoi : t.loiChung}</p>
        <button type="button" className="nut" onClick={() => location.reload()}>
          {t.thuLai}
        </button>
        {thanhCongCu}
      </main>
    );
  }
  if (tt.loai === 'can-passkey') {
    return <DangNhap t={t} toi={tt.toi} khoa={tt.khoa} xong={() => void napToi()} congCu={thanhCongCu} />;
  }

  const dangXuat = () => void goi('/phien/ket-thuc', { body: {} }).finally(() => napToi(true));
  const muc: [string, string, boolean][] = [
    ['/', t.tongQuan, true],
    ['/thiet-bi', t.thietBi, true],
    ['/quan-tri-vien', t.quanTriVien, tt.toi.quyen.includes('quan-tri-vien')],
  ];
  const chiTietId = /^\/thiet-bi\/([0-9A-Za-z-]{8,40})$/.exec(duong)?.[1];
  let noiDung: ReactNode;
  if (chiTietId) noiDung = <ChiTiet id={chiTietId} />;
  else if (duong === '/thiet-bi') noiDung = <DsThietBi />;
  else if (duong === '/quan-tri-vien' && tt.toi.quyen.includes('quan-tri-vien')) noiDung = <QuanTriVien />;
  else noiDung = <TongQuan />;

  return (
    <Ctx.Provider value={ctx}>
      <div className="khung">
        <header className="dau-trang">
          <a className="thuong-hieu" href="#/">
            <img src="/favicon.svg" alt="" width="28" height="28" />
            <span>{t.tieuDe}</span>
          </a>
          <nav aria-label={t.dieuHuong} className="dieu-huong">
            {muc
              .filter(([, , hien]) => hien)
              .map(([d, nhan]) => {
                const dang = d === '/' ? duong === '/' || duong === '' : duong.startsWith(d);
                return (
                  <a key={d} href={`#${d}`} aria-current={dang ? 'page' : undefined}>
                    {nhan}
                  </a>
                );
              })}
          </nav>
          <div className="nguoi-dung">
            <span className="email" title={tt.toi.email}>
              {tt.toi.email}
            </span>
            <span className="the-vai-tro">{t.vaiTro[tt.toi.vaiTro] ?? tt.toi.vaiTro}</span>
            {thanhCongCu}
            <button type="button" className="nut nut-phu" onClick={dangXuat}>
              {t.dangXuat}
            </button>
          </div>
        </header>
        <VungDuLieu email={tt.toi.email}>
          <main className="noi-dung">{noiDung}</main>
        </VungDuLieu>
      </div>
    </Ctx.Provider>
  );
}
