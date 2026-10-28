// DO GioiHanToc: cửa sổ trượt chính xác theo khoá (ip / thiết bị / phiên / endpoint) - SEC-API API-01.
// Rate Limiting binding (RL_IP) là lớp thô rẻ ở trước; DO này cho giới hạn nhiều chiều cấu hình theo route.
import { ghiNhan, type TrangThaiCuaSo } from '../thuan/gioi-han';

type KhoLuu = Pick<DurableObjectStorage, 'get' | 'put' | 'delete' | 'list' | 'getAlarm' | 'setAlarm'>;
type DaLuu = TrangThaiCuaSo & { cuaSoMs: number };

function json(status: number, du: unknown): Response {
  return new Response(JSON.stringify(du), { status, headers: { 'content-type': 'application/json' } });
}

export class GioiHanToc {
  private readonly kho: KhoLuu;
  private readonly bayGio: () => number;

  constructor(state: { storage: KhoLuu }, _env?: unknown, bayGio: () => number = Date.now) {
    this.kho = state.storage;
    this.bayGio = bayGio;
  }

  /** POST {khoa, gioiHan, cuaSoMs} -> {choPhep, conLai, thuLaiSau}. */
  async fetch(req: Request): Promise<Response> {
    if (req.method !== 'POST') return json(405, {});
    const du = (await req.json().catch(() => null)) as { khoa?: unknown; gioiHan?: unknown; cuaSoMs?: unknown } | null;
    const { khoa, gioiHan, cuaSoMs } = du ?? {};
    if (
      typeof khoa !== 'string' ||
      khoa.length === 0 ||
      khoa.length > 256 ||
      !Number.isInteger(gioiHan) ||
      !Number.isInteger(cuaSoMs) ||
      (gioiHan as number) < 1 ||
      (cuaSoMs as number) < 1000
    ) {
      return json(400, {});
    }
    const bayGio = this.bayGio();
    const cu = await this.kho.get<DaLuu>(`k:${khoa}`);
    const kq = ghiNhan(cu && cu.cuaSoMs === cuaSoMs ? cu : null, bayGio, gioiHan as number, cuaSoMs as number);
    await this.kho.put(`k:${khoa}`, { ...kq.trangThai, cuaSoMs });
    if ((await this.kho.getAlarm()) === null) await this.kho.setAlarm(bayGio + 2 * (cuaSoMs as number));
    return json(200, { choPhep: kq.choPhep, conLai: kq.conLai, thuLaiSau: kq.thuLaiSau });
  }

  /** Xoá khoá đã yên quá 2 cửa sổ; còn khoá thì hẹn lần dọn sau. */
  async alarm(): Promise<void> {
    const bayGio = this.bayGio();
    let sau: number | null = null;
    for (const [khoa, t] of await this.kho.list<DaLuu>({ prefix: 'k:' })) {
      const het = t.batDau + 2 * t.cuaSoMs;
      if (het <= bayGio) await this.kho.delete(khoa);
      else sau = sau === null ? het : Math.min(sau, het);
    }
    if (sau !== null) await this.kho.setAlarm(sau);
  }
}
