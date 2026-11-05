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

const CHO_KHIEN_TOI_DA_MS = 3000;

/**
 * S11 (Q58, SH-07): chỉ gọi API sau khi khiên (/js/khien.js) kiểm xong lần đầu (`data-khien-san`) và không đang nghi
 * (`data-khien-nghi`) - dữ liệu thật không xuống trình duyệt đang bị soi. Khiên không nạp được (mạng / bị chặn) thì sau 3
 * giây vẫn gọi: chốt chặn thật ở Worker (từ chối 10 phút theo IP sau tín hiệu khiên).
 */
export async function choKhien(goc: HTMLElement = document.documentElement, toiDaMs = CHO_KHIEN_TOI_DA_MS): Promise<void> {
  if (!goc.hasAttribute('data-khien-san')) {
    await new Promise<void>((xong) => {
      const quan = new MutationObserver(() => {
        if (goc.hasAttribute('data-khien-san')) ket();
      });
      const hen = setTimeout(ket, toiDaMs);
      function ket() {
        quan.disconnect();
        clearTimeout(hen);
        xong();
      }
      quan.observe(goc, { attributes: true, attributeFilter: ['data-khien-san'] });
    });
  }
  if (goc.hasAttribute('data-khien-nghi')) throw new LoiSoc(0, 'khien-nghi');
}

