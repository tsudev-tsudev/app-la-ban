// Phân tích IP / CIDR (IPv4 + IPv6) và so khớp - dùng cho allow-list, chặn IP / dải, đồng bộ Cloudflare Lists.

export type DiaChi = { v: 4 | 6; so: bigint };

export function phanTichIp(ip: string): DiaChi | null {
  const v4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(ip);
  if (v4) {
    const p = v4.slice(1).map(Number);
    if (p.some((x) => x > 255) || v4.slice(1).some((s) => s.length > 1 && s.startsWith('0'))) return null;
    return { v: 4, so: p.reduce((a, x) => (a << 8n) | BigInt(x), 0n) };
  }
  if (!ip.includes(':') || !/^[0-9a-fA-F:]+$/.test(ip)) return null;
  const phan = ip.split('::');
  if (phan.length > 2) return null;
  const dau = phan[0] ? phan[0].split(':') : [];
  const sau = phan.length === 2 && phan[1] ? phan[1].split(':') : [];
  const thieu = 8 - dau.length - sau.length;
  if ((phan.length === 1 && thieu !== 0) || (phan.length === 2 && thieu < 1)) return null;
  const nhom = [...dau, ...Array<string>(phan.length === 2 ? thieu : 0).fill('0'), ...sau];
  if (nhom.some((n) => !/^[0-9a-fA-F]{1,4}$/.test(n))) return null;
  return { v: 6, so: nhom.reduce((a, n) => (a << 16n) | BigInt(parseInt(n, 16)), 0n) };
}

export type Dai = { v: 4 | 6; goc: bigint; doDai: number };

export function phanTichCidr(cidr: string): Dai | null {
  const [dc, dd] = cidr.split('/');
  const ip = phanTichIp(dc ?? '');
  if (!ip) return null;
  const toiDa = ip.v === 4 ? 32 : 128;
  const doDai = dd === undefined ? toiDa : /^\d{1,3}$/.test(dd) ? Number(dd) : -1;
  if (doDai < 0 || doDai > toiDa) return null;
  return { v: ip.v, goc: ip.so & matNa(toiDa, doDai), doDai };
}

export function ipTrongDai(ip: string, cidr: string): boolean {
  const a = phanTichIp(ip);
  const d = phanTichCidr(cidr);
  if (!a || !d || a.v !== d.v) return false;
  return (a.so & matNa(a.v === 4 ? 32 : 128, d.doDai)) === d.goc;
}

/** Dạng chuẩn để so trùng (IPv6 viết gọn khác nhau vẫn ra một chuỗi). Không phải IP -> null. */
export function chuanHoaIp(ip: string): string | null {
  const a = phanTichIp(ip);
  if (!a) return null;
  if (a.v === 4) return ip;
  const nhom: string[] = [];
  for (let i = 7; i >= 0; i--) nhom.push(((a.so >> BigInt(i * 16)) & 0xffffn).toString(16));
  return nhom.join(':');
}

/** Cloudflare Lists nhận IPv4 /8-/32 và IPv6 /12-/64 (IPv6 đơn lẻ phải gửi dạng /64). Ngoài khoảng -> null. */
export function dangChoCloudflare(giaTri: string): string | null {
  const d = phanTichCidr(giaTri);
  if (!d) return null;
  if (d.v === 4) {
    if (d.doDai < 8) return null;
    const s = giaTriDai(d);
    return d.doDai === 32 ? s.slice(0, s.indexOf('/')) : s;
  }
  if (d.doDai < 12) return null;
  const doDai = Math.min(d.doDai, 64);
  return giaTriDai({ v: 6, doDai, goc: d.goc & matNa(128, doDai) });
}

function matNa(toiDa: number, doDai: number): bigint {
  return ((1n << BigInt(doDai)) - 1n) << BigInt(toiDa - doDai);
}

function giaTriDai(d: Dai): string {
  if (d.v === 4) {
    const p = [24n, 16n, 8n, 0n].map((s) => ((d.goc >> s) & 0xffn).toString());
    return `${p.join('.')}/${d.doDai}`;
  }
  const nhom: string[] = [];
  for (let i = 7; i >= 0; i--) nhom.push(((d.goc >> BigInt(i * 16)) & 0xffffn).toString(16));
  return `${nhom.join(':')}/${d.doDai}`;
}
