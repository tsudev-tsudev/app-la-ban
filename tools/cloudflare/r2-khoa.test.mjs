import { test } from 'node:test';
import assert from 'node:assert/strict';
import { QUY_TAC, thanLifecycle, thanLock } from './r2-khoa.mjs';

test('r2-khoa: nhật ký prod khoá >= 12 tháng, lifecycle xoá sau hạn khoá', () => {
  const p = thanLock(QUY_TAC['la-ban-nhat-ky']).rules.find((r) => r.prefix === 'nhat-ky/');
  assert.ok(p.condition.maxAgeSeconds >= 365 * 86_400);
  for (const q of Object.values(QUY_TAC)) assert.doesNotThrow(() => thanLifecycle(q));
  assert.ok(!thanLock(QUY_TAC['la-ban-nhat-ky']).rules.some((r) => 'trang-thai/'.startsWith(r.prefix)));
  assert.throws(() => thanLifecycle({ khoa: { 'a/': 10 }, xoa: { 'a/': 5 } }), /phải sau hạn khoá/);
});
