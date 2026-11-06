import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:app_shell/src/domain/chuyen_pro.dart';
import 'package:app_shell/src/pro.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/location_feature.dart';
import 'package:map_feature/map_feature.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// M2b bước 3 (QUYET_DINH Q56, Q66): chuyển dữ liệu bản miễn phí -> La bàn
/// Pro trên cùng máy. Bản miễn phí ghi gói vào Content Provider của nó (quyền
/// `signature`) rồi mở màn nhận của app Pro; app Pro đọc gói, cho người dùng
/// xem lại rồi mới ghi.

/// Yêu cầu từ app kia, đọc MỘT lần: bản miễn phí nhận "mở màn chuyển" (người
/// dùng bấm trong app Pro), app Pro nhận gói dữ liệu.
typedef YeuCauChuyen = ({bool moChuyen, Uint8List? goi});

/// Phần nền tảng (Kotlin ở `app/android` và `app_pro/android`).
abstract interface class NenTangChuyenPro {
  /// App kia (bản miễn phí <-> Pro cùng flavor) đã cài VÀ cùng chứng chỉ ký.
  Future<bool> ungDungKiaHopLe();

  /// Bản miễn phí: đưa gói vào Content Provider rồi mở màn nhận của app Pro.
  Future<bool> guiSangPro(Uint8List goi);

  /// Bản miễn phí: mở app Pro. App Pro: mở màn chuyển của bản miễn phí.
  Future<bool> moUngDungKia();

  Future<YeuCauChuyen?> layYeuCau();
}

/// Không có nền tảng (test, iOS - app Pro chỉ có Android).
final class NenTangChuyenProKhong implements NenTangChuyenPro {
  const new();

  @override
  Future<bool> ungDungKiaHopLe() async => false;

  @override
  Future<bool> guiSangPro(Uint8List goi) async => false;

  @override
  Future<bool> moUngDungKia() async => false;

  @override
  Future<YeuCauChuyen?> layYeuCau() async => null;
}

/// Kênh `la_ban/chuyen_pro` (MainActivity của từng app đăng ký).
final class NenTangChuyenProKenh implements NenTangChuyenPro {
  const new();

  static const _kenh = MethodChannel('la_ban/chuyen_pro');

