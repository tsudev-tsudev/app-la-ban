// SEC-API API-04: lỗi RFC 7807 CHUNG CHUNG cho client; chi tiết (nguyên nhân, đường dẫn trường...) chỉ đi vào log.

export type VanDe = {
  type: 'about:blank';
  title: string;
  status: number;
  /** Mã ngắn ổn định để app dịch thông báo (không lộ chi tiết nội bộ). */
  code?: string;
  /** Mã yêu cầu để người dùng báo lỗi / khiếu nại, khớp với log. */
  requestId?: string;
};

const TIEU_DE: Readonly<Record<number, string>> = Object.freeze({
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  409: 'Conflict',
  413: 'Content Too Large',
  415: 'Unsupported Media Type',
  422: 'Unprocessable Content',
  428: 'Precondition Required',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  503: 'Service Unavailable',
});

export function tieuDeHttp(status: number): string {
  return TIEU_DE[status] ?? (status >= 500 ? 'Internal Server Error' : 'Bad Request');
}

/** Lỗi có chủ đích trong handler / middleware. `chiTiet` CHỈ ghi log, không trả client. */
export class LoiApi extends Error {
  readonly status: number;
  readonly ma: string;
  readonly chiTiet: unknown;
  readonly tieuDePhu: Readonly<Record<string, string>>;

  constructor(status: number, ma: string, chiTiet?: unknown, tieuDePhu: Record<string, string> = {}) {
    super(ma);
    this.name = 'LoiApi';
    this.status = status;
    this.ma = ma;
    this.chiTiet = chiTiet;
    this.tieuDePhu = Object.freeze({ ...tieuDePhu });
  }
}

/** Thân problem+json cho [status]. Lỗi 5xx không bao giờ kèm `code` (tránh lộ loại sự cố). */
export function vanDe(status: number, ma?: string, requestId?: string): VanDe {
  const kq: VanDe = { type: 'about:blank', title: tieuDeHttp(status), status };
  if (ma && status < 500) kq.code = ma;
  if (requestId) kq.requestId = requestId;
  return kq;
}

/** Chuẩn hoá lỗi bất kỳ -> (status, mã, tiêu đề phụ). Lỗi lạ -> 500 `noi-bo`. */
export function phanLoaiLoi(loi: unknown): { status: number; ma: string; tieuDePhu: Readonly<Record<string, string>> } {
  if (loi instanceof LoiApi) return { status: loi.status, ma: loi.ma, tieuDePhu: loi.tieuDePhu };
  return { status: 500, ma: 'noi-bo', tieuDePhu: {} };
}
