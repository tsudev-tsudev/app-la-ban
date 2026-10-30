// SH-04 (S7a làm lại): thuỷ vân MỘT lớp nền vẽ bằng canvas (ô thưa 440 x 260, chữ mảnh ~5 %) thay cho lưới hàng trăm thẻ
// span - nội dung dễ đọc hơn, DOM nhẹ hơn. Lớp chấm ẩn mang mã dấu vết (dau-vet.ts). Tự đậm lên khi rời cửa sổ / ẩn tab /
// in; tuỳ chọn che mờ dữ liệu khi rời cửa sổ. Chỉ là lớp hình (aria-hidden, không nhận chuột); ảnh nền đặt qua CSSOM
// (CSP không cho style nội tuyến dạng chuỗi; img-src cho phép data:). S7b: Super Admin tắt thuỷ vân toàn hệ thống -> [bat]
// = false thì không tạo lớp (mã dấu vết + audit xem dữ liệu ở server vẫn giữ).
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import { ALPHA_GOC, bitDauVet, doMoLop, LUOI_CHAM, maDauVet, nhanThuyVan, O_THUY_VAN, type MucThuyVan } from './dau-vet';
import './watermark.css';

const PHUT = 60_000;

function veO(nhan: string, bit: number[], mau: string, phongChu: string): string {
  const dpr = Math.min(3, Math.max(1, window.devicePixelRatio || 1));
  const { rong, cao } = O_THUY_VAN;
  const cv = document.createElement('canvas');
  cv.width = Math.round(rong * dpr);
  cv.height = Math.round(cao * dpr);
  const g = cv.getContext('2d');
  if (!g) return '';
  g.scale(dpr, dpr);
  g.fillStyle = mau;
  g.globalAlpha = ALPHA_GOC;
  g.font = `500 12px ${phongChu}`;
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  // Hai nhãn so le trong một ô -> phủ đều mà vẫn thưa.
  for (const [x, y] of [
    [rong * 0.27, cao * 0.3],
    [rong * 0.77, cao * 0.8],
  ] as const) {
    g.save();
    g.translate(x, y);
    g.rotate((-22 * Math.PI) / 180);
    g.fillText(nhan, 0, 0);
    g.restore();
  }
  // Chấm dấu vết: 1 = chấm 2 px, 0 = chấm 1 px; thêm 4 chấm góc làm mốc căn lưới khi giải.
  g.globalAlpha = ALPHA_GOC * 0.35;
  const goc = { x: rong * 0.52, y: cao * 0.48 };
  const buoc = 5;
  bit.forEach((b, i) => {
    const r = b ? 1 : 0.5;
    g.beginPath();
    g.arc(goc.x + (i % LUOI_CHAM) * buoc, goc.y + Math.floor(i / LUOI_CHAM) * buoc, r, 0, Math.PI * 2);
    g.fill();
  });
  const mep = (LUOI_CHAM + 1) * buoc;
  for (const [dx, dy] of [
    [-buoc, -buoc],
    [mep - buoc, -buoc],
    [-buoc, mep - buoc],
    [mep - buoc, mep - buoc],
  ] as const) {
    g.fillRect(goc.x + dx - 1, goc.y + dy - 1, 2, 2);
  }
  return cv.toDataURL('image/png');
}

function useTangCuong(): boolean {
  const [roi, datRoi] = useState(() => document.visibilityState === 'hidden' || !document.hasFocus());
  useEffect(() => {
    const cap = () => datRoi(document.visibilityState === 'hidden' || !document.hasFocus());
    const bat = ['blur', 'focus'] as const;
    bat.forEach((s) => addEventListener(s, cap));
    document.addEventListener('visibilitychange', cap);
    return () => {
      bat.forEach((s) => removeEventListener(s, cap));
      document.removeEventListener('visibilitychange', cap);
    };
  }, []);
  return roi;
}

