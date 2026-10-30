// Hàm THUẦN: kiểm APK release theo SEC-APP (APP-01, APP-02, APP-06) từ đầu ra `aapt2 dump xmltree` + danh sách tệp.
// Dùng bởi tools/build/kiem-apk.mjs (gọi trong phat-hanh-apk.sh trước khi tải lên).

/** Thành phần được phép exported: chỉ màn chính (launcher). */
export const EXPORTED_CHO_PHEP = new Set(['com.tsudev.laban.MainActivity']);

/** Quyền chỉ hệ thống / adb có (protectionLevel signature|privileged): exported kèm quyền này không mở cho app khác. */
export const QUYEN_HE_THONG = new Set(['android.permission.DUMP']);

const THANH_PHAN = new Set(['activity', 'activity-alias', 'service', 'receiver', 'provider']);

/**
 * Phân tích `aapt2 dump xmltree --file AndroidManifest.xml` -> { debuggable, thanhPhan: [{ loai, ten, exported, coIntentFilter }] }.
 * aapt2 in thuộc tính dạng `A: http://schemas.android.com/apk/res/android:exported(0x01010010)=true`.
 */
export function phanTichManifest(xmltree) {
  const thanhPhan = [];
  let debuggable = false;
  let hienTai = null;
  let doSauHienTai = -1;
  for (const dong of xmltree.split('\n')) {
    const thut = dong.search(/\S/);
    if (thut < 0) continue;
    const e = dong.match(/^\s*E: ([\w-]+)/);
    if (e) {
      if (hienTai && thut <= doSauHienTai) hienTai = null;
      if (THANH_PHAN.has(e[1])) {
        hienTai = { loai: e[1], ten: '', exported: null, quyen: null, coIntentFilter: false };
        doSauHienTai = thut;
        thanhPhan.push(hienTai);
      } else if (hienTai && e[1] === 'intent-filter') {
        hienTai.coIntentFilter = true;
      }
      continue;
    }
    const a = dong.match(/^\s*A: (?:http:\/\/schemas\.android\.com\/apk\/res\/android:)?([\w]+)(?:\([^)]*\))?=(?:"([^"]*)"|(\S+))/);
    if (!a) continue;
    const [, ten, chuoi, tho] = a;
    const gt = chuoi ?? tho ?? '';
    if (ten === 'debuggable' && /^(true|0xffffffff|-1)$/i.test(gt)) debuggable = true;
    if (!hienTai || thut <= doSauHienTai) continue;
    if (ten === 'name' && !hienTai.ten) hienTai.ten = gt;
    if (ten === 'permission') hienTai.quyen = gt;
    if (ten === 'exported') hienTai.exported = /^(true|0xffffffff|-1)$/i.test(gt);
  }
  return { debuggable, thanhPhan };
}

/** Lỗi APK release (rỗng = đạt). [tep]: danh sách đường dẫn trong APK; [noiDungSo]: nội dung các thư viện la_ban_kt. */
export function kiemApk({ xmltree, tep, thuVienKiemTra }) {
  const loi = [];
  const m = phanTichManifest(xmltree);
  if (m.debuggable) loi.push('APK debuggable=true (APP-06)');
  for (const t of m.thanhPhan) {
    // targetSdk >= 31 bắt buộc khai exported khi có intent-filter; thiếu khai -> mặc định false.
    if (t.exported && !EXPORTED_CHO_PHEP.has(t.ten) && !QUYEN_HE_THONG.has(t.quyen ?? '')) loi.push(`${t.loai} ${t.ten} exported=true (APP-06)`);
  }
  const so = tep.filter((p) => /^lib\/[^/]+\/libla_ban_kt\.so$/.test(p));
  if (so.length === 0) loi.push('thiếu lib/*/libla_ban_kt.so - kiểm tra môi trường native (APP-02)');
  for (const { ten, noiDung } of thuVienKiemTra) {
    for (const lo of ['frida', 'magisk', 'XposedBridge', 'TracerPid', '/system/xbin/su', 'goldfish']) {
      if (noiDung.includes(lo)) loi.push(`${ten} lộ chuỗi "${lo}" (chưa mã hoá lúc build)`);
    }
  }
  if (!tep.some((p) => p.startsWith('classes') && p.endsWith('.dex'))) loi.push('không có classes*.dex');
  return loi;
}
