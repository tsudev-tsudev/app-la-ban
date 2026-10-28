// Hàm THUẦN dựng hình logo (SVG) - 3 phương án biểu tượng trong hộp 512x512, tâm (256, 256).
// Mỗi hàm nhận { id, mono } : id làm tiền tố cho gradient (ghép nhiều logo vào một SVG không trùng id);
// mono = true -> một màu (currentColor), mặt sáng / tối phân biệt bằng độ mờ (dùng cho icon themed Android 13+).

export const MAU = {
  cyan: '#00E5FF',
  cyanToi: '#00B8D4',
  coral: '#FF6D00',
  coralSang: '#FF8A3D',
  xanh: '#1A56DB',
  xanhDien: '#2962FF',
  xanhSang: '#4C8DFF',
  xanhNhat: '#9DBDFF',
  chu: '#0B1220',
  trang: '#FFFFFF',
};

const C = 256;
const r2 = (n) => Math.round(n * 100) / 100;

/** Điểm theo góc la bàn (0 = Bắc, theo chiều kim đồng hồ, độ) và bán kính. */
export function diem(goc, banKinh) {
  const t = ((goc - 90) * Math.PI) / 180;
  return [r2(C + banKinh * Math.cos(t)), r2(C + banKinh * Math.sin(t))];
}

const pts = (...ds) => ds.map((p) => p.join(',')).join(' ');
const tamGiac = (a, b, c, fill, extra = '') => `<polygon points="${pts(a, b, c)}" fill="${fill}"${extra}/>`;

/** Một cánh hoa gió chia hai mặt (tối bên phải, sáng bên trái theo chiều nhìn ra ngoài). */
function canh(goc, dai, rong, mauToi, mauSang) {
  const dinh = diem(goc, dai);
  const tam = [C, C];
  return (
    tamGiac(dinh, tam, diem(goc + 45, rong), mauToi) + tamGiac(dinh, tam, diem(goc - 45, rong), mauSang)
  );
}

function to(mono, mau, doMo = 1) {
  if (!mono) return `"${mau}"`;
  return doMo === 1 ? '"currentColor"' : `"currentColor" fill-opacity="${doMo}"`;
}
// Helper cho thuộc tính fill có thể kèm fill-opacity: trả chuỗi đã có dấu nháy.
const f = (mono, mau, doMo) => to(mono, mau, doMo).slice(1, -1);

function tick(goc, r1, r2_, rong, mau) {
  const [x1, y1] = diem(goc, r1);
  const [x2, y2] = diem(goc, r2_);
  return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${mau}" stroke-width="${rong}" stroke-linecap="round"/>`;
}

/** A - Hoa gió cổ điển: vòng tròn + 8 cánh, cánh Bắc cyan, cánh Nam coral. */
export function hinhA({ mono = false } = {}) {
  const o = [];
  const vien = mono ? 'currentColor' : MAU.xanh;
  o.push(`<circle cx="${C}" cy="${C}" r="226" fill="none" stroke="${vien}" stroke-width="22"/>`);
  for (let g = 0; g < 360; g += 30) if (g % 90) o.push(tick(g, 182, 200, 10, vien));
  for (const g of [45, 135, 225, 315]) {
    o.push(canh(g, 150, 34, f(mono, MAU.xanhSang, 0.7), f(mono, MAU.xanhNhat, 0.45)));
  }
  o.push(canh(90, 196, 44, f(mono, MAU.xanh), f(mono, MAU.xanhDien, 0.7)));
  o.push(canh(270, 196, 44, f(mono, MAU.xanh), f(mono, MAU.xanhDien, 0.7)));
  o.push(canh(180, 214, 48, f(mono, MAU.coral), f(mono, MAU.coralSang, 0.7)));
  o.push(canh(0, 214, 48, f(mono, MAU.cyanToi), f(mono, MAU.cyan, 0.7)));
  o.push(
    `<circle cx="${C}" cy="${C}" r="22" fill="${mono ? 'none' : MAU.trang}" stroke="${vien}" stroke-width="10"/>`,
  );
  return o.join('');
}

