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
};

export type BienYeuCau = {
  requestId: string;
  ip: string;
  /** Phạm vi khoá idempotency: thiết bị / phiên khi đã xác thực (S2), mặc định theo IP. */
  phamViIdem?: string;
  body?: unknown;
  /** Mẫu đường dẫn của route đã khớp (cho Analytics Engine / log), đặt bởi BoTuyen. */
  tuyen?: string;
};

export type MoiTruongHono = { Bindings: Env; Variables: BienYeuCau };
export type Ngu = Context<MoiTruongHono>;