  Future<T?> _goi<T>(String ten, [Object? thamSo]) async {
    try {
      return await _kenh.invokeMethod<T>(ten, thamSo);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> ungDungKiaHopLe() async =>
      await _goi<bool>('ungDungKiaHopLe') ?? false;

  @override
  Future<bool> guiSangPro(Uint8List goi) async =>
      await _goi<bool>('guiSangPro', {'goi': goi}) ?? false;

  @override
  Future<bool> moUngDungKia() async =>
      await _goi<bool>('moUngDungKia') ?? false;

  @override
  Future<YeuCauChuyen?> layYeuCau() async {
    final m = await _goi<Map<Object?, Object?>>('layYeuCau');
    return switch (m?['loai']) {
      'mo-chuyen' => (moChuyen: true, goi: null),
      'goi' when m!['duLieu'] is Uint8List => (
        moChuyen: false,
        goi: m['duLieu']! as Uint8List,
      ),
      _ => null,
    };
  }
}

final nenTangChuyenProProvider = Provider<NenTangChuyenPro>(
  (_) => const NenTangChuyenProKhong(),
);

/// App kia có hợp lệ không (đọc lại mỗi lần mở Cài đặt).
final FutureProvider<bool> ungDungKiaProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(nenTangChuyenProProvider).ungDungKiaHopLe(),
);

/// Trang La bàn Pro trên Google Play.
final Uri trangPlayPro = Uri.https('play.google.com', '/store/apps/details', {
  'id': 'com.tsudev.laban.pro',
});

/// Dữ liệu bản miễn phí sẽ gửi.
typedef NguonChuyen = ({
  List<DiemMoc> diem,
  List<AnhChuyen> anh,
  List<VungChuyen> vung,
});

/// Gom dữ liệu bản miễn phí (điểm + ảnh từ CSDL mã hoá, vùng offline từ
/// MapLibre). Vùng không đọc được -> bỏ qua, vẫn gửi điểm.
Future<NguonChuyen> thuThapNguon(WidgetRef ref) async {
  final kho = ref.read(khoDiemProvider);
  final diem = kho == null ? <DiemMoc>[] : await kho.tatCa();
  final anh = <AnhChuyen>[];
  if (kho != null) {
    for (final d in diem) {
      for (final a in await kho.theoDoiAnh(d.id).first) {
        anh.add((
          diemId: d.id,
          duLieu: a.duLieu,
          rong: a.rong,
          cao: a.cao,
          taoLuc: d.suaLuc,
        ));
      }
    }
  }
  var vung = <VungChuyen>[];
  try {
    vung = [
      for (final v in await ref.read(khoVungOfflineProvider).danhSach())
        if (v.khung case final k?)
          (
            ten: v.ten,
            bac: k.bac,
            nam: k.nam,
            dong: k.dong,
            tay: k.tay,
            zMin: v.zMin,
            zMax: v.zMax,
            tongQuan: v.tongQuan,
          ),
    ];
  } on Object {
    vung = [];
  }
  return (diem: diem, anh: anh, vung: vung);
}

/// Đóng gói JSON ở isolate riêng (ảnh base64 vài MB không giật giao diện).
Future<Uint8List> dongGoiChuyen(
  WidgetRef ref,
  NguonChuyen nguon, {
  required String phienBan,
}) => _dongGoiNen(
  nguon,
  phienBan: phienBan,
  caiDat: ref.read(caiDatProvider).toJson(),
  laBan: ref.read(tuyChonLaBanProvider).toJson(),
  viTri: ref.read(tuyChonViTriProvider).toJson(),
  luc: DateTime.now(),
);

// Hàm top-level: closure gửi sang isolate chỉ được giữ dữ liệu thuần (không
// State / ref).
Future<Uint8List> _dongGoiNen(
  NguonChuyen nguon, {
  required String phienBan,
  required Map<String, Object?> caiDat,
  required Map<String, Object?> laBan,
  required Map<String, Object?> viTri,
  required DateTime luc,
}) => Isolate.run(
  () => utf8.encode(
    jsonEncode(
      taoGoiChuyen(
        phienBanApp: phienBan,
        luc: luc,
        diem: nguon.diem,
        anh: nguon.anh,
        vung: nguon.vung,
        caiDat: caiDat,
        tuyChonLaBan: laBan,
        viTri: viTri,
      ),
    ),
  ),
);

/// Đọc + kiểm gói ở isolate riêng.
Future<GoiChuyen> docGoiNen(Uint8List byte) =>
    Isolate.run(() => docGoiChuyen(byte));

/// Ghi kế hoạch vào app Pro: điểm trong một transaction, ảnh cho điểm mới,
/// rồi (nếu chọn) lựa chọn giao diện / la bàn / định dạng toạ độ.
Future<void> apDungNhap(
  WidgetRef ref,
  GoiChuyen g,
  KeHoachNhapPro kh, {
  required bool caiDat,
}) async {
  final kho = ref.read(khoDiemProvider);
  if (kho != null) {
    await kho.luuNhieu([...kh.them, ...kh.capNhat]);
    for (final a in kh.anh) {
      await kho.themAnh(a.diemId, (
        duLieu: a.duLieu,
        rong: a.rong,
        cao: a.cao,
      ), luc: a.taoLuc);
    }
  }
  if (!caiDat) return;
  final c = g.caiDat;
  final cd = ref.read(caiDatProvider.notifier);
  if (c.ngonNgu case final v?) cd.datNgonNgu(LuaChonNgonNgu.values.byName(v));
  if (c.cheDo case final v?) cd.datCheDo(CheDoGiaoDien.values.byName(v));
  final lb = ref.read(tuyChonLaBanProvider.notifier);
  if (c.bacThuc case final v?) lb.datBacThuc(bat: v);
  if (c.rung case final v?) lb.datRung(bat: v);
  if (c.dinhDangToaDo case final v?) {
    ref
        .read(tuyChonViTriProvider.notifier)
        .datDinhDang(DinhDangToaDo.values.byName(v));
  }
}

void _bao(BuildContext context, String s) => ScaffoldMessenger.maybeOf(context)
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(s)));

