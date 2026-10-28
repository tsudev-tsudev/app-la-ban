import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { HASH_GOC, kiemChuoiAudit, taoDongAudit, type DongAudit } from '../src/thuan/audit';
import { jsonChuan, sha256Hex } from '../src/thuan/bam';
import { cheLog, rutGonIp } from '../src/thuan/che-pii';
import { catTrang, docGioiHanTrang, giaiMaCursor, maHoaCursor } from '../src/thuan/cursor';
import { doSau, laJson, phanTichBody } from '../src/thuan/dau-vao';
import { laIdHopLe, laUlid, laUuid, taoUlid, thoiGianUlid } from '../src/thuan/dinh-danh';
import { cauChonIpCanRutGon, cauLenhDonDep, cauLenhRutGonIp, LUU_IP_CHI_TIET_MS, LUU_SU_KIEN_MS } from '../src/thuan/don-dep';
import { ghiNhan, khoaGioiHan, uocLuong } from '../src/thuan/gioi-han';
import { bamYeuCau, IDEM_DANG_TOI_DA_MS, nenLuuPhanHoi, quyetDinhIdem, type BanGhiIdem } from '../src/thuan/idempotency';
import { LoiApi, phanLoaiLoi, tieuDeHttp, vanDe } from '../src/thuan/loi';
import { dungNonce, laNonceHopLe, NONCE_TTL_TOI_DA_MS } from '../src/thuan/nonce';

const loiCua = (f: () => unknown): LoiApi => {
  try {
    f();
  } catch (e) {
    if (e instanceof LoiApi) return e;
    throw e;
  }
  throw new Error('không ném lỗi');
};

describe('loi (RFC 7807)', () => {
  it('5xx không kèm code; 4xx có code + requestId', () => {
    expect(vanDe(500, 'db-sap', 'r1')).toEqual({ type: 'about:blank', title: 'Internal Server Error', status: 500, requestId: 'r1' });
    expect(vanDe(422, 'sai-du-lieu')).toEqual({ type: 'about:blank', title: 'Unprocessable Content', status: 422, code: 'sai-du-lieu' });
  });
  it('tiêu đề chuẩn, mã lạ -> chung chung', () => {
    expect(tieuDeHttp(429)).toBe('Too Many Requests');
    expect(tieuDeHttp(418)).toBe('Bad Request');
    expect(tieuDeHttp(599)).toBe('Internal Server Error');
  });
  it('phân loại: LoiApi giữ mã, lỗi lạ -> 500 noi-bo', () => {
    expect(phanLoaiLoi(new LoiApi(429, 'x', null, { 'retry-after': '3' }))).toEqual({ status: 429, ma: 'x', tieuDePhu: { 'retry-after': '3' } });
    expect(phanLoaiLoi(new TypeError('lộ chi tiết'))).toEqual({ status: 500, ma: 'noi-bo', tieuDePhu: {} });
  });
});

describe('dau-vao (API-02)', () => {
  const S = z.strictObject({ ten: z.string().max(10), so: z.number().int().optional() });
  it('độ sâu JSON', () => {
    expect(doSau(1)).toBe(0);
    expect(doSau({})).toBe(1);
    expect(doSau({ a: [{ b: 1 }] })).toBe(3);
    let sau: unknown = 0;
    for (let i = 0; i < 1000; i++) sau = [sau];
    expect(doSau(sau, 10)).toBeLessThanOrEqual(11);
  });
  it('Content-Type JSON', () => {
    expect(laJson('application/json; charset=utf-8')).toBe(true);
    expect(laJson('Application/JSON')).toBe(true);
    expect(laJson('text/plain')).toBe(false);
    expect(laJson(undefined)).toBe(false);
  });
  it('hợp lệ', () => {
    expect(phanTichBody('{"ten":"a","so":2}', S)).toEqual({ ten: 'a', so: 2 });
  });
  it('trường lạ / sai kiểu -> 422, chi tiết chỉ trong chiTiet', () => {
    const e = loiCua(() => phanTichBody('{"ten":"a","admin":true}', S));
    expect([e.status, e.ma]).toEqual([422, 'sai-du-lieu']);
    expect(JSON.stringify(e.chiTiet)).toContain('unrecognized_keys');
    expect(loiCua(() => phanTichBody('{"ten":5}', S)).status).toBe(422);
  });
  it('JSON hỏng -> 400, quá lớn -> 413, quá sâu -> 400', () => {
    expect(loiCua(() => phanTichBody('{', S)).ma).toBe('json-loi');
    expect(loiCua(() => phanTichBody(JSON.stringify({ ten: 'x'.repeat(50) }), S, { toiDa: 20 })).status).toBe(413);
    expect(loiCua(() => phanTichBody('[[[[1]]]]', z.any(), { sauToiDa: 3 })).ma).toBe('qua-sau');
  });
  it('kích thước tính theo byte UTF-8', () => {
    expect(loiCua(() => phanTichBody(JSON.stringify({ ten: 'ệệệệ' }), S, { toiDa: 20 })).status).toBe(413);
  });
});

