// Hộp thoại modal trên <dialog> gốc của trình duyệt: bẫy focus, Esc đóng, nền mờ - không cần thư viện, không style nội tuyến.
import { useEffect, useRef, type ReactNode } from 'react';

export function HopThoai({ mo, tieuDe, dong, children, rong = false }: { mo: boolean; tieuDe: string; dong: () => void; children: ReactNode; rong?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (mo && !d.open) d.showModal();
    if (!mo && d.open) d.close();
  }, [mo]);
  return (
    <dialog
      ref={ref}
      className={rong ? 'hop-thoai rong' : 'hop-thoai'}
      aria-label={tieuDe}
      onClose={dong}
      onClick={(e) => {
        // Bấm ra nền (chính phần tử dialog, ngoài khung nội dung) -> đóng.
        if (e.target === e.currentTarget) dong();
      }}
    >
      {mo && (
        <div className="hop-thoai-khung">
          <h2 className="hop-thoai-tieu-de">{tieuDe}</h2>
          {children}
        </div>
      )}
    </dialog>
  );
}