/// Bản miễn phí: màn "Chuyển sang La bàn Pro".
class ManChuyenSangPro extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManChuyenSangPro> createState() => _ManChuyenSangProState();
}

class _ManChuyenSangProState extends ConsumerState<ManChuyenSangPro> {
  NguonChuyen? _nguon;
  var _dangGui = false;

  @override
  void initState() {
    super.initState();
    unawaited(_nap());
  }

  Future<void> _nap() async {
    final n = await thuThapNguon(ref);
    if (mounted) setState(() => _nguon = n);
  }

  Future<void> _gui() async {
    final nguon = _nguon;
    if (nguon == null) return;
    final loi = context.l10n.m2bMoveFailed;
    setState(() => _dangGui = true);
    var ok = false;
    try {
      final goi = await dongGoiChuyen(
        ref,
        nguon,
        phienBan: ref.read(cauHinhSanPhamProvider).phienBan,
      );
      ok = await ref.read(nenTangChuyenProProvider).guiSangPro(goi);
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _dangGui = false);
    if (!ok) _bao(context, loi);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kieu = Theme.of(context).textTheme;
    final hopLe = ref.watch(ungDungKiaProvider).value;
    final n = _nguon;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.m2bMoveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LbSpacing.md),
        children: [
          Text(l10n.m2bMoveIntro, style: kieu.bodyMedium),
          const SizedBox(height: LbSpacing.md),
          if (n == null)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              l10n.m2bMoveCounts(n.diem.length, n.anh.length, n.vung.length),
              key: const ValueKey('chuyen-dem'),
              style: kieu.titleMedium,
            ),
          const SizedBox(height: LbSpacing.lg),
          if (hopLe == false) ...[
            Text(l10n.m2bMoveNotInstalled, style: kieu.bodyMedium),
            const SizedBox(height: LbSpacing.sm),
            OutlinedButton(
              onPressed: () => unawaited(moTrangLaBan(trangPlayPro)),
              child: Text(l10n.m2bMoveGetPro),
            ),
          ] else ...[
            FilledButton(
              key: const ValueKey('chuyen-gui'),
              onPressed: hopLe == true && n != null && !_dangGui
                  ? () => unawaited(_gui())
                  : null,
              child: Text(l10n.m2bMoveSend),
            ),
            const SizedBox(height: LbSpacing.sm),
            OutlinedButton(
              onPressed: hopLe == true
                  ? () => unawaited(
                      ref.read(nenTangChuyenProProvider).moUngDungKia(),
                    )
                  : null,
              child: Text(l10n.m2bMoveOpenPro),
            ),
          ],
        ],
      ),
    );
  }
}

/// App Pro: màn "Nhập dữ liệu từ La bàn". [goi] = gói vừa nhận từ bản miễn
/// phí (null: người dùng mở từ Cài đặt).
class ManNhapTuMienPhi extends ConsumerStatefulWidget {
  const new({this.goi, super.key});

  final Uint8List? goi;

  @override
  ConsumerState<ManNhapTuMienPhi> createState() => _ManNhapTuMienPhiState();
}

class _ManNhapTuMienPhiState extends ConsumerState<ManNhapTuMienPhi> {
  GoiChuyen? _goi;
  KeHoachNhapPro? _keHoach;
  var _caiDat = true;
  var _dangGhi = false;

  /// Sau khi nhập: kết quả + vùng cần tải lại.
  ({int them, int capNhat})? _xong;

