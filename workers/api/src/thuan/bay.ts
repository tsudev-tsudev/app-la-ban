// Bẫy quét (honeypot, S8 - SEC-EDGE): đường dẫn mà app / web của La bàn KHÔNG BAO GIỜ gọi (API chỉ có /v1/*). Ai gọi tới
// gần như chắc chắn là máy quét lỗ hổng -> sự kiện HONEYPOT_HIT theo IP cho Threat Engine (rule R-006), trả 404 như thường.

const TIEN_TO: readonly string[] = Object.freeze([
  '/wp-',
  '/wordpress',
  '/.env',
  '/.git',
  '/.svn',
  '/.aws',
  '/.ssh',
  '/.vscode',
  '/.ds_store',
  '/phpmyadmin',
  '/pma',
  '/cgi-bin',
  '/vendor/phpunit',
  '/actuator',
  '/server-status',
  '/boaform',
  '/hnap1',
  '/solr',
  '/owa',
  '/autodiscover',
]);

const DUOI = /\.(php\d?|aspx?|jsp|cgi|env|bak|sql)$/;

/** Nhãn bẫy (tiền tố hoặc đuôi tệp đã khớp) - chỉ nhãn này vào tín hiệu, không lưu nguyên đường dẫn kẻ quét gửi. */
export function khopBay(duongDan: string): string | null {
  const p = duongDan.toLowerCase();
  for (const t of TIEN_TO) if (p === t || p.startsWith(t)) return t;
  const d = DUOI.exec(p);
  return d ? `*.${d[1]}` : null;
}

/**
 * Nén báo cáo theo IP trong một isolate: kẻ quét gõ 100 đường dẫn / giây không thành 100 lượt ghi D1. Trả true khi được
 * báo (và ghi nhận), false khi IP vừa báo trong [khoangMs]. Bảng tự dọn khi quá [toiDa] khoá.
 */
export function nenBao(bang: Map<string, number>, ip: string, bayGio: number, khoangMs = 10_000, toiDa = 5_000): boolean {
  const truoc = bang.get(ip);
  if (truoc !== undefined && bayGio - truoc < khoangMs) return false;
  if (bang.size >= toiDa) {
    for (const [k, t] of bang) if (bayGio - t >= khoangMs) bang.delete(k);
    if (bang.size >= toiDa) bang.clear();
  }
  bang.set(ip, bayGio);
  return true;
}
