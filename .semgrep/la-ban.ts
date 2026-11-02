// Ca thử cho `semgrep --test .semgrep/` (cổng day-du). Không phải mã chạy - chỉ để luật la-ban.yml luôn bắt đúng / không báo nhầm.
// Luật có `paths.include` nên ở chế độ --test semgrep bỏ qua include (thử trên chính tệp này).

declare const d: any, r: any, c: any, ids: string[], tatCa: boolean, q: string, CANH: string;
declare function canQuyen(q: string): any;

// ruleid: la-ban-sql-noi-chuoi
d.prepare(`SELECT * FROM devices WHERE id = '${q}'`);
// ruleid: la-ban-sql-noi-chuoi
d.prepare('SELECT * FROM devices WHERE id = ' + q);
// ok: la-ban-sql-noi-chuoi
d.prepare('SELECT * FROM devices WHERE id = ?').bind(q);
// ok: la-ban-sql-noi-chuoi
d.prepare(`SELECT ${CANH} FROM devices WHERE id IN (${ids.map(() => '?').join(', ')})`);
// ok: la-ban-sql-noi-chuoi
d.prepare(`SELECT id FROM rules${tatCa ? '' : ' WHERE enabled = 1'}`);
// ok: la-ban-sql-noi-chuoi
d.prepare('SELECT id ' + 'FROM rules');

// ruleid: la-ban-admin-thieu-canquyen
r.post('/thiet-bi/chan', async (c: any) => c.json({}));
// ok: la-ban-admin-thieu-canquyen
r.post('/thiet-bi/chan', canQuyen('can-thiep:tao'), async (c: any) => c.json({}));

// ruleid: la-ban-worker-log-bi-mat
console.log('khoa', c.env.KHOA_KY);
// ok: la-ban-worker-log-bi-mat
console.log('so dong', ids.length);

// ruleid: la-ban-web-eval
eval(q);
// ruleid: la-ban-web-eval
new Function(q);
// ok: la-ban-web-eval
JSON.parse(q);
