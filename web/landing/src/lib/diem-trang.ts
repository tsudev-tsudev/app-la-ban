// Mã trình duyệt của trang /w/<token> (đóng gói -> dist/js/diem.js bởi edge/dong-goi.mjs). Chỉ gán textContent /
// thuộc tính href đã dựng: nội dung token không tin cậy, không bao giờ thành HTML.
import { giaiMaToken, linkBanDo, linkMoApp, tokenTuDuongDan, type LoiToken } from './diem-chia-se';

const THUOC_TINH_LOI: Record<LoiToken, string> = { hong: 'hong', hetHan: 'hetHan', phienBanLa: 'phienBanLa' };

function chon<T extends Element>(goc: Element, o: string): T {
  return goc.querySelector(`[data-o="${o}"]`) as T;
}

function hien(goc: HTMLElement): void {
  const lang = goc.dataset.ngonNgu === 'en' ? 'en' : 'vi';
  const token = tokenTuDuongDan(location.pathname) ?? '';
  const kq = giaiMaToken(token, Math.floor(Date.now() / 1000));
  chon<HTMLElement>(goc, 'dang-doc').hidden = true;
  if ('loi' in kq) {
    const p = chon<HTMLElement>(goc, 'loi');
    p.textContent = p.dataset[THUOC_TINH_LOI[kq.loi]] ?? '';
    p.hidden = false;
    return;
  }
  const d = kq.diem;
  const so = new Intl.NumberFormat(lang === 'vi' ? 'vi-VN' : 'en-GB', { maximumFractionDigits: 1 });
  chon(goc, 'ten').textContent = d.ten;
  chon(goc, 'toa-do').textContent = `${d.viDo.toFixed(6)}, ${d.kinhDo.toFixed(6)}`;
  if (d.caoDo !== null) {
    const c = chon<HTMLElement>(goc, 'cao-do');
    c.textContent = (c.dataset.mau ?? '').replace('{m}', so.format(d.caoDo));
    c.hidden = false;
  }
  if (d.ghiChu) {
    chon(goc, 'ghi-chu').textContent = d.ghiChu;
    chon<HTMLElement>(goc, 'khoi-ghi-chu').hidden = false;
  }
  const h = chon<HTMLElement>(goc, 'het-han');
  const gio = new Intl.DateTimeFormat(lang === 'vi' ? 'vi-VN' : 'en-GB', { dateStyle: 'medium', timeStyle: 'short' });
  h.textContent = (h.dataset.mau ?? '').replace('{gio}', gio.format(new Date(d.hetHan * 1000)));
  if (/Android/i.test(navigator.userAgent)) chon<HTMLAnchorElement>(goc, 'mo-app').href = linkMoApp(token);
  else chon<HTMLElement>(goc, 'mo-app').hidden = true;
  chon<HTMLAnchorElement>(goc, 'ban-do').href = linkBanDo(d);
  chon<HTMLElement>(goc, 'noi-dung').hidden = false;
}

const viet = (navigator.languages ?? [navigator.language]).some((l) => /^vi\b/i.test(l));
for (const goc of document.querySelectorAll<HTMLElement>('[data-ngon-ngu]')) {
  const dung = (goc.dataset.ngonNgu === 'vi') === viet;
  goc.hidden = !dung;
  if (dung) {
    document.documentElement.lang = goc.dataset.ngonNgu ?? 'vi';
    hien(goc);
  }
}
