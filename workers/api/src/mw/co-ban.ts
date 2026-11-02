import type { MiddlewareHandler } from 'hono';
import { taoUlid } from '../thuan/dinh-danh';
import { DongHo } from '../thuan/do-tre';
import { ganTieuDe } from '../thuan/tieu-de';
import { LoiApi, phanLoaiLoi, vanDe } from '../thuan/loi';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from './ghi-log';

/** Yêu cầu đầu tiên của isolate (đệm danh sách chặn / khoá / latest đều trống) - tách riêng khi đọc p95. */
let isolateMoi = true;

/** Gắn requestId (cf-ray nếu có, không thì ULID) + IP client; thêm header bảo mật và x-request-id cho mọi phản hồi. */
export const coBan: MiddlewareHandler<MoiTruongHono> = async (c, next) => {
  const ray = c.req.header('cf-ray');
  c.set('requestId', ray && /^[0-9a-f]{16}(-[A-Z]{3})?$/.test(ray) ? ray : taoUlid());
  c.set('ip', c.req.header('cf-connecting-ip') ?? '');
  const dongHo = new DongHo();
  c.set('dongHo', dongHo);
  const lanh = isolateMoi;
  isolateMoi = false;
  const batDau = Date.now();
  await next();
  // Nâng cấp WebSocket (SOC realtime): giữ nguyên Response gốc - dựng lại sẽ mất thuộc tính webSocket.
  if (c.res.status === 101) return;
  const headers = ganTieuDe(c.res.headers);
  headers.set('x-request-id', c.get('requestId'));
  c.res = new Response(c.res.body, { status: c.res.status, statusText: c.res.statusText, headers });
  c.env.SU_KIEN?.writeDataPoint({
    indexes: [c.get('tuyen') ?? 'khac'],
    // blob5 = colo Cloudflare phục vụ (gói Free có thể bị định tuyến xa - giải thích độ trễ D1 / DO).
    blobs: [c.req.method, c.get('tuyen') ?? 'khac', String(c.res.status), c.req.header('cf-ipcountry') ?? '', coloCua(c.req.raw)],
    doubles: dongHo.doubles(Date.now() - batDau, lanh),
  });
};

function coloCua(req: Request): string {
  const colo = (req as { cf?: { colo?: unknown } }).cf?.colo;
  return typeof colo === 'string' ? colo.slice(0, 8) : '';
}

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
