// Danh tính người xem cho watermark (SH-04): Cloudflare Access phục vụ `/cdn-cgi/access/get-identity` trên CHÍNH origin
// admin khi đã đăng nhập (S6). Chưa có Access -> null, watermark ghi "chưa xác thực".
import { useEffect, useState } from 'react';

const MAU_EMAIL = /^[^\s@]{1,64}@[^\s@]{1,190}$/;

export function emailTuDanhTinh(x: unknown): string | null {
  if (typeof x !== 'object' || x === null) return null;
  const e = (x as Record<string, unknown>).email;
  return typeof e === 'string' && MAU_EMAIL.test(e) ? e : null;
}

export function useEmailNguoiXem(): string | null {
  const [email, datEmail] = useState<string | null>(null);
  useEffect(() => {
    const huy = new AbortController();
    fetch('/cdn-cgi/access/get-identity', { credentials: 'same-origin', signal: huy.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((j: unknown) => datEmail(emailTuDanhTinh(j)))
      .catch(() => undefined);
    return () => huy.abort();
  }, []);
  return email;
}
