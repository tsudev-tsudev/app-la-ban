// Hàm THUẦN: ARB tiếng Anh -> ARB pseudo-locale en-XA để thử tràn chữ / ký tự có dấu / chuỗi bị nối cứng.
// Mỗi chuỗi: nguyên âm / phụ âm Latin -> biến thể có dấu, dài thêm ~40%, bọc "[ ]" để thấy chuỗi bị cắt. Placeholder `{x}` và
// cú pháp ICU plural/select giữ nguyên, chỉ biến đổi phần chữ bên trong các nhánh.

// Chỉ dùng ký tự có trong Be Vietnam Pro (test kiểm cmap) để thử đúng font thật, không rơi về font dự phòng.
export const DAU = {
  a: 'ả',
  c: 'ç',
  d: 'đ',
  e: 'ẽ',
  g: 'ğ',
  i: 'ỉ',
  l: 'ł',
  n: 'ñ',
  o: 'ở',
  r: 'ř',
  s: 'š',
  t: 'ť',
  u: 'ữ',
  w: 'ŵ',
  y: 'ỹ',
  z: 'ž',
  A: 'Ả',
  C: 'Ç',
  D: 'Đ',
  E: 'Ẽ',
  G: 'Ğ',
  I: 'Ỉ',
  L: 'Ł',
  N: 'Ñ',
  O: 'Ở',
  R: 'Ř',
  S: 'Š',
  T: 'Ť',
  U: 'Ữ',
  W: 'Ŵ',
  Y: 'Ỹ',
  Z: 'Ž',
};

/** Đổi chữ Latin sang biến thể có dấu (phần văn bản thuần, không chứa ngoặc nhọn). */
export function doiDau(s) {
  return [...s].map((c) => DAU[c] ?? c).join('');
}

/** Vị trí ngoặc đóng khớp với ngoặc mở tại [i]. */
function dongNgoac(s, i) {
  let sau = 0;
  for (let k = i; k < s.length; k++) {
    if (s[k] === '{') sau++;
    else if (s[k] === '}' && --sau === 0) return k;
  }
  throw new Error(`thiếu "}" trong: ${s}`);
}

/** Biến đổi phần chữ của một thông điệp ICU, giữ nguyên placeholder và từ khoá. */
export function bienDoiIcu(s) {
  let kq = '';
  let i = 0;
  while (i < s.length) {
    if (s[i] !== '{') {
      const j = s.indexOf('{', i);
      kq += doiDau(s.slice(i, j < 0 ? s.length : j));
      i = j < 0 ? s.length : j;
      continue;
    }
    const k = dongNgoac(s, i);
    const trong = s.slice(i + 1, k);
    const m = /^(\s*\w+\s*,\s*(?:plural|select)\s*,)([\s\S]*)$/.exec(trong);
    if (!m) {
      kq += s.slice(i, k + 1);
    } else {
      // Nhánh: khoá (=1, one, other, male...) + {thông điệp con}.
      let nhanh = '';
      let p = 0;
      const than = m[2];
      while (p < than.length) {
        const mo = than.indexOf('{', p);
        if (mo < 0) {
          nhanh += than.slice(p);
          break;
        }
        const dong = dongNgoac(than, mo);
        nhanh += than.slice(p, mo) + '{' + bienDoiIcu(than.slice(mo + 1, dong)) + '}';
        p = dong + 1;
      }
      kq += '{' + m[1] + nhanh + '}';
    }
    i = k + 1;
  }
  return kq;
}

/** Chuỗi -> chuỗi pseudo: có dấu + kéo dài ~40% (tối thiểu 2 ký tự) + bọc [ ]. */
export function gia(s) {
  const chu = s.replace(/\{[^{}]*\}/g, '').length;
  const them = Math.max(2, Math.ceil(chu * 0.4));
  return `[${bienDoiIcu(s)} ${'·'.repeat(them)}]`;
}

/** ARB en (object) -> ARB en_XA: chỉ khoá thông điệp, bỏ metadata `@...`. */
export function sinhArbGia(arbEn) {
  const kq = { '@@locale': 'en_XA' };
  for (const [k, v] of Object.entries(arbEn)) {
    if (k.startsWith('@')) continue;
    kq[k] = gia(v);
  }
  return kq;
}
