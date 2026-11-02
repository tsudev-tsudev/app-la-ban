import type { VaiTro } from './thuan/soc';
import type { Context } from 'hono';
import type { DongHo } from './thuan/do-tre';

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
  /** R3c (Q52): giới hạn theo IP cho route công khai chỉ đọc (/v1/config, /v1/web/cau-hinh) - không ghi D1. */
  RL_DOC_CONG_KHAI?: RateLimit;
  /** A7a: bucket chứa tile / glyph bản đồ (`ban-do/`), dùng chung prod + staging (dữ liệu công khai). */
  BAN_DO?: R2Bucket;
  /** A7a: giới hạn riêng theo IP cho /ban-do (tải vùng offline = hàng nghìn tile). */
  RL_BAN_DO?: RateLimit;
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
  /** Admin SOC (S6): team Zero Trust (`<team>.cloudflareaccess.com`) + AUD của ứng dụng Access (dấu phẩy). Thiếu -> /admin 503. */
  ACCESS_TEAM?: string;
  ACCESS_AUD?: string;
  /** Origin của giao diện SOC (dấu phẩy) - kiểm CSRF + rpId passkey. */
  SOC_NGUON?: string;
  /** Common name service token Access được coi là danh tính `svc:<cn>` (CHỈ staging, thử e2e). Rỗng = không nhận. */
  ACCESS_DICH_VU?: string;
  /** Cảnh báo Telegram (S7a, `wrangler secret`): token bot + chat id. Thiếu một trong hai -> không gửi. */
  TELEGRAM_BOT_TOKEN?: string;
  TELEGRAM_CHAT_ID?: string;
  /**
   * Remote Config ký số từ SOC (S7c2, `wrangler secret`): khoá bí mật Ed25519 PKCS8 PEM kid app-1 / web-1. Thiếu hoặc
   * không khớp khoá công khai app / web đang tin -> SOC chỉ xem, duyệt trả 503 (dùng công cụ ngoại tuyến).
   */
  KHOA_KY_APP?: string;
  KHOA_KY_WEB?: string;
  /** Khiếu nại (S7c1): bí mật Turnstile (`wrangler secret`; thiếu -> 503) + hostname hợp lệ (dấu phẩy, rỗng = không kiểm). */
  TURNSTILE_SECRET?: string;
  TURNSTILE_TEN_MIEN?: string;
  /** Sao lưu D1 (S10a): khoá CÔNG KHAI RSA-OAEP 4096 (SPKI base64, biến thường - không bí mật). Thiếu -> bỏ sao lưu. */
  KHOA_SAO_LUU?: string;
  /** Phát hiện đột biến (S10a): token CHỈ quyền Account Analytics Read (`wrangler secret`) + tên dataset AE. Thiếu -> bỏ. */
  CF_AE_TOKEN?: string;
  AE_BANG?: string;
};

export type BienYeuCau = {
  requestId: string;
  /** R3c: thời gian chờ I/O theo bước -> doubles AE (mw/co-ban.ts). */
  dongHo?: DongHo;
  /** R3c: kết quả kiểm chặn IP / ASN (mw/chan.ts) - route có xác thực chờ song song với truy vấn phiên. */
  choChan?: Promise<boolean>;
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
  /** Admin SOC (S6), đặt bởi middleware src/admin/xac-thuc.ts. */
  quanTri?: { email: string; vaiTro: VaiTro };
  phienSoc?: { idHash: string; stepUpAt: number; expiresAt: number };
};

export type MoiTruongHono = { Bindings: Env; Variables: BienYeuCau };
export type Ngu = Context<MoiTruongHono>;
