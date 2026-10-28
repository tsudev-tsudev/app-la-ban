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

/**
 * @param {object} muon nội dung zone.json
 * @param {{caiDat: Record<string, unknown>, dnssec: string, dns: object[], pagesDomain: Record<string, string[]>,
 *   r2Domain: Record<string, string[]>, workerDomain: string[], headerRuleset: {id: string, rules: object[]} | null}} hien
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
