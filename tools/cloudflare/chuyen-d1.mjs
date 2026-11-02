// Chuyển D1 sang database mới GIỮ NGUYÊN rowid (QUYET_DINH Q53). `wrangler d1 export` không xuất rowid -> bảng không có
// INTEGER PRIMARY KEY bị đánh số lại khi nạp, làm lệch con trỏ rowid của chuỗi nhật ký bất biến S10a (rowid nằm trong băm).
//
//   node tools/cloudflare/chuyen-d1.mjs vi-tri  <uuid>                  colo đang phục vụ primary (served_by_colo)
//   node tools/cloudflare/chuyen-d1.mjs sao-chep <uuid-nguon> <uuid-dich> dựng lược đồ + chép dữ liệu (đích phải trống)
//   node tools/cloudflare/chuyen-d1.mjs doi-chieu <uuid-nguon> <uuid-dich> so từng dòng theo khoá (rowid / khoá chính)
//
// Cần CLOUDFLARE_ACCOUNT_ID + CLOUDFLARE_API_TOKEN (set -a; . ~/.config/la-ban/cf.env; set +a). Gọi D1 REST API trực tiếp.
// Thứ tự dựng: bảng (theo thứ tự tạo = thứ tự migration, bảng cha trước) -> dữ liệu -> chỉ mục -> trigger (trigger
// chặn sửa / xoá audit_logs tạo SAU khi nạp) -> sqlite_sequence.

const acc = process.env.CLOUDFLARE_ACCOUNT_ID;
const token = process.env.CLOUDFLARE_API_TOKEN;
if (!acc || !token) {
  console.error('Thiếu CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN - nạp cf.env bằng set -a');
  process.exit(2);
}
const LO_DONG = 400;
const SQL_TOI_DA = 80_000;
const COT_ROWID = '__rowid__';

/** Một truy vấn (có thể nhiều câu lệnh nếu không có tham số). Trả mảng kết quả theo câu lệnh. */
async function hoi(uuid, sql, params = []) {
  for (let lan = 1; ; lan++) {
    const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${acc}/d1/database/${uuid}/query`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ sql, params }),
    });
    const du = await res.json().catch(() => null);
    if (res.ok && du?.success) return du.result;
    const loi = JSON.stringify(du?.errors ?? res.status);
    if (lan >= 3 || (res.status < 500 && res.status !== 429)) throw new Error(`D1 ${uuid.slice(0, 8)}: ${loi} :: ${sql.slice(0, 160)}`);
    await new Promise((r) => setTimeout(r, 1000 * lan));
  }
}
const dong = async (uuid, sql, params) => (await hoi(uuid, sql, params))[0]?.results ?? [];

const tenQ = (t) => `"${t.replaceAll('"', '""')}"`;
function giaTri(v) {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) throw new Error(`số không hữu hạn: ${v}`);
    return String(v);
  }
  if (typeof v === 'string') return `'${v.replaceAll("'", "''")}'`;
  throw new Error(`kiểu chưa hỗ trợ: ${typeof v}`);
}

async function luocDo(uuid) {
  return dong(
    uuid,
    "SELECT type, name, tbl_name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' ORDER BY rowid",
  );
}

/** Cách đọc một bảng: rowid tường minh (bảng rowid thường) hay khoá chính (WITHOUT ROWID / INTEGER PRIMARY KEY). */
async function cachDoc(uuid, bang) {
  const cot = await dong(uuid, `SELECT name, type, pk FROM pragma_table_info('${bang.name.replaceAll("'", "''")}')`);
  const pk = cot.filter((c) => c.pk > 0).sort((a, b) => a.pk - b.pk);
  const withoutRowid = /\)\s*WITHOUT\s+ROWID\s*;?\s*$/i.test(bang.sql);
  const ipk = pk.length === 1 && String(pk[0].type).toUpperCase() === 'INTEGER';
  const khoa = withoutRowid || ipk ? pk.map((c) => c.name) : [COT_ROWID];
  if (!khoa.length) throw new Error(`bảng ${bang.name} không có khoá để so`);
  return { cot: cot.map((c) => c.name), khoa, rowid: !(withoutRowid || ipk) };
}

async function docHet(uuid, bang, c) {
  const chon = c.rowid ? `rowid AS ${COT_ROWID}, *` : '*';
  const sapXep = c.khoa.map((k) => (k === COT_ROWID ? 'rowid' : tenQ(k))).join(', ');
  const ra = [];
  for (let tu = 0; ; tu += LO_DONG) {
    const lo = await dong(uuid, `SELECT ${chon} FROM ${tenQ(bang.name)} ORDER BY ${sapXep} LIMIT ${LO_DONG} OFFSET ${tu}`);
    ra.push(...lo);
    if (lo.length < LO_DONG) return ra;
  }
}

async function chayLo(uuid, cau) {
  let goi = [];
  let co = 0;
  const xa = async () => {
    if (!goi.length) return;
    await hoi(uuid, ['PRAGMA defer_foreign_keys = on', ...goi].join(';\n'));
    goi = [];
    co = 0;
  };
  for (const c of cau) {
    if (co + c.length > SQL_TOI_DA) await xa();
    goi.push(c);
    co += c.length + 2;
  }
  await xa();
}

