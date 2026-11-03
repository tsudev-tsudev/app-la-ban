// Lớp DOM của khiên (SH-01..03): gắn sự kiện, đo kích thước cửa sổ, phủ màn khi nghi ngờ, gửi tín hiệu về Worker.
// Quyết định nằm ở các hàm thuần (muc / phim / devtools / cau-hinh); ở đây chỉ nối vào trình duyệt. Không innerHTML,
// không eval, không style nội tuyến -> chạy được dưới CSP nonce + Trusted Types.
import { kiemGoi, mucChoTrang, phanTichGoi } from './cau-hinh';
import { capNhatDo, debuggerDangGan, ketLuan, laTuDongHoa, TRANG_THAI_DAU, type KetLuan, type SuKienDo, type TrangThaiDo } from './devtools';
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
  const daBao = new Set<string>();
  let phu: HTMLElement | null = null;
  // S11 (Q58): nội dung trang được GỠ khỏi DOM khi nghi ngờ (Elements không còn gì để xem), giữ ngoài cây để trả lại.
  let giuLai: DocumentFragment | null = null;
  let hen: ReturnType<typeof setInterval> | null = null;
  let henDebugger: ReturnType<typeof setInterval> | null = null;
  let suKienCuoi: SuKienDo['loai'] = 'do';
  const dem = { phim: 0, menu: 0 };

  const chan = (e: Event) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const baoTinHieu = (kl: KetLuan) => {
    const loai = kl.tuDong ? 'tu-dong-hoa' : suKienCuoi === 'debugger' ? 'debugger' : 'devtools';
    if (daBao.has(loai)) return;
    daBao.add(loai);
    void fetch(`${tc.api}/v1/web/signals`, {
      method: 'POST',
      mode: 'cors',
      credentials: 'omit',
      keepalive: true,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        trang: tc.trang,
        loai,
        duongDan: location.pathname.slice(0, 128),
        tinHieu: {
          kich_thuoc: kl.kichThuoc,
          diem: kl.diem,
          phim: dem.phim,
          menu: dem.menu,
          debugger: loai === 'debugger',
          tu_dong: kl.tuDong,
        },
      }),
    }).catch(() => undefined);
  };

  const datNghi = (nghi: boolean) => {
    if (nghi === dangNghi) return;
    dangNghi = nghi;
    const than = document.body;
    if (nghi) {
      html.setAttribute('data-khien-nghi', '');
      if (than && !giuLai) {
        giuLai = document.createDocumentFragment();
        while (than.firstChild) giuLai.append(than.firstChild);
      }
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
      than?.append(phu);
    } else {
      html.removeAttribute('data-khien-nghi');
      phu?.remove();
      phu = null;
      if (than && giuLai) than.append(giuLai);
      giuLai = null;
    }
  };

  const xet = (e: SuKienDo) => {
    if (!hv.doDevtools) return;
    if (e.loai !== 'do') suKienCuoi = e.loai;
    trangThai = capNhatDo(trangThai, e, Date.now());
    const kl = ketLuan(trangThai);
    if (kl.nghi) baoTinHieu(kl);
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

  // Chỉ dừng khi có công cụ gắn vào (DevTools, kể cả tách cửa sổ; remote debugging qua USB từ máy tính). Không công cụ:
  // câu lệnh không làm gì, < 1 ms - không ảnh hưởng người dùng thường.
  const kiemDebugger = () => {
    const truoc = performance.now();
    // eslint-disable-next-line no-debugger -- S11: dò công cụ đang gắn (Q58)
    debugger;
    if (debuggerDangGan(truoc, performance.now())) xet({ loai: 'debugger' });
  };

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
      henDebugger = setInterval(kiemDebugger, 2000);
      const nav = navigator as Navigator & { userAgentData?: { brands?: { brand: string }[] } };
      if (laTuDongHoa({ webdriver: nav.webdriver === true, ua: nav.userAgent, brands: (nav.userAgentData?.brands ?? []).map((b) => b.brand) })) {
        xet({ loai: 'tuDong' });
      }
      doKichThuoc();
      kiemDebugger();
    } else if (!hv.doDevtools && hen !== null) {
      clearInterval(hen);
      hen = null;
      if (henDebugger !== null) clearInterval(henDebugger);
      henDebugger = null;
      trangThai = TRANG_THAI_DAU;
      datNghi(false);
    }
    // Admin chỉ tải dữ liệu sau lần kiểm đầu (SH-07, Q58): giao diện chờ thuộc tính này + không có `data-khien-nghi`.
    html.setAttribute('data-khien-san', '');
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
    if (henDebugger !== null) clearInterval(henDebugger);
    datNghi(false);
    html.removeAttribute('data-khien');
  };
}
