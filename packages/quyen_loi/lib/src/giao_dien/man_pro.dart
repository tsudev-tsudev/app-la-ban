import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:quyen_loi/src/dich_vu_quyen_loi.dart';
import 'package:quyen_loi/src/domain/luong_mua.dart';
import 'package:quyen_loi/src/domain/quyen_loi.dart';
import 'package:quyen_loi/src/domain/san_pham.dart';

/// Dịch vụ của lần chạy (null: test / chưa nối / chế độ an toàn).
final dichVuQuyenLoiProvider = Provider<DichVuQuyenLoi?>((_) => null);

/// Quyền lợi đang áp dụng (miễn phí khi chưa có dịch vụ).
final trangThaiQuyenLoiProvider = Provider<TrangThaiQuyenLoi>((ref) {
  final dv = ref.watch(dichVuQuyenLoiProvider);
  if (dv == null) {
    return const TrangThaiQuyenLoi(MucQuyenLoi.mienPhi, QuyenLoi.mienPhi);
  }
  void doi() => ref.invalidateSelf();
  dv.addListener(doi);
  ref.onDispose(() => dv.removeListener(doi));
  return dv.trangThai;
});

/// Mở trang Gói thuê bao của Google Play (huỷ / đổi gói). App nối; null ->
/// ẩn nút.
final moQuanLyGoiProvider = Provider<Future<bool> Function()?>((_) => null);

/// Paywall La bàn Pro (M1a bước 2): giá lấy từ Play, điều khoản tự gia hạn
/// theo chính sách Play, Khôi phục, Quản lý gói. Mọi vùng đổi trạng thái dùng
/// ô cố định (A9c - không nhảy layout).
class ManPro extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManPro> createState() => _ManProState();
}

class _ManProState extends ConsumerState<ManPro> {
  SanPham _chon = SanPham.proNam;

  @override
  void initState() {
    super.initState();
    // Sau khung đầu: tải gói phát thông báo, không được báo trong lúc dựng.
    final dv = ref.read(dichVuQuyenLoiProvider);
    if (dv != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(dv.taiGoi());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dv = ref.watch(dichVuQuyenLoiProvider);
    final ql = ref.watch(trangThaiQuyenLoiProvider);
    final moQuanLy = ref.watch(moQuanLyGoiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.m1ProTitle)),
      body: dv == null
          ? Center(child: Text(l10n.m1Unavailable, textAlign: TextAlign.center))
          : ListenableBuilder(
              listenable: dv,
              builder: (context, _) {
                final s = dv.mua;
                final goi = s.goi;
                final chon = goi.isEmpty
                    ? null
                    : goi.firstWhere(
                        (g) => g.sanPham == _chon,
                        orElse: () => goi.first,
                      );
                return ListView(
                  padding: const EdgeInsets.all(LbSpacing.md),
                  children: [
                    _DauTrang(ql: ql),
                    const SizedBox(height: LbSpacing.md),
                    const _LoiIch(),
                    const SizedBox(height: LbSpacing.md),
                    if (!ql.coPro) ...[
                      _VungGoi(
                        s: s,
                        chon: chon,
                        khiChon: (sp) => setState(() => _chon = sp),
                        khiThuLai: () => unawaited(dv.taiGoi()),
                      ),
                      const SizedBox(height: LbSpacing.sm),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('mua-pro'),
                          onPressed: chon == null || s.ban
                              ? null
                              : () => unawaited(dv.muaGoi(chon)),
                          child: Text(
                            chon?.ngayDungThu != null
                                ? l10n.m1StartTrial
                                : l10n.m1Continue,
                          ),
                        ),
                      ),
                    ],
                    _ThongBao(s: s, boLoi: dv.boLoi),
                    if (!ql.coPro && chon != null) _DieuKhoan(goi: chon),
                    const SizedBox(height: LbSpacing.sm),
                    TextButton(
                      key: const ValueKey('khoi-phuc'),
                      onPressed: s.ban ? null : () => unawaited(dv.khoiPhuc()),
                      child: Text(l10n.m1Restore),
                    ),
                    if (moQuanLy != null)
                      TextButton(
                        key: const ValueKey('quan-ly-goi'),
                        onPressed: () async {
                          if (!await moQuanLy() && context.mounted) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(content: Text(l10n.m1ManageFailed)),
                            );
                          }
                        },
                        child: Text(l10n.m1Manage),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _DauTrang extends StatelessWidget {
  const new({required this.ql});

  final TrangThaiQuyenLoi ql;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = Theme.of(context);
    final het = ql.quyenLoi.hetHan;
    final phu = !ql.coPro
        ? l10n.m1ProTagline
        : ql.muc == MucQuyenLoi.anHan
        ? l10n.m1Grace
        : het == null
        ? l10n.m1ActiveLifetime
        : l10n.m1ActiveUntil(
            MaterialLocalizations.of(context)
                .formatMediumDate(DateTime.fromMillisecondsSinceEpoch(het)),
          );
    return Semantics(
      container: true,
      child: Row(
        children: [
          Icon(Icons.workspace_premium, size: 48, color: t.colorScheme.primary),
          const SizedBox(width: LbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ql.coPro ? l10n.m1Active : l10n.m1ProTitle,
                  style: t.textTheme.titleLarge,
                ),
                const SizedBox(height: LbSpacing.xxs),
                Text(phu, style: t.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoiIch extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mau = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        for (final (icon, chu) in [
          (Icons.block, l10n.m1BenefitNoAds),
          (Icons.explore, l10n.m1BenefitFree),
          (Icons.auto_awesome, l10n.m1BenefitNew),
          (Icons.favorite, l10n.m1BenefitSupport),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LbSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, color: mau, size: 22)),
                const SizedBox(width: LbSpacing.sm),
                Expanded(child: Text(chu)),
              ],
            ),
          ),
      ],
    );
  }
}

class _VungGoi extends StatelessWidget {
  const new({
    required this.s,
    required this.chon,
    required this.khiChon,
    required this.khiThuLai,
  });

