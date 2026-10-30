// DO PhongSoc (S6): kênh realtime cho Admin SOC bằng WebSocket hibernation - DO ngủ giữa các tin, socket vẫn mở.
// Một phòng duy nhất ("soc"). Worker đã kiểm Access + vai trò + phiên TRƯỚC khi chuyển request nâng cấp vào đây; DO chỉ
// gắn thẻ vai trò để che PII đúng mức khi phát. Lớp kiểu cũ (không kế thừa `cloudflare:workers`) để vitest chạy ngoài workerd.
import type { Env } from '../moi-truong';
import { ghiLog } from '../mw/ghi-log';
import { laVaiTro, tinChoVaiTro, type TinSoc, type VaiTro } from '../thuan/soc';

const TOI_DA_SOCKET = 200;

type GanSocket = { vaiTro: VaiTro; het: number };

export class PhongSoc {
  constructor(private readonly state: DurableObjectState) {
    this.state.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === '/ws') {
      if (req.headers.get('upgrade')?.toLowerCase() !== 'websocket') return new Response(null, { status: 426 });
      const vaiTro = url.searchParams.get('vaiTro');
      const het = Number(url.searchParams.get('het'));
      if (!laVaiTro(vaiTro) || !Number.isFinite(het)) return new Response(null, { status: 400 });
      if (this.state.getWebSockets().length >= TOI_DA_SOCKET) return new Response(null, { status: 503 });
      const { 0: khach, 1: may } = new WebSocketPair();
      this.state.acceptWebSocket(may, [vaiTro]);
      may.serializeAttachment({ vaiTro, het } satisfies GanSocket);
      return new Response(null, { status: 101, webSocket: khach });
    }
    if (url.pathname === '/phat' && req.method === 'POST') {
      const tin = (await req.json()) as TinSoc;
      return Response.json({ gui: this.phat(tin) });
    }
    return new Response(null, { status: 404 });
  }

  /** Gửi cho mọi socket còn hạn; socket quá hạn phiên tuyệt đối bị đóng (client tự xác thực lại). */
  phat(tin: TinSoc): number {
    const bayGio = Date.now();
    const theoVaiTro = new Map<VaiTro, string>();
    let gui = 0;
    for (const ws of this.state.getWebSockets()) {
      const gan = ws.deserializeAttachment() as GanSocket | null;
      if (!gan || bayGio >= gan.het) {
        ws.close(4401, 'het-phien');
        continue;
      }
      let chuoi = theoVaiTro.get(gan.vaiTro);
      if (!chuoi) {
        chuoi = JSON.stringify(tinChoVaiTro(tin, gan.vaiTro));
        theoVaiTro.set(gan.vaiTro, chuoi);
      }
      try {
        ws.send(chuoi);
        gui++;
      } catch {
        // Socket đang đóng - bỏ qua.
      }
    }
    return gui;
  }

  webSocketMessage(): void {
    // SOC chỉ nhận; tin "ping" được trả tự động không đánh thức DO.
  }

  webSocketClose(ws: WebSocket, ma: number): void {
    try {
      ws.close(ma === 1005 ? 1000 : ma, 'dong');
    } catch {
      // Đã đóng.
    }
  }
}

/** Threat Engine gọi sau mỗi lô có sự kiện mới. Lỗi phát KHÔNG làm hỏng việc xử lý sự kiện. */
export async function phatSoc(env: Env, tin: TinSoc): Promise<void> {
  if (!env.PHONG_SOC) return;
  try {
    const stub = env.PHONG_SOC.get(env.PHONG_SOC.idFromName('soc'));
    await stub.fetch('https://soc/phat', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(tin) });
  } catch (e) {
    ghiLog('warn', 'phat-soc-loi', { loi: String(e) });
  }
}

/** Chuyển request nâng cấp (đã xác thực ở Worker) vào phòng. */
export function vaoPhongSoc(env: Env, req: Request, vaiTro: VaiTro, het: number): Promise<Response> {
  if (!env.PHONG_SOC) return Promise.resolve(new Response(null, { status: 503 }));
  const stub = env.PHONG_SOC.get(env.PHONG_SOC.idFromName('soc'));
  return stub.fetch(`https://soc/ws?vaiTro=${vaiTro}&het=${het}`, { headers: req.headers });
}
