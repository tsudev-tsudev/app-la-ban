// Bộ đăng ký route: MỘT định nghĩa sinh cả chuỗi middleware (giới hạn, đọc body, idempotency) lẫn tài liệu OpenAPI
// (src/openapi.ts - chỉ test / công cụ import, không vào bản deploy; SEC-API API-05).
import type { Hono, MiddlewareHandler } from 'hono';
import { z } from 'zod';
import { BODY_TOI_DA, laJson, phanTichBody } from './thuan/dau-vao';
import type { LuatGioiHan } from './thuan/gioi-han';
import { LoiApi } from './thuan/loi';
import type { MoiTruongHono, Ngu } from './moi-truong';
import { gioiHanRoute } from './mw/gioi-han';
import { idempotency } from './mw/idempotency';

export type DinhNghiaTuyen<B extends z.ZodType = z.ZodType, P extends z.ZodType = z.ZodType> = {
  phuongThuc: 'get' | 'post';
  /** Đường dẫn kiểu Hono (`/v1/x/:id`). */
  duongDan: string;
  tomTat: string;
  /** Schema body (POST). Phải là z.strictObject để trường lạ bị từ chối. */
  body?: B;
  phanHoi: P;
  maThanhCong?: 200 | 201 | 202;
  gioiHan?: LuatGioiHan[];
  /** POST mặc định bắt buộc Idempotency-Key; đặt false cho POST không ghi dữ liệu. */
  idempotent?: boolean;
  bodyToiDa?: number;
};

export type XuLy<B extends z.ZodType> = (c: Ngu, body: z.infer<B>) => Response | Promise<Response>;

/** Đọc + kiểm body JSON: 415 sai loại, 413 quá lớn (kiểm Content-Length trước khi đọc), 400/422 từ phanTichBody. */
export function docBody(schema: z.ZodType, toiDa = BODY_TOI_DA): MiddlewareHandler<MoiTruongHono> {
  return async (c, next) => {
    if (!laJson(c.req.header('content-type'))) throw new LoiApi(415, 'can-json');
    const doDai = Number(c.req.header('content-length') ?? '0');
    if (doDai > toiDa) throw new LoiApi(413, 'qua-lon');
    c.set('body', phanTichBody(await c.req.text(), schema, { toiDa }));
    await next();
  };
}

export class BoTuyen {
  readonly ds: DinhNghiaTuyen[] = [];

  constructor(private readonly app: Hono<MoiTruongHono>) {}

  dangKy<B extends z.ZodType, P extends z.ZodType>(d: DinhNghiaTuyen<B, P>, xuLy: XuLy<B>): void {
    if (d.phuongThuc === 'post' && !d.body) throw new Error(`${d.duongDan}: POST cần schema body`);
    this.ds.push(d as unknown as DinhNghiaTuyen);
    const chuoi: MiddlewareHandler<MoiTruongHono>[] = [
      async (c, next) => {
        c.set('tuyen', d.duongDan);
        await next();
      },
      gioiHanRoute(d.gioiHan ?? []),
    ];
    if (d.body) chuoi.push(docBody(d.body, d.bodyToiDa));
    if (d.phuongThuc === 'post' && d.idempotent !== false) chuoi.push(idempotency);
    const cuoi: MiddlewareHandler<MoiTruongHono> = async (c) => xuLy(c, c.get('body') as z.infer<B>);
    // Ép kiểu: overload của Hono.on không nhận mảng handler trải ra (...chuoi).
    const dangKyHono = this.app.on.bind(this.app) as unknown as (
      m: string,
      p: string,
      ...h: MiddlewareHandler<MoiTruongHono>[]
    ) => void;
    dangKyHono(d.phuongThuc.toUpperCase(), d.duongDan, ...chuoi, cuoi);
  }
}
