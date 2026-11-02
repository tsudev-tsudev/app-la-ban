import { describe, expect, it } from 'vitest';
import { app } from '../src/index';
import { BUOC_DO, doBuoc, DongHo } from '../src/thuan/do-tre';

describe('R3c đo độ trễ theo bước', () => {
  it('doubles = [tong, ...bước theo thứ tự cố định, lanh]; cộng dồn + không âm', () => {
    const dh = new DongHo();
    dh.cong('chan', 12);
    dh.cong('nonce', 5);
    dh.cong('nonce', 7);
    dh.cong('d1', -3);
    const d = dh.doubles(40, true);
    expect(d).toHaveLength(BUOC_DO.length + 2);
    expect(d[0]).toBe(40);
    expect(d[1 + BUOC_DO.indexOf('chan')]).toBe(12);
    expect(d[1 + BUOC_DO.indexOf('nonce')]).toBe(12);
    expect(d[1 + BUOC_DO.indexOf('d1')]).toBe(0);
    expect(d.at(-1)).toBe(1);
  });

  it('doBuoc cộng thời gian kể cả khi lỗi; không có đồng hồ -> chỉ chạy', async () => {
    let t = 100;
    const gio = () => t;
    const dh = new DongHo();
    expect(await doBuoc(dh, 'phien', async () => ((t += 30), 'x'), gio)).toBe('x');
    await expect(doBuoc(dh, 'phien', async () => ((t += 5), Promise.reject(new Error('h'))), gio)).rejects.toThrow('h');
    expect(dh.lay('phien')).toBe(35);
    expect(await doBuoc(undefined, 'phien', async () => 1)).toBe(1);
  });

  it('/v1/health không chạm D1 (DB ném lỗi nếu bị gọi) và ghi AE đủ doubles + colo', async () => {
    const diem: AnalyticsEngineDataPoint[] = [];
    const DB = new Proxy({}, { get: () => () => { throw new Error('khong duoc cham D1'); } }) as unknown as D1Database;
    const res = await app.request(
      '/v1/health',
      { headers: { 'cf-connecting-ip': '203.0.113.9' } },
      { MOI_TRUONG: 'test', DB, SU_KIEN: { writeDataPoint: (p?: AnalyticsEngineDataPoint) => p && diem.push(p) } },
    );
    expect(res.status).toBe(200);
    expect(diem).toHaveLength(1);
    expect(diem[0]?.doubles).toHaveLength(BUOC_DO.length + 2);
    expect(diem[0]?.blobs).toHaveLength(5);
  });
});
