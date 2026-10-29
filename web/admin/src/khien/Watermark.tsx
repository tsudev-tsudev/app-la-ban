// SH-04: watermark động phủ vùng dữ liệu - email người xem + thời điểm (đổi mỗi phút). Chỉ là lớp hình (aria-hidden,
// không nhận chuột); không dùng style nội tuyến dạng chuỗi (CSP) - React đặt qua CSSOM.
import { noiDungWatermark, soO } from '@laban/web-shield';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import './watermark.css';

const PHUT = 60_000;

export function VungDuLieu({ email, children }: { email: string; children: ReactNode }) {
  const goc = useRef<HTMLDivElement>(null);
  const [bayGio, datBayGio] = useState(() => Date.now());
  const [so, datSo] = useState(0);

  useEffect(() => {
    const hen = setInterval(() => datBayGio(Date.now()), PHUT);
    return () => clearInterval(hen);
  }, []);

  useEffect(() => {
    const el = goc.current;
    if (!el) return;
    const do_ = () => datSo(soO(el.clientWidth, el.clientHeight));
    do_();
    const ro = new ResizeObserver(do_);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const nhan = noiDungWatermark(email, bayGio);
  return (
    <div className="vung-du-lieu" ref={goc} data-nhay-cam="">
      {children}
      <div className="watermark" aria-hidden="true">
        {Array.from({ length: so }, (_, i) => (
          <span key={i}>{nhan}</span>
        ))}
      </div>
    </div>
  );
}
