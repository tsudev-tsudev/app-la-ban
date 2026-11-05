import { test } from 'node:test';
import assert from 'node:assert/strict';
import { docMucPubspec, docImport, kiemLop } from './lop-luat.mjs';

const goi = (deps = [], tep = [], devDeps = []) => ({ deps, devDeps, tep });
const tep = (duongDan, imports, lib = true) => ({ duongDan, lib, imports });

test('docMucPubspec đọc đúng mục, bỏ khoá lồng sâu', () => {
  const y =
    'name: a\ndependencies:\n  core:\n  flutter:\n    sdk: flutter\n  intl: any\ndev_dependencies:\n  test_kit:\nflutter:\n  fonts:\n';
  assert.deepEqual(docMucPubspec(y, 'dependencies'), ['core', 'flutter', 'intl']);
  assert.deepEqual(docMucPubspec(y, 'dev_dependencies'), ['test_kit']);
  assert.deepEqual(docMucPubspec(y, 'khong_co'), []);
});

test('docImport lấy import / export package', () => {
  const ma =
    "import 'dart:ui';\nimport 'package:core/core.dart';\nexport 'package:i18n/src/gen/x.dart';\n// import 'package:no/a.dart';";
  assert.deepEqual(docImport(ma), [
    { goi: 'core', duongDan: 'core.dart' },
    { goi: 'i18n', duongDan: 'src/gen/x.dart' },
  ]);
});

test('hợp lệ: app -> tính năng -> nền -> core, test_kit ở dev', () => {
  const loi = kiemLop({
    core: goi(),
    design_system: goi(['core'], [], ['test_kit']),
    compass_feature: goi(
      ['design_system', 'i18n'],
      [tep('compass_feature/lib/a.dart', [{ goi: 'design_system', duongDan: 'design_system.dart' }])],
      ['test_kit'],
    ),
    la_ban: goi(
      ['compass_feature'],
      [tep('app/test/a.dart', [{ goi: 'test_kit', duongDan: 'test_kit.dart' }], false)],
      ['test_kit'],
    ),
    test_kit: goi(
      ['design_system', 'flutter_test'],
      [tep('test_kit/lib/a.dart', [{ goi: 'flutter_test', duongDan: 'flutter_test.dart' }])],
    ),
  });
  assert.deepEqual(loi, []);
});

test('chặn import ngược lớp / tính năng gọi nhau / gói chưa có tầng', () => {
  const loi = kiemLop({
    core: goi(['design_system']),
    map_feature: goi(['compass_feature']),
    goi_moi: goi(),
  });
  assert.equal(loi.length, 3);
  assert.match(loi[0], /core \(tầng 0\) không được phụ thuộc design_system/);
  assert.match(loi[1], /map_feature .* compass_feature/);
  assert.match(loi[2], /goi_moi: gói chưa có tầng/);
});

test('chặn import src/ của gói khác, import chưa khai báo, lib dùng gói chỉ-test', () => {
  const loi = kiemLop({
    compass_feature: goi(
      ['design_system', 'test_kit'],
      [
        tep('c/lib/a.dart', [
          { goi: 'design_system', duongDan: 'src/tokens/tokens.g.dart' },
          { goi: 'i18n', duongDan: 'i18n.dart' },
          { goi: 'test_kit', duongDan: 'test_kit.dart' },
          { goi: 'compass_feature', duongDan: 'src/x.dart' },
        ]),
      ],
      ['flutter_test'],
    ),
  });
  assert.deepEqual(loi, [
    'compass_feature: test_kit chỉ được ở dev_dependencies',
    'c/lib/a.dart: import vào nội bộ gói khác (package:design_system/src/tokens/tokens.g.dart)',
    'c/lib/a.dart: import i18n nhưng pubspec không khai báo',
    'c/lib/a.dart: mã lib/ import gói chỉ-test test_kit',
  ]);
});

test('lib/ không được import gói chỉ có ở dev_dependencies', () => {
  const loi = kiemLop({
    compass_feature: goi(
      [],
      [tep('c/lib/a.dart', [{ goi: 'design_system', duongDan: 'design_system.dart' }])],
      ['design_system'],
    ),
  });
  assert.deepEqual(loi, ['c/lib/a.dart: mã lib/ import design_system chỉ có ở dev_dependencies']);
});

test('M2 (Q56): app Pro / app_shell không phụ thuộc quảng cáo kể cả bắc cầu; app miễn phí được', () => {
  const loi = kiemLop({
    core: goi(),
    ads_iap: goi(['core']),
    quyen_loi: goi(['core']),
    app_shell: goi(['quyen_loi']),
    la_ban: goi(['app_shell', 'ads_iap']),
    la_ban_pro: goi(['app_shell']),
  });
  assert.deepEqual(loi, []);
  const loi2 = kiemLop({
    core: goi(),
    ads_iap: goi(['core']),
    quyen_loi: goi(['ads_iap']),
    app_shell: goi(['quyen_loi']),
    la_ban_pro: goi(['app_shell']),
  });
  assert.equal(loi2.filter((l) => l.includes('quảng cáo')).length, 2);
});