describe('dinh-danh (API-03)', () => {
  it('ULID đúng định dạng, sắp theo thời gian, giải lại được thời gian', () => {
    const a = taoUlid(1_700_000_000_000);
    const b = taoUlid(1_700_000_000_001);
    expect(laUlid(a)).toBe(true);
    expect(a < b).toBe(true);
    expect(thoiGianUlid(a)).toBe(1_700_000_000_000);
    expect(taoUlid(0, (n) => new Uint8Array(n))).toBe('0'.repeat(26));
    expect(() => taoUlid(-1)).toThrow(RangeError);
    expect(() => taoUlid(2 ** 48)).toThrow(RangeError);
  });
  it('UUID / ULID hợp lệ, chuỗi khác bị từ chối', () => {
    expect(laUuid(crypto.randomUUID())).toBe(true);
    expect(laIdHopLe(crypto.randomUUID())).toBe(true);
    expect(laIdHopLe(taoUlid())).toBe(true);
    for (const x of ['', 'abc', '8ZZZZZZZZZZZZZZZZZZZZZZZZZ', "1' OR '1'='1", null, undefined]) expect(laIdHopLe(x)).toBe(false);
  });
});

describe('bam', () => {
  it('JSON chuẩn: khoá sắp xếp, bỏ undefined', () => {
    expect(jsonChuan({ b: 1, a: { d: [1, undefined], c: null }, u: undefined })).toBe('{"a":{"c":null,"d":[1,null]},"b":1}');
    expect(jsonChuan(undefined)).toBe('null');
  });
  it('sha256 hex', async () => {
    expect(await sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
});

describe('idempotency', () => {
  const ghi = (p: Partial<BanGhiIdem>): BanGhiIdem => ({
    bam_yeu_cau: 'h',
    trang_thai: 'xong',
    ma_http: 201,
    noi_dung: '{"id":1}',
    loai_noi_dung: 'application/json',
    tao_luc: 1000,
    het_han: 10_000,
    ...p,
  });
  it('băm không phụ thuộc thứ tự khoá body', async () => {
    expect(await bamYeuCau('post', '/v1/x', { a: 1, b: 2 })).toBe(await bamYeuCau('POST', '/v1/x', { b: 2, a: 1 }));
    expect(await bamYeuCau('POST', '/v1/x', { a: 1 })).not.toBe(await bamYeuCau('POST', '/v1/y', { a: 1 }));
  });
  it('các nhánh quyết định', () => {
    expect(quyetDinhIdem(null, 'h', 2000)).toEqual({ loai: 'moi' });
    expect(quyetDinhIdem(ghi({}), 'h', 10_000)).toEqual({ loai: 'moi' });
    expect(quyetDinhIdem(ghi({}), 'khac', 2000)).toEqual({ loai: 'khac-noi-dung' });
    expect(quyetDinhIdem(ghi({}), 'h', 2000)).toEqual({ loai: 'phat-lai', ma: 201, noiDung: '{"id":1}', loaiNoiDung: 'application/json' });
    expect(quyetDinhIdem(ghi({ trang_thai: 'dang' }), 'h', 2000)).toEqual({ loai: 'dang-xu-ly' });
    expect(quyetDinhIdem(ghi({ trang_thai: 'dang', het_han: 1e9 }), 'h', 1000 + IDEM_DANG_TOI_DA_MS + 1)).toEqual({ loai: 'moi' });
    expect(quyetDinhIdem(ghi({ ma_http: null, noi_dung: null, loai_noi_dung: null }), 'h', 2000)).toEqual({
      loai: 'phat-lai',
      ma: 200,
      noiDung: '',
      loaiNoiDung: 'application/json',
    });
  });
  it('chỉ lưu phản hồi xác định', () => {
    expect([200, 201, 400, 422].every(nenLuuPhanHoi)).toBe(true);
    expect([408, 425, 429, 500, 503].some(nenLuuPhanHoi)).toBe(false);
  });
});

describe('cursor', () => {
  it('mã hoá / giải mã khứ hồi, chặn cursor giả', () => {
    const c = { t: 1_700_000_000_000, id: '01HZX' };
    expect(giaiMaCursor(maHoaCursor(c))).toEqual(c);
    expect(giaiMaCursor(null)).toBeNull();
    expect(giaiMaCursor('')).toBeNull();
    for (const x of ['!!', 'a'.repeat(201), btoa('{"t":-1,"id":"x"}').replace(/=+$/, ''), btoa('{"t":1,"id":"x","z":1}'), 'e30']) {
      expect(loiCua(() => giaiMaCursor(x)).ma).toBe('cursor-loi');
    }
  });
  it('limit: mặc định 50, kẹp 1..200, rác -> 400', () => {
    expect(docGioiHanTrang(undefined)).toBe(50);
    expect(docGioiHanTrang('0')).toBe(1);
    expect(docGioiHanTrang('9999')).toBe(200);
    expect(docGioiHanTrang('20')).toBe(20);
    expect(loiCua(() => docGioiHanTrang('-1')).ma).toBe('limit-loi');
    expect(loiCua(() => docGioiHanTrang('1e3')).ma).toBe('limit-loi');
  });
  it('cắt trang', () => {
    const dong = [5, 4, 3].map((t) => ({ t, id: `i${t}` }));
    expect(catTrang(dong, 3, (d) => d)).toEqual({ items: dong, nextCursor: null });
    const kq = catTrang(dong, 2, (d) => d);
    expect(kq.items).toHaveLength(2);
    expect(giaiMaCursor(kq.nextCursor)).toEqual({ t: 4, id: 'i4' });
  });
});

describe('gioi-han (API-01)', () => {
  it('cho phép tới giới hạn rồi chặn, Retry-After > 0', () => {
    let t = null;
    for (let i = 0; i < 5; i++) {
      const kq = ghiNhan(t, 60_000 + i, 5, 60_000);
      expect(kq.choPhep).toBe(true);
      t = kq.trangThai;
    }
    const bi = ghiNhan(t, 60_010, 5, 60_000);
    expect(bi.choPhep).toBe(false);
    expect(bi.thuLaiSau).toBeGreaterThanOrEqual(1);
    expect(bi.thuLaiSau).toBeLessThanOrEqual(60);
  });
  it('cửa sổ trượt: đầu cửa sổ mới vẫn tính trọng số cửa sổ trước', () => {
    let t = null;
    for (let i = 0; i < 10; i++) t = ghiNhan(t, 0 + i, 10, 1000).trangThai;
    // t=1050: 10 x 0.95 + 0 = 9.5 -> thêm 1 vượt 10.
    const kq = ghiNhan(t, 1050, 10, 1000);
    expect(kq.choPhep).toBe(false);
    expect(kq.thuLaiSau).toBe(1);
    // t=1100: 10 x 0.9 = 9 -> còn chỗ cho 1.
    expect(ghiNhan(t, 1100, 10, 1000).choPhep).toBe(true);
    expect(ghiNhan(t, 5000, 10, 1000)).toMatchObject({ choPhep: true, trangThai: { dem: 1, demTruoc: 0 } });
  });
  it('ước lượng và khoá', () => {
    expect(uocLuong({ batDau: 0, dem: 2, demTruoc: 10 }, 500, 1000)).toBe(7);
    expect(khoaGioiHan('ip', '1.2.3.4', 'POST /v1/x')).toBe('ip:1.2.3.4:POST /v1/x');
    expect(khoaGioiHan('thiet-bi', 'd1')).toBe('thiet-bi:d1');
    expect(() => ghiNhan(null, 0, 0, 1000)).toThrow(RangeError);
  });
});

describe('nonce', () => {
  it('lần đầu nhận, dùng lại trong hạn -> null, hết hạn -> nhận lại; TTL bị kẹp', () => {
    expect(dungNonce(undefined, 1000, 5000)).toBe(6000);
    expect(dungNonce(6000, 2000, 5000)).toBeNull();
    expect(dungNonce(6000, 6000, 5000)).toBe(11_000);
    expect(dungNonce(undefined, 0, 1)).toBe(1000);
    expect(dungNonce(undefined, 0, 1e12)).toBe(NONCE_TTL_TOI_DA_MS);
  });
  it('định dạng nonce', () => {
    expect(laNonceHopLe('a'.repeat(16))).toBe(true);
    expect(laNonceHopLe('ngắn')).toBe(false);
    expect(laNonceHopLe('a'.repeat(129))).toBe(false);
    expect(laNonceHopLe(123)).toBe(false);
  });
});

describe('audit chuỗi băm (DAT-02)', () => {
  const nd = (i: number) => ({ id: `a${i}`, actor: 'admin@x', action: 'chan', target: `d${i}`, before: { s: 'clean' }, after: { s: 'banned' }, ip: null, ts: i });
  async function chuoi(n: number): Promise<DongAudit[]> {
    const ds: DongAudit[] = [];
    let truoc = HASH_GOC;
    for (let i = 0; i < n; i++) {
      const d = await taoDongAudit(nd(i), truoc);
      ds.push(d);
      truoc = d.hash_self;
    }
    return ds;
  }
  it('chuỗi nguyên vẹn -> -1; sửa / xoá giữa / đổi thứ tự -> vị trí lỗi', async () => {
    const ds = await chuoi(4);
    const o = (i: number): DongAudit => {
      const d = ds[i];
      if (!d) throw new Error(`thiếu dòng ${i}`);
      return d;
    };
    expect(await kiemChuoiAudit(ds)).toBe(-1);
    expect(await kiemChuoiAudit([o(0), { ...o(1), after: '{"s":"clean"}' }, o(2), o(3)])).toBe(1);
    expect(await kiemChuoiAudit([o(0), o(2), o(3)])).toBe(1);
    expect(await kiemChuoiAudit([o(1), o(0)])).toBe(0);
  });
  it('before/after lưu JSON chuẩn, null giữ null', async () => {
    const d = await taoDongAudit({ ...nd(0), before: { b: 1, a: 2 }, after: undefined }, HASH_GOC);
    expect(d.before).toBe('{"a":2,"b":1}');
    expect(d.after).toBeNull();
    expect(d.hash_self).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('che PII (DAT-01)', () => {
  it('rút gọn IPv4 /24, IPv6 /48', () => {
    expect(rutGonIp('203.0.113.77')).toBe('203.0.113.0/24');
    expect(rutGonIp('2001:db8:abcd:12::1')).toBe('2001:db8:abcd::/48');
    expect(rutGonIp('2001:0db8:0000:0000:0000:0000:0000:0001')).toBe('2001:db8:0::/48');
    expect(rutGonIp('::1')).toBe('0:0:0::/48');
    for (const x of ['999.1.1.1', 'abc', '', null, '1:2:3:4:5:6:7:8:9', '1:2:3']) expect(rutGonIp(x)).toBe('khong-ro');
  });
  it('che khoá nhạy cảm + IP, đệ quy, giới hạn độ sâu', () => {
    const kq = cheLog({ ip: '1.2.3.4', client_ip: '5.6.7.8', token: 'x', nested: { Authorization: 'B', lat: 21, ok: 1 }, ds: [{ email: 'a@b' }] });
    expect(kq).toEqual({
      ip: '1.2.3.0/24',
      client_ip: '5.6.7.0/24',
      token: '[che]',
      nested: { Authorization: '[che]', lat: '[che]', ok: 1 },
      ds: [{ email: '[che]' }],
    });
    let sau: unknown = 1;
    for (let i = 0; i < 10; i++) sau = { a: sau };
    expect(JSON.stringify(cheLog(sau))).toContain('[sau]');
  });
});

describe('don-dep (hạn lưu Spec §6.4)', () => {
  it('câu lệnh tham số hoá đúng mốc thời gian', () => {
    const bayGio = 1_800_000_000_000;
    const ds = cauLenhDonDep(bayGio);
    expect(ds[0]).toEqual({ sql: 'DELETE FROM idempotency_keys WHERE het_han <= ?', thamSo: [bayGio] });
    expect(ds[1]?.thamSo).toEqual([bayGio - LUU_SU_KIEN_MS]);
    expect(cauChonIpCanRutGon(bayGio, 10).thamSo).toEqual([bayGio - LUU_IP_CHI_TIET_MS, 10]);
    const rg = cauLenhRutGonIp({ device_id: 'd', ip: '1.2.3.4', asn: null, country: 'VN', first_seen: 1, last_seen: 2, count: 3 }, '1.2.3.0/24');
    expect(rg[0]?.thamSo).toEqual(['d', '1.2.3.0/24', null, 'VN', 1, 2, 3]);
    expect(rg[1]?.thamSo).toEqual(['d', '1.2.3.4']);
    for (const l of [...ds, ...rg]) expect(l.sql.split('?').length - 1).toBe(l.thamSo.length);
  });
});
