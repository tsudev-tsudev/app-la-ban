#!/usr/bin/env node
// Xuất toàn bộ tài sản thương hiệu từ logo đã chốt (phương án B, chốt 28/10/2026 - xem design/BRAND.md):
// logo SVG/PNG, app icon iOS + Android (adaptive, monochrome, legacy, nhãn flavor dev/stg, app Pro), splash Android/iOS,
// favicon + apple-touch + OG image cho web, ảnh xem trước launcher.
//   node tools/build/thuong-hieu.mjs
import { Buffer } from 'node:buffer';
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync, crc32 } from 'node:zlib';
import { Resvg } from '@resvg/resvg-js';
import { hinhB as hinh, MAU, svg } from './logo-hinh.mjs';
import { banNgang, banDoc, png, ico, wordmark } from './anh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const tokens = JSON.parse(readFileSync(join(goc, 'design/tokens.json'), 'utf8'));
const ghi = (tep, noiDung) => {
  const p = join(goc, tep);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, noiDung);
};

const NEN_ICON = ['#FFFFFF', '#DCE9FF'];
const DPI = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
// Pro (QUYET_DINH Q56): app trả phí không quảng cáo - cùng kiểu nhãn DEV, viên nhãn xanh lá token success (chữ tối, AA).
const NHAN = {
  dev: { chu: 'DEV', mau: MAU.coral },
  staging: { chu: 'STG', mau: '#FFB300' },
  pro: { chu: 'PRO', mau: tokens.color.light.success },
  // Biểu tượng sản phẩm Play (M1a, Q55): mỗi gói một ảnh riêng (Play yêu cầu), cùng viên nhãn xanh lá của Pro.
  'pro-thang': { chu: 'THÁNG', mau: tokens.color.light.success },
  'pro-nam': { chu: 'NĂM', mau: tokens.color.light.success },
  'pro-vinh-vien': { chu: 'VĨNH VIỄN', mau: tokens.color.light.success },
};

/** PNG RGB không kênh alpha (App Store từ chối icon 1024 có alpha). Ảnh phải phủ kín nền. */
function pngKhongAlpha(svgText, rong) {
  // Cùng font với png() (anh.mjs): nhãn PRO trên icon store phải là Be Vietnam Pro, không phải font hệ thống.
  const anh = new Resvg(svgText, {
    fitTo: { mode: 'width', value: rong },
    font: {
      fontFiles: ['Bold', 'Regular'].map((w) => join(goc, `design/fonts/BeVietnamPro-${w}.ttf`)),
      loadSystemFonts: false,
      defaultFontFamily: 'Be Vietnam Pro',
    },
  }).render();
  const { width: w, height: h } = anh;
  const rgba = anh.pixels;
  const tho = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const s = (y * w + x) * 4;
      const d = y * (w * 3 + 1) + 1 + x * 3;
      tho[d] = rgba[s];
      tho[d + 1] = rgba[s + 1];
      tho[d + 2] = rgba[s + 2];
    }
  }
  const khoi = (loai, du) => {
    const dai = Buffer.alloc(4);
    dai.writeUInt32BE(du.length);
    const ld = Buffer.concat([Buffer.from(loai, 'ascii'), du]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(ld));
    return Buffer.concat([dai, ld, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    khoi('IHDR', ihdr),
    khoi('IDAT', deflateSync(tho, { level: 9 })),
    khoi('IEND', Buffer.alloc(0)),
  ]);
}

const nenGradient = (id, w, h, rx = 0) =>
  `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${NEN_ICON[0]}"/>` +
  `<stop offset="1" stop-color="${NEN_ICON[1]}"/></linearGradient></defs><rect width="${w}" height="${h}" rx="${rx}" fill="url(#${id})"/>`;

/** Biểu tượng 512 đặt giữa hộp `hop` px, rộng `co` px. */
const datGiua = (hop, co, noiDung, extra = '') =>
  `<g transform="translate(${(hop - co) / 2} ${(hop - co) / 2}) scale(${co / 512})"${extra}>${noiDung}</g>`;

