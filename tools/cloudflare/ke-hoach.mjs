// Hàm THUẦN: so cấu hình mong muốn (zone.json) với trạng thái hiện có -> danh sách hành động API Cloudflare.
// Zone tsudev.com DÙNG CHUNG với dự án khác: chỉ thêm / sửa đúng mục khai báo, KHÔNG bao giờ sinh hành động xoá.
// `{Z}` / `{A}` trong path được ap-dung.mjs thay bằng zone id / account id.

function khoaDns(b) {
  if (b.type === 'CAA') return `CAA ${b.name} ${b.data.tag} ${b.data.value}`;
  return `${b.type} ${b.name}`;
}

function dnsKhac(muon, hien) {
  if (muon.type === 'CAA') return false;
  return muon.content !== hien.content || Boolean(muon.proxied) !== Boolean(hien.proxied);
}

function headerThanhThaoTac(headers) {
  const kq = {};
  for (const [ten, giaTri] of Object.entries(headers)) kq[ten] = { operation: 'set', value: giaTri };
  return kq;
}

function quyTacKhac(muon, hien) {
  if (hien.expression !== muon.expression || hien.enabled === false) return true;
  const a = headerThanhThaoTac(muon.headers);
  const b = hien.action_parameters?.headers ?? {};
  return JSON.stringify(Object.entries(a).sort()) !== JSON.stringify(Object.entries(b).sort());
}

// So sánh ổn định (không phụ thuộc thứ tự khoá) cho action_parameters.
function onDinh(v) {
  if (Array.isArray(v)) return v.map(onDinh);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, onDinh(v[k])]));
  return v;
}

function quyTacPhaseKhac(muon, hien) {
  return (
    hien.expression !== muon.expression ||
    hien.action !== muon.action ||
    hien.enabled === false ||
    JSON.stringify(onDinh(muon.action_parameters ?? null)) !== JSON.stringify(onDinh(hien.action_parameters ?? null))
  );
}

/**
 * @param {object} muon nội dung zone.json
 * @param {{caiDat: Record<string, unknown>, dnssec: string, dns: object[], pagesDomain: Record<string, string[]>,
 *   r2Domain: Record<string, string[]>, workerDomain: string[], headerRuleset: {id: string, rules: object[]} | null,
 *   phase?: Record<string, {id: string, rules: object[]} | null>, rum?: {id: string, rules: object[]} | null}} hien
 * @returns {{loai: string, moTa: string, method?: string, path?: string, body?: unknown}[]}
 */
