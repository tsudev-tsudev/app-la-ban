import type { Context } from 'hono';

// Binding khai báo ở wrangler.toml. Tuỳ chọn (?) để test đơn vị dựng được app thiếu binding; middleware xử lý khi thiếu.
export type Env = {
  MOI_TRUONG: string;
  BAN_BUILD?: string;
  DB?: D1Database;
  CAU_HINH?: KVNamespace;
  CDN?: R2Bucket;
  NHAT_KY?: R2Bucket;
  KHO_NONCE?: DurableObjectNamespace;
  GIOI_HAN_TOC?: DurableObjectNamespace;
  PHONG_SOC?: DurableObjectNamespace;
  SU_KIEN?: AnalyticsEngineDataset;
  /** Rate Limiting binding: lớp thô theo IP trước mọi route. */
  RL_IP?: RateLimit;
  /** Đồng bộ chặn IP lên Cloudflare List (chỉ prod): token chỉ quyền Account Filter Lists Edit (wrangler secret). */
  CF_LISTS_TOKEN?: string;
  CF_ACCOUNT_ID?: string;
  CF_LIST_ID?: string;
  /** HMAC ký URL tài nguyên `/v1/tn/*` (SH-05, wrangler secret). Thiếu -> route trả 503. */
  KHOA_URL_KY?: string;
  /** Khoá ký phiên ES256 (JWK riêng tư có kid, hoặc mảng để xoay - wrangler secret). Thiếu -> route phiên trả 503. */
  KHOA_PHIEN?: string;
  /** JSON khoá service account giải mã Play Integrity (wrangler secret). Thiếu -> attestation 'unverified'. */
  PLAY_INTEGRITY_SA_JSON?: string;
  /** Gói Android được chấp nhận, cách nhau dấu phẩy (prod: chỉ com.tsudev.laban). */
  PI_GOI?: string;
  /** SHA-256 chứng chỉ ký app (hex, dấu phẩy). Rỗng = không kiểm (staging nhận bản ký debug). */
  PI_CHUNG_CHI?: string;
};

export type BienYeuCau = {
  requestId: string;
  ip: string;
  /** Phạm vi khoá idempotency: thiết bị / phiên khi đã xác thực (S2), mặc định theo IP. */
  phamViIdem?: string;
  body?: unknown;
  /** Mẫu đường dẫn của route đã khớp (cho Analytics Engine / log), đặt bởi BoTuyen. */
  tuyen?: string;
  /** Đặt bởi middleware xacThuc (S2). */
  thietBi?: string;
  phien?: string;
  mucTin?: string;
  /** Trạng thái thiết bị (clean / suspicious / restricted / banned), đặt bởi xacThuc. */
  trangThai?: string;
};

export type MoiTruongHono = { Bindings: Env; Variables: BienYeuCau };
export type Ngu = Context<MoiTruongHono>;
