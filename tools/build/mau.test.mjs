import { test } from 'node:test';
import assert from 'node:assert/strict';
import { docHex, doChoi, tuongPhan, kiemCap } from './mau.mjs';
import { mauDart, mauCss, kebab, sinhCss, sinhDart } from './tokens-sinh.mjs';

test('docHex đọc 6 và 8 ký tự, từ chối sai định dạng', () => {
  assert.deepEqual(docHex('#00E5FF'), { r: 0, g: 229, b: 255, a: 1 });
  assert.equal(docHex('#80000000').a.toFixed(2), '0.50');
  assert.throws(() => docHex('00E5FF'));
  assert.throws(() => docHex('#FFF'));
});

test('độ chói và tương phản theo WCAG', () => {
  assert.equal(doChoi('#000000'), 0);
  assert.equal(doChoi('#FFFFFF'), 1);
  assert.equal(tuongPhan('#000000', '#FFFFFF'), 21);
  assert.equal(tuongPhan('#FFFFFF', '#000000'), 21);
  assert.equal(tuongPhan('#777777', '#777777'), 1);
  assert.ok(Math.abs(tuongPhan('#767676', '#FFFFFF') - 4.54) < 0.01);
});

test('kiemCap báo đạt / trượt và thiếu token', () => {
  const bang = { light: { a: '#000000', b: '#FFFFFF', c: '#EEEEEE' } };
  const kq = kiemCap(bang, [
    { fg: 'a', bg: 'b', min: 4.5 },
    { fg: 'c', bg: 'b', min: 4.5 },
  ]);
  assert.deepEqual(
    kq.map((r) => r.dat),
    [true, false],
  );
  assert.throws(() => kiemCap(bang, [{ fg: 'x', bg: 'b', min: 3 }]));
});

test('chuyển màu sang Dart / CSS và tên kebab', () => {
  assert.equal(mauDart('#00e5ff'), 'Color(0xFF00E5FF)');
  assert.equal(mauDart('#330B1220'), 'Color(0x330B1220)');
  assert.equal(mauCss('#1A56DB'), '#1a56db');
  assert.equal(mauCss('#80000000'), 'rgb(0 0 0 / 0.502)');
  assert.equal(kebab('primaryDeep'), 'primary-deep');
  assert.equal(kebab('bodySmall'), 'body-small');
});

const mini = {
  color: { light: { bg: '#FFFFFF', text: '#000000' }, dark: { bg: '#000000', text: '#FFFFFF' } },
  spacing: { xs: 8 },
  radius: { sm: 8 },
  shadow: {
    light: { sm: [{ x: 0, y: 1, blur: 3, spread: 0, color: '#1F000000' }] },
    dark: { sm: [{ x: 0, y: 1, blur: 3, spread: 0, color: '#66000000' }] },
  },
  glass: { blur: 16, light: { fill: '#B8FFFFFF', border: '#99FFFFFF' }, dark: { fill: '#99000000', border: '#33FFFFFF' } },
  font: { family: 'F', cssFamily: 'F, sans-serif' },
  type: { body: { size: 16, height: 24, weight: 400 }, num: { size: 32, height: 40, weight: 600, tabular: true } },
  breakpoint: { medium: 600 },
  motion: { fast: 120 },
};

test('sinhDart tạo lớp và hằng đúng', () => {
  const d = sinhDart(mini);
  assert.match(d, /static const light = LbColors\(\n {4}bg: Color\(0xFFFFFFFF\),/);
  assert.match(d, /static const double xs = 8;/);
  assert.match(d, /height: 1\.5, fontWeight: FontWeight\.w400\);/);
  assert.match(d, /num = TextStyle\(.*FontFeature\.tabularFigures\(\)/);
  assert.match(d, /Duration fast = Duration\(milliseconds: 120\)/);
  assert.equal(sinhDart(mini), d, 'sinh lặp lại phải giống hệt');
});

test('sinhCss có biến theme, dark theo media và data-theme, không comment', () => {
  const c = sinhCss(mini);
  assert.match(c, /--lb-color-bg:#ffffff/);
  assert.match(c, /@media \(prefers-color-scheme:dark\)\{:root:not\(\[data-theme="light"\]\)\{--lb-color-bg:#000000/);
  assert.match(c, /\[data-theme="dark"\]\{--lb-color-bg:#000000/);
  assert.match(c, /--lb-type-num:600 2rem\/2\.5rem var\(--lb-font-family\)/);
  assert.doesNotMatch(c, /\/\*/);
});

test('light và dark lệch bộ khoá thì báo lỗi', () => {
  const sai = { ...mini, color: { light: { bg: '#FFFFFF' }, dark: { text: '#000000' } } };
  assert.throws(() => sinhCss(sai));
  assert.throws(() => sinhDart(sai));
});

test('kiemIcon: đạt quy ước và bắt lỗi màu cứng / nét lệch', async () => {
  const { kiemIcon } = await import('./icon-luat.mjs');
  const dau =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
  assert.deepEqual(kiemIcon(`${dau}<path d="M3 3h18"/></svg>`), []);
  assert.equal(kiemIcon(`${dau}<path fill="#FF0000" d="M3 3h18"/></svg>`).length, 2);
  assert.equal(kiemIcon(`${dau}<path stroke-width="1.5" d="M3 3h18"/></svg>`).length, 1);
  assert.equal(kiemIcon(`${dau}<text>x</text></svg>`).length, 1);
  assert.ok(kiemIcon('<svg viewBox="0 0 48 48"></svg>').length >= 5);
  assert.deepEqual(kiemIcon('<g/>'), ['không có thẻ <svg>']);
});
