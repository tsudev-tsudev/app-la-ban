// Mã trình duyệt trang khiếu nại (đóng gói -> dist/js/khieu-nai.js bởi edge/dong-goi.mjs). Turnstile render tường minh
// vào ô của form; token dùng một lần -> reset sau mỗi lượt gửi. Thông báo lấy từ data-* (chuỗi i18n nằm ở HTML).
import { API_KHIEU_NAI, maLoiTuPhanHoi, refTuQuery } from './khieu-nai';

type Turnstile = {
  render(el: HTMLElement, tc: Record<string, unknown>): string;
  reset(id?: string): void;
};

const form = document.querySelector<HTMLFormElement>('form[data-khieu-nai]');
const ts = (window as unknown as { turnstile?: Turnstile }).turnstile;

if (form) {
  const o = <T extends HTMLElement>(ten: string) => form.querySelector<T>(`[data-o="${ten}"]`);
  const trangThai = o<HTMLParagraphElement>('trang-thai');
  const nut = o<HTMLButtonElement>('gui');
  const oTs = o<HTMLDivElement>('turnstile');
  const ref = form.elements.namedItem('ref') as HTMLInputElement | null;
  const lang = document.documentElement.lang === 'en' ? 'en' : 'vi';
  let token = '';
  let idTs: string | undefined;

  const bao = (chu: string, loai: 'loi' | 'xong' | 'tin') => {
    if (!trangThai) return;
    trangThai.textContent = chu;
    trangThai.dataset.loai = loai;
    trangThai.hidden = false;
  };
  const loi = (ma: string) => bao(form.dataset[`loi${ma.replace(/(^|-)([a-z])/g, (_, _g, c: string) => c.toUpperCase())}`] ?? form.dataset.loiChung ?? '', 'loi');

  if (ref && !ref.value) ref.value = refTuQuery(location.search);

  if (!ts || !oTs || !form.dataset.siteKey) {
    // Script Turnstile bị chặn / lỗi mạng: không gửi được -> chỉ còn đường email bên dưới.
    form.querySelectorAll<HTMLElement>('input, textarea, button').forEach((x) => x.setAttribute('disabled', ''));
    loi('chung');
  } else {
    idTs = ts.render(oTs, {
      sitekey: form.dataset.siteKey,
      action: 'khieu-nai',
      language: lang,
      theme: 'auto',
      size: 'flexible',
      callback: (t: string) => {
        token = t;
      },
      'expired-callback': () => {
        token = '';
      },
      'error-callback': () => {
        token = '';
      },
    });

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      if (!form.reportValidity()) return;
      if (!token) {
        loi('chua-xac-minh');
        return;
      }
      const f = new FormData(form);
      const than = {
        ref: String(f.get('ref') ?? '').trim(),
        noiDung: String(f.get('noiDung') ?? '').trim(),
        lienHe: String(f.get('lienHe') ?? '').trim(),
        ngonNgu: lang,
        turnstile: token,
      };
      if (nut) {
        nut.disabled = true;
        nut.textContent = nut.dataset.dangGui ?? nut.textContent;
      }
      bao(form.dataset.dangGui ?? '', 'tin');
      void fetch(API_KHIEU_NAI, { method: 'POST', mode: 'cors', credentials: 'omit', headers: { 'content-type': 'application/json' }, body: JSON.stringify(than) })
        .then(async (res) => {
          if (res.ok) {
            form.reset();
            bao(form.dataset.xong ?? '', 'xong');
            return;
          }
          const j = (await res.json().catch(() => ({}))) as { code?: string };
          loi(maLoiTuPhanHoi(res.status, j.code));
        })
        .catch(() => loi('chung'))
        .finally(() => {
          token = '';
          ts.reset(idTs);
          if (nut) {
            nut.disabled = false;
            nut.textContent = nut.dataset.gui ?? nut.textContent;
          }
        });
    });
  }
}
