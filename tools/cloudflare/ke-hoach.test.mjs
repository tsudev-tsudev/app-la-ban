import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dienId, lapKeHoach } from './ke-hoach.mjs';

const muon = {
  caiDat: { min_tls_version: '1.2', always_use_https: 'on' },
  dnssec: 'active',
  dns: [
    { type: 'CNAME', name: 'compass.tsudev.com', content: 'la-ban-landing.pages.dev', proxied: true },
    { type: 'CAA', name: 'tsudev.com', data: { flags: 0, tag: 'issue', value: 'pki.goog' } },
  ],
  pagesDomain: [{ project: 'la-ban-landing', domain: 'compass.tsudev.com' }],
  r2Domain: [{ bucket: 'la-ban-cdn', domain: 'compass-cdn.tsudev.com', minTLS: '1.2' }],
  workerDomain: ['compass-api.tsudev.com'],
  headerRule: [{ description: 'la-ban: x', expression: '(http.host eq "a")', headers: { 'x-content-type-options': 'nosniff' } }],
};

const khop = {
  caiDat: { min_tls_version: '1.2', always_use_https: 'on' },
  dnssec: 'active',
  dns: [
    { id: 'd1', type: 'CNAME', name: 'compass.tsudev.com', content: 'la-ban-landing.pages.dev', proxied: true },
    { id: 'd2', type: 'CAA', name: 'tsudev.com', data: { flags: 0, tag: 'issue', value: 'pki.goog' } },
    { id: 'khac', type: 'A', name: 'www.tsudev.com', content: '1.2.3.4', proxied: true },
  ],
  pagesDomain: { 'la-ban-landing': ['compass.tsudev.com'] },
  r2Domain: { 'la-ban-cdn': ['compass-cdn.tsudev.com'] },
  workerDomain: ['compass-api.tsudev.com'],
  headerRuleset: {
    id: 'rs',
    rules: [
      { id: 'r0', description: 'của dự án khác', expression: 'true', action_parameters: { headers: {} } },
      {
        id: 'r1',
        description: 'la-ban: x',
        expression: '(http.host eq "a")',
        enabled: true,
        action_parameters: { headers: { 'x-content-type-options': { operation: 'set', value: 'nosniff' } } },
      },
    ],
  },
};

test('đã khớp -> không hành động (idempotent), bỏ qua bản ghi của dự án khác', () => {
  assert.deepEqual(lapKeHoach(muon, khop), []);
});

test('zone trống -> đủ hành động, không có xoá', () => {
  const hd = lapKeHoach(muon, {
    caiDat: { min_tls_version: '1.0', always_use_https: 'on' },
    dnssec: 'disabled',
    dns: [],
    pagesDomain: {},
    r2Domain: {},
    workerDomain: [],
    headerRuleset: null,
  });
  assert.deepEqual(
    hd.map((h) => h.loai),
    ['cai-dat', 'dnssec', 'dns-them', 'dns-them', 'pages-domain', 'r2-domain', 'canh-bao', 'header-ruleset'],
  );
  assert.ok(hd.every((h) => h.method !== 'DELETE'));
  assert.deepEqual(hd[0].body, { value: '1.2' });
  assert.equal(hd[3].body.type, 'CAA');
  assert.equal(hd[3].body.content, undefined);
});

test('DNSSEC pending không bật lại', () => {
  assert.deepEqual(lapKeHoach(muon, { ...khop, dnssec: 'pending' }), []);
});

test('bản ghi lệch nội dung / proxied -> PATCH đúng id', () => {
  const hd = lapKeHoach(muon, {
    ...khop,
    dns: [{ id: 'd1', type: 'CNAME', name: 'compass.tsudev.com', content: 'la-ban-landing.pages.dev', proxied: false }, khop.dns[1]],
  });
  assert.equal(hd.length, 1);
  assert.equal(hd[0].method, 'PATCH');
  assert.equal(hd[0].path, '/zones/{Z}/dns_records/d1');
});

test('rule header thiếu -> POST vào ruleset; lệch -> PATCH; rule khác giữ nguyên', () => {
  const thieu = lapKeHoach(muon, { ...khop, headerRuleset: { id: 'rs', rules: [khop.headerRuleset.rules[0]] } });
  assert.equal(thieu.length, 1);
  assert.equal(thieu[0].method, 'POST');
  assert.equal(thieu[0].path, '/zones/{Z}/rulesets/rs/rules');

  const lech = structuredClone(khop);
  lech.headerRuleset.rules[1].action_parameters.headers['x-content-type-options'].value = 'khac';
  const sua = lapKeHoach(muon, lech);
  assert.equal(sua.length, 1);
  assert.equal(sua[0].path, '/zones/{Z}/rulesets/rs/rules/r1');

  const tat = structuredClone(khop);
  tat.headerRuleset.rules[1].enabled = false;
  assert.equal(lapKeHoach(muon, tat)[0].loai, 'header-sua');
});