/** Nhãn flavor (DEV / STG / PRO) dạng viên thuốc ở dưới, trong vùng an toàn. `hop` = cạnh ảnh, `cy` = tâm nhãn. */
function nhanFlavor(flavor, hop, cy, cao) {
  if (!flavor) return '';
  const { chu, mau } = NHAN[flavor];
  // Nhãn 3 ký tự giữ đúng cao x 2.5 như cũ; nhãn dài hơn nới theo số ký tự.
  const rong = Math.max(cao * 2.5, cao * (1 + 0.5 * [...chu].length));
  return (
    `<rect x="${(hop - rong) / 2}" y="${cy - cao / 2}" width="${rong}" height="${cao}" rx="${cao / 2}" fill="${mau}" stroke="#FFFFFF" stroke-width="${cao * 0.08}"/>` +
    `<text x="${hop / 2}" y="${cy + cao * 0.24}" text-anchor="middle" font-family="Be Vietnam Pro" font-weight="700" font-size="${cao * 0.62}" fill="${MAU.chu}">${chu}</text>`
  );
}

/** Icon vuông kín nền (iOS / store). */
const iconKin = (hop, flavor) =>
  svg(hop, hop, nenGradient('n', hop, hop) + datGiua(hop, hop * 0.68, hinh({ id: 'i' })) + nhanFlavor(flavor, hop, hop * 0.8, hop * 0.15));

/** Adaptive foreground 108dp: nội dung trong vùng an toàn 66dp. Trả SVG hộp 108 đơn vị. */
const tienCanh = (flavor, mono = false) =>
  svg(
    108,
    108,
    datGiua(108, 60, hinh({ id: 'f', mono }), mono ? ' color="#FFFFFF"' : '') + (mono ? '' : nhanFlavor(flavor, 108, 74, 12)),
  );

/** Icon legacy (API < 26) 48dp: ô bo tròn hoặc tròn có lề. */
const iconLegacy = (tron, flavor) => {
  const nen = tron
    ? `<defs><linearGradient id="n" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${NEN_ICON[0]}"/><stop offset="1" stop-color="${NEN_ICON[1]}"/></linearGradient></defs><circle cx="24" cy="24" r="22" fill="url(#n)"/>`
    : `<g transform="translate(2 2)">${nenGradient('n', 44, 44, 9)}</g>`;
  return svg(48, 48, nen + datGiua(48, 34, hinh({ id: 'l' })) + nhanFlavor(flavor, 48, 36, 7));
};

function xuatLogo() {
  const m = hinh({ id: 'b0' });
  ghi('design/logo/bieu-tuong.svg', svg(512, 512, m));
  ghi('design/logo/don-sac.svg', svg(512, 512, hinh({ id: 'bm', mono: true }), ` color="${MAU.chu}"`));
  for (const [ten, nen] of [
    ['', 'sang'],
    ['-nen-toi', 'toi'],
  ]) {
    const ng = banNgang(hinh({ id: 'bn' }), nen);
    ghi(`design/logo/ngang${ten}.svg`, svg(ng.w, ng.h, ng.noiDung));
    const dc = banDoc(hinh({ id: 'bd' }), nen);
    ghi(`design/logo/doc${ten}.svg`, svg(dc.w, dc.h, dc.noiDung));
  }
  ghi('design/logo/bieu-tuong-1024.png', png(svg(512, 512, m), 1024));
  ghi('design/logo/ngang-1200.png', png(readFileSync(join(goc, 'design/logo/ngang.svg'), 'utf8'), 1200));
}

