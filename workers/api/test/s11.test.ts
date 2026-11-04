// S11 (QUYET_DINH Q57): chặn chế độ Nhà phát triển phía Worker. App báo `pt` qua GET /v1/status (đã ký) ->
// devices.dev_mode_at; prod (CHAN_DEV_MODE=1) chặn route nghiệp vụ 403, vẫn cho /v1/status + /v1/events; tắt -> dùng lại ngay.
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SchemaDeXuatApp } from '../src/thuan/cau-hinh-tu-xa';
import { biChanPhatTrien, capNhatPhatTrien } from '../src/thuan/che-do-phat-trien';
import { chuoiDangKy } from '../src/thuan/ma-hoa';
import { taoMf } from './tich-hop/mf';
import { taoKhoaPhien, taoThietBiGia, tieuDeKy, type ThietBiGia } from './tich-hop/thiet-bi-gia';

describe('hàm thuần', () => {
  it('Remote Config SOC nhận kill-switch chanDevMode + mua-pro (Q57 / Q61), từ chối cờ lạ', () => {
    const pin = ['A'.repeat(43) + '=', 'B'.repeat(43) + '='];
    const co = { toiThieu: 1, khuyenNghi: 1, pin, ngay: 7 };
    expect(SchemaDeXuatApp.safeParse({ ...co, tat: ['chanDevMode', 'mua-pro'] }).success).toBe(true);
    expect(SchemaDeXuatApp.safeParse({ ...co, tat: ['camera'] }).success).toBe(false);
  });
  it('capNhatPhatTrien: bật giữ mốc đầu, tắt xoá, thiếu / lạ giữ nguyên', () => {
    expect(capNhatPhatTrien(null, '1', 5)).toEqual({ moi: 5, doi: true });
    expect(capNhatPhatTrien(3, '1', 5)).toEqual({ moi: 3, doi: false });
    expect(capNhatPhatTrien(3, '0', 5)).toEqual({ moi: null, doi: true });
    expect(capNhatPhatTrien(null, '0', 5)).toEqual({ moi: null, doi: false });
    expect(capNhatPhatTrien(3, undefined, 5)).toEqual({ moi: 3, doi: false });
    expect(capNhatPhatTrien(null, 'x', 5)).toEqual({ moi: null, doi: false });
  });
  it('biChanPhatTrien: chỉ khi cờ = 1 và có mốc', () => {
    expect(biChanPhatTrien('1', 7)).toBe(true);
    expect(biChanPhatTrien('1', null)).toBe(false);
    expect(biChanPhatTrien('0', 7)).toBe(false);
    expect(biChanPhatTrien(undefined, 7)).toBe(false);
  });
});

const goc = 'https://compass-api.tsudev.com';
let soIp = 0;

function bo(mfThu: () => Miniflare) {
  const goi = async (duong: string, o: { body?: string; tieuDe?: Record<string, string> } = {}) => {
    const res = await mfThu().dispatchFetch(`${goc}${duong}`, {
      method: o.body === undefined ? 'GET' : 'POST',
      headers: {
        'content-type': 'application/json',
        'cf-connecting-ip': `198.18.0.${(soIp++ % 200) + 1}`,
        ...o.tieuDe,
      },
      ...(o.body === undefined ? {} : { body: o.body }),
    });
    const vb = await res.text();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any -- thân phản hồi tuỳ route trong test
    return { status: res.status, du: (vb ? JSON.parse(vb) : null) as Record<string, any> };
  };
  const dangKy = async () => {
    const tb = await taoThietBiGia();
    const installationId = crypto.randomUUID();
    const thach = (await goi('/v1/device/challenge', { body: JSON.stringify({ installationId }) })).du
      .thachThuc as string;
    const r = await goi('/v1/device/register', {
      body: JSON.stringify({
        installationId,
        khoaCongKhai: tb.khoaCongKhai,
        thachThuc: thach,
        chuKy: await tb.ky(chuoiDangKy(thach, installationId, tb.khoaCongKhai)),
        nenTang: 'android',
        goi: 'com.tsudev.laban',
        integrityToken: null,
        thongTin: { heDieuHanh: '13', model: 'SM-M325FV', phienBan: '0.2.0', build: 20, ngonNgu: 'vi' },
      }),
    });
    expect(r.status).toBe(201);
    return { tb, token: r.du.phien.accessToken as string };
  };
  const goiKy = async (t: { tb: ThietBiGia; token: string }, duongDay: string, body?: unknown) => {
    const than = body === undefined ? undefined : JSON.stringify(body);
    return goi(duongDay, {
      ...(than === undefined ? {} : { body: than }),
      tieuDe: await tieuDeKy(t.tb, t.token, {
        phuongThuc: than === undefined ? 'GET' : 'POST',
        duong: duongDay,
        ...(than === undefined ? {} : { than }),
      }),
    });
  };
  return { goi, dangKy, goiKy };
}

