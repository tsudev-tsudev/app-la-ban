import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/dinh_danh.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// Dịch vụ RASP của lần chạy (null: chế độ an toàn / test không bật).
final dichVuRaspProvider = Provider<DichVuRasp?>((_) => null);

/// Mã REF của lần bị khoá trước (lưu ở `rasp.json`): app mở lại khi offline
/// vẫn hiện màn khoá cho tới khi server trả trạng thái khác `banned`.
final khoaDaLuuProvider = Provider<String?>((_) => null);

/// Mức rủi ro hiện hành + mã REF - suy từ trạng thái SERVER (Q8), không từ
/// tín hiệu cục bộ.
final ruiRoProvider = Provider<({MucRuiRo muc, String? ref})>((ref) {
  final tt = ref.watch(tinhTrangProvider);
  if (tt != null) {
    return (muc: MucRuiRo.tu(tt.trangThai, tt.mucTin), ref: tt.ref);
  }
  final daLuu = ref.watch(khoaDaLuuProvider);
  return daLuu == null
      ? (muc: MucRuiRo.thap, ref: null)
      : (muc: MucRuiRo.nghiemTrong, ref: daLuu);
});

/// Cờ tính năng nhạy cảm bị tắt theo mức rủi ro (Spec §7.3: MEDIUM trở lên).
Set<CoTinhNang> coTatTheoRuiRo(MucRuiRo muc) => muc.choTinhNangNhayCam
    ? const {}
    : const {CoTinhNang.chiaSe, CoTinhNang.dongBo, CoTinhNang.quangCao};

/// `rasp.json` + dịch vụ RASP gửi qua kênh đã ký của [dv].
DichVuRasp taoDichVuRasp(KhoLuuTru kho, DichVuDinhDanh dv) {
  final pb = tachPhienBan(phienBanApp);
  return DichVuRasp(
    nenTang: const NenTangThietBiKenh(),
    tep: KhoTrangThaiTep(TepJson.mo('${kho.thuMuc}/rasp.json')),
    gui: dv.guiSuKien,
    cauHinh: CauHinhRasp(
      phienBanApp: pb.ten,
      build: pb.build,
      // Bản debug ký bằng khoá debug của máy dev -> không so chứng chỉ.
      chungChiHopLe: kReleaseMode ? const [Flavor.chungChiUpload] : const [],
      guiMayChu: !kDebugMode,
    ),
  )..baoLuuTru(
    lyDo: kho.anToan?.name,
    loiCsdl: kho.ketQuaCsdl.loi?.code,
    matKhoa: kho.ketQuaCsdl.lamMoiDoMatKhoa,
  );
}

/// Đọc mã REF đã lưu (null = chưa từng bị khoá / đã gỡ).
String? docKhoaDaLuu(KhoLuuTru kho) =>
    TepJson.mo('${kho.thuMuc}/rasp.json').duLieu['khoa'] as String?;

/// Lịch kiểm tra (SEC-APP APP-05): sau khung đầu [cho] + ngẫu nhiên, rồi định
/// kỳ [khoang] +- ngẫu nhiên (không một điểm kiểm cố định dễ vá), mỗi lần
/// quay lại foreground (cách nhau >= 5 phút). freeRASP chạy song song, tự
/// báo khi phát hiện. Bị cấm (CRITICAL) -> gửi nốt sự kiện rồi huỷ phiên.
void batDauRasp(
  DichVuRasp rasp,
  Flavor flavor, {
  DichVuDinhDanh? dinhDanh,
  KenhApp? kenh,
  Random? ngauNhien,
  Duration cho = const Duration(seconds: 2),
  Duration khoang = const Duration(minutes: 30),
}) {
  final r = ngauNhien ?? Random.secure();
  DateTime? lanCuoi;
  Timer? hen;

  void kiem() {
    lanCuoi = DateTime.now();
    unawaited(rasp.kiemTra());
  }

  void henDinhKy() {
    hen?.cancel();
    final ms = khoang.inMilliseconds;
    hen = Timer(Duration(milliseconds: ms ~/ 2 + r.nextInt(ms)), () {
      kiem();
      henDinhKy();
    });
  }

  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(cho + Duration(milliseconds: r.nextInt(6000)), () {
      kiem();
      henDinhKy();
      if (!kIsWeb && Platform.isAndroid) {
        nguonFreeRasp(
          cauHinhFreeRasp(
            goi: flavor.goi,
            chungChi: const [Flavor.chungChiUpload],
            banThat: kReleaseMode,
          ),
        ).listen(rasp.nhan);
      }
      AppLifecycleListener(
        onResume: () {
          final lc = lanCuoi;
          if (lc == null ||
              DateTime.now().difference(lc) >= const Duration(minutes: 5)) {
            kiem();
          }
        },
      );
    }),
  );

  if (kenh != null && dinhDanh != null) {
    var daHuy = false;
    kenh.addListener(() {
      final tt = kenh.tinhTrang;
      if (tt == null) return;
      unawaited(
        apKhoa(
          rasp,
          dinhDanh,
          tt,
          daHuy: daHuy,
        ).then((huy) => daHuy = daHuy || huy),
      );
    });
  }
}

