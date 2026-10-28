#!/usr/bin/env node
// Xuất logo: SVG (biểu tượng, bản ngang, bản dọc, đơn sắc) cho từng phương án + ảnh PNG so sánh.
//   node tools/build/logo.mjs phuong-an     -> design/logo/phuong-an/<a|b|c>/*.svg + so-sanh.png
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PHUONG_AN, MAU, svg } from './logo-hinh.mjs';
import { banNgang, banDoc, png } from './anh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');

function xuatPhuongAn() {
  const thuMuc = join(goc, 'design/logo/phuong-an');
  const hang = [];
  const NEN_SANG = '#F8FAFC';
  const NEN_TOI = '#0B1220';
  const W = 1800;
  const HH = 300;
  let y = 90;
  for (const [ma, { ten, hinh }] of Object.entries(PHUONG_AN)) {
    const d = join(thuMuc, ma);
    mkdirSync(d, { recursive: true });
    const mau = hinh({ id: `${ma}0` });
    writeFileSync(join(d, 'bieu-tuong.svg'), svg(512, 512, mau));
    writeFileSync(join(d, 'don-sac.svg'), svg(512, 512, hinh({ id: `${ma}m`, mono: true }), ` color="${MAU.chu}"`));
    const ng = banNgang(mau);
    writeFileSync(join(d, 'ngang.svg'), svg(ng.w, ng.h, ng.noiDung));
    const ngT = banNgang(hinh({ id: `${ma}t` }), 'toi');
    writeFileSync(join(d, 'ngang-nen-toi.svg'), svg(ngT.w, ngT.h, ngT.noiDung));
    const dc = banDoc(mau);
    writeFileSync(join(d, 'doc.svg'), svg(dc.w, dc.h, dc.noiDung));

    // Một hàng ảnh so sánh: nhãn | biểu tượng nền sáng | nền tối | đơn sắc | cỡ nhỏ 48/32/24 | bản ngang sáng / tối.
    const k = (s, x, yy, id, extra = {}) =>
      `<g transform="translate(${x} ${yy}) scale(${s / 512})"${extra.color ? ` color="${extra.color}"` : ''}>${hinh({ id, mono: !!extra.color })}</g>`;
    const ngS = banNgang(hinh({ id: `${ma}h1` }));
    const ngD = banNgang(hinh({ id: `${ma}h2` }), 'toi');
    const sc = 0.62;
    hang.push(
      `<text x="24" y="${y - 14}" font-family="Be Vietnam Pro" font-weight="700" font-size="30" fill="${MAU.chu}">${ten}</text>`,
      `<rect x="20" y="${y}" width="${W - 40}" height="${HH - 60}" rx="24" fill="${NEN_SANG}" stroke="#CBD5E1"/>`,
      k(200, 40, y + 20, `${ma}p1`),
      `<rect x="260" y="${y + 20}" width="200" height="200" rx="24" fill="${NEN_TOI}"/>`,
      k(176, 272, y + 32, `${ma}p2`),
      k(200, 480, y + 20, `${ma}p3`, { color: MAU.chu }),
      k(48, 700, y + 96, `${ma}p4`),
      k(32, 760, y + 104, `${ma}p5`),
      k(24, 804, y + 108, `${ma}p6`),
      `<g transform="translate(860 ${y + 70}) scale(${sc})">${ngS.noiDung}</g>`,
      `<rect x="${860 + ngS.w * sc + 24}" y="${y + 50}" width="${ngD.w * sc + 40}" height="${160 * sc + 40}" rx="16" fill="${NEN_TOI}"/>`,
      `<g transform="translate(${860 + ngS.w * sc + 44} ${y + 70}) scale(${sc})">${ngD.noiDung}</g>`,
    );
    y += HH;
  }
  const H = y - 30;
  const tong = svg(W, H, `<rect width="${W}" height="${H}" fill="#FFFFFF"/>${hang.join('')}`);
  writeFileSync(join(thuMuc, 'so-sanh.png'), png(tong, W));
  for (const ma of Object.keys(PHUONG_AN)) {
    writeFileSync(join(thuMuc, ma, 'bieu-tuong-512.png'), png(readFileSync(join(thuMuc, ma, 'bieu-tuong.svg'), 'utf8'), 512));
  }
  console.log('ghi design/logo/phuong-an/{a,b,c}/*.svg + so-sanh.png');
}

const lenh = process.argv[2];
if (lenh === 'phuong-an') xuatPhuongAn();
else {
  console.error('Dùng: node tools/build/logo.mjs phuong-an');
  process.exit(2);
}
