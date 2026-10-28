// Tiện ích xuất ảnh thương hiệu: wordmark "La bàn" dạng path, ghép bản ngang / dọc, SVG -> PNG (resvg), PNG -> ICO.
import { Buffer } from 'node:buffer';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import { Resvg } from '@resvg/resvg-js';
import { MAU } from './logo-hinh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const docFont = (ten) => {
  const b = readFileSync(join(goc, 'design/fonts', ten));
  return opentype.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
};
const fontDam = docFont('BeVietnamPro-Bold.ttf');

/** Wordmark "La bàn" dạng path (không phụ thuộc font máy xem). Trả { d1, d2, rong } cỡ chữ `co`, baseline y=0. */
export function wordmark(co) {
  const p1 = fontDam.getPath('La', 0, 0, co, { kerning: true });
  const x2 = fontDam.getAdvanceWidth('La ', co, { kerning: true }) - co * 0.04;
  const p2 = fontDam.getPath('bàn', x2, 0, co, { kerning: true });
  const bb = p2.getBoundingBox();
  return { d1: p1.toPathData(2), d2: p2.toPathData(2), rong: bb.x2 };
}

function chu(co, x, y, mauLa, mauBan) {
  const w = wordmark(co);
  return {
    rong: w.rong,
    svg: `<g transform="translate(${x} ${y})"><path d="${w.d1}" fill="${mauLa}"/><path d="${w.d2}" fill="${mauBan}"/></g>`,
  };
}

/** Bản ngang: biểu tượng 512 thu về cao H, chữ bên phải. */
export function banNgang(hinh, nen = 'sang') {
  const H = 160;
  const co = 112;
  const [mLa, mBan] = nen === 'sang' ? [MAU.chu, MAU.xanh] : [MAU.trang, MAU.xanhSang];
  const c = chu(co, H + 36, H / 2 + co * 0.36, mLa, mBan);
  const w = Math.ceil(H + 36 + c.rong + 8);
  return { w, h: H, noiDung: `<g transform="scale(${H / 512})">${hinh}</g>${c.svg}` };
}

/** Bản dọc: biểu tượng trên, chữ dưới, căn giữa. */
export function banDoc(hinh, nen = 'sang') {
  const S = 240;
  const co = 96;
  const [mLa, mBan] = nen === 'sang' ? [MAU.chu, MAU.xanh] : [MAU.trang, MAU.xanhSang];
  const w0 = wordmark(co).rong;
  const W = Math.ceil(Math.max(S, w0) + 16);
  const c = chu(co, (W - w0) / 2, S + 24 + co * 0.75, mLa, mBan);
  return {
    w: W,
    h: Math.ceil(S + 24 + co * 1.05),
    noiDung: `<g transform="translate(${(W - S) / 2} 0) scale(${S / 512})">${hinh}</g>${c.svg}`,
  };
}

export function png(svgText, rong) {
  return new Resvg(svgText, {
    fitTo: { mode: 'width', value: rong },
    background: 'rgba(0,0,0,0)',
    font: {
      fontFiles: ['Bold', 'Regular'].map((w) => join(goc, `design/fonts/BeVietnamPro-${w}.ttf`)),
      loadSystemFonts: false,
      defaultFontFamily: 'Be Vietnam Pro',
    },
  })
    .render()
    .asPng();
}

/** Gói các PNG (vuông, <= 256 px) thành tệp .ico (mục PNG nhúng, hỗ trợ từ Windows Vista). */
export function ico(dsPng) {
  const dau = Buffer.alloc(6 + 16 * dsPng.length);
  dau.writeUInt16LE(0, 0);
  dau.writeUInt16LE(1, 2);
  dau.writeUInt16LE(dsPng.length, 4);
  let viTri = dau.length;
  dsPng.forEach(({ co, du }, i) => {
    const o = 6 + 16 * i;
    dau.writeUInt8(co >= 256 ? 0 : co, o);
    dau.writeUInt8(co >= 256 ? 0 : co, o + 1);
    dau.writeUInt16LE(1, o + 4);
    dau.writeUInt16LE(32, o + 6);
    dau.writeUInt32LE(du.length, o + 8);
    dau.writeUInt32LE(viTri, o + 12);
    viTri += du.length;
  });
  return Buffer.concat([dau, ...dsPng.map((p) => p.du)]);
}
