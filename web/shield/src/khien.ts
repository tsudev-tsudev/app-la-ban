// Lớp DOM của khiên (SH-01..03): gắn sự kiện, đo kích thước cửa sổ, phủ màn khi nghi ngờ, gửi tín hiệu về Worker.
// Quyết định nằm ở các hàm thuần (muc / phim / devtools / cau-hinh); ở đây chỉ nối vào trình duyệt. Không innerHTML,
// không eval, không style nội tuyến -> chạy được dưới CSP nonce + Trusted Types.
import { kiemGoi, mucChoTrang, phanTichGoi } from './cau-hinh';
import { capNhatDo, ketLuan, TRANG_THAI_DAU, type SuKienDo, type TrangThaiDo } from './devtools';
import { KHOA_CONG_KHAI } from './khoa';
import { hanhViTheoMuc, type HanhVi, type MucBaoVe, type Trang } from './muc';
import { chuoiTheoNgonNgu } from './ngon-ngu';
import { phanLoaiPhim } from './phim';

export type TuyChonKhien = {
  trang: Trang;
  /** Gốc Worker API, ví dụ https://compass-api.tsudev.com */
  api: string;
  chuKyDoMs?: number;
};

/** Vùng người dùng vẫn chọn / dán / mở menu được: ô nhập liệu và phần trang tự đánh dấu (mã kiểm SHA-256...). */
export const VUNG_CHO_PHEP =
  'input, textarea, select, [contenteditable]:not([contenteditable="false"]), [data-cho-chon]';

function laVungChoPhep(n: EventTarget | Node | null): boolean {
  const el = n instanceof Element ? n : n instanceof Node ? n.parentElement : null;
  return el?.closest(VUNG_CHO_PHEP) != null;
}

function vungChonChoPhep(): boolean {
  const s = document.getSelection();
  return !!s && s.rangeCount > 0 && laVungChoPhep(s.anchorNode) && laVungChoPhep(s.focusNode);
}

export function khoiDong(tc: TuyChonKhien): () => void {
  const html = document.documentElement;
  let hv: HanhVi = hanhViTheoMuc('chat');
  let trangThai: TrangThaiDo = TRANG_THAI_DAU;
  let dangNghi = false;
  let daBao = false;
  let phu: HTMLElement | null = null;
  let hen: ReturnType<typeof setInterval> | null = null;
  const dem = { phim: 0, menu: 0 };

  const chan = (e: Event) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const baoTinHieu = (kichThuoc: boolean, diem: number) => {
    if (daBao) return;
    daBao = true;
    void fetch(`${tc.api}/v1/web/signals`, {
      method: 'POST',
      mode: 'cors',
      credentials: 'omit',
      keepalive: true,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        trang: tc.trang,
        loai: 'devtools',
        duongDan: location.pathname.slice(0, 128),
        tinHieu: { kich_thuoc: kichThuoc, diem, phim: dem.phim, menu: dem.menu },
      }),
    }).catch(() => undefined);
  };

  const datNghi = (nghi: boolean) => {
    if (nghi === dangNghi) return;
    dangNghi = nghi;
    if (nghi) {
      html.setAttribute('data-khien-nghi', '');
      const c = chuoiTheoNgonNgu(html.lang);
      phu = document.createElement('div');
      phu.className = 'khien-phu';
      phu.setAttribute('role', 'alertdialog');
      phu.setAttribute('aria-modal', 'true');
      phu.setAttribute('aria-labelledby', 'khien-tieu-de');
      const h = document.createElement('h2');
      h.id = 'khien-tieu-de';
      h.textContent = c.tieuDe;
      const p = document.createElement('p');
      p.textContent = c.moTa;
      phu.append(h, p);
      document.body.append(phu);
    } else {
      html.removeAttribute('data-khien-nghi');
      phu?.remove();
      phu = null;
    }
  };

  const xet = (e: SuKienDo) => {
    if (!hv.doDevtools) return;
    trangThai = capNhatDo(trangThai, e, Date.now());
    const kl = ketLuan(trangThai);
    if (kl.nghi) baoTinHieu(kl.kichThuoc, kl.diem);
    datNghi(kl.nghi);
  };

  const coarse = window.matchMedia?.('(pointer: coarse)');
  const doKichThuoc = () =>
    xet({
      loai: 'do',
      kichThuoc: {
        ngoaiRong: window.outerWidth,
        ngoaiCao: window.outerHeight,
        trongRong: window.innerWidth,
        trongCao: window.innerHeight,
        camUng: coarse?.matches === true,
      },
    });

  const onKey = (e: KeyboardEvent) => {
    if (!hv.phimTat) return;
    const loai = phanLoaiPhim(e);
    if (!loai) return;
    chan(e);
    if (loai === 'devtools') {
      dem.phim++;
      xet({ loai: 'phimDevtools' });
    }
  };
  const onMenu = (e: MouseEvent) => {
    if (!hv.menuChuot || laVungChoPhep(e.target)) return;
    chan(e);
    dem.menu++;
    xet({ loai: 'menuChuot' });
  };
  const onKeo = (e: DragEvent) => {
    if (!hv.keoAnh || laVungChoPhep(e.target)) return;
    const el = e.target instanceof Element ? e.target : null;
    if (el?.closest('img, picture, svg, a')) chan(e);
  };
  const onChon = (e: Event) => {
    if (hv.saoChep && !laVungChoPhep(e.target)) chan(e);
  };
  const onChep = (e: ClipboardEvent) => {
    if (hv.saoChep && !laVungChoPhep(e.target) && !vungChonChoPhep()) chan(e);
  };

  const apDung = (muc: MucBaoVe) => {
    hv = hanhViTheoMuc(muc);
    html.setAttribute('data-khien', muc);
    if (hv.doDevtools && hen === null) {
      hen = setInterval(doKichThuoc, tc.chuKyDoMs ?? 1000);
      doKichThuoc();
    } else if (!hv.doDevtools && hen !== null) {
      clearInterval(hen);
      hen = null;
      trangThai = TRANG_THAI_DAU;
      datNghi(false);
    }
  };

  const tuyChonNghe = { capture: true };
  window.addEventListener('keydown', onKey, tuyChonNghe);
  document.addEventListener('contextmenu', onMenu, tuyChonNghe);
  document.addEventListener('dragstart', onKeo, tuyChonNghe);
  document.addEventListener('selectstart', onChon, tuyChonNghe);
  document.addEventListener('copy', onChep, tuyChonNghe);
  document.addEventListener('cut', onChep, tuyChonNghe);
  apDung('chat');

  void (async () => {
    try {
      const res = await fetch(`${tc.api}/v1/web/cau-hinh`, { mode: 'cors', credentials: 'omit' });
      if (!res.ok) return;
      const goi = phanTichGoi(await res.json());
      if (!goi || !crypto.subtle) return;
      apDung(mucChoTrang(await kiemGoi(goi, KHOA_CONG_KHAI, crypto.subtle), tc.trang, Date.now()));
    } catch {
      // Giữ mức chat (đóng khi lỗi).
    }
  })();

  return () => {
    window.removeEventListener('keydown', onKey, tuyChonNghe);
    document.removeEventListener('contextmenu', onMenu, tuyChonNghe);
    document.removeEventListener('dragstart', onKeo, tuyChonNghe);
    document.removeEventListener('selectstart', onChon, tuyChonNghe);
    document.removeEventListener('copy', onChep, tuyChonNghe);
    document.removeEventListener('cut', onChep, tuyChonNghe);
    if (hen !== null) clearInterval(hen);
    datNghi(false);
    html.removeAttribute('data-khien');
  };
}
