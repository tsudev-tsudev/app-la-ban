import { test } from 'node:test';
import assert from 'node:assert/strict';
import { vongDongTam, svgVongDongTam } from './vong-dong-tam.mjs';

test('vongDongTam: tất định, vòng đều từ rTrong tới rNgoai, mờ dần ra ngoài, 8 vạch', () => {
  const a = vongDongTam();
  assert.deepEqual(a, vongDongTam());
  assert.equal(a.vong.length, 6);
  assert.equal(a.vong[0].r, 70);
  assert.equal(a.vong.at(-1).r, 290);
  assert.ok(a.vong.every((v, i, ds) => i === 0 || v.a < ds[i - 1].a));
  assert.ok(a.vong.every((v) => v.a <= 0.5));
  assert.equal(a.vach.length, 8);
  assert.throws(() => vongDongTam({ so: 1 }));
});

test('svgVongDongTam: chỉ circle + line, không fill đặc', () => {
  const s = svgVongDongTam('var(--lb-color-accent)');
  assert.equal((s.match(/<circle /g) ?? []).length, 6);
  assert.equal((s.match(/<line /g) ?? []).length, 8);
  assert.ok(!/fill="(?!none)/.test(s));
});
