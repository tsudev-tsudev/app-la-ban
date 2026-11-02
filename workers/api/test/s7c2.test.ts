import { generateKeyPairSync } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { cheEmail, dayNgay, DINH_NGHIA, docKhoang, gioVn, kiemKhoang, oCsv, taoCsv, tenTep } from '../src/thuan/bao-cao';
import {
  deXuatTuGoi,
  giaiMaGoi,
  GOC_DONG_GOI,
  KHOA_CONG_KHAI,
  kiemDeXuatApp,
  kiemGoi,
  kyGoi,
  napKhoaKy,
  phatHanhMoi,
  SchemaYeuCauCauHinh,
  taoNoiDungApp,
  taoNoiDungWeb,
  type DeXuatApp,
} from '../src/thuan/cau-hinh-tu-xa';
import { DEM_CHAN_MS } from '../src/threat/nap';
import { coQuyen, dsQuyen } from '../src/thuan/soc';

const P = GOC_DONG_GOI.map((g) => g.pin);
const NGAY = 86_400_000;

describe('S7c2: Remote Config ký số', () => {
  it('CA đóng gói khớp tools/cau-hinh/goc-tin-cay.json; khoá công khai khớp app + web', () => {
    const goc = JSON.parse(readFileSync(join(__dirname, '../../../tools/cau-hinh/goc-tin-cay.json'), 'utf8')) as { ten: string; pin: string; het: string }[];
    expect(GOC_DONG_GOI).toEqual(goc);
    const dart = readFileSync(join(__dirname, '../../../packages/network/lib/src/khoa_cau_hinh.dart'), 'utf8');
    const web = readFileSync(join(__dirname, '../../../web/shield/src/khoa.ts'), 'utf8');
    expect(dart).toContain(`'app-1': '${KHOA_CONG_KHAI['app-1']}'`);
    expect(web).toContain(`'web-1': '${KHOA_CONG_KHAI['web-1']}'`);
  });

  it('đề xuất app: mã tối thiểu <= khuyến nghị <= bản đã phát hành, >= 2 pin trong bộ đóng gói', () => {
    const dx: DeXuatApp = { toiThieu: 5, khuyenNghi: 9, tat: [], pin: [P[0] as string, P[3] as string], ngay: 30 };
    expect(kiemDeXuatApp(dx, null, 10)).toBeNull();
    expect(kiemDeXuatApp({ ...dx, khuyenNghi: 4 }, null, 10)).toBe('khuyen-nghi-thap');
    expect(kiemDeXuatApp({ ...dx, toiThieu: 11, khuyenNghi: 11 }, null, 10)).toBe('toi-thieu-vuot-ban-moi');
    expect(kiemDeXuatApp({ ...dx, toiThieu: 11, khuyenNghi: 11 }, null, null)).toBeNull();
    expect(kiemDeXuatApp({ ...dx, pin: [P[0] as string, P[0] as string] }, null, 10)).toBe('pin-it');
    const la = 'A'.repeat(43) + '=';
    expect(kiemDeXuatApp({ ...dx, pin: [P[0] as string, la] }, null, 10)).toBe('pin-la');
    // CA thêm bằng công cụ ngoại tuyến: được giữ, không được bỏ (PEM mồ côi app từ chối).
    const ht = { pin: [P[0] as string, la], gocThem: ['-----BEGIN CERTIFICATE-----x'] };
    expect(kiemDeXuatApp({ ...dx, pin: [P[1] as string, la] }, ht, 10)).toBeNull();
    expect(kiemDeXuatApp({ ...dx, pin: [P[1] as string, P[2] as string] }, ht, 10)).toBe('goc-them-can-cong-cu');
  });

  it('schema yêu cầu: cờ lạ / pin sai dạng / lý do ngắn / trường lạ bị từ chối', () => {
    const goc = { dich: 'app', noiDung: { toiThieu: 1, khuyenNghi: 2, tat: ['ar'], pin: P.slice(0, 2), ngay: 90 }, lyDo: 'Tắt AR do lỗi camera' };
    expect(SchemaYeuCauCauHinh.safeParse(goc).success).toBe(true);
    expect(SchemaYeuCauCauHinh.safeParse({ ...goc, noiDung: { ...goc.noiDung, tat: ['x'] } }).success).toBe(false);
    expect(SchemaYeuCauCauHinh.safeParse({ ...goc, noiDung: { ...goc.noiDung, pin: ['abc', 'def'] } }).success).toBe(false);
    expect(SchemaYeuCauCauHinh.safeParse({ ...goc, lyDo: 'ngắn' }).success).toBe(false);
    expect(SchemaYeuCauCauHinh.safeParse({ ...goc, la: 1 }).success).toBe(false);
    expect(SchemaYeuCauCauHinh.safeParse({ dich: 'web', noiDung: { landing: 'nhe', admin: 'chat', ngay: 30 }, lyDo: 'Giảm khiên landing' }).success).toBe(true);
    expect(SchemaYeuCauCauHinh.safeParse({ dich: 'web', noiDung: { landing: 'manh', admin: 'chat', ngay: 30 }, lyDo: 'Giảm khiên landing' }).success).toBe(false);
  });

  it('nội dung khớp công cụ ngoại tuyến: cờ sắp xếp + bỏ trùng, giữ gocThem, hạn theo ngày; phatHanh luôn tăng', () => {
    const nd = taoNoiDungApp({ toiThieu: 2, khuyenNghi: 3, tat: ['chia-se', 'ar', 'ar'], pin: P.slice(0, 2), ngay: 10 }, { gocThem: ['PEM'] }, 1000);
    expect(nd).toEqual({ v: 1, phatHanh: 1000, het: 1000 + 10 * NGAY, capNhat: { toiThieu: 2, khuyenNghi: 3 }, tat: ['ar', 'chia-se'], pin: P.slice(0, 2), gocThem: ['PEM'] });
    expect(Object.keys(nd)).toEqual(['v', 'phatHanh', 'het', 'capNhat', 'tat', 'pin', 'gocThem']);
    expect(taoNoiDungWeb({ landing: 'nhe', admin: 'chat', ngay: 1 }, 5)).toEqual({ v: 1, phatHanh: 5, het: 5 + NGAY, muc: { landing: 'nhe', admin: 'chat' } });
    expect(phatHanhMoi(100, null)).toBe(100);
    expect(phatHanhMoi(100, 50)).toBe(100);
    expect(phatHanhMoi(100, 100)).toBe(101);
    expect(phatHanhMoi(100, 500)).toBe(501);
  });

  it('ký Ed25519 bằng WebCrypto: kiểm được bằng khoá công khai; khoá secret không khớp kid -> null', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('ed25519');
    const pem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
    const x = publicKey.export({ format: 'jwk' }).x as string;
    const cu = KHOA_CONG_KHAI['app-1'] as string;
    expect(await napKhoaKy(pem, 'app-1')).toBeNull();
    expect(await napKhoaKy(undefined, 'app-1')).toBeNull();
    expect(await napKhoaKy('rác', 'app-1')).toBeNull();
    KHOA_CONG_KHAI['app-1'] = x;
    try {
      const k = await napKhoaKy(pem, 'app-1');
      expect(k).not.toBeNull();
      const nd = taoNoiDungApp({ toiThieu: 1, khuyenNghi: 1, tat: [], pin: P, ngay: 90 }, null, 7);
      const goi = JSON.stringify(await kyGoi(k as CryptoKey, 'app-1', nd));
      expect(await kiemGoi(goi)).toBe(true);
      expect(giaiMaGoi(goi)?.noiDung).toEqual(nd);
      const sai = JSON.parse(goi) as { duLieu: string };
      sai.duLieu = Buffer.from(JSON.stringify({ ...nd, tat: ['ar'] })).toString('base64url');
      expect(await kiemGoi(JSON.stringify(sai))).toBe(false);
    } finally {
      KHOA_CONG_KHAI['app-1'] = cu;
    }
  });

  it('điền sẵn form từ gói hiện tại; thiếu gói -> mặc định đóng gói', () => {
    expect(deXuatTuGoi(null, 'app')).toEqual({ toiThieu: 1, khuyenNghi: 1, tat: [], pin: P, ngay: 90 });
    expect(deXuatTuGoi({ capNhat: { toiThieu: 3, khuyenNghi: 4 }, tat: ['ar', 'la'], pin: P.slice(0, 2) }, 'app')).toEqual({ toiThieu: 3, khuyenNghi: 4, tat: ['ar'], pin: P.slice(0, 2), ngay: 90 });
    expect(deXuatTuGoi({ muc: { landing: 'nhe' } }, 'web')).toEqual({ landing: 'nhe', admin: 'chat', ngay: 90 });
  });
});

