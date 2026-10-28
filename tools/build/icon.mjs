#!/usr/bin/env node
// Bộ icon 24dp: kiểm quy ước mọi tệp design/icons/*.svg và (tuỳ chọn) xuất ảnh xem trước.
//   node tools/build/icon.mjs            kiểm (dùng trong cổng)
//   node tools/build/icon.mjs xem-truoc  kiểm + ghi design/icons/xem-truoc.png
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { kiemIcon } from './icon-luat.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const thuMuc = join(goc, 'design/icons');
const tep = readdirSync(thuMuc).filter((t) => t.endsWith('.svg')).sort();
let loi = 0;
for (const t of tep) {
  for (const l of kiemIcon(readFileSync(join(thuMuc, t), 'utf8'))) {
    console.error(`✗ design/icons/${t}: ${l}`);
    loi++;
  }
}
if (loi) process.exit(1);
console.log(`icon 24dp: ${tep.length} tệp đúng quy ước ✓`);

if (process.argv[2] === 'xem-truoc') {
  const { png } = await import('./anh.mjs');
  const { svg } = await import('./logo-hinh.mjs');
  const O = 150;
  const W = tep.length * O;
  const hang = (y, nen, mau, co) =>
    `<rect y="${y}" width="${W}" height="${O}" fill="${nen}"/>` +
    tep
      .map((t, i) => {
        const trong = readFileSync(join(thuMuc, t), 'utf8').replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
        const x = i * O + (O - co) / 2;
        return (
          `<g transform="translate(${x} ${y + 30}) scale(${co / 24})" fill="none" stroke="${mau}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${trong}</g>` +
          `<text x="${i * O + O / 2}" y="${y + O - 18}" text-anchor="middle" font-family="Be Vietnam Pro" font-size="14" fill="${mau}">${t.replace('.svg', '')}</text>`
        );
      })
      .join('');
  const anh = svg(W, O * 2, hang(0, '#F8FAFC', '#0B1220', 72) + hang(O, '#0B1220', '#E8EEF7', 72));
  writeFileSync(join(thuMuc, 'xem-truoc.png'), png(anh, W));
  console.log('ghi design/icons/xem-truoc.png');
}