  @override
  void initState() {
    super.initState();
    if (widget.goi case final g?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_doc(g)));
    }
  }

  Future<void> _doc(Uint8List byte) async {
    final l10n = context.l10n;
    final GoiChuyen g;
    try {
      g = await docGoiNen(byte);
    } on FormatException {
      if (mounted) _bao(context, l10n.m2bImportBadFile);
      return;
    }
    if (g.rong) {
      if (mounted) _bao(context, l10n.m2bImportEmpty);
      return;
    }
    final kho = ref.read(khoDiemProvider);
    final coSan = {for (final d in await kho?.tatCa() ?? <DiemMoc>[]) d.id: d};
    if (!mounted) return;
    setState(() {
      _goi = g;
      _keHoach = keHoachNhapPro(g, coSan: coSan);
      _xong = null;
    });
  }

  Future<void> _layTuMienPhi() async {
    final l10n = context.l10n;
    final nt = ref.read(nenTangChuyenProProvider);
    if (!await nt.ungDungKiaHopLe() || !await nt.moUngDungKia()) {
      if (mounted) _bao(context, l10n.m2bImportFreeMissing);
    }
  }

  Future<void> _chonTep() async {
    final l10n = context.l10n;
    final Uint8List? byte;
    try {
      byte = await ref.read(nenTangDiemProvider).moTep();
    } on PlatformException {
      if (mounted) _bao(context, l10n.wpFileError);
      return;
    }
    if (byte != null) await _doc(byte);
  }

  Future<void> _nhap() async {
    final g = _goi;
    final kh = _keHoach;
    if (g == null || kh == null) return;
    final l10n = context.l10n;
    setState(() => _dangGhi = true);
    try {
      await apDungNhap(ref, g, kh, caiDat: _caiDat);
    } on Object {
      if (mounted) {
        setState(() => _dangGhi = false);
        _bao(context, l10n.wpFileError);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _dangGhi = false;
      _xong = (them: kh.them.length, capNhat: kh.capNhat.length);
    });
    _bao(context, l10n.m2bImportDone(kh.them.length, kh.capNhat.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kieu = Theme.of(context).textTheme;
    final g = _goi;
    final kh = _keHoach;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.m2bImportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LbSpacing.md),
        children: [
          if (g == null || kh == null) ...[
            Text(l10n.m2bImportIntro, style: kieu.bodyMedium),
            const SizedBox(height: LbSpacing.lg),
            FilledButton(
              key: const ValueKey('nhap-tu-mien-phi'),
              onPressed: () => unawaited(_layTuMienPhi()),
              child: Text(l10n.m2bImportFromFree),
            ),
            const SizedBox(height: LbSpacing.sm),
            OutlinedButton(
              key: const ValueKey('nhap-chon-tep'),
              onPressed: () => unawaited(_chonTep()),
              child: Text(l10n.m2bImportFile),
            ),
          ] else if (_xong == null) ...[
            Semantics(
              header: true,
              child: Text(l10n.m2bImportConfirmTitle, style: kieu.titleMedium),
            ),
            const SizedBox(height: LbSpacing.sm),
            Text(
              l10n.m2bImportPlan(kh.them.length, kh.capNhat.length, kh.trung),
              key: const ValueKey('nhap-ke-hoach'),
              style: kieu.bodyLarge,
            ),
            if (kh.anh.isNotEmpty) Text(l10n.m2bImportPhotos(kh.anh.length)),
            if (g.boQua > 0) Text(l10n.m2bImportSkipped(g.boQua)),
            if (!g.coAnhVung) ...[
              const SizedBox(height: LbSpacing.xs),
              Text(l10n.m2bImportNoPhotos, style: kieu.bodySmall),
            ],
            CheckboxListTile(
              key: const ValueKey('nhap-cai-dat'),
              contentPadding: EdgeInsets.zero,
              value: _caiDat,
              onChanged: (v) => setState(() => _caiDat = v ?? false),
              title: Text(l10n.m2bImportSettings),
            ),
            const SizedBox(height: LbSpacing.sm),
            FilledButton(
              key: const ValueKey('nhap-xac-nhan'),
              onPressed: _dangGhi ? null : () => unawaited(_nhap()),
              child: Text(l10n.m2bImportDo),
            ),
          ] else ...[
            Text(
              l10n.m2bImportDone(_xong!.them, _xong!.capNhat),
              key: const ValueKey('nhap-xong'),
              style: kieu.titleMedium,
            ),
            if (g.vung.isNotEmpty) ...[
              const SizedBox(height: LbSpacing.lg),
              Semantics(
                header: true,
                child: Text(l10n.m2bAreasTitle, style: kieu.titleMedium),
              ),
              Text(l10n.m2bAreasIntro, style: kieu.bodySmall),
              for (final v in g.vung) _DongVungTaiLai(vung: v),
            ],
          ],
        ],
      ),
    );
  }
}