function xuatAndroid() {
  const res = 'app/android/app/src';
  const adaptive = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
`;
  ghi(`${res}/main/res/mipmap-anydpi-v26/ic_launcher.xml`, adaptive);
  ghi(`${res}/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`, adaptive);
  ghi(
    `${res}/main/res/drawable/ic_launcher_background.xml`,
    `<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="315" android:startColor="${NEN_ICON[0]}" android:endColor="${NEN_ICON[1]}"/>
</shape>
`,
  );
  for (const [thuMuc, k] of Object.entries(DPI)) {
    ghi(`${res}/main/res/mipmap-${thuMuc}/ic_launcher_monochrome.png`, png(tienCanh(null, true), 108 * k));
    for (const flavor of [null, 'dev', 'staging']) {
      const nguon = flavor ?? 'main';
      ghi(`${res}/${nguon}/res/mipmap-${thuMuc}/ic_launcher_foreground.png`, png(tienCanh(flavor), 108 * k));
      ghi(`${res}/${nguon}/res/mipmap-${thuMuc}/ic_launcher.png`, png(iconLegacy(false, flavor), 48 * k));
      ghi(`${res}/${nguon}/res/mipmap-${thuMuc}/ic_launcher_round.png`, png(iconLegacy(true, flavor), 48 * k));
    }
    // Splash < API 31: bitmap 120dp giữa nền; API 31+: icon động 288dp, nội dung trong vòng 192dp.
    ghi(`${res}/main/res/drawable-${thuMuc}/splash_logo.png`, png(svg(512, 512, hinh({ id: 's' })), 120 * k));
    ghi(`${res}/main/res/drawable-${thuMuc}/splash_icon.png`, png(svg(288, 288, datGiua(288, 176, hinh({ id: 's' }))), 288 * k));
  }
  const { light, dark } = tokens.color;
  for (const [thuMuc, mau] of [
    ['values', light.bg],
    ['values-night', dark.bg],
  ]) {
    ghi(
      `${res}/main/res/${thuMuc}/colors.xml`,
      `<?xml version="1.0" encoding="utf-8"?>
<!-- Sinh bởi tools/build/thuong-hieu.mjs từ design/tokens.json (color.bg). -->
<resources>
    <color name="lb_splash_bg">${mau}</color>
</resources>
`,
    );
  }
  ghi('design/store/play-icon-512.png', pngKhongAlpha(iconKin(512), 512));
}

function xuatIos() {
  const thuMuc = 'app/ios/Runner/Assets.xcassets';
  const nd = JSON.parse(readFileSync(join(goc, thuMuc, 'AppIcon.appiconset/Contents.json'), 'utf8'));
  const daGhi = new Set();
  for (const anh of nd.images) {
    if (!anh.filename || daGhi.has(anh.filename)) continue;
    daGhi.add(anh.filename);
    const px = Math.round(parseFloat(anh.size) * parseInt(anh.scale, 10));
    ghi(`${thuMuc}/AppIcon.appiconset/${anh.filename}`, pngKhongAlpha(iconKin(1024), px));
  }
  for (const [ten, k] of [
    ['LaunchImage.png', 1],
    ['LaunchImage@2x.png', 2],
    ['LaunchImage@3x.png', 3],
  ]) {
    ghi(`${thuMuc}/LaunchImage.imageset/${ten}`, png(svg(512, 512, hinh({ id: 's' })), 128 * k));
  }
  const rgb = (hex) => {
    const n = parseInt(hex.slice(1), 16);
    return { red: ((n >> 16) & 255) / 255, green: ((n >> 8) & 255) / 255, blue: (n & 255) / 255 };
  };
  const mau = (hex) => {
    const c = rgb(hex);
    return {
      'color-space': 'srgb',
      components: { alpha: '1.000', red: c.red.toFixed(3), green: c.green.toFixed(3), blue: c.blue.toFixed(3) },
    };
  };
  ghi(
    `${thuMuc}/LaunchBackground.colorset/Contents.json`,
    JSON.stringify(
      {
        colors: [
          { idiom: 'universal', color: mau(tokens.color.light.bg) },
          {
            idiom: 'universal',
            appearances: [{ appearance: 'luminosity', value: 'dark' }],
            color: mau(tokens.color.dark.bg),
          },
        ],
        info: { author: 'xcode', version: 1 },
      },
      null,
      2,
    ) + '\n',
  );
}

function xuatWeb() {
  const m = svg(512, 512, hinh({ id: 'w' }));
  const touch = pngKhongAlpha(iconKin(180), 180);
  const favIco = ico([16, 32, 48].map((co) => ({ co, du: png(m, co) })));
  for (const site of ['web/landing/public', 'web/admin/public']) {
    ghi(`${site}/favicon.svg`, m);
    ghi(`${site}/favicon.ico`, favIco);
    ghi(`${site}/apple-touch-icon.png`, touch);
  }
  ghi('web/landing/public/icon-192.png', png(m, 192));
  ghi('web/landing/public/icon-512.png', png(m, 512));

  // OG image 1200x630: nền sáng, bản ngang lớn, khẩu hiệu song ngữ.
  const ng = banNgang(hinh({ id: 'o' }));
  const sc = 1.45;
  const x0 = (1200 - ng.w * sc) / 2;
  const og = svg(
    1200,
    630,
    nenGradient('n', 1200, 630) +
      `<circle cx="1080" cy="80" r="220" fill="${MAU.cyan}" fill-opacity="0.12"/>` +
      `<circle cx="120" cy="590" r="180" fill="${MAU.coral}" fill-opacity="0.10"/>` +
      `<g transform="translate(${x0} 150) scale(${sc})">${ng.noiDung}</g>` +
      `<text x="600" y="460" text-anchor="middle" font-family="Be Vietnam Pro" font-weight="700" font-size="44" fill="${MAU.chu}">La bàn thông minh - chính xác, riêng tư</text>` +
      `<text x="600" y="516" text-anchor="middle" font-family="Be Vietnam Pro" font-size="30" fill="#475569">Smart Compass for Android &amp; iOS</text>`,
  );
  ghi('web/landing/public/og.png', png(og, 1200));
  ghi('design/store/og-1200x630.png', png(og, 1200));

  // Ảnh nổi bật Google Play 1024x500 (R2): không alpha, chữ ít, chủ thể giữa (Play có thể cắt mép / phủ nút phát).
  const scP = 1.2;
  const xP = (1024 - ng.w * scP) / 2;
  const noiBat = svg(
    1024,
    500,
    nenGradient('p', 1024, 500) +
      `<circle cx="930" cy="60" r="200" fill="${MAU.cyan}" fill-opacity="0.12"/>` +
      `<circle cx="90" cy="470" r="160" fill="${MAU.coral}" fill-opacity="0.10"/>` +
      `<g transform="translate(${xP} 120) scale(${scP})">${ng.noiDung}</g>` +
      `<text x="512" y="390" text-anchor="middle" font-family="Be Vietnam Pro" font-weight="700" font-size="34" fill="${MAU.chu}">Bắc thực chính xác · Ngoại tuyến · Riêng tư</text>`,
  );
  ghi('design/store/play-feature-1024x500.png', pngKhongAlpha(noiBat, 1024));
}

/**
 * App "La bàn Pro" (M2, Q56): icon riêng để người dùng phân biệt bản không quảng cáo. `app_pro/` chưa có (M2 bước 1
 * tách vỏ app) nên tài nguyên Android đặt ở design/logo/pro/android/res - M2 chép sang `app_pro/android/app/src/main/res`
 * (adaptive XML + nền + monochrome dùng chung bản miễn phí). Flavor dev / staging của app Pro giữ nhãn DEV / STG.
 */
function xuatPro() {
  const res = 'design/logo/pro/android/res';
  for (const [thuMuc, k] of Object.entries(DPI)) {
    ghi(`${res}/mipmap-${thuMuc}/ic_launcher_foreground.png`, png(tienCanh('pro'), 108 * k));
    ghi(`${res}/mipmap-${thuMuc}/ic_launcher.png`, png(iconLegacy(false, 'pro'), 48 * k));
    ghi(`${res}/mipmap-${thuMuc}/ic_launcher_round.png`, png(iconLegacy(true, 'pro'), 48 * k));
  }
  ghi('design/logo/pro/bieu-tuong-pro-1024.png', pngKhongAlpha(iconKin(1024, 'pro'), 1024));
  ghi('design/store/pro/play-icon-512.png', pngKhongAlpha(iconKin(512, 'pro'), 512));
}

/** Biểu tượng sản phẩm trong Play Console (PNG 32 bit RGBA - Play yêu cầu, 512, 1:1): design/store/san-pham/<mã sản phẩm>.png. */
function xuatSanPham() {
  for (const [flavor, ma] of [['pro-thang', 'pro_thang'], ['pro-nam', 'pro_nam'], ['pro-vinh-vien', 'pro_vinh_vien']]) {
    ghi(`design/store/san-pham/${ma}.png`, png(iconKin(512, flavor), 512));
  }
  // Play Console ghi "Đừng chèn văn bản" vào biểu tượng sản phẩm: bản thay thế không chữ - phân biệt gói bằng số chấm
  // trắng trong viên nhãn xanh lá (1 tháng · 2 năm · 3 vĩnh viễn), cùng kích thước / vị trí viên nhãn có chữ.
  for (const [soCham, ma] of [[1, 'pro_thang'], [2, 'pro_nam'], [3, 'pro_vinh_vien']]) {
    ghi(`design/store/san-pham/khong-chu/${ma}.png`, png(iconKhongChu(512, soCham), 512));
  }
}

/** Icon kín nền + viên nhãn xanh lá chứa `soCham` chấm trắng, không ký tự nào (biểu tượng sản phẩm Play). */
function iconKhongChu(hop, soCham) {
  const cao = hop * 0.15;
  const cy = hop * 0.8;
  const rong = cao * 2.5;
  const r = cao * 0.2;
  const buoc = r * 3;
  const x0 = hop / 2 - ((soCham - 1) * buoc) / 2;
  const cham = Array.from({ length: soCham }, (_, i) => `<circle cx="${x0 + i * buoc}" cy="${cy}" r="${r}" fill="#FFFFFF"/>`).join('');
  return svg(
    hop,
    hop,
    nenGradient('n', hop, hop) +
      datGiua(hop, hop * 0.68, hinh({ id: 'i' })) +
      `<rect x="${(hop - rong) / 2}" y="${cy - cao / 2}" width="${rong}" height="${cao}" rx="${cao / 2}" fill="${tokens.color.light.success}" stroke="#FFFFFF" stroke-width="${cao * 0.08}"/>` +
      cham,
  );
}

/** Ảnh xem trước icon trên launcher: 3 nền (sáng, tối, ảnh) x mặt nạ tròn / squircle / themed + bản dev, stg, Pro. */
function xuatXemTruoc() {
  const NEN = [
    ['Nền sáng', '<rect width="100%" height="100%" fill="#EEF2F7"/>', '#0B1220'],
    ['Nền tối', '<rect width="100%" height="100%" fill="#101418"/>', '#FFFFFF'],
    [
      'Nền ảnh',
      '<defs><linearGradient id="anh" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF9A62"/><stop offset=".5" stop-color="#7B4DFF"/><stop offset="1" stop-color="#0F5C4D"/></linearGradient></defs><rect width="100%" height="100%" fill="url(#anh)"/>',
      '#FFFFFF',
    ],
  ];
  const O = 132;
  const W = 40 + 7 * (O + 40);
  const HANG = 230;
  const tienDich = (flavor) =>
    `<rect width="108" height="108" fill="url(#g)"/>` +
    tienCanh(flavor).replace(/^<svg[^>]*>/, '').replace(/<\/svg>\n$/, '');
  const defs = `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${NEN_ICON[0]}"/><stop offset="1" stop-color="${NEN_ICON[1]}"/></linearGradient>
    <clipPath id="tron"><circle cx="54" cy="54" r="40"/></clipPath>
    <clipPath id="squircle"><rect x="14" y="14" width="80" height="80" rx="22"/></clipPath>
    <clipPath id="vuong"><rect x="14" y="14" width="80" height="80" rx="12"/></clipPath></defs>`;
  const o = [defs];
  NEN.forEach(([ten, nen, mauChu], i) => {
    const y = i * HANG;
    o.push(`<svg x="0" y="${y}" width="${W}" height="${HANG}">${nen}`);
    o.push(`<text x="20" y="34" font-family="Be Vietnam Pro" font-weight="700" font-size="22" fill="${mauChu}">${ten}</text>`);
    const o1 = (j, nd, nhan) => {
      const x = 20 + j * (O + 40);
      return (
        `<g transform="translate(${x - 0.22 * O} ${40 - 0.1 * O}) scale(${(O * 1.35) / 108})">${nd}</g>` +
        `<text x="${x + O / 2}" y="${HANG - 22}" text-anchor="middle" font-family="Be Vietnam Pro" font-size="17" fill="${mauChu}">${nhan}</text>`
      );
    };
    const mono = tienCanh(null, true)
      .replace(/^<svg[^>]*>/, '')
      .replace(/<\/svg>\n$/, '')
      .replace('color="#FFFFFF"', 'color="#1B3A6B"');
    o.push(o1(0, `<g clip-path="url(#tron)">${tienDich(null)}</g>`, 'Pixel (tròn)'));
    o.push(o1(1, `<g clip-path="url(#squircle)">${tienDich(null)}</g>`, 'Squircle / iOS'));
    o.push(o1(2, `<g clip-path="url(#vuong)">${tienDich(null)}</g>`, 'Bo góc'));
    o.push(o1(3, `<g clip-path="url(#tron)"><rect width="108" height="108" fill="#D6E3FF"/>${mono}</g>`, 'Themed (A13+)'));
    o.push(o1(4, `<g clip-path="url(#tron)">${tienDich('dev')}</g>`, 'Flavor dev'));
    o.push(o1(5, `<g clip-path="url(#tron)">${tienDich('staging')}</g>`, 'Flavor staging'));
    o.push(o1(6, `<g clip-path="url(#tron)">${tienDich('pro')}</g>`, 'La bàn Pro'));
    o.push('</svg>');
  });
  ghi('design/logo/xem-truoc-launcher.png', png(svg(W, NEN.length * HANG, o.join('')), W));
}

xuatLogo();
xuatAndroid();
xuatIos();
xuatWeb();
xuatXemTruoc();
xuatPro();
xuatSanPham();
console.log(`ghi logo, icon Android/iOS, splash, favicon/OG, xem trước launcher (wordmark rộng ${Math.round(wordmark(100).rong)})`);
