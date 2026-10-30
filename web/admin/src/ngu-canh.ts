// Ngữ cảnh SOC dùng chung giữa khung và các trang (tách riêng để không nhập vòng App <-> trang).
import { createContext, useContext } from 'react';
import type { Toi } from './api';
import type { ChuoiSoc, NgonNgu } from './i18n';

export type NguCanh = { t: ChuoiSoc; nn: NgonNgu; toi: Toi; coQuyen: (q: string) => boolean; hetPhien: () => void };
export const Ctx = createContext<NguCanh | null>(null);

export function useSoc(): NguCanh {
  const c = useContext(Ctx);
  if (!c) throw new Error('ngoài SOC');
  return c;
}
