import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:location_feature/location_feature.dart';
import 'package:sensors/sensors.dart';
import 'package:test_kit/test_kit.dart';

final TaiNguyenViTri _taiNguyen = (
  diaGioi: BanDoDiaGioi.tuBytes(
    File('assets/dia_gioi_vn.bin').readAsBytesSync(),
  ),
  geoid: LuoiGeoid.tuBytes(
    ByteData.sublistView(File('assets/geoid_egm96_1do.bin').readAsBytesSync()),
  ),
);

/// Hồ Gươm, 29/10/2026 9:30 giờ Hà Nội.
final _luc = DateTime.utc(2026, 10, 29, 2, 30);
final _doc = DocViTri(
  viDo: 21.0285,
  kinhDo: 105.8542,
  luc: _luc,
  doCaoElip: -18,
  doChinhXacNgang: 4.6,
  doChinhXacDung: 6,
  tocDo: 1.3,
  huongDi: 87,
  nguon: NguonDocViTri.gps,
);

const _huong = HuongDoc(
  phuongVi: 42,
  phuongViTho: 42,
  doc: 2,
  lan: -1,
  theoCamera: false,
  muc: MucTinCay.cao,
  nhieuTu: false,
  canHieuChuan: false,
  cuongDoTu: 44.2,
  nguon: NguonHuong.madgwick,
  dungYen: false,
  tNs: 0,
  apSuat: 1009.6,
);

List<Override> ghiDe({
  NguonViTri? nguon,
  ViTriDiaLy? viTri = const ViTriDiaLy(viDo: 21.0285, kinhDo: 105.8542),
  KhoViTri? kho,
}) => [
  nguonViTriProvider.overrideWithValue(nguon ?? NguonViTriGhiSan([_doc])),
  taiNguyenViTriProvider.overrideWith((_) => SynchronousFuture(_taiNguyen)),
  huongProvider.overrideWith((_) => Stream.value(_huong)),
  phutProvider.overrideWith((_) => Stream.value(_luc)),
  dongHoProvider.overrideWithValue(() => _luc),
  lechMuiGioProvider.overrideWithValue((_) => const Duration(hours: 7)),
  viTriBanDauProvider.overrideWithValue(viTri),
  if (kho != null) khoViTriProvider.overrideWithValue(kho),
];

Widget dung(OMaTran o, Widget man, List<Override> gd) => ProviderScope(
  overrides: gd,
  child: khungThu(man, o: o),
);

