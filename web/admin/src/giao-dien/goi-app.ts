/** M2 (Q56): gói app "La bàn Pro" (prod + hậu tố flavor .dev / .stg). Chỉ để hiển thị - lọc thật ở Worker theo PI_GOI_PRO. */
export function laGoiPro(goi: string | null | undefined): boolean {
  return goi === 'com.tsudev.laban.pro' || (goi ?? '').startsWith('com.tsudev.laban.pro.');
}