/** B - Vòng tối giản + kim kim cương: vòng gradient xanh, 2 chấm Đông/Tây, kim đứng Bắc cyan / Nam coral. */
export function hinhB({ id = 'b', mono = false } = {}) {
  const o = [];
  if (!mono) {
    o.push(
      `<defs><linearGradient id="${id}-vong" x1="0" y1="0" x2="1" y2="1">` +
        `<stop offset="0" stop-color="${MAU.xanhDien}"/><stop offset="1" stop-color="${MAU.xanh}"/></linearGradient></defs>`,
    );
  }
  const vong = mono ? 'currentColor' : `url(#${id}-vong)`;
  o.push(`<circle cx="${C}" cy="${C}" r="200" fill="none" stroke="${vong}" stroke-width="44"/>`);
  for (const g of [90, 270]) {
    const [x, y] = diem(g, 146);
    o.push(`<circle cx="${x}" cy="${y}" r="11" fill="${mono ? 'currentColor' : MAU.xanhSang}"/>`);
  }
  const goc = 0;
  const dai = 172;
  const rong = 50;
  const dinhB = diem(goc, dai);
  const dinhN = diem(goc + 180, dai);
  const trai = diem(goc - 90, rong);
  const phai = diem(goc + 90, rong);
  o.push(tamGiac(dinhB, [C, C], phai, f(mono, MAU.cyanToi)));
  o.push(tamGiac(dinhB, [C, C], trai, f(mono, MAU.cyan, 0.7)));
  o.push(tamGiac(dinhN, [C, C], phai, f(mono, MAU.coral, 0.45)));
  o.push(tamGiac(dinhN, [C, C], trai, f(mono, MAU.coralSang, 0.3)));
  o.push(
    `<circle cx="${C}" cy="${C}" r="18" fill="${mono ? 'currentColor' : MAU.trang}" stroke="${mono ? 'none' : MAU.chu}" stroke-width="8"/>`,
  );
  return o.join('');
}

/** Cánh sao lõm: hai nửa, mỗi nửa là đường cong từ đỉnh về tâm qua điểm eo. */
function canhSao(goc, dai, eo, mauToi, mauSang) {
  const dinh = diem(goc, dai);
  const p = diem(goc + 45, eo);
  const t = diem(goc - 45, eo);
  const nua = (ben, mau) => `<path d="M${dinh} Q${ben} ${C},${C} Z" fill="${mau}"/>`;
  return nua(p, mauToi) + nua(t, mauSang);
}

/** C - Sao bốn cánh trong ô bo tròn: nền gradient xanh, vòng mảnh, sao lõm Bắc cyan / Nam coral / Đông Tây trắng. */
export function hinhC({ id = 'c', mono = false } = {}) {
  const o = [];
  if (!mono) {
    o.push(
      `<defs><linearGradient id="${id}-nen" x1="0" y1="0" x2="1" y2="1">` +
        `<stop offset="0" stop-color="${MAU.xanhDien}"/><stop offset="1" stop-color="${MAU.xanh}"/></linearGradient></defs>`,
    );
    o.push(`<rect x="8" y="8" width="496" height="496" rx="120" fill="url(#${id}-nen)"/>`);
  } else {
    o.push(`<rect x="8" y="8" width="496" height="496" rx="120" fill="none" stroke="currentColor" stroke-width="20"/>`);
  }
  const net = mono ? 'currentColor' : MAU.trang;
  o.push(`<circle cx="${C}" cy="${C}" r="176" fill="none" stroke="${net}" stroke-opacity="0.35" stroke-width="6"/>`);
  for (let g = 0; g < 360; g += 30) if (g % 90) o.push(tick(g, 186, 204, 8, net).replace('/>', ' stroke-opacity="0.5"/>'));
  o.push(canhSao(90, 156, 78, f(mono, MAU.trang, 0.85), f(mono, MAU.trang, 0.6)));
  o.push(canhSao(270, 156, 78, f(mono, MAU.trang, 0.85), f(mono, MAU.trang, 0.6)));
  o.push(canhSao(180, 214, 92, f(mono, MAU.coral), f(mono, MAU.coralSang, 0.7)));
  o.push(canhSao(0, 214, 92, f(mono, MAU.cyan), f(mono, '#7DF2FF', 0.7)));
  return o.join('');
}

export const PHUONG_AN = {
  a: { ten: 'A - Hoa gió cổ điển', hinh: hinhA },
  b: { ten: 'B - Vòng tối giản + kim kim cương', hinh: hinhB },
  c: { ten: 'C - Sao bốn cánh trong ô bo tròn', hinh: hinhC },
};

/** Bọc nội dung thành tệp SVG độc lập. */
export function svg(w, h, noiDung, extra = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"${extra}>${noiDung}</svg>\n`;
}
