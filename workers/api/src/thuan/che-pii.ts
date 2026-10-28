// SEC-DATA DAT-01: che PII trong log; rút gọn IP (IPv4 /24, IPv6 /48) khi hết hạn lưu chi tiết.

const KHOA_NHAY_CAM = /(authorization|cookie|token|secret|password|passwd|signature|^sig$|public_key|refresh|attest|nonce|email|phone|lat|lon|lng|location)/i;

/** IPv4 -> a.b.c.0/24, IPv6 -> 3 nhóm đầu ::/48. Chuỗi không phải IP -> 'khong-ro'. */
export function rutGonIp(ip: string | null | undefined): string {
  if (!ip) return 'khong-ro';
  const v4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(ip);
  if (v4) {
    const so = v4.slice(1, 4).map(Number);
    if (so.some((x) => x > 255) || Number(v4[4]) > 255) return 'khong-ro';
    return `${so.join('.')}.0/24`;
  }
  if (ip.includes(':') && /^[0-9a-fA-F:.]+$/.test(ip)) {
    const [dau = '', sau] = ip.split('::');
    const nhomDau = dau ? dau.split(':') : [];
    const nhomSau = sau !== undefined && sau !== '' ? sau.split(':') : [];
    if (sau === undefined && nhomDau.length !== 8) return 'khong-ro';
    const thieu = 8 - nhomDau.length - nhomSau.length;
    if (thieu < 0) return 'khong-ro';
    const du = [...nhomDau, ...Array<string>(thieu).fill('0'), ...nhomSau];
    const ba = du.slice(0, 3).map((n) => (n === '' ? '0' : n.toLowerCase().replace(/^0+(?=.)/, '')));
    return `${ba.join(':')}::/48`;
  }
  return 'khong-ro';
}

/** Bản sao [giaTri] với trường nhạy cảm thay bằng '[che]' và IP rút gọn - dùng trước MỌI lệnh ghi log. */
export function cheLog(giaTri: unknown, sau = 0): unknown {
  if (sau > 6) return '[sau]';
  if (Array.isArray(giaTri)) return giaTri.slice(0, 50).map((v) => cheLog(v, sau + 1));
  if (giaTri === null || typeof giaTri !== 'object') return giaTri;
  const kq: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(giaTri as Record<string, unknown>)) {
    if (/^ip$|_ip$|^ip_/i.test(k) && typeof v === 'string') kq[k] = rutGonIp(v);
    else if (KHOA_NHAY_CAM.test(k)) kq[k] = '[che]';
    else kq[k] = cheLog(v, sau + 1);
  }
  return kq;
}
