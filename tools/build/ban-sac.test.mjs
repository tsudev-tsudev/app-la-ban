import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { docMau, hexAlpha, phu, chuAnToan, gopMau, docBoGoc, docTokens, MA_SAN_PHAM } from './ban-sac.mjs';
import { tuongPhan } from './mau.mjs';

test('docMau / hexAlpha / phu: rgba -> #AARRGGBB, phủ glow lên nền', () => {
  assert.deepEqual(docMau('rgba(177, 76, 3, 0.1)'), { r: 177, g: 76, b: 3, a: 0.1 });
  assert.equal(hexAlpha('#ff843f'), '#FF843F');
  assert.equal(hexAlpha('rgba(10, 10, 10, 0.45)'), '#730A0A0A');
  assert.equal(phu('rgba(0, 0, 0, 0.5)', '#FFFFFF'), '#808080');
  assert.throws(() => docMau('#FFF'));
});

test('chuAnToan: giữ màu đã đạt, pha đậm màu chưa đạt tới >= 4.5 trên mọi nền', () => {
  assert.equal(chuAnToan('#0A0A0A', ['#FFFFFF'], false), '#0A0A0A');
  const ra = chuAnToan('#DC2626', ['#FAFAFA', '#F4F4F5'], false);
  assert.notEqual(ra, '#DC2626');
  for (const n of ['#FAFAFA', '#F4F4F5']) assert.ok(tuongPhan(ra, n) >= 4.5);
});

test('gopMau: màu chính lấy từ products/compass.json, nền / trạng thái từ lớp nền', () => {
  const nen = JSON.parse(readFileSync('.standards/tokens/design-tokens.json', 'utf8'));
  const sp = JSON.parse(readFileSync(`.standards/tokens/products/${MA_SAN_PHAM}.json`, 'utf8'));
  const c = gopMau(nen, sp);
  assert.equal(c.light.primary, sp.colors.light.primary);
  assert.equal(c.dark.primary, sp.colors.dark.primary);
  assert.equal(c.dark.bg, nen.color.dark['bg-base']);
  assert.equal(c.light.danger, nen.color.light.danger);
  assert.deepEqual(Object.keys(c.light), Object.keys(c.dark));
  assert.throws(() => gopMau(nen, {}));
});

test('docBoGoc: đọc bo góc shape từ products.css, thiếu khối thì đỏ', () => {
  const css = readFileSync('.standards/tokens/products.css', 'utf8');
  assert.deepEqual(docBoGoc(css, MA_SAN_PHAM), { sm: 8, md: 14, lg: 20, control: 999 });
  assert.throws(() => docBoGoc(css, 'khong-co'));
});

test('docTokens: design/tokens.json không còn tự khai bảng màu', () => {
  assert.equal(JSON.parse(readFileSync('design/tokens.json', 'utf8')).color, undefined);
  const t = docTokens();
  assert.equal(t.radius.control, 999);
  assert.ok(t.color.light.tint && t.color.dark.tint);
});