/// Một vùng chuyển sang: nút tải lại + tiến độ.
class _DongVungTaiLai extends ConsumerStatefulWidget {
  const new({required this.vung});

  final VungChuyen vung;

  @override
  ConsumerState<_DongVungTaiLai> createState() => _DongVungTaiLaiState();
}

class _DongVungTaiLaiState extends ConsumerState<_DongVungTaiLai> {
  StreamSubscription<TienDoTai>? _sub;
  TienDoTai? _tienDo;
  var _dangTai = false;
  var _xong = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _tai() {
    final v = widget.vung;
    final loi = context.l10n.mapOfflineFailed;
    var coLoi = false;
    setState(() => _dangTai = true);
    _sub =
        taiVung(
          context,
          ref,
          ten: v.ten,
          khung: (tay: v.tay, nam: v.nam, dong: v.dong, bac: v.bac),
          zMin: v.zMin,
          zMax: v.zMax,
          tongQuan: v.tongQuan,
        ).listen(
          (t) {
            if (mounted) setState(() => _tienDo = t);
          },
          onError: (Object _) {
            coLoi = true;
            if (mounted) _bao(context, loi);
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _dangTai = false;
                _xong = !coLoi;
              });
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = widget.vung;
    final t = _tienDo;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        v.tongQuan || v.ten.isEmpty ? l10n.mapOfflineOverview : v.ten,
      ),
      subtitle: Text(
        _dangTai && t != null
            ? l10n.mapOfflineDownloading(t.daXong, t.tong)
            : l10n.mapOfflineZoom(v.zMin, v.zMax),
      ),
      trailing: _xong
          ? Text(l10n.m2bAreaDone)
          : TextButton(
              onPressed: _dangTai ? null : _tai,
              child: Text(l10n.mapOfflineDownload),
            ),
    );
  }
}

/// Mục Cài đặt: app Pro -> "Nhập dữ liệu từ La bàn" (luôn hiện); bản miễn phí
/// -> "Chuyển sang La bàn Pro" khi máy có app Pro chính thức.
class MucChuyenPro extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final laPro = ref.watch(cauHinhSanPhamProvider).laPro;
    if (laPro) {
      return ListTile(
        key: const ValueKey('muc-nhap-mien-phi'),
        leading: Icon(
          Icons.move_down,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(l10n.m2bImportTitle),
        subtitle: Text(l10n.m2bImportSubtitle),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ManNhapTuMienPhi()),
        ),
      );
    }
    if (ref.watch(ungDungKiaProvider).value != true) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const ValueKey('muc-chuyen-pro'),
      leading: Icon(
        Icons.move_up,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.m2bMoveTitle),
      subtitle: Text(l10n.m2bMoveSubtitle),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ManChuyenSangPro())),
    );
  }
}

/// Nghe yêu cầu từ app kia lúc mở app và mỗi lần quay lại foreground, rồi
/// đẩy màn tương ứng lên [dieuHuong].
class KhungChuyenPro extends ConsumerStatefulWidget {
  const new({required this.dieuHuong, required this.child, super.key});

  final GlobalKey<NavigatorState> dieuHuong;
  final Widget child;

  @override
  ConsumerState<KhungChuyenPro> createState() => _KhungChuyenProState();
}

class _KhungChuyenProState extends ConsumerState<KhungChuyenPro> {
  late final AppLifecycleListener _nghe;

  @override
  void initState() {
    super.initState();
    _nghe = AppLifecycleListener(onResume: () => unawaited(_kiem()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_kiem()));
  }

  @override
  void dispose() {
    _nghe.dispose();
    super.dispose();
  }

  Future<void> _kiem() async {
    final yc = await ref.read(nenTangChuyenProProvider).layYeuCau();
    final nav = widget.dieuHuong.currentState;
    if (yc == null || nav == null || !mounted) return;
    final laPro = ref.read(cauHinhSanPhamProvider).laPro;
    final Widget man;
    if (laPro && yc.goi != null) {
      man = ManNhapTuMienPhi(goi: yc.goi);
    } else if (!laPro && yc.moChuyen) {
      man = const ManChuyenSangPro();
    } else {
      return;
    }
    nav.push(MaterialPageRoute<void>(builder: (_) => man));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