test('dienId thay {Z}/{A} trong path và body', () => {
  const h = dienId({ path: '/accounts/{A}/x', body: { zoneId: '{Z}', n: 1 } }, 'zz', 'aa');
  assert.equal(h.path, '/accounts/aa/x');
  assert.deepEqual(h.body, { zoneId: 'zz', n: 1 });
  assert.equal(dienId({ loai: 'canh-bao' }, 'z', 'a').body, undefined);
});

test('quyTac WAF: chưa có -> thêm vào ruleset sẵn có; khớp -> không; lệch -> sửa; không đụng rule dự án khác', () => {
  const q = { phase: 'http_request_firewall_custom', description: 'la-ban: chặn', expression: '(ip.src in $la_ban_chan_ip)', action: 'block' };
  const co = (rules) => lapKeHoach({ quyTac: [q] }, { caiDat: {}, dns: [], pagesDomain: {}, r2Domain: {}, workerDomain: [], phase: { [q.phase]: { id: 'fw', rules } } });
  const khac = { id: 'o', description: 'PTSAM', expression: 'true', action: 'skip' };
  assert.deepEqual(co([khac]).map((h) => [h.loai, h.method, h.path]), [['quy-tac-them', 'POST', '/zones/{Z}/rulesets/fw/rules']]);
  assert.deepEqual(co([khac, { id: 'm', description: q.description, expression: q.expression, action: 'block', enabled: true }]), []);
  const sua = co([{ id: 'm', description: q.description, expression: q.expression, action: 'managed_challenge', enabled: true }]);
  assert.deepEqual(sua.map((h) => [h.loai, h.method, h.path, h.body.action]), [['quy-tac-sua', 'PATCH', '/zones/{Z}/rulesets/fw/rules/m', 'block']]);
  const moi = lapKeHoach({ quyTac: [q] }, { caiDat: {}, dns: [], pagesDomain: {}, r2Domain: {}, workerDomain: [], phase: {} });
  assert.deepEqual(moi.map((h) => [h.loai, h.method]), [['quy-tac-ruleset', 'PUT']]);
});

test('action_parameters so sánh không phụ thuộc thứ tự khoá', () => {
  const q = { phase: 'p', description: 'la-ban: x', expression: 'e', action: 'skip', action_parameters: { a: 1, b: { c: 2, d: 3 } } };
  const hien = { id: 'r', description: 'la-ban: x', expression: 'e', action: 'skip', enabled: true, action_parameters: { b: { d: 3, c: 2 }, a: 1 } };
  assert.deepEqual(lapKeHoach({ quyTac: [q] }, { caiDat: {}, dns: [], pagesDomain: {}, r2Domain: {}, workerDomain: [], phase: { p: { id: 'x', rules: [hien] } } }), []);
});

test('rumLoaiTru: thêm luật loại trừ, giữ luật "*" của zone, sửa luật đang bao gồm', () => {
  const nen = { caiDat: {}, dns: [], pagesDomain: {}, r2Domain: {}, workerDomain: [] };
  const rum = (rules) => lapKeHoach({ rumLoaiTru: ['compass.tsudev.com', 'compass-admin.tsudev.com'] }, { ...nen, rum: { id: 'rs', rules } });
  const tatCa = { id: 'z', host: '*', paths: ['*'], inclusive: true };
  const hd = rum([tatCa, { id: 'c', host: 'compass-admin.tsudev.com', paths: ['*'], inclusive: true }]);
  assert.deepEqual(hd.map((h) => [h.loai, h.method, h.path, h.body.inclusive]), [
    ['rum-them', 'POST', '/accounts/{A}/rum/v2/rs/rule', false],
    ['rum-sua', 'PUT', '/accounts/{A}/rum/v2/rs/rule/c', false],
  ]);
  assert.deepEqual(rum([tatCa, { id: 'a', host: 'compass.tsudev.com', paths: ['*'], inclusive: false }, { id: 'c', host: 'compass-admin.tsudev.com', paths: ['*'], inclusive: false }]), []);
  assert.deepEqual(lapKeHoach({ rumLoaiTru: ['compass.tsudev.com'] }, { ...nen, rum: null }), []);
});
