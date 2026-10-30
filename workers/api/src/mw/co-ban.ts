import type { MiddlewareHandler } from 'hono';
import { taoUlid } from '../thuan/dinh-danh';
import { ganTieuDe } from '../thuan/tieu-de';
import { LoiApi, phanLoaiLoi, vanDe } from '../thuan/loi';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from './ghi-log';

/** Gắn requestId (cf-ray nếu có, không thì ULID) + IP client; thêm header bảo mật và x-request-id cho mọi phản hồi. */
export const coBan: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const ray = c.req.header('cf-ray');
  c.set('requestId', ray && /^[0-9a-f]{16}(-[A-Z]{3})?$/.test(ray) ? ray : taoUlid());
  c.set('ip', c.req.header('cf-connecting-ip') ?? '');
  const batDau = Date.now();
  await next();
  // Nâng cấp WebSocket (SOC realtime): giữ nguyên Response gốc - dựng lại sẽ mất thuộc tính webSocket.
  if (c.res.status === 101) return;
  const headers = ganTieuDe(c.res.headers);
  headers.set('x-request-id', c.get('requestId'));
  c.res = new Response(c.res.body, { status: c.res.status, statusText: c.res.statusText, headers });
  c.env.SU_KIEN?.writeDataPoint({
    indexes: [c.get('tuyen') ?? 'khac'],
    blobs: [c.req.method, c.get('tuyen') ?? 'khac', String(c.res.status), c.req.header('cf-ipcountry') ?? ''],
    doubles: [Date.now() - batDau],
  });
};

/** Trả problem+json với header phụ (Retry-After...). */
export function traVanDe(c: Ngu, status: number, ma?: string, tieuDePhu: Readonly<Record<string, string>> = {}): Response {
  return c.newResponse(JSON.stringify(vanDe(status, ma, c.get('requestId'))), status as 400, {
    'content-type': 'application/problem+json',
    ...tieuDePhu,
  });
}

/** app.onError: lỗi có chủ đích -> mã của nó; lỗi lạ -> 500 chung. Chi tiết + stack CHỈ vào log. */
export function xuLyLoi(loi: Error, c: Ngu): Response {
  const { status, ma, tieuDePhu } = phanLoaiLoi(loi);
  ghiLog(status >= 500 ? 'error' : 'warn', 'loi-yeu-cau', {
    requestId: c.get('requestId'),
    route: c.get('tuyen') ?? c.req.path.slice(0, 64),
    status,
    ma,
    chiTiet: loi instanceof LoiApi ? loi.chiTiet : { ten: loi.name, thongDiep: loi.message, stack: loi.stack },
  });
  return traVanDe(c, status, ma, tieuDePhu);
}
