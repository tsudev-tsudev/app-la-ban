#!/usr/bin/env node
// Kiểm docs/store/play-listing.md (độ dài + từ cấm). node tools/build/kiem-listing.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { kiemListing, phanTichListing } from './kiem-listing-luat.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const ds = phanTichListing(readFileSync(join(goc, 'docs/store/play-listing.md'), 'utf8'));
const loi = kiemListing(ds);
if (loi.length) {
  console.error(`Listing Play sai:\n- ${loi.join('\n- ')}`);
  process.exit(1);
}
for (const [ma, l] of Object.entries(ds)) {
  console.log(`${ma}: tên ${[...l.ten].length}/30 · ngắn ${[...l.ngan].length}/80 · đầy đủ ${[...l.day].length}/4000`);
}
