// Khung SOC (S6, làm lại bố cục ở S7a): trạng thái đăng nhập (Access -> vai trò -> passkey), thanh bên theo nhóm + thanh
// trên (môi trường, đếm ngược phiên, bảng lệnh Ctrl K), phím tắt kiểu "g c", tuỳ chọn hiển thị (giao diện, ngôn ngữ, mật
// độ, thuỷ vân), khoá khi nhàn rỗi 15 phút (server cũng tự hết hạn - đây chỉ để màn hình không còn hiện dữ liệu). S7b: nhóm
// Phản ứng (can thiệp, rule, cấu hình điểm), Cài đặt hệ thống (Super Admin) và thuỷ vân theo cài đặt toàn hệ thống.
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { goi, LoiSoc, type DsCanhBao, type DsKhieuNai, type DsThucThi, type Toi } from './api';
import { BangLenh } from './giao-dien/BangLenh';
import { BieuTuong } from './giao-dien/BieuTuong';
import { HopThoai } from './giao-dien/HopThoai';
import type { Lenh } from './giao-dien/lenh';
import { NguonThongBao } from './giao-dien/ThongBao';
import { ghiKho, luuTuyChon, napTuyChon, docKho, tuyChonHieuLuc, type TuyChon } from './giao-dien/tuy-chon';
import { chuoi, ngonNgu, type NgonNgu } from './i18n';
import { Ctx, type NguCanh } from './ngu-canh';
import { VungDuLieu } from './khien/Watermark';
import { BaoCao } from './trang/BaoCao';
import { CaiDatHeThong } from './trang/CaiDatHeThong';
import { CanThiep } from './trang/CanThiep';
import { CanhBao } from './trang/CanhBao';
import { CauHinhNguyCo } from './trang/CauHinhNguyCo';
import { CauHinhTuXa } from './trang/CauHinhTuXa';
import { ChiTiet } from './trang/ChiTiet';
import { DangNhap } from './trang/DangNhap';
import { DsThietBi } from './trang/DsThietBi';
import { KhieuNai } from './trang/KhieuNai';
import { SuCoApp } from './trang/SuCoApp';
import { Luat } from './trang/Luat';
import { NhatKyAudit } from './trang/NhatKyAudit';
import { QuanTriVien } from './trang/QuanTriVien';
import { TaiKhoan } from './trang/TaiKhoan';
import { TongQuan } from './trang/TongQuan';

const NHAN_ROI_MS = 15 * 60_000;
const GO_TAT: Record<string, string> = {
  o: '#/',
  c: '#/canh-bao',
  t: '#/thiet-bi',
  x: '#/can-thiep',
  l: '#/luat',
  n: '#/cau-hinh-nguy-co',
  k: '#/tai-khoan',
  q: '#/quan-tri-vien',
  s: '#/cai-dat',
  i: '#/khieu-nai',
  a: '#/audit',
  b: '#/bao-cao',
  r: '#/cau-hinh-tu-xa',
  e: '#/su-co-app',
};

function useHash(): string {
  const [hash, datHash] = useState(() => location.hash || '#/');
  useEffect(() => {
    const nghe = () => datHash(location.hash || '#/');
    addEventListener('hashchange', nghe);
    return () => removeEventListener('hashchange', nghe);
  }, []);
  return hash;
}

function useBayGio(chuKyMs: number): number {
  const [x, datX] = useState(() => Date.now());
  useEffect(() => {
    const hen = setInterval(() => datX(Date.now()), chuKyMs);
    return () => clearInterval(hen);
  }, [chuKyMs]);
  return x;
}

function dongHo(ms: number): string {
  const p = Math.max(0, Math.floor(ms / 60_000));
  return `${Math.floor(p / 60)}:${String(p % 60).padStart(2, '0')}`;
}

/** Phím đang gõ vào ô nhập -> không coi là phím tắt. */
function dangGo(e: KeyboardEvent): boolean {
  const el = e.target as HTMLElement | null;
  return !!el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName));
}

