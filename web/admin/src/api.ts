// Gọi Admin API cùng origin (/api/* -> Worker /admin/v1/* qua service binding). Ghi luôn kèm `x-soc: 1` (chống CSRF);
// làm mới nền gắn `x-soc-nen: 1` để server không coi là người dùng đang thao tác (timeout nhàn rỗi).

export class LoiSoc extends Error {
  constructor(
    readonly status: number,
    readonly ma: string | null,
  ) {
    super(ma ?? String(status));
  }
}

export type TuyChonGoi = { body?: unknown; nen?: boolean; signal?: AbortSignal };

export async function goi<T>(duong: string, tc: TuyChonGoi = {}): Promise<T> {
  const h: Record<string, string> = { accept: 'application/json' };
  if (tc.nen) h['x-soc-nen'] = '1';
  let res: Response;
  try {
    res = await fetch(`/api${duong}`, {
      method: tc.body === undefined ? 'GET' : 'POST',
      credentials: 'same-origin',
      headers: tc.body === undefined ? h : { ...h, 'content-type': 'application/json', 'x-soc': '1' },
      ...(tc.body === undefined ? {} : { body: JSON.stringify(tc.body) }),
      ...(tc.signal ? { signal: tc.signal } : {}),
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new LoiSoc(0, 'mang');
  }
  if (!res.ok) {
    const j = (await res.json().catch(() => ({}))) as { code?: string };
    throw new LoiSoc(res.status, j.code ?? null);
  }
  return (await res.json()) as T;
}

// ---------------------------------------------------------------- passkey (base64url <-> ArrayBuffer)
function b64(b: ArrayBuffer): string {
  let s = '';
  for (const x of new Uint8Array(b)) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function tuB64(s: string): ArrayBuffer {
  const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));
  const b = new Uint8Array(nhiPhan.length);
  for (let i = 0; i < nhiPhan.length; i++) b[i] = nhiPhan.charCodeAt(i);
  return b.buffer;
}

type MoTaKhoa = { type: 'public-key'; id: string };
type TuyChonTao = {
  challenge: string;
  rp: { id: string; name: string };
  user: { id: string; name: string; displayName: string };
  pubKeyCredParams: { type: 'public-key'; alg: number }[];
  timeout: number;
  attestation: AttestationConveyancePreference;
  authenticatorSelection: AuthenticatorSelectionCriteria;
  excludeCredentials: MoTaKhoa[];
};
type TuyChonLay = { challenge: string; rpId: string; timeout: number; userVerification: UserVerificationRequirement; allowCredentials: MoTaKhoa[] };

export function hoTroPasskey(): boolean {
  return typeof window !== 'undefined' && 'PublicKeyCredential' in window && !!navigator.credentials;
}

/** Hai bước đăng ký passkey; trả thời điểm hết phiên nếu server mở phiên luôn (passkey đầu tiên). */
export async function dangKyPasskey(): Promise<number | null> {
  const bd = await goi<{ thachThucId: string; tuyChon: TuyChonTao }>('/passkey/dang-ky/bat-dau', { body: {} });
  const t = bd.tuyChon;
  const cred = (await navigator.credentials.create({
    publicKey: {
      ...t,
      challenge: tuB64(t.challenge),
      user: { ...t.user, id: tuB64(t.user.id) },
      excludeCredentials: t.excludeCredentials.map((x) => ({ type: x.type, id: tuB64(x.id) })),
    },
  })) as PublicKeyCredential | null;
  if (!cred) throw new LoiSoc(0, 'huy');
  const r = cred.response as AuthenticatorAttestationResponse;
  const kq = await goi<{ phienHet: number | null }>('/passkey/dang-ky/xong', {
    body: { thachThucId: bd.thachThucId, clientDataJSON: b64(r.clientDataJSON), attestationObject: b64(r.attestationObject) },
  });
  return kq.phienHet;
}

/** Đăng nhập hoặc step-up bằng passkey (server phân biệt theo cookie phiên). */
export async function xacThucPasskey(): Promise<void> {
  const bd = await goi<{ thachThucId: string; tuyChon: TuyChonLay }>('/phien/bat-dau', { body: {} });
  const t = bd.tuyChon;
  const cred = (await navigator.credentials.get({
    publicKey: { ...t, challenge: tuB64(t.challenge), allowCredentials: t.allowCredentials.map((x) => ({ type: x.type, id: tuB64(x.id) })) },
  })) as PublicKeyCredential | null;
  if (!cred) throw new LoiSoc(0, 'huy');
  const r = cred.response as AuthenticatorAssertionResponse;
  await goi('/phien/xong', {
    body: {
      thachThucId: bd.thachThucId,
      id: b64(cred.rawId),
      clientDataJSON: b64(r.clientDataJSON),
      authenticatorData: b64(r.authenticatorData),
      signature: b64(r.signature),
    },
  });
}

/** Lỗi passkey của trình duyệt (huỷ / hết giờ) -> mã ngắn cho thông báo. */
export function maLoiPasskey(e: unknown): 'huy' | 'loi' {
  if (e instanceof DOMException && (e.name === 'NotAllowedError' || e.name === 'AbortError')) return 'huy';
  if (e instanceof LoiSoc && e.ma === 'huy') return 'huy';
  return 'loi';
}

// ---------------------------------------------------------------- kiểu dữ liệu
export type Toi = {
  email: string;
  vaiTro: string;
  quyen: string[];
  soPasskey: number;
  phien: { het: number; stepUpLuc: number; hoatDongLuc: number } | null;
};
export type Dem = { k: string | number | null; n: number };
export type TongQuan = {
  luc: number;
  thietBi: { tong: number; dau: number; mau: number; trangThai: Dem[] };
  heDieuHanh: Dem[];
  phienBan: Dem[];
  quocGia: Dem[];
  suKien24h: { loai: Dem[]; theoGio: Dem[] };
  topIp: Dem[];
  topAsn: Dem[];
  dem: { canhBao?: number; thucThi?: number; choDuyet?: number; khieuNai?: number };
  haTang: { moiTruong: string; build: string; d1Ms: number };
};
export type CanhBao = {
  id: string;
  rule_id: string;
  rule_name: string | null;
  severity: string;
  group_key: string;
  count: number;
  shadow: number;
  first_ts: number;
  last_ts: number;
  status: string;
};
export type DongThietBi = {
  id: string;
  platform: string;
  model: string | null;
  os_version: string | null;
  app_version: string | null;
  build: number | null;
  status: string;
  risk_score: number;
  attestation_level: string;
  country: string | null;
  first_seen: number;
  last_seen: number;
  ip: string | null;
  asn: number | null;
};
export type TinSoc = {
  loai: 'su-kien';
  nhanLuc: number;
  thietBi: string | null;
  ip: string | null;
  quocGia: string | null;
  ds: { type: string; severity: string }[];
  kichHoat: string[];
  trangThai: string | null;
};