describe('S7c2: báo cáo CSV', () => {
  it('ô CSV chặn công thức bảng tính, bọc nháy, giữ số âm; BOM + CRLF', () => {
    expect(oCsv('=HYPERLINK("x")')).toBe(`"'=HYPERLINK(""x"")"`);
    expect(oCsv('+1')).toBe("'+1");
    expect(oCsv('-cmd')).toBe("'-cmd");
    expect(oCsv('@SUM(A1)')).toBe("'@SUM(A1)");
    expect(oCsv('\tx')).toBe("'\tx");
    expect(oCsv(-5)).toBe('-5');
    expect(oCsv(null)).toBe('');
    expect(oCsv('a,b')).toBe('"a,b"');
    expect(oCsv('dòng\nmới')).toBe('"dòng\nmới"');
    expect(taoCsv(['a', 'b'], [[1, 'x']])).toBe('\uFEFFa,b\r\n1,x\r\n');
  });

  it('khoảng: tối đa 92 ngày, tu < den; mặc định 7 ngày', () => {
    const now = 100 * NGAY;
    expect(kiemKhoang(0, 92 * NGAY, now)).toEqual({ tu: 0, den: 92 * NGAY });
    expect(kiemKhoang(0, 93 * NGAY, now)).toBeNull();
    expect(kiemKhoang(5, 5, now)).toBeNull();
    expect(kiemKhoang(0, now + 2 * NGAY, now)).toBeNull();
    expect(docKhoang({}, now)).toEqual({ tu: now - 7 * NGAY, den: now });
    expect(docKhoang({ tu: 'abc' }, now)).toEqual({ tu: now - 7 * NGAY, den: now });
  });

  it('giờ VN + tên tệp + điền đủ ngày', () => {
    const t = Date.UTC(2026, 10, 1, 17, 30); // 00:30 ngày 02/11 giờ VN
    expect(gioVn(t)).toBe('2026-11-02 00:30:00');
    expect(gioVn(null)).toBe('');
    expect(tenTep('su-kien', { tu: t, den: t + 2 * NGAY })).toBe('la-ban-su-kien-2026-11-02_2026-11-04.csv');
    expect(dayNgay({ tu: t, den: t + 2 * NGAY }, [{ k: '2026-11-03', n: 4 }])).toEqual([
      { k: '2026-11-02', n: 0 },
      { k: '2026-11-03', n: 4 },
      { k: '2026-11-04', n: 0 },
    ]);
  });

  it('che PII theo vai trò: IP rút gọn khi thiếu quyền; email liên hệ chỉ security_admin thấy đủ', () => {
    const r = { id: 'e', ts: 0, device_id: 'd', type: 'X', severity: 'low', rule_id: null, risk_delta: 0, ip: '203.0.113.77' };
    expect(DINH_NGHIA['su-kien'].dong(r, 'viewer').at(-1)).not.toBe('203.0.113.77');
    expect(DINH_NGHIA['su-kien'].dong(r, 'analyst').at(-1)).toBe('203.0.113.77');
    expect(cheEmail('ban@vi.du', 'responder')).toBe('b***@vi.du');
    expect(cheEmail('ban@vi.du', 'security_admin')).toBe('ban@vi.du');
    for (const d of Object.values(DINH_NGHIA)) expect(d.dong({}, 'viewer')).toHaveLength(d.cot.length);
  });

  it('quyền: viewer xem tổng hợp, analyst xuất CSV, security_admin sửa cấu hình; kill-switch đệm <= 5 s', () => {
    expect(coQuyen('viewer', 'bao-cao:xem')).toBe(true);
    expect(coQuyen('viewer', 'bao-cao:xuat')).toBe(false);
    expect(coQuyen('analyst', 'bao-cao:xuat')).toBe(true);
    expect(coQuyen('responder', 'cau-hinh-tu-xa:sua')).toBe(false);
    expect(coQuyen('security_admin', 'cau-hinh-tu-xa:sua')).toBe(true);
    expect(dsQuyen('super_admin')).toHaveLength(24);
    expect(DEM_CHAN_MS).toBeLessThanOrEqual(5000);
  });
});