const suKien = () => ({
  events: [
    {
      event_id: crypto.randomUUID(),
      ts: new Date().toISOString(),
      type: 'DEV_MODE',
      severity: 'info',
      signals: { dev_settings: true },
      app: { version: '0.2.0', build: 20, install_source: null },
      env: { os: 'android', os_ver: '13', model: 'SM-M325FV', emulator: false, root: 'no' },
    },
  ],
});

describe('Worker prod (CHAN_DEV_MODE=1)', () => {
  let mf: Miniflare;
  beforeAll(async () => {
    mf = await taoMf(undefined, {
      bindings: { KHOA_PHIEN: await taoKhoaPhien(), PI_GOI: 'com.tsudev.laban', CHAN_DEV_MODE: '1' },
    });
  }, 60_000);
  afterAll(async () => {
    await mf?.dispose();
  });

  it('bật -> 403 route nghiệp vụ, status + events vẫn qua; tắt -> dùng lại ngay', async () => {
    const { dangKy, goiKy } = bo(() => mf);
    const t = await dangKy();
    expect((await goiKy(t, '/v1/device/me')).status).toBe(200);
    expect((await goiKy(t, '/v1/status?pt=1')).du).toMatchObject({ cheDoPhatTrien: true });
    expect(await goiKy(t, '/v1/device/me')).toMatchObject({
      status: 403,
      du: { code: 'che-do-nha-phat-trien' },
    });
    expect((await goiKy(t, '/v1/events', suKien())).status).toBe(202);
    // App cũ không gửi pt -> giữ nguyên trạng thái đã biết.
    expect((await goiKy(t, '/v1/status')).du.cheDoPhatTrien).toBe(true);
    expect((await goiKy(t, '/v1/status?pt=0')).du.cheDoPhatTrien).toBe(false);
    expect((await goiKy(t, '/v1/device/me')).status).toBe(200);
  });

  it('pt nằm trong chuỗi ký: sửa query sau khi ký -> 401', async () => {
    const { dangKy, goi } = bo(() => mf);
    const t = await dangKy();
    const tieuDe = await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/status?pt=1' });
    expect((await goi('/v1/status?pt=0', { tieuDe })).status).toBe(401);
  });
});

describe('Worker staging (CHAN_DEV_MODE=0)', () => {
  let mf: Miniflare;
  beforeAll(async () => {
    mf = await taoMf(undefined, {
      bindings: { KHOA_PHIEN: await taoKhoaPhien(), PI_GOI: 'com.tsudev.laban', CHAN_DEV_MODE: '0' },
    });
  }, 60_000);
  afterAll(async () => {
    await mf?.dispose();
  });

  it('chỉ ghi nhận, không chặn', async () => {
    const { dangKy, goiKy } = bo(() => mf);
    const t = await dangKy();
    expect((await goiKy(t, '/v1/status?pt=1')).du.cheDoPhatTrien).toBe(false);
    expect((await goiKy(t, '/v1/device/me')).status).toBe(200);
  });
});