/// Lưu / gỡ khoá theo trạng thái server. CRITICAL: gửi nốt hàng chờ sự kiện
/// TRƯỚC rồi mới huỷ phiên (Spec §7.3). Trả true khi đã huỷ phiên.
Future<bool> apKhoa(
  DichVuRasp rasp,
  DichVuDinhDanh dv,
  TinhTrangThietBi tt, {
  bool daHuy = false,
}) async {
  final muc = MucRuiRo.tu(tt.trangThai, tt.mucTin);
  final luu = rasp.tep.duLieu['khoa'];
  if (!muc.khoaApp) {
    if (luu != null) await rasp.tep.ghi({...rasp.tep.duLieu}..remove('khoa'));
    return false;
  }
  if (luu != tt.ref) {
    await rasp.tep.ghi({...rasp.tep.duLieu, 'khoa': tt.ref ?? ''});
  }
  if (daHuy) return false;
  await rasp.xa();
  await dv.huyPhien();
  return true;
}

/// Bọc toàn app (MaterialApp.builder, trong KhungCapNhat): CRITICAL -> màn
/// khoá; HIGH -> băng thông báo cố định phía trên, la bàn offline vẫn dùng.
class KhungRuiRo extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rr = ref.watch(ruiRoProvider);
    // Nằm trên Navigator (MaterialApp.builder): màn khoá tự có Overlay để
    // chọn chữ REF; băng chỉ có chữ thường + nút chép.
    return switch (rr.muc) {
      MucRuiRo.nghiemTrong => Overlay.wrap(child: ManKhoa(maRef: rr.ref)),
      MucRuiRo.cao => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(child: BangHanChe(maRef: rr.ref)),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
      _ => child,
    };
  }
}

/// Trang khiếu nại theo ngôn ngữ giao diện.
Uri trangKhieuNai(Locale l) => Uri.parse(
  l.languageCode == 'vi'
      ? 'https://compass.tsudev.com/khieu-nai'
      : 'https://compass.tsudev.com/en/appeal',
);

/// Mã REF + nút chép (không lộ nguyên nhân kỹ thuật - Spec §7.3).
class _MaRef extends StatelessWidget {
  const new(this.maRef, {this.chonDuoc = false});

  final String maRef;

  /// SelectableText cần Overlay phía trên.
  final bool chonDuoc;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kieu = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        if (chonDuoc)
          SelectableText(
            l10n.securityRef(maRef),
            key: const ValueKey('ma-ref'),
            style: kieu,
          )
        else
          Text(
            l10n.securityRef(maRef),
            key: const ValueKey('ma-ref'),
            style: kieu,
          ),
        TextButton(
          key: const ValueKey('chep-ref'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final xong = l10n.securityRefCopied;
            await Clipboard.setData(ClipboardData(text: maRef));
            messenger?.showSnackBar(SnackBar(content: Text(xong)));
          },
          child: Text(l10n.securityCopyRef),
        ),
      ],
    );
  }
}

/// Băng HIGH: tính năng trực tuyến bị hạn chế, la bàn vẫn dùng được.
class BangHanChe extends StatelessWidget {
  const new({this.maRef, super.key});

  final String? maRef;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = LbThemeExt.of(context).colors;
    final chu = Theme.of(context).textTheme;
    final ref = maRef;
    return Material(
      key: const ValueKey('bang-han-che'),
      color: Color.alphaBlend(c.warning.withValues(alpha: 0.18), c.surface),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LbIcon(LbIcons.khien, color: c.warningStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.securityRestrictedTitle,
                      style: chu.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l10n.securityRestrictedBody, style: chu.bodyMedium),
              if (ref != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _MaRef(ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Màn khoá CRITICAL: chỉ logo, thông báo chung, mã REF và đường khiếu nại.
/// Bật FLAG_SECURE khi đang hiện.
class ManKhoa extends StatefulWidget {
  const new({this.maRef, this.nenTang = const NenTangThietBiKenh(), super.key});

  final String? maRef;
  final NenTangThietBi nenTang;

  @override
  State<ManKhoa> createState() => _ManKhoaState();
}

class _ManKhoaState extends State<ManKhoa> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.nenTang.cheManHinh(bat: true));
  }

  @override
  void dispose() {
    unawaited(widget.nenTang.cheManHinh(bat: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final ref = widget.maRef;
    return Scaffold(
      key: const ValueKey('man-khoa'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const LbLogo(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.securityLockedTitle,
                    style: chu.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.securityLockedBody,
                    style: chu.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (ref != null && ref.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MaRef(ref, chonDuoc: true),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('khieu-nai'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final loi = l10n.securityAppealOpenFailed;
                      final url = trangKhieuNai(
                        Localizations.localeOf(context),
                      );
                      if (!await moTrangLaBan(url)) {
                        messenger?.showSnackBar(SnackBar(content: Text(loi)));
                      }
                    },
                    child: Text(l10n.securityAppeal),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
