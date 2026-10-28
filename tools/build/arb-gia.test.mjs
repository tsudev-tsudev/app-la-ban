import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import { DAU, doiDau, bienDoiIcu, gia, sinhArbGia } from './arb-gia-sinh.mjs';

test('doiDau đổi chữ có biến thể, giữ chữ còn lại, số và dấu câu', () => {
  assert.equal(doiDau('Map 1, OK!'), 'Mảp 1, ỞK!');
  assert.equal(doiDau('Settings'), 'Šẽťťỉñğš');
});

test('mọi ký tự pseudo có glyph trong Be Vietnam Pro (không rơi về font dự phòng)', () => {
  for (const tep of ['Regular', 'SemiBold', 'Bold']) {
    const f = opentype.parse(
      readFileSync(
        join(dirname(fileURLToPath(import.meta.url)), `../../design/fonts/BeVietnamPro-${tep}.ttf`),
      ).buffer,
    );
    const thieu = [...Object.values(DAU), '[', ']', '·'].filter((c) => !(f.charToGlyph(c)?.index > 0));
    assert.deepEqual(thieu, [], `${tep} thiếu: ${thieu.join(' ')}`);
  }
});

test('bienDoiIcu giữ placeholder và từ khoá plural / select, đổi chữ trong nhánh', () => {
  assert.equal(bienDoiIcu('Version {version}'), 'Vẽřšỉởñ {version}');
  assert.equal(
    bienDoiIcu('{n, plural, =0{No pin} =1{One pin} other{{n} pins}}'),
    '{n, plural, =0{Ñở pỉñ} =1{Ởñẽ pỉñ} other{{n} pỉñš}}',
  );
  assert.equal(bienDoiIcu('{g, select, a{Hi} other{Yo}} end'), '{g, select, a{Hỉ} other{Ỹở}} ẽñđ');
  assert.throws(() => bienDoiIcu('a {b'), /thiếu/);
});

test('gia kéo dài ~40% (không tính placeholder) và bọc ngoặc', () => {
  assert.equal(gia('Map'), '[Mảp ··]');
  assert.equal(gia('Waypoints'), '[Ŵảỹpởỉñťš ····]');
  assert.equal(gia('Version {version}'), '[Vẽřšỉởñ {version} ····]');
});

test('sinhArbGia bỏ metadata, đặt locale en_XA', () => {
  const kq = sinhArbGia({ '@@locale': 'en', a: 'Hi', '@a': { description: 'x' } });
  assert.deepEqual(kq, { '@@locale': 'en_XA', a: '[Hỉ ··]' });
});