/// Thẻ đặt như dưới mặt la bàn.
const _the = Scaffold(
  body: SingleChildScrollView(padding: EdgeInsets.all(16), child: TheViTri()),
);

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận màn chi tiết: không tràn', (tester) async {
    await kiemMaTran(tester, (o) => dung(o, const ManViTri(), ghiDe()));
  });

  testWidgets('ma trận thẻ (mời bật + có vị trí): không tràn', (tester) async {
    await kiemMaTran(
      tester,
      (o) => dung(
        o,
        _the,
        ghiDe(nguon: NguonViTriGhiSan([], quyenHienTai: QuyenViTri.chuaHoi)),
      ),
      dsO: toHop(dsManHinh: [manHinh12.first, manHinh12[6]]),
    );
    await kiemMaTran(
      tester,
      (o) => dung(o, _the, ghiDe()),
      dsO: toHop(dsManHinh: [manHinh12.first, manHinh12[6]]),
    );
  });

  testWidgets('golden: thẻ telemetry tự lấp + màn chi tiết', (tester) async {
    await chupGolden(tester, 'the_vi_tri', (o) => dung(o, _the, ghiDe()));
    await chupGolden(
      tester,
      'man_vi_tri',
      (o) => dung(o, const ManViTri(), ghiDe()),
      dsO: [oChup.first, oChup.last],
    );
  });

  testWidgets('màn chi tiết hiện đủ số liệu', (tester) async {
    await tester.pumpWidget(dung(oChup.first, const ManViTri(), ghiDe()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('21.028500, 105.854200'), findsOneWidget);
    expect(find.text('48Q WJ 88760 25500'), findsNothing); // MGRS thật khác
    expect(find.textContaining('48Q '), findsWidgets);
    expect(find.text('Phường Hoàn Kiếm, Thành phố Hà Nội'), findsOneWidget);
    // Elipxoit -18 m, geoid Hà Nội ~ -28 m -> ~10 m trên mực biển.
    await tester.scrollUntilVisible(find.text('10 m ±6 m'), 200);
    expect(find.text('10 m ±6 m'), findsOneWidget);
    expect(find.text('4,7 km/h'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('44,2 µT'), 200);
    expect(find.text('44,2 µT'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Trưa thực'), 200);
    expect(find.text('Trưa thực'), findsOneWidget);
  });

  testWidgets('chưa có quyền: bấm cho phép -> hỏi quyền rồi hiện toạ độ, '
      'đẩy vị trí sang phần dùng chung', (tester) async {
    final nguon = NguonViTriGhiSan([_doc], quyenHienTai: QuyenViTri.chuaHoi);
    final kho = KhoViTriBoNho();
    late WidgetRef r;
    await tester.pumpWidget(
      dung(
        oChup.first,
        Consumer(
          builder: (_, ref, _) {
            r = ref;
            return _the;
          },
        ),
        ghiDe(nguon: nguon, viTri: null, kho: kho),
      ),
    );
    await tester.pump();
    expect(nguon.soLanXin, 0, reason: 'không tự hỏi khi chưa bấm');
    expect(find.text('Cho phép vị trí'), findsOneWidget);
    await tester.tap(find.text('Cho phép vị trí'));
    await tester.pump();
    await tester.pump();
    expect(nguon.soLanXin, 1);
    expect(find.text('21.028500, 105.854200'), findsOneWidget);
    expect(r.read(viTriProvider)?.viDo, 21.0285);
    expect(kho.doc().viDoLuu, 21.0);
    expect(kho.doc().kinhDoLuu, 105.9);
  });

  testWidgets('chạm toạ độ đổi định dạng và nhớ', (tester) async {
    final kho = KhoViTriBoNho();
    await tester.pumpWidget(dung(oChup.first, _the, ghiDe(kho: kho)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('21.028500, 105.854200'));
    await tester.pump();
    expect(find.text('21°01\'42.6"N 105°51\'15.1"E'), findsOneWidget);
    expect(kho.doc().dinhDang, DinhDangToaDo.dms);
  });

  testWidgets('nhấn giữ toạ độ để chép', (tester) async {
    String? chep;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'Clipboard.setData') {
          chep = (c.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(dung(oChup.first, _the, ghiDe()));
    await tester.pump();
    await tester.pump();
    await tester.longPress(find.text('21.028500, 105.854200'));
    await tester.pump();
    expect(chep, '21.028500, 105.854200');
    expect(find.text('Đã chép toạ độ'), findsOneWidget);
  });

  testWidgets('từ chối hẳn: nút mở cài đặt', (tester) async {
    final nguon = NguonViTriGhiSan([], quyenHienTai: QuyenViTri.tuChoiHan);
    await tester.pumpWidget(dung(oChup.first, _the, ghiDe(nguon: nguon)));
    await tester.pump();
    await tester.tap(find.text('Mở cài đặt'));
    expect(nguon.soLanMoCaiDat, 1);
  });

  testWidgets('dịch vụ vị trí tắt', (tester) async {
    final nguon = NguonViTriGhiSan([])..dichVu = false;
    await tester.pumpWidget(dung(oChup.first, _the, ghiDe(nguon: nguon)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Dịch vụ vị trí của máy đang tắt.'), findsOneWidget);
  });

  test('tuỳ chọn vị trí đọc / ghi JSON, bỏ giá trị hỏng', () {
    const t = TuyChonViTri(
      dinhDang: DinhDangToaDo.mgrs,
      viDoLuu: 21,
      kinhDoLuu: 105.9,
    );
    expect(TuyChonViTri.tuJson(t.toJson()), t);
    expect(
      TuyChonViTri.tuJson(const {'viDo': 200, 'kinhDo': 1}).viDoLuu,
      isNull,
    );
    expect(
      TuyChonViTri.tuJson(const {'dinhDang': 'x'}).dinhDang,
      DinhDangToaDo.dd,
    );
    expect(viTriTuTuyChon(const TuyChonViTri()), isNull);
    expect(viTriTuTuyChon(t)?.kinhDo, 105.9);
  });
}
