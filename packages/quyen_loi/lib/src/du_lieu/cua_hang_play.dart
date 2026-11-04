import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:quyen_loi/src/domain/san_pham.dart';
import 'package:quyen_loi/src/du_lieu/cua_hang.dart';

/// Google Play Billing qua plugin chính chủ `in_app_purchase` (Q55 - không
/// SDK bên thứ ba). Chỉ Android; nền tảng khác báo không khả dụng (iOS ở I1).
final class CuaHangPlay implements CuaHang {
  new({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> khaDung() async {
    try {
      return await _iap.isAvailable();
    } on Object {
      return false;
    }
  }

  @override
  Future<List<GoiBan>> taiGoi() async {
    final ProductDetailsResponse r;
    try {
      r = await _iap.queryProductDetails(SanPham.dsMa);
    } on Object {
      return const [];
    }
    final theoSp = <SanPham, List<GooglePlayProductDetails>>{};
    for (final p in r.productDetails.whereType<GooglePlayProductDetails>()) {
      final sp = SanPham.tuMa(p.id);
      if (sp != null) (theoSp[sp] ??= []).add(p);
    }
    final ds = <GoiBan>[];
    for (final MapEntry(key: sp, value: cac) in theoSp.entries) {
      if (!sp.dangKy) {
        ds.add(
          GoiBan(sanPham: sp, giaHienThi: cac.first.price, nguon: cac.first),
        );
        continue;
      }
      final uuDai = [
        for (final p in cac)
          if (p.subscriptionIndex case final i?)
            if (p.productDetails.subscriptionOfferDetails?[i] case final o?)
              UuDai(
                basePlan: o.basePlanId,
                offerId: o.offerId,
                chiSo: i,
                giaiDoan: [
                  for (final g in o.pricingPhases)
                    GiaiDoanGia(
                      giaMicros: g.priceAmountMicros,
                      giaHienThi: g.formattedPrice,
                      kyHan: g.billingPeriod,
                      soChuKy: g.billingCycleCount,
                      lapVoHan:
                          g.recurrenceMode == RecurrenceMode.infiniteRecurring,
                    ),
                ],
              ),
      ];
      final chon = chonUuDai(uuDai);
      final gia = chon?.giaGiaHan;
      if (chon == null || gia == null) continue;
      ds.add(
        GoiBan(
          sanPham: sp,
          giaHienThi: gia.giaHienThi,
          donVi: donViKy(gia.kyHan),
          ngayDungThu: chon.ngayDungThu,
          nguon: cac.firstWhere((p) => p.subscriptionIndex == chon.chiSo),
        ),
      );
    }
    return sapXepGoi(ds);
  }

  @override
  Stream<List<GiaoDich>> get capNhat =>
      _iap.purchaseStream.map((ds) => [for (final p in ds) _tuPlugin(p)]);

  @override
  Future<bool> mua(GoiBan goi, {required String maTaiKhoan}) async {
    final p = goi.nguon;
    if (p is! ProductDetails) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: p,
          applicationUserName: maTaiKhoan,
        ),
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<List<GiaoDich>> khoiPhuc() async => [
    for (final p in await _quaKhu())
      if (p.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.purchased)
        _tuPlugin(p, loai: LoaiGiaoDich.khoiPhuc),
  ];

  @override
  Future<List<GiaoDich>> chuaXacNhan() async => [
    for (final p in await _quaKhu())
      if (p.billingClientPurchase.purchaseState ==
              PurchaseStateWrapper.purchased &&
          !p.billingClientPurchase.isAcknowledged)
        _tuPlugin(p, loai: LoaiGiaoDich.daMua),
  ];

  @override
  Future<void> hoanTat(GiaoDich g) async {
    final p = g.nguon;
    if (p is! PurchaseDetails || !p.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(p);
    } on Object {
      // Worker đã acknowledge ở nền (M1a bước 3) - lỗi ở đây không làm
      // mất quyền lợi.
    }
  }

  Future<List<GooglePlayPurchaseDetails>> _quaKhu() async {
    try {
      final a = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await a.queryPastPurchases();
      return r.error == null ? r.pastPurchases : const [];
    } on Object {
      return const [];
    }
  }

  static GiaoDich _tuPlugin(PurchaseDetails p, {LoaiGiaoDich? loai}) =>
      GiaoDich(
        maSanPham: p.productID,
        token: p.verificationData.serverVerificationData,
        loai:
            loai ??
            switch (p.status) {
              PurchaseStatus.pending => LoaiGiaoDich.choThanhToan,
              PurchaseStatus.purchased => LoaiGiaoDich.daMua,
              PurchaseStatus.restored => LoaiGiaoDich.khoiPhuc,
              PurchaseStatus.error => LoaiGiaoDich.loi,
              PurchaseStatus.canceled => LoaiGiaoDich.huy,
            },
        canHoanTat: p.pendingCompletePurchase,
        nguon: p,
      );
}
