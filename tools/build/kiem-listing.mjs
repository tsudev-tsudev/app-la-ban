#!/usr/bin/env node
// Kiểm docs/store/play-listing.md + play-listing-pro.md (M2b) (độ dài + từ cấm). node tools/build/kiem-listing.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { kiemListing, phanTichListing } from './kiem-listing-luat.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
let sai = false;
for (const tep of ['play-listing.md', 'play-listing-pro.md']) {
  const ds = phanTichListing(readFileSync(join(goc, 'docs/store', tep), 'utf8'));
  const loi = kiemListing(ds);
  if (loi.length) {
    console.error(`Listing Play ${tep} sai:\n- ${loi.join('\n- ')}`);
    sai = true;
    continue;
  }
  for (const [ma, l] of Object.entries(ds)) {
    console.log(`${tep} ${ma}: tên ${[...l.ten].length}/30 · ngắn ${[...l.ngan].length}/80 · đầy đủ ${[...l.day].length}/4000`);
  }
}
if (sai) process.exit(1);
