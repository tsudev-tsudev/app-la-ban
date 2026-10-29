import { generateKeyPairSync, sign } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  capNhatDo,
  chuanHoaMuc,
  chuanHoaTrang,
  chuoiTheoNgonNgu,
  giaiB64url,
  hanhViTheoMuc,
  ketLuan,
  kichThuocBatThuong,
  kiemGoi,
  maB64url,
  mucChoTrang,
  noiDungWatermark,
  phanLoaiPhim,
  phanTichGoi,
  phanTichNoiDung,
  soO,
  TRANG_THAI_DAU,
  type DoKichThuoc,
  type NoiDungCauHinh,
  type PhimNhan,
  type TrangThaiDo,
} from '../src/index';
import { KHOA_CONG_KHAI } from '../src/khoa';

describe('mức', () => {
  it('giá trị lạ -> chat (đóng khi lỗi), trang lạ -> landing', () => {
    expect(chuanHoaMuc('nhe')).toBe('nhe');
    expect(chuanHoaMuc('xyz')).toBe('chat');
    expect(chuanHoaMuc(undefined)).toBe('chat');
    expect(chuanHoaTrang('admin')).toBe('admin');
    expect(chuanHoaTrang('x')).toBe('landing');
  });
  it('tat tắt hết, nhe không chặn chọn / menu / dò, chat bật hết', () => {
    expect(Object.values(hanhViTheoMuc('tat')).every((x) => !x)).toBe(true);
    expect(hanhViTheoMuc('nhe')).toEqual({ phimTat: true, keoAnh: true, chanIn: true, menuChuot: false, saoChep: false, doDevtools: false });
    expect(Object.values(hanhViTheoMuc('chat')).every(Boolean)).toBe(true);
  });
});

const phim = (code: string, o: Partial<PhimNhan> = {}): PhimNhan => ({
  key: code.replace(/^Key/, '').toLowerCase(),
  code,
  ctrlKey: false,
  metaKey: false,
  altKey: false,
  shiftKey: false,
  ...o,
});

describe('phanLoaiPhim', () => {
  it('công cụ nhà phát triển: F12, Ctrl+Shift+I/J/C, ⌘⌥I/J/C', () => {
    expect(phanLoaiPhim({ ...phim('F12'), key: 'F12' })).toBe('devtools');
    for (const c of ['KeyI', 'KeyJ', 'KeyC']) {
      expect(phanLoaiPhim(phim(c, { ctrlKey: true, shiftKey: true }))).toBe('devtools');
      expect(phanLoaiPhim({ ...phim(c, { metaKey: true, altKey: true }), key: 'ˆ' })).toBe('devtools');
    }
  });
  it('xem nguồn / lưu / in', () => {
    expect(phanLoaiPhim(phim('KeyU', { ctrlKey: true }))).toBe('nguon');
    expect(phanLoaiPhim(phim('KeyU', { metaKey: true, altKey: true }))).toBe('nguon');
    expect(phanLoaiPhim(phim('KeyS', { metaKey: true }))).toBe('luu');
    expect(phanLoaiPhim(phim('KeyP', { ctrlKey: true }))).toBe('in');
  });
  it('không chặn gõ chữ, sao chép / dán / hoàn tác trong ô nhập, Ctrl+Shift+S...', () => {
    for (const c of ['KeyI', 'KeyU', 'KeyS', 'KeyP', 'KeyC']) expect(phanLoaiPhim(phim(c))).toBeNull();
    for (const c of ['KeyC', 'KeyV', 'KeyX', 'KeyZ', 'KeyA', 'KeyF']) expect(phanLoaiPhim(phim(c, { ctrlKey: true }))).toBeNull();
    expect(phanLoaiPhim(phim('KeyS', { ctrlKey: true, shiftKey: true }))).toBeNull();
    expect(phanLoaiPhim(phim('KeyI', { shiftKey: true }))).toBeNull();
  });
});

const kt = (o: Partial<DoKichThuoc>): DoKichThuoc => ({
  ngoaiRong: 1920,
  ngoaiCao: 1040,
  trongRong: 1920,
  trongCao: 930,
  camUng: false,
  ...o,
});