export function VungDuLieu({
  bat = true,
  email,
  muc,
  cheKhiRoi,
  chuDe,
  nhanChe,
  children,
}: {
  bat?: boolean;
  email: string;
  muc: MucThuyVan;
  cheKhiRoi: boolean;
  /** Đổi giao diện sáng / tối -> vẽ lại theo màu chữ mới. */
  chuDe: string;
  nhanChe: string;
  children: ReactNode;
}) {
  const goc = useRef<HTMLDivElement>(null);
  const lop = useRef<HTMLDivElement | null>(null);
  /** Giá trị đã đặt gần nhất - bị xoá bằng DevTools thì đặt lại thẳng (không qua state, không vòng lặp). */
  const daDat = useRef({ anh: '', doMo: '' });
  const [bayGio, datBayGio] = useState(() => Date.now());
  const [ma, datMa] = useState('');
  const [lanVe, datLanVe] = useState(0);
  const tangCuong = useTangCuong();

  useEffect(() => {
    const hen = setInterval(() => datBayGio(Date.now()), PHUT);
    return () => clearInterval(hen);
  }, []);

  useEffect(() => {
    let con = true;
    void maDauVet(email, bayGio).then((m) => con && datMa(m));
    return () => {
      con = false;
    };
  }, [email, bayGio]);

  // Lớp tạo ngoài React: bị gỡ / ẩn bằng DevTools -> gắn lại ngay mà không làm vỡ cây React (răn đe; server vẫn là lớp
  // kiểm soát chính).
  useLayoutEffect(() => {
    const g = goc.current;
    if (!g || !bat) return;
    const el = document.createElement('div');
    el.className = 'thuy-van';
    el.setAttribute('aria-hidden', 'true');
    g.appendChild(el);
    lop.current = el;
    const sua = () => {
      let doi = false;
      if (!el.isConnected || el.parentNode !== g) {
        g.appendChild(el);
        doi = true;
      }
      if (el.className !== 'thuy-van') el.className = 'thuy-van';
      if (el.hidden) el.hidden = false;
      for (const k of ['display', 'visibility', 'opacity', 'filter', 'transform', 'inset', 'z-index'] as const) {
        if (el.style.getPropertyValue(k)) el.style.removeProperty(k);
      }
      const { anh, doMo } = daDat.current;
      if (anh && !el.style.backgroundImage) el.style.backgroundImage = anh;
      if (doMo && el.style.getPropertyValue('--do-mo-thuy-van') !== doMo) el.style.setProperty('--do-mo-thuy-van', doMo);
      if (doi) datLanVe((n) => n + 1);
    };
    const mo = new MutationObserver(sua);
    mo.observe(g, { childList: true });
    mo.observe(el, { attributes: true });
    return () => {
      mo.disconnect();
      el.remove();
      lop.current = null;
    };
  }, [bat]);

  useLayoutEffect(() => {
    const el = lop.current;
    if (!el || !ma) return;
    const kieu = getComputedStyle(el);
    const anh = veO(nhanThuyVan(email, bayGio, ma), bitDauVet(ma), kieu.color, kieu.fontFamily || 'sans-serif');
    daDat.current.anh = anh ? `url("${anh}")` : '';
    el.style.backgroundImage = daDat.current.anh;
    el.style.backgroundSize = `${O_THUY_VAN.rong}px ${O_THUY_VAN.cao}px`;
  }, [email, bayGio, ma, chuDe, lanVe, bat]);

  useLayoutEffect(() => {
    daDat.current.doMo = String(doMoLop(muc, tangCuong));
    lop.current?.style.setProperty('--do-mo-thuy-van', daDat.current.doMo);
  }, [muc, tangCuong, bat]);

  const che = cheKhiRoi && tangCuong;
  return (
    <div className="vung-du-lieu" ref={goc} data-nhay-cam="" data-che={che ? '' : undefined}>
      {children}
      {che && (
        <div className="man-che" role="status">
          {nhanChe}
        </div>
      )}
    </div>
  );
}
