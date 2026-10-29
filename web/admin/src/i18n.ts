// Chuỗi giao diện admin vi / en (khung S9; S6 thay bằng bộ i18n đầy đủ khi dựng SOC thật).
export type NgonNgu = 'vi' | 'en';

const CHUOI = {
  vi: {
    tieuDe: 'La bàn SOC',
    dangXay: 'Đang xây dựng.',
    chuaXacThuc: 'chưa xác thực',
  },
  en: {
    tieuDe: 'Compass SOC',
    dangXay: 'Under construction.',
    chuaXacThuc: 'unauthenticated',
  },
} as const satisfies Record<NgonNgu, Record<string, string>>;

export type Chuoi = (typeof CHUOI)[NgonNgu];

export function ngonNgu(lang: string | null | undefined): NgonNgu {
  return (lang ?? '').toLowerCase().startsWith('en') ? 'en' : 'vi';
}

export function chuoi(n: NgonNgu): Chuoi {
  return CHUOI[n];
}
