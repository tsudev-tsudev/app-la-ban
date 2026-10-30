// Thông báo nổi (toast) dùng chung: một vùng aria-live, tự ẩn sau 5 giây (lỗi: 8 giây), tối đa 4 cái.
import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';

type Loai = 'ok' | 'loi' | 'tin';
type MotThongBao = { id: number; loai: Loai; noiDung: string };
type HamBao = (noiDung: string, loai?: Loai) => void;

const Ctx = createContext<HamBao>(() => undefined);

export function useThongBao(): HamBao {
  return useContext(Ctx);
}

export function NguonThongBao({ children, nhanDong }: { children: ReactNode; nhanDong: string }) {
  const [ds, datDs] = useState<MotThongBao[]>([]);
  const so = useRef(0);
  const bo = useCallback((id: number) => datDs((d) => d.filter((x) => x.id !== id)), []);
  const bao = useCallback<HamBao>(
    (noiDung, loai = 'ok') => {
      const id = ++so.current;
      datDs((d) => [...d.slice(-3), { id, loai, noiDung }]);
      setTimeout(() => bo(id), loai === 'loi' ? 8000 : 5000);
    },
    [bo],
  );
  const giaTri = useMemo(() => bao, [bao]);
  return (
    <Ctx.Provider value={giaTri}>
      {children}
      <div className="vung-thong-bao" aria-live="polite" aria-relevant="additions">
        {ds.map((x) => (
          <div key={x.id} className={`thong-bao tb-${x.loai}`} role={x.loai === 'loi' ? 'alert' : 'status'}>
            <span>{x.noiDung}</span>
            <button type="button" className="nut-bieu-tuong" aria-label={nhanDong} onClick={() => bo(x.id)}>
              ×
            </button>
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}