  final TrangThaiMua s;
  final GoiBan? chon;
  final ValueChanged<SanPham> khiChon;
  final VoidCallback khiThuLai;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (s.goi.isNotEmpty) {
      return RadioGroup<SanPham>(
        groupValue: chon?.sanPham,
        onChanged: (v) {
          if (v != null && !s.ban) khiChon(v);
        },
        child: Column(children: [for (final g in s.goi) _TheGoi(goi: g)]),
      );
    }
    final dangTai = s.giaiDoan == GiaiDoanMua.dangTai;
    return LbOCoDinh(
      chiSo: dangTai ? 0 : 1,
      phuongAn: [
        Padding(
          padding: const EdgeInsets.all(LbSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: LbSpacing.sm),
              Flexible(child: Text(l10n.m1Loading)),
            ],
          ),
        ),
        Column(
          children: [
            Text(l10n.m1Unavailable, textAlign: TextAlign.center),
            TextButton(onPressed: khiThuLai, child: Text(l10n.m1Retry)),
          ],
        ),
      ],
    );
  }
}

class _TheGoi extends StatelessWidget {
  const new({required this.goi});

  final GoiBan goi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ten = switch (goi.sanPham) {
      SanPham.proNam => l10n.m1PlanYear,
      SanPham.proThang => l10n.m1PlanMonth,
      SanPham.proVinhVien => l10n.m1PlanLifetime,
    };
    final gia = giaTheoKy(l10n, goi);
    final thu = goi.ngayDungThu;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: LbSpacing.xxs),
      child: RadioListTile<SanPham>(
        key: ValueKey('goi-${goi.sanPham.ma}'),
        value: goi.sanPham,
        title: Text(ten),
        subtitle: Text(thu == null ? gia : '$gia\n${l10n.m1TrialBadge(thu)}'),
        isThreeLine: thu != null,
      ),
    );
  }
}

/// Giá kèm kỳ ("99.000 đ / năm") theo loại gói.
String giaTheoKy(LbL10n l10n, GoiBan g) {
  if (!g.sanPham.dangKy) return l10n.m1PriceOnce(g.giaHienThi);
  return switch (g.donVi) {
    DonViKy.thang => l10n.m1PricePerMonth(g.giaHienThi),
    DonViKy.nam => l10n.m1PricePerYear(g.giaHienThi),
    _ => g.giaHienThi,
  };
}

class _ThongBao extends StatelessWidget {
  const new({required this.s, required this.boLoi});

  final TrangThaiMua s;
  final VoidCallback boLoi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = Theme.of(context);
    final loi = s.loi;
    final (String? chu, bool laLoi) = loi != null
        ? (thongBaoLoi(l10n, loi), true)
        : switch (s.giaiDoan) {
            GiaiDoanMua.choThanhToan => (l10n.m1Pending, false),
            GiaiDoanMua.dangXacMinh => (l10n.m1Verifying, false),
            GiaiDoanMua.thanhCong => (l10n.m1Success, false),
            _ => (null, false),
          };
    if (chu == null) return const SizedBox(height: LbSpacing.sm);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LbSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Card(
          color: laLoi
              ? t.colorScheme.errorContainer
              : t.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              LbSpacing.md,
              LbSpacing.sm,
              LbSpacing.xs,
              LbSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chu,
                    style: TextStyle(
                      color: laLoi
                          ? t.colorScheme.onErrorContainer
                          : t.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (laLoi)
                  IconButton(
                    tooltip: l10n.m1Dismiss,
                    onPressed: boLoi,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lỗi -> chuỗi hiển thị.
String thongBaoLoi(LbL10n l10n, LoiMua l) => switch (l) {
  LoiMua.mang => l10n.m1ErrNetwork,
  LoiMua.cuaHang => l10n.m1ErrStore,
  LoiMua.tokenSai => l10n.m1ErrToken,
  LoiMua.quaSoThietBi => l10n.m1ErrShared,
  LoiMua.khongPhaiBanPlay => l10n.m1ErrNotPlay,
  LoiMua.mayChu => l10n.m1ErrServer,
  LoiMua.khongCoGiaoDich => l10n.m1ErrNothing,
};

class _DieuKhoan extends StatelessWidget {
  const new({required this.goi});

  final GoiBan goi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gia = giaTheoKy(l10n, goi);
    final thu = goi.ngayDungThu;
    final chu = !goi.sanPham.dangKy
        ? l10n.m1TermsLifetime
        : [
            if (thu != null) l10n.m1TermsTrial(thu, gia),
            l10n.m1TermsSub(gia),
          ].join(' ');
    return Text(chu, style: Theme.of(context).textTheme.bodySmall);
  }
}

/// Mục "La bàn Pro" trong Cài đặt (app truyền vào `ManCaiDat`).
class MucPro extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ql = ref.watch(trangThaiQuyenLoiProvider);
    return ListTile(
      key: const ValueKey('muc-pro'),
      leading: Icon(
        Icons.workspace_premium,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(l10n.m1ProTitle),
      subtitle: Text(ql.coPro ? l10n.m1SettingsSubPro : l10n.m1SettingsSubFree),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const ManPro())),
    );
  }
}
