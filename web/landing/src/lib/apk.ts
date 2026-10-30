// Thông tin bản APK mới nhất, đọc LÚC BUILD từ compass-cdn (tools/build/phat-hanh-apk.sh ghi latest.json) -> trang tĩnh,
// không gọi mạng ở trình duyệt. Mạng lỗi / chưa phát hành -> null, trang hiện "đang chuẩn bị" (build không hỏng).
import { readFileSync } from 'node:fs';

export type TepApk = { loai: 'arm64' | 'armv7' | 'universal'; ten: string; url: string; co: number; sha256: string };
export type BanApk = {
  phienBan: string;
  maPhienBan: number;
  ngay: string;
  minSdk: number;
  chungChiSha256: string;
  github: string;
  tep: TepApk[];
};

export const URL_LATEST = 'https://compass-cdn.tsudev.com/android/latest.json';

function hopLe(x: unknown): x is BanApk {
  const b = x as BanApk;
  return (
    typeof b?.phienBan === 'string' &&
    /^[0-9a-f]{64}$/.test(b.chungChiSha256 ?? '') &&
    Array.isArray(b.tep) &&
    b.tep.length > 0 &&
    b.tep.every((t) => t.url.startsWith('https://compass-cdn.tsudev.com/android/') && /^[0-9a-f]{64}$/.test(t.sha256) && t.co > 0)
  );
}

let daNap: Promise<BanApk | null> | null = null;

/** LA_BAN_APK_JSON=<tệp> để build ngoại tuyến / thử; LA_BAN_APK_JSON=none để bỏ qua mạng. */
export function napBanApk(): Promise<BanApk | null> {
  daNap ??= (async () => {
    const tep = process.env.LA_BAN_APK_JSON;
    if (tep === 'none') return null;
    try {
      const du: unknown = tep
        ? JSON.parse(readFileSync(tep, 'utf8'))
        : await (await fetch(URL_LATEST, { signal: AbortSignal.timeout(8000) })).json();
      return hopLe(du) ? du : null;
    } catch {
      return null;
    }
  })();
  return daNap;
}

export function dinhDangCo(byte: number, lang: string): string {
  return `${new Intl.NumberFormat(lang, { maximumFractionDigits: 1 }).format(byte / 1024 / 1024)} MB`;
}

/** minSdk -> phiên bản Android tối thiểu dễ đọc. */
export function androidToiThieu(minSdk: number): string {
  const bang: Record<number, string> = { 21: '5.0', 23: '6.0', 24: '7.0', 26: '8.0', 28: '9', 29: '10', 30: '11', 31: '12', 33: '13', 34: '14' };
  return `Android ${bang[minSdk] ?? `API ${minSdk}`}+`;
}
