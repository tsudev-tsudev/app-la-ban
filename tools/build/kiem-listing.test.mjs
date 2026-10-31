import assert from 'node:assert/strict';
import { test } from 'node:test';
import { kiemListing, phanTichListing } from './kiem-listing-luat.mjs';

const md = ({ ten = 'La bàn - TsuDev Compass', ngan = 'La bàn bắc thực', day = 'Mô tả.' } = {}) => `
<!-- listing:vi -->
### Tên
${ten}

### Mô tả ngắn
${ngan}

### Mô tả đầy đủ
${day}
<!-- /listing:vi -->
<!-- listing:en -->
### Title
La bàn - TsuDev Compass

### Short description
True-north compass

### Full description
Line one.

Line two.
<!-- /listing:en -->
`;

test('đọc đúng 3 mục mỗi ngôn ngữ, mô tả nhiều đoạn', () => {
  const ds = phanTichListing(md());
  assert.equal(ds.vi.ten, 'La bàn - TsuDev Compass');
  assert.equal(ds.en.day, 'Line one.\n\nLine two.');
  assert.deepEqual(kiemListing(ds), []);
});

test('quá giới hạn đếm theo ký tự Unicode', () => {
  assert.deepEqual(kiemListing(phanTichListing(md({ ten: 'à'.repeat(30) }))), []);
  assert.match(kiemListing(phanTichListing(md({ ten: 'à'.repeat(31) })))[0], /vi\.ten: 31 > 30/);
  assert.match(kiemListing(phanTichListing(md({ day: 'x'.repeat(4001) })))[0], /vi\.day/);
});

test('từ xếp hạng / khuyến mãi / emoji trong tên hoặc mô tả ngắn', () => {
  assert.match(kiemListing(phanTichListing(md({ ten: 'La bàn tốt nhất' })))[0], /xếp hạng/);
  assert.match(kiemListing(phanTichListing(md({ ngan: 'Best compass' })))[0], /xếp hạng/);
  assert.match(kiemListing(phanTichListing(md({ ngan: 'La bàn 🧭' })))[0], /emoji/);
});

test('thiếu ngôn ngữ / mục trống', () => {
  assert.deepEqual(kiemListing({ en: { ten: 'a', ngan: 'b', day: 'c' } }), ['vi: thiếu khối listing']);
  assert.match(kiemListing(phanTichListing(md({ ngan: '' })))[0], /vi\.ngan: trống/);
});