async function saoChep(nguon, dich) {
  const daCo = (await luocDo(dich)).filter((m) => m.type === 'table');
  if (daCo.length) throw new Error(`đích đã có bảng (${daCo.map((m) => m.name).join(', ')}) - chỉ chép vào database trống`);
  const ld = await luocDo(nguon);
  const bang = ld.filter((m) => m.type === 'table');
  console.log(`lược đồ: ${bang.length} bảng, ${ld.filter((m) => m.type === 'index').length} chỉ mục, ${ld.filter((m) => m.type === 'trigger').length} trigger`);
  await hoi(dich, bang.map((m) => m.sql).join(';\n'));
  for (const b of bang) {
    const c = await cachDoc(nguon, b);
    const ds = await docHet(nguon, b, c);
    const cotChen = c.rowid ? ['rowid', ...c.cot] : c.cot;
    const cau = ds.map(
      (d) =>
        `INSERT INTO ${tenQ(b.name)} (${cotChen.map((x) => (x === 'rowid' ? 'rowid' : tenQ(x))).join(', ')}) VALUES (${cotChen
          .map((x) => giaTri(x === 'rowid' ? d[COT_ROWID] : d[x]))
          .join(', ')})`,
    );
    await chayLo(dich, cau);
    console.log(`  ${b.name}: ${ds.length} dòng${c.rowid ? ' (giữ rowid)' : ''}`);
  }
  const phu = ld.filter((m) => m.type === 'index' || m.type === 'trigger');
  if (phu.length) await hoi(dich, phu.map((m) => m.sql).join(';\n'));
  const seq = await dong(nguon, 'SELECT name, seq FROM sqlite_sequence').catch(() => []);
  for (const s of seq) {
    await hoi(dich, 'UPDATE sqlite_sequence SET seq = ? WHERE name = ? AND seq < ?', [s.seq, s.name, s.seq]).catch((e) =>
      console.warn(`  cảnh báo sqlite_sequence ${s.name}: ${e.message}`),
    );
  }
  console.log('✓ chép xong - chạy doi-chieu');
}

async function doiChieu(nguon, dich) {
  const ldN = await luocDo(nguon);
  const ldD = await luocDo(dich);
  const kyHieu = (ds) => ds.map((m) => `${m.type}:${m.name}:${m.sql}`).sort();
  const lechLd = kyHieu(ldN).filter((x) => !kyHieu(ldD).includes(x)).concat(kyHieu(ldD).filter((x) => !kyHieu(ldN).includes(x)));
  let tong = lechLd.length;
  if (lechLd.length) console.log(`✗ lược đồ lệch:\n  ${lechLd.join('\n  ')}`);
  for (const b of ldN.filter((m) => m.type === 'table')) {
    const c = await cachDoc(nguon, b);
    const khoaCua = (d) => JSON.stringify(c.khoa.map((k) => d[k]));
    const mapN = new Map((await docHet(nguon, b, c)).map((d) => [khoaCua(d), JSON.stringify(d)]));
    const mapD = new Map((await docHet(dich, b, c)).map((d) => [khoaCua(d), JSON.stringify(d)]));
    const chiN = [...mapN.keys()].filter((k) => !mapD.has(k));
    const chiD = [...mapD.keys()].filter((k) => !mapN.has(k));
    const khac = [...mapN.keys()].filter((k) => mapD.has(k) && mapD.get(k) !== mapN.get(k));
    const lech = chiN.length + chiD.length + khac.length;
    tong += lech;
    console.log(`${lech ? '✗' : '✓'} ${b.name}: ${mapN.size} / ${mapD.size} dòng${lech ? ` - chỉ nguồn ${chiN.length}, chỉ đích ${chiD.length}, khác ${khac.length}` : ''}`);
    for (const k of [...chiN, ...khac].slice(0, 5)) console.log(`    nguồn ${k}: ${mapN.get(k)?.slice(0, 300)}`);
    for (const k of [...chiD, ...khac].slice(0, 5)) console.log(`    đích  ${k}: ${mapD.get(k)?.slice(0, 300)}`);
  }
  console.log(tong ? `✗ ${tong} khác biệt` : '✓ trùng khớp hoàn toàn');
  process.exitCode = tong ? 1 : 0;
}

const [lenh, a, b] = process.argv.slice(2);
const uuid = /^[0-9a-f-]{36}$/;
if (lenh === 'vi-tri' && uuid.test(a ?? '')) {
  const r = await hoi(a, 'SELECT 1');
  console.log(r[0]?.meta?.served_by_colo ?? '?', r[0]?.meta?.served_by_region ?? '', r[0]?.meta?.served_by_primary ? 'primary' : '');
} else if (lenh === 'sao-chep' && uuid.test(a ?? '') && uuid.test(b ?? '') && a !== b) await saoChep(a, b);
else if (lenh === 'doi-chieu' && uuid.test(a ?? '') && uuid.test(b ?? '') && a !== b) await doiChieu(a, b);
else {
  console.error('Dùng: vi-tri <uuid> | sao-chep <nguon> <dich> | doi-chieu <nguon> <dich>');
  process.exit(2);
}
