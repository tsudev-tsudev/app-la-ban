// DO KhoNonce: mỗi nonce dùng đúng một lần trong hạn (chống replay). Worker chọn instance theo phạm vi (thiết bị / phiên)
// bằng idFromName -> mỗi instance nhỏ, thao tác tuần tự (input gate) nên không có tranh chấp.
// Lớp kiểu cũ (không kế thừa `cloudflare:workers`) để vitest chạy được ngoài workerd.
import { dungNonce, laNonceHopLe, NONCE_TTL_MAC_DINH_MS } from '../thuan/nonce';

type KhoLuu = Pick<DurableObjectStorage, 'get' | 'put' | 'delete' | 'list' | 'getAlarm' | 'setAlarm'>;

function json(status: number, du: unknown): Response {
  return new Response(JSON.stringify(du), { status, headers: { 'content-type': 'application/json' } });
}

export class KhoNonce {
  private readonly kho: KhoLuu;
  private readonly bayGio: () => number;

  constructor(state: { storage: KhoLuu }, _env?: unknown, bayGio: () => number = Date.now) {
    this.kho = state.storage;
    this.bayGio = bayGio;
  }

  /**
   * POST {nonce, ttlMs?} -> 200 {ok:true} lần đầu, 409 {ok:false} nếu đã dùng và còn hạn.
   * POST /cap {nonce, ttlMs?}: lưu thách thức do server cấp (S2). POST /dung {nonce}: thách thức còn hạn -> xoá, 200;
   * không có / hết hạn / đã dùng -> 409.
   */
  async fetch(req: Request): Promise<Response> {
    if (req.method !== 'POST') return json(405, { ok: false });
    const du = (await req.json().catch(() => null)) as { nonce?: unknown; ttlMs?: unknown } | null;
    if (!du || !laNonceHopLe(du.nonce)) return json(400, { ok: false });
    const ttl = typeof du.ttlMs === 'number' && Number.isFinite(du.ttlMs) ? du.ttlMs : NONCE_TTL_MAC_DINH_MS;
    const bayGio = this.bayGio();
    const duong = new URL(req.url).pathname;
    if (duong === '/dung') {
      const hetHanThach = await this.kho.get<number>(`c:${du.nonce}`);
      if (hetHanThach === undefined) return json(409, { ok: false });
      await this.kho.delete(`c:${du.nonce}`);
      return json(hetHanThach > bayGio ? 200 : 409, { ok: hetHanThach > bayGio });
    }
    if (duong === '/cap') {
      const hetHanThach = dungNonce(undefined, bayGio, ttl) as number;
      await this.kho.put(`c:${du.nonce}`, hetHanThach);
      await this.henDon(hetHanThach);
      return json(200, { ok: true });
    }
    const hetHan = dungNonce(await this.kho.get<number>(`n:${du.nonce}`), bayGio, ttl);
    if (hetHan === null) return json(409, { ok: false });
    await this.kho.put(`n:${du.nonce}`, hetHan);
    await this.henDon(hetHan);
    return json(200, { ok: true });
  }

  private async henDon(hetHan: number): Promise<void> {
    const henDon = await this.kho.getAlarm();
    if (henDon === null || henDon > hetHan) await this.kho.setAlarm(hetHan);
  }

  /** Xoá nonce hết hạn; còn nonce thì hẹn lần dọn kế tiếp ở hạn sớm nhất. */
  async alarm(): Promise<void> {
    const bayGio = this.bayGio();
    let somNhat: number | null = null;
    for (const tienTo of ['n:', 'c:']) {
      for (const [khoa, hetHan] of await this.kho.list<number>({ prefix: tienTo })) {
        if (hetHan <= bayGio) await this.kho.delete(khoa);
        else somNhat = somNhat === null ? hetHan : Math.min(somNhat, hetHan);
      }
    }
    if (somNhat !== null) await this.kho.setAlarm(somNhat);
  }
}