describe('kichThuocBatThuong', () => {
  it('cửa sổ thường / phóng to / thu nhỏ: không nghi', () => {
    expect(kichThuocBatThuong(kt({}))).toBe(false);
    // Phóng 125%: hụt cả hai chiều.
    expect(kichThuocBatThuong(kt({ trongRong: 1536, trongCao: 744 }))).toBe(false);
    // Phóng 110%.
    expect(kichThuocBatThuong(kt({ trongRong: 1745, trongCao: 845 }))).toBe(false);
    // Toàn màn hình (không thanh) + phóng 110%.
    expect(kichThuocBatThuong(kt({ ngoaiCao: 1080, trongRong: 1745, trongCao: 982 }))).toBe(false);
    // Thu 80%: trong lớn hơn ngoài.
    expect(kichThuocBatThuong(kt({ trongRong: 2400, trongCao: 1160 }))).toBe(false);
  });
  it('công cụ gắn cạnh hoặc đáy: nghi; màn cảm ứng: bỏ qua', () => {
    expect(kichThuocBatThuong(kt({ trongRong: 1300 }))).toBe(true);
    expect(kichThuocBatThuong(kt({ trongCao: 600 }))).toBe(true);
    expect(kichThuocBatThuong(kt({ trongRong: 1056, trongCao: 744 }))).toBe(true);
    expect(kichThuocBatThuong(kt({ trongRong: 1300, camUng: true }))).toBe(false);
    expect(kichThuocBatThuong(kt({ ngoaiRong: 0, trongRong: 1300 }))).toBe(false);
  });
});

describe('capNhatDo / ketLuan', () => {
  const lap = (t: TrangThaiDo, ds: Parameters<typeof capNhatDo>[1][], bayGio = 0) =>
    ds.reduce((s, e) => capNhatDo(s, e, bayGio), t);
  const mo = { loai: 'do' as const, kichThuoc: kt({ trongRong: 1300 }) };
  const dong = { loai: 'do' as const, kichThuoc: kt({}) };

  it('kích thước phải giữ 2 lần đo liên tiếp; đóng công cụ -> hết nghi', () => {
    const mot = lap(TRANG_THAI_DAU, [mo]);
    expect(ketLuan(mot).nghi).toBe(false);
    const hai = lap(mot, [mo]);
    expect(ketLuan(hai)).toEqual({ nghi: true, kichThuoc: true, diem: 0 });
    expect(ketLuan(lap(hai, [dong])).nghi).toBe(false);
    expect(ketLuan(lap(TRANG_THAI_DAU, [mo, dong, mo])).nghi).toBe(false);
  });
  it('một lần F12 hoặc vài lần chuột phải không đủ; F12 hai lần thì nghi; điểm tự giảm', () => {
    expect(ketLuan(lap(TRANG_THAI_DAU, [{ loai: 'phimDevtools' }])).nghi).toBe(false);
    expect(ketLuan(lap(TRANG_THAI_DAU, [{ loai: 'menuChuot' }, { loai: 'menuChuot' }, { loai: 'menuChuot' }])).nghi).toBe(false);
    const t = lap(TRANG_THAI_DAU, [{ loai: 'phimDevtools' }, { loai: 'phimDevtools' }], 1_000);
    expect(ketLuan(t)).toEqual({ nghi: true, kichThuoc: false, diem: 4 });
    expect(ketLuan(capNhatDo(t, dong, 11_000)).diem).toBe(3);
    expect(ketLuan(capNhatDo(t, dong, 41_000)).diem).toBe(0);
    expect(ketLuan(capNhatDo(t, dong, 999_000)).diem).toBe(0);
  });
});

function taoKhoa() {
  const { privateKey, publicKey } = generateKeyPairSync('ed25519');
  return { bimat: privateKey, cong: publicKey.export({ format: 'jwk' }).x };
}

function kyThu(bimat: unknown, kid: string, nd: unknown) {
  const duLieu = new TextEncoder().encode(JSON.stringify(nd));
  return { kid, duLieu: maB64url(duLieu), chuKy: maB64url(new Uint8Array(sign(null, duLieu, bimat))) };
}

