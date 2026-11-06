import assert from 'node:assert/strict';
import { test } from 'node:test';
import { kiemApk, phanTichManifest } from './kiem-apk-luat.mjs';

const ANDROID = 'http://schemas.android.com/apk/res/android';
const manifest = ({ debuggable = false, them = '' } = {}) => `N: android=${ANDROID} (line=2)
  E: manifest (line=2)
    A: package="com.tsudev.laban" (Raw: "com.tsudev.laban")
    E: application (line=10)
      A: ${ANDROID}:label(0x01010001)="La bàn" (Raw: "La bàn")
${debuggable ? `      A: ${ANDROID}:debuggable(0x0101000f)=true\n` : ''}      E: activity (line=20)
        A: ${ANDROID}:name(0x01010003)="com.tsudev.laban.MainActivity" (Raw: "com.tsudev.laban.MainActivity")
        A: ${ANDROID}:exported(0x01010010)=true
        E: intent-filter (line=30)
          E: action (line=31)
            A: ${ANDROID}:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
      E: activity (line=40)
        A: ${ANDROID}:name(0x01010003)="com.google.android.play.core.common.PlayCoreDialogWrapperActivity" (Raw: "x")
        A: ${ANDROID}:exported(0x01010010)=false
${them}`;

const tep = ['AndroidManifest.xml', 'classes.dex', 'lib/arm64-v8a/libla_ban_kt.so', 'lib/arm64-v8a/libflutter.so'];
const sach = [{ ten: 'lib/arm64-v8a/libla_ban_kt.so', noiDung: '\u0000JNI_OnLoad\u0000' }];

test('phân tích manifest: tên, exported, intent-filter của đúng thành phần', () => {
  const m = phanTichManifest(manifest());
  assert.equal(m.debuggable, false);
  assert.deepEqual(
    m.thanhPhan.map((t) => [t.ten, t.exported, t.coIntentFilter]),
    [
      ['com.tsudev.laban.MainActivity', true, true],
      ['com.google.android.play.core.common.PlayCoreDialogWrapperActivity', false, false],
    ],
  );
});

test('APK sạch -> không lỗi', () => {
  assert.deepEqual(kiemApk({ xmltree: manifest(), tep, thuVienKiemTra: sach }), []);
});

test('debuggable / thành phần lạ exported / thiếu thư viện native / lộ chuỗi -> lỗi', () => {
  const them = `      E: receiver (line=50)
        A: ${ANDROID}:name(0x01010003)="com.vi.du.Nhan" (Raw: "com.vi.du.Nhan")
        A: ${ANDROID}:exported(0x01010010)=true
`;
  const loi = kiemApk({
    xmltree: manifest({ debuggable: true, them }),
    tep: ['classes.dex'],
    thuVienKiemTra: [{ ten: 'lib/x86_64/libla_ban_kt.so', noiDung: 'abc/system/xbin/su\u0000frida' }],
  });
  assert.equal(loi.length, 5);
  assert.match(loi.join('\n'), /debuggable/);
  assert.match(loi.join('\n'), /com\.vi\.du\.Nhan/);
  assert.match(loi.join('\n'), /thiếu lib/);
  assert.match(loi.join('\n'), /"frida"/);
});

test('receiver exported nhưng giữ bằng quyền hệ thống DUMP (ProfileInstaller) -> đạt', () => {
  const them = `      E: receiver (line=50)
        A: ${ANDROID}:name(0x01010003)="androidx.profileinstaller.ProfileInstallReceiver" (Raw: "x")
        A: ${ANDROID}:permission(0x01010006)="android.permission.DUMP" (Raw: "android.permission.DUMP")
        A: ${ANDROID}:exported(0x01010010)=true
`;
  assert.deepEqual(kiemApk({ xmltree: manifest({ them }), tep, thuVienKiemTra: sach }), []);
});

const quyenChuKy = (muc) => `    E: permission (line=5)
      A: ${ANDROID}:name(0x01010003)="com.tsudev.laban.permission.CHUYEN_PRO" (Raw: "com.tsudev.laban.permission.CHUYEN_PRO")
      A: ${ANDROID}:protectionLevel(0x01010009)=(type 0x11)${muc}
`;
const provider = (them = '') => `      E: provider (line=60)
        A: ${ANDROID}:name(0x01010003)="com.tsudev.laban.ChuyenProProvider" (Raw: "x")
        A: ${ANDROID}:exported(0x01010010)=true
        A: ${ANDROID}:readPermission(0x01010007)="com.tsudev.laban.permission.CHUYEN_PRO" (Raw: "x")
${them}      E: activity (line=70)
        A: ${ANDROID}:name(0x01010003)="com.tsudev.laban.MoChuyenProActivity" (Raw: "x")
        A: ${ANDROID}:exported(0x01010010)=true
        A: ${ANDROID}:permission(0x01010006)="com.tsudev.laban.permission.CHUYEN_PRO" (Raw: "x")
`;
const coQuyen = (muc, them) => manifest({ them }).replace('    E: application', `${quyenChuKy(muc)}    E: application`);
const ghi = `        A: ${ANDROID}:writePermission(0x01010008)="com.tsudev.laban.permission.CHUYEN_PRO" (Raw: "x")\n`;

test('M2b: provider + activity giữ bằng quyền signature của chính app -> đạt', () => {
  const m = phanTichManifest(coQuyen('0x2', provider(ghi)));
  assert.deepEqual([...m.quyenChuKy], ['com.tsudev.laban.permission.CHUYEN_PRO']);
  assert.deepEqual(kiemApk({ xmltree: coQuyen('0x2', provider(ghi)), tep, thuVienKiemTra: sach }), []);
});

test('M2b: quyền normal / provider thiếu quyền ghi -> lỗi', () => {
  const thuong = kiemApk({ xmltree: coQuyen('0x0', provider(ghi)), tep, thuVienKiemTra: sach });
  assert.equal(thuong.length, 2);
  const thieuGhi = kiemApk({ xmltree: coQuyen('0x2', provider()), tep, thuVienKiemTra: sach });
  assert.deepEqual(thieuGhi, ['provider com.tsudev.laban.ChuyenProProvider exported=true (APP-06)']);
});

test('M2b: định dạng aapt2 thật (build-tools 36, đo 06/11) "protectionLevel(...)=0x00000002" -> signature', () => {
  const xml = coQuyen('0x2', provider(ghi)).replace('=(type 0x11)0x2', '=0x00000002');
  assert.match(xml, /protectionLevel\(0x01010009\)=0x00000002$/m);
  assert.deepEqual([...phanTichManifest(xml).quyenChuKy], ['com.tsudev.laban.permission.CHUYEN_PRO']);
  assert.deepEqual(kiemApk({ xmltree: xml, tep, thuVienKiemTra: sach }), []);
});
