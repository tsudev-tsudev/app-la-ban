// Hàm THUẦN: luật phụ thuộc giữa các lớp của pub workspace (app -> tính năng -> nền -> core).
// Gói chỉ được phụ thuộc gói ở tầng THẤP HƠN; tính năng không gọi nhau; không import vào `src/` của gói khác;
// mã lib/ không dùng gói chỉ-test. Không đọc ghi tệp.

/** Tầng của từng gói nội bộ (số lớn = cao hơn). */
export const TANG = {
  core: 0,
  design_system: 1,
  i18n: 1,
  sensors: 1,
  network: 1,
  storage: 1,
  security_sdk: 1,
  compass_feature: 2,
  location_feature: 2,
  waypoint_feature: 2,
  map_feature: 2,
  ar_feature: 2,
  settings_feature: 2,
  ads_iap: 2,
  la_ban: 3,
};

/** Gói chỉ được khai báo ở dev_dependencies và chỉ import trong test/. */
export const CHI_TEST = new Set(['test_kit', 'flutter_test']);

// Cặp cùng tầng được phép "goi>dich" (hiện chưa có: design_system / i18n là nền giao diện độc lập).
const CUNG_TANG_DUOC = new Set([]);

/** Đọc danh sách tên gói ở một mục (dependencies / dev_dependencies) của pubspec.yaml đơn giản. */
export function docMucPubspec(yaml, muc) {
  const kq = [];
  let trong = false;
  for (const dong of yaml.split('\n')) {
    if (/^\S/.test(dong)) {
      trong = dong.trim() === `${muc}:`;
      continue;
    }
    const m = /^ {2}([a-z0-9_]+):/.exec(dong);
    if (trong && m) kq.push(m[1]);
  }
  return kq;
}

/** Các import `package:` trong một tệp Dart -> [{goi, duongDan}]. */
export function docImport(maDart) {
  return [...maDart.matchAll(/^\s*(?:import|export)\s+'package:([a-z0-9_]+)\/([^']+)'/gm)].map((m) => ({
    goi: m[1],
    duongDan: m[2],
  }));
}

/**
 * dsGoi: {ten: {deps: string[], devDeps: string[], tep: [{duongDan, lib: boolean, imports: [{goi, duongDan}]}]}}
 * Trả mảng lỗi (rỗng = đạt).
 */
export function kiemLop(dsGoi) {
  const loi = [];
  for (const [ten, g] of Object.entries(dsGoi)) {
    const tang = TANG[ten];
    const laTest = ten === 'test_kit';
    if (tang === undefined && !laTest) {
      loi.push(`${ten}: gói chưa có tầng trong TANG (tools/kiem-tra/lop-luat.mjs)`);
      continue;
    }
    for (const d of g.deps) {
      if (CHI_TEST.has(d) && !laTest) loi.push(`${ten}: ${d} chỉ được ở dev_dependencies`);
      const td = TANG[d];
      if (td === undefined || laTest) continue;
      if (td > tang || (td === tang && !CUNG_TANG_DUOC.has(`${ten}>${d}`))) {
        loi.push(`${ten} (tầng ${tang}) không được phụ thuộc ${d} (tầng ${td})`);
      }
    }
    const khaiBao = new Set([...g.deps, ...g.devDeps, ten]);
    for (const t of g.tep) {
      for (const im of t.imports) {
        if (!(im.goi in TANG) && !CHI_TEST.has(im.goi)) continue;
        if (t.lib && CHI_TEST.has(im.goi) && !laTest)
          loi.push(`${t.duongDan}: mã lib/ import gói chỉ-test ${im.goi}`);
        if (im.goi !== ten && im.duongDan.startsWith('src/')) {
          loi.push(`${t.duongDan}: import vào nội bộ gói khác (package:${im.goi}/${im.duongDan})`);
        }
        if (!khaiBao.has(im.goi)) loi.push(`${t.duongDan}: import ${im.goi} nhưng pubspec không khai báo`);
        else if (t.lib && !g.deps.includes(im.goi) && im.goi !== ten) {
          loi.push(`${t.duongDan}: mã lib/ import ${im.goi} chỉ có ở dev_dependencies`);
        }
      }
    }
  }
  return loi;
}