type TrangThai = { loai: 'tai' } | { loai: 'loi'; ma: 'vai-tro' | 'access' | 'chung' | 'khien' } | { loai: 'can-passkey'; toi: Toi; khoa: boolean } | { loai: 'vao'; toi: Toi };

export function App() {
  const [nn, datNn] = useState<NgonNgu>(() => ngonNgu(docKho('soc-nn') ?? document.documentElement.lang));
  const [tc, datTc] = useState<TuyChon>(napTuyChon);
  const [tt, datTt] = useState<TrangThai>({ loai: 'tai' });
  const [moLenh, datMoLenh] = useState(false);
  const [moPhim, datMoPhim] = useState(false);
  const [moMenu, datMoMenu] = useState(false);
  const t = chuoi(nn);
  const hash = useHash();
  const duong = hash.slice(1).split('?')[0] ?? '/';
  const bayGio = useBayGio(30_000);

  useEffect(() => {
    document.documentElement.lang = nn;
    document.title = t.tieuDe;
  }, [nn, t.tieuDe]);
  useEffect(() => {
    const h = document.documentElement;
    if (tc.chuDe) h.dataset.theme = tc.chuDe;
    else delete h.dataset.theme;
    h.dataset.matDo = tc.matDo;
  }, [tc.chuDe, tc.matDo]);

  const doiTc = useCallback((p: Partial<TuyChon>) => {
    datTc((cu) => {
      const moi = { ...cu, ...p };
      luuTuyChon(moi);
      return moi;
    });
  }, []);

  const napToi = useCallback(async (khoa = false) => {
    try {
      const toi = await goi<Toi>('/toi');
      datTt(toi.phien && !khoa ? { loai: 'vao', toi } : { loai: 'can-passkey', toi, khoa });
    } catch (e) {
      const s = e instanceof LoiSoc ? e.status : 0;
      // S11 (Q58): khiên đang nghi / Worker từ chối 10 phút sau tín hiệu DevTools của IP này.
      const khien = e instanceof LoiSoc && (e.ma === 'khien-nghi' || e.ma === 'khien-devtools');
      datTt({ loai: 'loi', ma: khien ? 'khien' : s === 403 ? 'vai-tro' : s === 401 ? 'access' : 'chung' });
    }
  }, []);
  useEffect(() => void napToi(), [napToi]);

  const hetPhien = useCallback(() => void napToi(true), [napToi]);
  const dangXuat = useCallback(() => void goi('/phien/ket-thuc', { body: {} }).finally(() => napToi(true)), [napToi]);

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

  const laToi = tc.chuDe ? tc.chuDe === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  const doiChuDe = useCallback(() => doiTc({ chuDe: laToi ? 'light' : 'dark' }), [doiTc, laToi]);
  const doiNn = useCallback(() => {
    const moi = nn === 'vi' ? 'en' : 'vi';
    datNn(moi);
    ghiKho('soc-nn', moi);
  }, [nn]);

  // Phím tắt: Ctrl/Cmd K, "?", "/", chuỗi "g <chữ>" trong 1 giây.
  useEffect(() => {
    if (!dangVao) return;
    let choG = 0;
    const nghe = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        datMoLenh(true);
        return;
      }
      if (dangGo(e) || e.ctrlKey || e.metaKey || e.altKey || document.querySelector('dialog[open]')) return;
      if (e.key === '?') {
        datMoPhim(true);
      } else if (e.key === '/') {
        const o = document.querySelector<HTMLElement>('[data-o-tim]');
        if (o) {
          e.preventDefault();
          o.focus();
        }
      } else if (e.key === 'g') {
        choG = Date.now();
      } else if (Date.now() - choG < 1000 && GO_TAT[e.key]) {
        location.hash = GO_TAT[e.key] as string;
        choG = 0;
      }
    };
    addEventListener('keydown', nghe);
    return () => removeEventListener('keydown', nghe);
  }, [dangVao]);

  const ctx = useMemo<NguCanh | null>(
    () => (tt.loai === 'vao' ? { t, nn, toi: tt.toi, coQuyen: (q) => tt.toi.quyen.includes(q), hetPhien, tuyChon: tc, doiTuyChon: doiTc } : null),
    [t, nn, tt, hetPhien, tc, doiTc],
  );

  // Số cảnh báo đang mở cho huy hiệu thanh bên (làm mới nền 60 giây, không gia hạn nhàn rỗi).
  const [soMo, datSoMo] = useState<number | null>(null);
  useEffect(() => {
    if (!dangVao) return;
    const nap = () =>
      goi<DsCanhBao>('/canh-bao?limit=1', { nen: true })
        .then((d) => datSoMo((d.dem.mo ?? 0) + (d.dem.ack ?? 0)))
        .catch(() => undefined);
    void nap();
    const hen = setInterval(nap, 60_000);
    return () => clearInterval(hen);
  }, [dangVao, duong]);

  // Cài đặt toàn hệ thống (thuỷ vân...) do Super Admin đổi -> mọi màn SOC đang mở nhận trong <= 5 phút (request nền).
  useEffect(() => {
    if (!dangVao) return;
    const hen = setInterval(() => {
      goi<Toi>('/toi', { nen: true })
        .then((moi) => datTt((cu) => (cu.loai === 'vao' && moi.caiDat ? { loai: 'vao', toi: { ...cu.toi, caiDat: moi.caiDat } } : cu)))
        .catch(() => undefined);
    }, 5 * 60_000);
    return () => clearInterval(hen);
  }, [dangVao]);

  // Việc chờ duyệt (đề xuất chặn dải + yêu cầu four-eyes) cho huy hiệu "Can thiệp" - chỉ người duyệt được mới cần.
  const coDuyet = tt.loai === 'vao' && tt.toi.quyen.includes('can-thiep:duyet');
  const [soChoDuyet, datSoChoDuyet] = useState<number | null>(null);
  useEffect(() => {
    if (!coDuyet) return;
    const nap = () =>
      goi<DsThucThi>('/thuc-thi?trangThai=cho-duyet&limit=1', { nen: true })
        .then((d) => datSoChoDuyet((d.dem.choDuyet ?? 0) + (d.dem.yeuCau ?? 0)))
        .catch(() => undefined);
    void nap();
    const hen = setInterval(nap, 60_000);
    return () => clearInterval(hen);
  }, [coDuyet, duong]);

  // Khiếu nại đang mở (S7c1) cho huy hiệu "Khiếu nại" - người xem được khiếu nại.
  const coKhieuNai = tt.loai === 'vao' && tt.toi.quyen.includes('khieu-nai:xem');
  const [soKhieuNai, datSoKhieuNai] = useState<number | null>(null);
  const [lanDemKn, datLanDemKn] = useState(0);
  useEffect(() => {
    if (!coKhieuNai) return;
    const nap = () =>
      goi<DsKhieuNai>('/khieu-nai?limit=1', { nen: true })
        .then((d) => datSoKhieuNai(d.dem.open ?? 0))
        .catch(() => undefined);
    void nap();
    const hen = setInterval(nap, 60_000);
    return () => clearInterval(hen);
  }, [coKhieuNai, lanDemKn]);
  const doiDemKn = useCallback(() => datLanDemKn((n) => n + 1), []);

  const di = useCallback((h: string) => {
    location.hash = h;
  }, []);

  const quyen = tt.loai === 'vao' ? tt.toi.quyen : [];
  const toiCd = tt.loai === 'vao' || tt.loai === 'can-passkey' ? tt.toi.caiDat : undefined;
  const hieuLuc = tuyChonHieuLuc(tc, toiCd);
  const nhom: { nhan: string; muc: { d: string; nhan: string; bt: string; dem?: number | null }[] }[] = [
    {
      nhan: t.nhomGiamSat,
      muc: [
        { d: '/', nhan: t.tongQuan, bt: 'tong-quan' },
        { d: '/canh-bao', nhan: t.canhBao, bt: 'canh-bao', dem: soMo },
        { d: '/thiet-bi', nhan: t.thietBi, bt: 'thiet-bi' },
        ...(quyen.includes('khieu-nai:xem') ? [{ d: '/khieu-nai', nhan: t.khieuNai, bt: 'khieu-nai', dem: soKhieuNai }] : []),
        ...(quyen.includes('bao-cao:xem') ? [{ d: '/bao-cao', nhan: t.baoCao, bt: 'bao-cao' }] : []),
        ...(quyen.includes('su-co:xem') ? [{ d: '/su-co-app', nhan: t.suCoApp, bt: 'su-co-app' }] : []),
      ],
    },
    {
      nhan: t.nhomPhanUng,
      muc: quyen.includes('luat:xem')
        ? [
            { d: '/can-thiep', nhan: t.canThiep, bt: 'can-thiep', dem: soChoDuyet },
            { d: '/luat', nhan: t.luat, bt: 'luat' },
            { d: '/cau-hinh-nguy-co', nhan: t.cauHinhNguyCo, bt: 'cau-hinh' },
            ...(quyen.includes('cau-hinh-tu-xa:xem') ? [{ d: '/cau-hinh-tu-xa', nhan: t.cauHinhTuXa, bt: 'cau-hinh-tu-xa' }] : []),
          ]
        : [],
    },
    {
      nhan: t.nhomQuanTri,
      muc: [
        ...(quyen.includes('quan-tri-vien') ? [{ d: '/quan-tri-vien', nhan: t.quanTriVien, bt: 'quan-tri-vien' }] : []),
        ...(quyen.includes('audit:xem') ? [{ d: '/audit', nhan: t.nhatKyAudit, bt: 'audit' }] : []),
        ...(quyen.includes('cai-dat-soc') ? [{ d: '/cai-dat', nhan: t.caiDatHeThong, bt: 'cai-dat' }] : []),
        { d: '/tai-khoan', nhan: t.taiKhoan, bt: 'tai-khoan' },
      ],
    },
  ];

  const dsLenh = useMemo<Lenh[]>(
    () => [
      ...nhom.flatMap((g) => g.muc.map((m) => ({ id: `di${m.d}`, nhom: g.nhan, nhan: m.nhan, tuKhoa: m.d, chay: () => di(`#${m.d}`) }))),
      { id: 'chu-de', nhom: t.hienThi, nhan: t.lenhDoiGiaoDien, tuKhoa: 'theme dark light', chay: doiChuDe },
      { id: 'ngon-ngu', nhom: t.hienThi, nhan: t.lenhDoiNgonNgu, tuKhoa: 'language ngon ngu', chay: doiNn },
      { id: 'mat-do', nhom: t.hienThi, nhan: t.lenhMatDo, tuKhoa: 'density', chay: () => doiTc({ matDo: tc.matDo === 'gon' ? 'thoang' : 'gon' }) },
      ...(hieuLuc.thuyVanBat && toiCd?.thuyVan.mucToiThieu !== 'chuan'
        ? [{ id: 'thuy-van', nhom: t.hienThi, nhan: t.lenhThuyVan, tuKhoa: 'watermark', chay: () => doiTc({ thuyVan: tc.thuyVan === 'nhe' ? 'chuan' : 'nhe' }) }]
        : []),
      { id: 'phim', nhom: t.hienThi, nhan: t.lenhPhimTat, tuKhoa: 'shortcuts', chay: () => datMoPhim(true) },
      { id: 'dang-xuat', nhom: t.taiKhoan, nhan: t.dangXuat, tuKhoa: 'logout sign out', chay: dangXuat },
    ],
    [t, quyen.join(','), soMo, soChoDuyet, doiChuDe, doiNn, doiTc, tc.matDo, tc.thuyVan, hieuLuc.thuyVanBat, toiCd, dangXuat, di],
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
        <p>{tt.ma === 'khien' ? t.khienChan : tt.ma === 'vai-tro' ? t.khongCoVaiTro : tt.ma === 'access' ? t.accessLoi : t.loiChung}</p>
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

  const toi = tt.toi;
  const chiTietId = /^\/thiet-bi\/([0-9A-Za-z-]{8,40})$/.exec(duong)?.[1];
  const canhBaoId = /^\/canh-bao\/([0-9A-Za-z-]{8,40})$/.exec(duong)?.[1];
  const luatId = /^\/luat\/(R-\d{3,6})$/.exec(duong)?.[1];
  let noiDung: ReactNode;
  let tieuDeTrang = t.tongQuan;
  if (chiTietId) {
    noiDung = <ChiTiet id={chiTietId} />;
    tieuDeTrang = t.thietBi;
  } else if (duong === '/thiet-bi') {
    noiDung = <DsThietBi key={hash} />;
    tieuDeTrang = t.thietBi;
  } else if (duong === '/canh-bao' || canhBaoId) {
    noiDung = <CanhBao moId={canhBaoId ?? null} />;
    tieuDeTrang = t.tieuDeCanhBao;
  } else if ((duong === '/luat' || luatId) && toi.quyen.includes('luat:xem')) {
    noiDung = <Luat moId={luatId ?? null} />;
    tieuDeTrang = t.luat;
  } else if (duong === '/can-thiep' && toi.quyen.includes('luat:xem')) {
    noiDung = <CanThiep />;
    tieuDeTrang = t.canThiep;
  } else if (duong === '/cau-hinh-nguy-co' && toi.quyen.includes('luat:xem')) {
    noiDung = <CauHinhNguyCo />;
    tieuDeTrang = t.cauHinhNguyCo;
  } else if (duong === '/khieu-nai' && toi.quyen.includes('khieu-nai:xem')) {
    noiDung = <KhieuNai doiDem={doiDemKn} />;
    tieuDeTrang = t.khieuNai;
  } else if (duong === '/bao-cao' && toi.quyen.includes('bao-cao:xem')) {
    noiDung = <BaoCao />;
    tieuDeTrang = t.baoCao;
  } else if (duong === '/su-co-app' && toi.quyen.includes('su-co:xem')) {
    noiDung = <SuCoApp />;
    tieuDeTrang = t.suCoApp;
  } else if (duong === '/cau-hinh-tu-xa' && toi.quyen.includes('cau-hinh-tu-xa:xem')) {
    noiDung = <CauHinhTuXa />;
    tieuDeTrang = t.cauHinhTuXa;
  } else if (duong === '/audit' && toi.quyen.includes('audit:xem')) {
    noiDung = <NhatKyAudit />;
    tieuDeTrang = t.nhatKyAudit;
  } else if (duong === '/cai-dat' && toi.quyen.includes('cai-dat-soc')) {
    noiDung = <CaiDatHeThong daDoi={() => void napToi()} />;
    tieuDeTrang = t.caiDatHeThong;
  } else if (duong === '/tai-khoan') {
    noiDung = <TaiKhoan />;
    tieuDeTrang = t.tkTieuDe;
  } else if (duong === '/quan-tri-vien' && toi.quyen.includes('quan-tri-vien')) {
    noiDung = <QuanTriVien />;
    tieuDeTrang = t.quanTriVien;
  } else {
    noiDung = <TongQuan />;
  }
  const moiTruong = toi.moiTruong ?? '';
  const laProd = /^prod/.test(moiTruong);
  const conLai = toi.phien ? toi.phien.het - bayGio : 0;

  return (
    <Ctx.Provider value={ctx}>
      <NguonThongBao nhanDong={t.dong}>
        <div className="khung" data-menu-mo={moMenu ? '' : undefined}>
          <a className="bo-qua" href="#noi-dung-chinh">
            {t.dieuHuong}
          </a>
          <aside className="thanh-ben" aria-label={t.dieuHuong}>
            <a className="thuong-hieu" href="#/">
              <img src="/favicon.svg" alt="" width="28" height="28" />
              <span>{t.tieuDe}</span>
            </a>
            <nav className="dieu-huong">
              {nhom
                .filter((g) => g.muc.length > 0)
                .map((g) => (
                  <div key={g.nhan} className="nhom-dieu-huong">
                    <p className="nhom-nhan">{g.nhan}</p>
                    {g.muc.map((m) => {
                      const dang = m.d === '/' ? duong === '/' || duong === '' : duong.startsWith(m.d);
                      return (
                        <a key={m.d} href={`#${m.d}`} aria-current={dang ? 'page' : undefined} onClick={() => datMoMenu(false)}>
                          <BieuTuong ten={m.bt} />
                          <span>{m.nhan}</span>
                          {m.dem ? <span className="huy-hieu">{m.dem > 99 ? '99+' : m.dem}</span> : null}
                        </a>
                      );
                    })}
                  </div>
                ))}
            </nav>
            <div className="chan-thanh-ben">
              <span className="email" title={toi.email}>
                {toi.email}
              </span>
              <span className="the-vai-tro">{t.vaiTro[toi.vaiTro] ?? toi.vaiTro}</span>
            </div>
          </aside>
          <div className="cot-chinh">
            <header className="thanh-tren">
              <button type="button" className="nut-bieu-tuong chi-hep" aria-label={t.moMenu} aria-expanded={moMenu} onClick={() => datMoMenu((m) => !m)}>
                <BieuTuong ten="menu" />
              </button>
              <h1 className="tieu-de-thanh">{tieuDeTrang}</h1>
              {moiTruong && <span className={laProd ? 'moi-truong mt-prod' : 'moi-truong'}>{t.moiTruongNhan(moiTruong)}</span>}
              <button type="button" className="o-tim-lenh" onClick={() => datMoLenh(true)}>
                <BieuTuong ten="tim" co={16} />
                <span>{t.timLenh}</span>
                <kbd>Ctrl K</kbd>
              </button>
              <div className="nhom-nut">
                {toi.phien && (
                  <span className={conLai < 30 * 60_000 ? 'dem-phien sap-het' : 'dem-phien'} title={t.phienHetLuc}>
                    {t.phienConLai(dongHo(conLai))}
                  </span>
                )}
                <button type="button" className="nut-bieu-tuong" onClick={doiNn} aria-label={t.lenhDoiNgonNgu} title={t.lenhDoiNgonNgu}>
                  <BieuTuong ten="ngon-ngu" />
                </button>
                <button type="button" className="nut-bieu-tuong" onClick={doiChuDe} aria-label={laToi ? t.giaoDienSang : t.giaoDienToi} title={laToi ? t.giaoDienSang : t.giaoDienToi}>
                  <BieuTuong ten={laToi ? 'mat-troi' : 'mat-trang'} />
                </button>
                <button type="button" className="nut-bieu-tuong" onClick={() => datMoPhim(true)} aria-label={t.phimTat} title={t.phimTat}>
                  <BieuTuong ten="ban-phim" />
                </button>
                <button type="button" className="nut-bieu-tuong" onClick={dangXuat} aria-label={t.dangXuat} title={t.dangXuat}>
                  <BieuTuong ten="dang-xuat" />
                </button>
              </div>
            </header>
            <VungDuLieu bat={hieuLuc.thuyVanBat} email={toi.email} muc={hieuLuc.thuyVan} cheKhiRoi={hieuLuc.cheKhiRoi} chuDe={laToi ? 'dark' : 'light'} nhanChe={t.noiDungDaChe}>
              <main id="noi-dung-chinh" className="noi-dung" tabIndex={-1}>
                {noiDung}
              </main>
            </VungDuLieu>
          </div>
          <BangLenh mo={moLenh} dong={() => datMoLenh(false)} ds={dsLenh} t={t} di={di} />
          <HopThoai mo={moPhim} tieuDe={t.phimTat} dong={() => datMoPhim(false)}>
            <dl className="dl phim-tat">
              {t.dsPhimTat.map(([k, mo]) => (
                <div key={k} className="dl-dong">
                  <dt>
                    <kbd>{k}</kbd>
                  </dt>
                  <dd>{mo}</dd>
                </div>
              ))}
            </dl>
            <div className="hang-nut">
              <button type="button" className="nut" onClick={() => datMoPhim(false)}>
                {t.dong}
              </button>
            </div>
          </HopThoai>
        </div>
      </NguonThongBao>
    </Ctx.Provider>
  );
}