export async function goi<T>(duong: string, tc: TuyChonGoi = {}): Promise<T> {
  await choKhien();
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

/**
 * Ghi cần step-up (S7a): server trả 401 `can-step-up` -> hỏi passkey (báo trước qua [truocPasskey]) rồi gửi lại ĐÚNG một
 * lần. Lỗi khác ném nguyên trạng.
 */
export async function goiStepUp<T>(duong: string, body: unknown, truocPasskey?: () => void): Promise<T> {
  try {
    return await goi<T>(duong, { body });
  } catch (loi) {
    if (!(loi instanceof LoiSoc && loi.ma === 'can-step-up')) throw loi;
    truocPasskey?.();
    await xacThucPasskey();
    return goi<T>(duong, { body });
  }
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
  moiTruong?: string;
  quyen: string[];
  soPasskey: number;
  /** Cài đặt SOC toàn hệ thống (S7b; server cũ không gửi -> mặc định). */
  caiDat?: CaiDatSoc;
  phien: { het: number; stepUpLuc: number; hoatDongLuc: number } | null;
};
export type Dem = { k: string | number | null; n: number };
export type TongQuan = {
  luc: number;
  thietBi: { tong: number; dau: number; mau: number; trangThai: Dem[] };
  heDieuHanh: Dem[];
  phienBan: Dem[];
  quocGia: Dem[];
  ungDung?: Dem[];
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
  status: 'open' | 'ack' | 'closed';
  assignee: string | null;
  resolution: string | null;
  updated_at: number | null;
  updated_by: string | null;
};
export type DemCanhBao = { mo?: number | null; ack?: number | null; chuaGiao?: number | null; cuaToi?: number | null; cao?: number | null };
export type DsCanhBao = { ds: CanhBao[]; tiepTheo: string | null; dem: DemCanhBao; ms: number };
export type GhiCanhBao = { id: string; actor: string; kind: 'note' | 'status' | 'assign'; body: string; ts: number };
export type ChiTietCanhBao = {
  canhBao: CanhBao & { notified_at: number | null };
  dich: { loai: 'device' | 'ip' | 'cidr' | 'khac'; giaTri: string | null };
  rule: { id: string; name: string; condition: unknown; window: number; threshold: number; action: string; enabled: number; version: number } | null;
  lanKichHoat: { ts: number; shadow: number; rule_version: number; actions: string }[];
  dongThoiGian: GhiCanhBao[];
  thietBi: { id: string; status: string; risk_score: number; model: string | null; app_version: string | null; last_seen: number } | null;
  telegram: boolean;
};
export type Passkey = { id: string; name: string | null; alg: number; rp_id: string; created_at: number; last_used: number | null };
export type DongThietBi = {
  id: string;
  platform: string;
  package_name?: string | null;
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

// ---------------------------------------------------------------- S7b: rule, can thiệp, cấu hình, cài đặt SOC
export type CaiDatSoc = { thuyVan: { bat: boolean; mucToiThieu: 'nhe' | 'chuan' }; epCheKhiRoi: boolean };
export type DieuKienLuat = { event: string[]; group_by: 'device' | 'ip' | 'cidr24'; count: 'events' | 'devices' | 'types' };
export type Luat = {
  id: string;
  ten: string;
  phienBan: number;
  hong: boolean;
  dieuKien: DieuKienLuat | null;
  cuaSo: number;
  nguong: number;
  hanhDong: string[];
  bat: boolean;
  cheDo: 'active' | 'shadow';
  shadowTu: number | null;
  coTheBat: boolean;
  batDuocLuc: number | null;
  suaBoi: string | null;
  kichHoat7n?: { that: number; shadow: number; cuoi: number | null };
};
export type ThanLuat = { ten: string; dieuKien: DieuKienLuat; cuaSo: number; nguong: number; hanhDong: string[] };
export type PhienBanLuat = {
  version: number;
  name: string;
  condition: DieuKienLuat | null;
  window: number;
  threshold: number;
  action: string[] | null;
  note: string | null;
  created_by: string;
  created_at: number;
};
export type ChiTietLuat = { luat: Luat; phienBan: PhienBanLuat[]; lanKichHoat: { ts: number; shadow: number; rule_version: number; group_key: string; actions: string }[] };
export type KetQuaMoPhong = {
  tu: number;
  den: number;
  soSuKien: number;
  catBot: boolean;
  soLanKichHoat: number;
  soNhom: number;
  theoNgay: { ngay: number; n: number }[];
  topNhom: { khoa: string; n: number }[];
  hienTai: { that: number | null; shadow: number | null } | null;
  ms: number;
};
export type ThucThi = {
  id: string;
  target_type: 'device' | 'ip' | 'cidr' | 'asn';
  target_value: string;
  action: string;
  reason: string;
  created_by: string;
  approved_by: string | null;
  created_at: number;
  expires_at: number;
  revoked_at: number | null;
  source: 'auto' | 'manual';
  pending_approval: number;
  rule_id: string | null;
  level: number;
};
export type DsThucThi = { ds: ThucThi[]; tiepTheo: string | null; dem: { hieuLuc?: number | null; choDuyet?: number | null; yeuCau?: number | null }; underAttack: boolean };
export type YeuCauDuyet = {
  id: string;
  kind: 'chan' | 'go-chan';
  payload: { dich?: { loai: string; giaTri: string }[]; hanhDong?: string; thoiHan?: string; ids?: string[]; lyDo: string };
  reason: string;
  created_by: string;
  created_at: number;
  expires_at: number;
  status: 'pending' | 'approved' | 'rejected' | 'cancelled';
  decided_by: string | null;
  decided_at: number | null;
  decision_note: string | null;
};
export type CauHinhNguyCo = {
  diem: Record<string, number>;
  nguong: { suspicious: number; restricted: number; banned: number };
  hoiPhuc: { diemMoiTuan: number; san: number };
  ttlBac: number[];
  underAttack: boolean;
  diemToiDa: number;
};
// S7c1
export type KhieuNai = {
  id: string;
  device_id: string;
  ref: string;
  enforcement_id: string | null;
  message: string;
  status: 'open' | 'approved' | 'rejected';
  reviewed_by: string | null;
  reviewed_at: number | null;
  decision_note: string | null;
  ts: number;
  contact: string | null;
  lang: string | null;
  device_status: string;
  model: string | null;
  app_version: string | null;
  risk_score: number;
  e_action: string | null;
  e_reason: string | null;
  e_source: string | null;
  e_created_at: number | null;
  e_expires_at: number | null;
  e_revoked_at: number | null;
};
export type DsKhieuNai = { ds: KhieuNai[]; tiepTheo: string | null; dem: Record<string, number> };
export type DongAudit = {
  so: number;
  id: string;
  actor: string;
  action: string;
  target: string | null;
  before: unknown;
  after: unknown;
  ip: string | null;
  ts: number;
  hash_prev: string;
  hash_self: string;
};
export type KetQuaKiemAudit = { nguyenVen: boolean; soDongDung: number; dongLoi: { so: number; id: string; ts: number } | null; ms: number };

// ---------------------------------------------------------------- S7c2: báo cáo + Remote Config
export type DemK = { k: string | number | null; n: number };
export type TongHop = {
  khoang: { tu: number; den: number };
  taoLuc: number;
  moiTruong: string;
  thietBi: { tong: number; moi: number; hoatDong: number; trangThai: DemK[] };
  suKien: { mucDo: DemK[]; loai: DemK[]; theoNgay: { k: string; n: number }[] };
  thucThi: { theoLoai: { hanhDong: string; nguon: string; n: number }[]; goTrongKy: number; hieuLuc: number };
  khieuNai: { k: string; n: number; tbXuLyMs: number | null }[];
  canhBao: { mucDo: DemK[]; ketLuan: DemK[] };
  rule: DemK[];
  audit: DemK[];
  cauHinh: DemK[];
};

export type DeXuatApp = { toiThieu: number; khuyenNghi: number; tat: string[]; pin: string[]; ngay: number };
export type DeXuatWeb = { landing: string; admin: string; ngay: number };
export type GoiCauHinh<D> = { noiDung: Record<string, unknown> | null; chuKyDung: boolean; deXuat: D };
export type YeuCauCauHinh = {
  id: string;
  target: 'app' | 'web';
  payload: DeXuatApp | DeXuatWeb;
  reason: string;
  created_by: string;
  created_at: number;
  expires_at: number;
  status: 'pending' | 'approved' | 'rejected' | 'cancelled';
  decided_by: string | null;
  decided_at: number | null;
  decision_note: string | null;
  hetHan: boolean;
};
export type CauHinhTuXa = {
  app: GoiCauHinh<DeXuatApp>;
  web: GoiCauHinh<DeXuatWeb>;
  coKhoa: { app: boolean; web: boolean };
  banMoi: number | null;
  gocDongGoi: { ten: string; pin: string; het: string }[];
  tinhNang: string[];
  yeuCau: YeuCauCauHinh[];
  lichSu: { id: string; target: 'app' | 'web'; issued_at: number; content: Record<string, unknown>; created_by: string; approved_by: string }[];
  toi: string;
};

/** Tên tệp từ Content-Disposition (server chỉ dùng ASCII). */
export function tenTepTai(cd: string | null, macDinh: string): string {
  const m = /filename="([A-Za-z0-9._-]{1,120})"/.exec(cd ?? '');
  return m?.[1] ?? macDinh;
}

async function xuatMotLan(body: unknown): Promise<{ blob: Blob; ten: string; soDong: number; biCat: boolean }> {
  let res: Response;
  try {
    res = await fetch('/api/bao-cao/xuat', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { accept: 'text/csv', 'content-type': 'application/json', 'x-soc': '1' },
      body: JSON.stringify(body),
    });
  } catch {
    throw new LoiSoc(0, 'mang');
  }
  if (!res.ok) {
    const j = (await res.json().catch(() => ({}))) as { code?: string };
    throw new LoiSoc(res.status, j.code ?? null);
  }
  return {
    blob: await res.blob(),
    ten: tenTepTai(res.headers.get('content-disposition'), 'la-ban.csv'),
    soDong: Number(res.headers.get('x-so-dong') ?? '0'),
    biCat: res.headers.get('x-bi-cat') === '1',
  };
}

/** Xuất CSV (S7c2): server đòi passkey gần đây -> hỏi passkey rồi gửi lại, như [goiStepUp]. */
export async function xuatCsv(body: unknown, truocPasskey?: () => void): Promise<{ blob: Blob; ten: string; soDong: number; biCat: boolean }> {
  try {
    return await xuatMotLan(body);
  } catch (loi) {
    if (!(loi instanceof LoiSoc && loi.ma === 'can-step-up')) throw loi;
    truocPasskey?.();
    await xacThucPasskey();
    return xuatMotLan(body);
  }
}