describe('cấu hình ký số', () => {
  const k = taoKhoa();
  const khoa = { 't-1': k.cong };
  const nd: NoiDungCauHinh = { v: 1, phatHanh: 1_000, het: 10_000, muc: { landing: 'nhe', admin: 'tat' } };

  it('base64url hai chiều', () => {
    const b = new Uint8Array([0, 250, 251, 252, 253, 254, 255]);
    expect(giaiB64url(maB64url(b))).toEqual(b);
    expect(giaiB64url('a+b/')).toBeNull();
  });
  it('khoá công khai nhúng là Ed25519 raw 32 byte', () => {
    for (const v of Object.values(KHOA_CONG_KHAI)) expect(giaiB64url(v)?.length).toBe(32);
  });
  it('gói đúng chữ ký -> nội dung; mức theo trang', async () => {
    const goi = phanTichGoi(kyThu(k.bimat, 't-1', nd));
    if (!goi) throw new Error('gói sai hình dạng');
    const kq = await kiemGoi(goi, khoa, crypto.subtle);
    expect(kq).toEqual(nd);
    expect(mucChoTrang(kq, 'landing', 5_000)).toBe('nhe');
    expect(mucChoTrang(kq, 'admin', 5_000)).toBe('tat');
  });
  it('sai chữ ký / đổi nội dung / kid lạ / khoá khác -> null', async () => {
    const goi = kyThu(k.bimat, 't-1', nd);
    const nd2 = maB64url(new TextEncoder().encode(JSON.stringify({ ...nd, muc: { landing: 'tat' } })));
    expect(await kiemGoi({ ...goi, duLieu: nd2 }, khoa, crypto.subtle)).toBeNull();
    expect(await kiemGoi({ ...goi, kid: 'khac' }, khoa, crypto.subtle)).toBeNull();
    expect(await kiemGoi({ ...goi, kid: 'toString' }, khoa, crypto.subtle)).toBeNull();
    expect(await kiemGoi(goi, { 't-1': taoKhoa().cong }, crypto.subtle)).toBeNull();
    expect(await kiemGoi({ ...goi, chuKy: goi.chuKy.slice(4) }, khoa, crypto.subtle)).toBeNull();
  });
  it('hết hạn / phát hành ở tương lai xa / thiếu trang -> chat', () => {
    expect(mucChoTrang(nd, 'landing', 10_000)).toBe('chat');
    expect(mucChoTrang({ ...nd, phatHanh: 5_000 + 2 * 86_400_000, het: 9e15 }, 'landing', 5_000)).toBe('chat');
    expect(mucChoTrang({ ...nd, muc: {} }, 'admin', 5_000)).toBe('chat');
    expect(mucChoTrang(null, 'admin', 5_000)).toBe('chat');
  });
  it('hình dạng gói / nội dung lạ bị loại', () => {
    expect(phanTichGoi(null)).toBeNull();
    expect(phanTichGoi({ kid: 'a', duLieu: 'b' })).toBeNull();
    expect(phanTichGoi({ kid: 'a', duLieu: 'b c', chuKy: 'd' })).toBeNull();
    const ma = (o: unknown) => new TextEncoder().encode(JSON.stringify(o));
    expect(phanTichNoiDung(ma({ v: 2, phatHanh: 1, het: 2 }))).toBeNull();
    expect(phanTichNoiDung(new TextEncoder().encode('{'))).toBeNull();
    expect(phanTichNoiDung(ma({ v: 1, phatHanh: 1, het: 2, muc: { landing: 'zz', x: 'tat' } }))?.muc).toEqual({ landing: 'chat' });
  });
});

describe('watermark + chuỗi', () => {
  it('giờ Việt Nam cố định, không phụ thuộc múi giờ máy', () => {
    expect(noiDungWatermark(' a@b.vn ', Date.UTC(2026, 9, 29, 17, 5))).toBe('a@b.vn · 2026-10-30 00:05 (UTC+7)');
  });
  it('số ô có trần', () => {
    expect(soO(1280, 720)).toBe(4 * 6);
    expect(soO(10_000, 10_000)).toBe(120);
    expect(soO(0, 720)).toBe(0);
  });
  it('vi mặc định, en theo lang', () => {
    expect(chuoiTheoNgonNgu('en-US').tieuDe).toMatch(/hidden/);
    expect(chuoiTheoNgonNgu('vi').tieuDe).toMatch(/ẩn/);
    expect(chuoiTheoNgonNgu(null)).toBe(chuoiTheoNgonNgu('vi'));
  });
});