export function lapKeHoach(muon, hien) {
  const hd = [];

  for (const [id, giaTri] of Object.entries(muon.caiDat ?? {})) {
    if (hien.caiDat[id] !== giaTri) {
      hd.push({
        loai: 'cai-dat',
        moTa: `${id}: ${JSON.stringify(hien.caiDat[id])} -> ${JSON.stringify(giaTri)}`,
        method: 'PATCH',
        path: `/zones/{Z}/settings/${id}`,
        body: { value: giaTri },
      });
    }
  }

  if (muon.dnssec === 'active' && hien.dnssec !== 'active' && hien.dnssec !== 'pending') {
    hd.push({ loai: 'dnssec', moTa: `DNSSEC ${hien.dnssec} -> active`, method: 'PATCH', path: '/zones/{Z}/dnssec', body: { status: 'active' } });
  }

  const dnsHien = new Map(hien.dns.map((b) => [khoaDns(b), b]));
  for (const b of muon.dns ?? []) {
    const cu = dnsHien.get(khoaDns(b));
    const body = b.type === 'CAA' ? { type: 'CAA', name: b.name, data: b.data, ttl: 1 } : { ...b, ttl: 1 };
    if (!cu) {
      hd.push({ loai: 'dns-them', moTa: `thêm ${khoaDns(b)}`, method: 'POST', path: '/zones/{Z}/dns_records', body });
    } else if (dnsKhac(b, cu)) {
      hd.push({ loai: 'dns-sua', moTa: `sửa ${khoaDns(b)}`, method: 'PATCH', path: `/zones/{Z}/dns_records/${cu.id}`, body });
    }
  }

  for (const { project, domain } of muon.pagesDomain ?? []) {
    if (!(hien.pagesDomain[project] ?? []).includes(domain)) {
      hd.push({
        loai: 'pages-domain',
        moTa: `gắn ${domain} vào Pages ${project}`,
        method: 'POST',
        path: `/accounts/{A}/pages/projects/${project}/domains`,
        body: { name: domain },
      });
    }
  }

  for (const { bucket, domain, minTLS } of muon.r2Domain ?? []) {
    if (!(hien.r2Domain[bucket] ?? []).includes(domain)) {
      hd.push({
        loai: 'r2-domain',
        moTa: `gắn ${domain} vào R2 ${bucket}`,
        method: 'POST',
        path: `/accounts/{A}/r2/buckets/${bucket}/domains/custom`,
        body: { domain, zoneId: '{Z}', enabled: true, minTLS },
      });
    }
  }

  for (const ten of muon.workerDomain ?? []) {
    if (!hien.workerDomain.includes(ten)) {
      hd.push({ loai: 'canh-bao', moTa: `${ten} chưa gắn Worker - chạy deploy Worker (wrangler tự tạo custom domain)` });
    }
  }

  for (const q of muon.headerRule ?? []) {
    const rule = {
      description: q.description,
      expression: q.expression,
      action: 'rewrite',
      action_parameters: { headers: headerThanhThaoTac(q.headers) },
      enabled: true,
    };
    if (!hien.headerRuleset) {
      hd.push({
        loai: 'header-ruleset',
        moTa: `tạo ruleset response header với "${q.description}"`,
        method: 'PUT',
        path: '/zones/{Z}/rulesets/phases/http_response_headers_transform/entrypoint',
        body: { rules: [rule] },
      });
      continue;
    }
    const cu = hien.headerRuleset.rules.find((r) => r.description === q.description);
    if (!cu) {
      hd.push({ loai: 'header-them', moTa: `thêm rule "${q.description}"`, method: 'POST', path: `/zones/{Z}/rulesets/${hien.headerRuleset.id}/rules`, body: rule });
    } else if (quyTacKhac(q, cu)) {
      hd.push({
        loai: 'header-sua',
        moTa: `sửa rule "${q.description}"`,
        method: 'PATCH',
        path: `/zones/{Z}/rulesets/${hien.headerRuleset.id}/rules/${cu.id}`,
        body: rule,
      });
    }
  }

  // Rule ruleset theo phase (WAF custom...): nhận diện bằng description, chỉ thêm / sửa rule của mình.
  for (const q of muon.quyTac ?? []) {
    const rule = { description: q.description, expression: q.expression, action: q.action, enabled: true };
    if (q.action_parameters) rule.action_parameters = q.action_parameters;
    const rs = hien.phase?.[q.phase] ?? null;
    if (!rs) {
      hd.push({
        loai: 'quy-tac-ruleset',
        moTa: `tạo ruleset ${q.phase} với "${q.description}"`,
        method: 'PUT',
        path: `/zones/{Z}/rulesets/phases/${q.phase}/entrypoint`,
        body: { rules: [rule] },
      });
      continue;
    }
    const cu = rs.rules.find((r) => r.description === q.description);
    if (!cu) {
      hd.push({ loai: 'quy-tac-them', moTa: `thêm rule ${q.phase} "${q.description}"`, method: 'POST', path: `/zones/{Z}/rulesets/${rs.id}/rules`, body: rule });
    } else if (quyTacPhaseKhac(rule, cu)) {
      hd.push({
        loai: 'quy-tac-sua',
        moTa: `sửa rule ${q.phase} "${q.description}"`,
        method: 'PATCH',
        path: `/zones/{Z}/rulesets/${rs.id}/rules/${cu.id}`,
        body: rule,
      });
    }
  }

  // Web Analytics (RUM) tự chèn cho cả zone -> loại trừ tên miền của La bàn (trang Quyền riêng tư: không công cụ phân
  // tích; CSP cũng chặn beacon). Không đụng luật của dự án khác.
  if ((muon.rumLoaiTru ?? []).length && hien.rum) {
    for (const host of muon.rumLoaiTru) {
      const cu = hien.rum.rules.find((r) => r.host === host);
      const body = { host, paths: ['*'], inclusive: false, is_paused: false };
      if (!cu) {
        hd.push({ loai: 'rum-them', moTa: `loại trừ Web Analytics cho ${host}`, method: 'POST', path: `/accounts/{A}/rum/v2/${hien.rum.id}/rule`, body });
      } else if (cu.inclusive !== false || cu.is_paused || JSON.stringify(cu.paths) !== '["*"]') {
        hd.push({ loai: 'rum-sua', moTa: `sửa luật Web Analytics ${host}`, method: 'PUT', path: `/accounts/{A}/rum/v2/${hien.rum.id}/rule/${cu.id}`, body });
      }
    }
  }

  return hd;
}

// Thay {Z} / {A} trong path và body.
export function dienId(hanhDong, zoneId, accountId) {
  const thay = (s) => s.replaceAll('{Z}', zoneId).replaceAll('{A}', accountId);
  return {
    ...hanhDong,
    path: hanhDong.path && thay(hanhDong.path),
    body: hanhDong.body === undefined ? undefined : JSON.parse(thay(JSON.stringify(hanhDong.body))),
  };
}
