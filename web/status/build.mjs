#!/usr/bin/env node
// Trang trạng thái compass-status.tsudev.com: tĩnh, không bundler. Chép src/ + tokens.css + favicon vào dist/.
import { cpSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const goc = dirname(fileURLToPath(import.meta.url));
const dist = join(goc, 'dist');
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
cpSync(join(goc, 'src'), dist, { recursive: true });
cpSync(join(goc, '../../design/gen/tokens.css'), join(dist, 'tokens.css'));
for (const tep of ['favicon.ico', 'favicon.svg']) cpSync(join(goc, '../landing/public', tep), join(dist, tep));
console.log('✓ web/status/dist');
