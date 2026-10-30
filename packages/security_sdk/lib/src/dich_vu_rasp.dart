import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:security_sdk/src/domain/chuoi_ky.dart';
import 'package:security_sdk/src/domain/rasp.dart';
import 'package:security_sdk/src/du_lieu/cong.dart';
import 'package:security_sdk/src/du_lieu/nen_tang_thiet_bi.dart';

/// Cấu hình RASP theo flavor / kiểu build.
final class CauHinhRasp {
  const new({
    required this.phienBanApp,
    required this.build,
    required this.chungChiHopLe,
    required this.guiMayChu,
  });

  final String phienBanApp;
  final int build;

  /// SHA-256 hex chứng chỉ ký hợp lệ; rỗng = không kiểm (bản debug).
  final List<String> chungChiHopLe;

  /// false ở bản debug nội bộ (Spec §7.3b: không phạt máy dev): vẫn kiểm
  /// tra + in log để thử, KHÔNG gửi server.
  final bool guiMayChu;
}

/// Gom tín hiệu môi trường (freeRASP + kiểm tra native) -> lô sự kiện đã ký
/// gửi `/v1/events` (SEC-APP APP-02, APP-05). Chỉ BÁO - quyết định chặn ở
/// server (Q8); app phản ứng theo trạng thái server trả về (`MucRuiRo`).
///
/// `rasp.json`: lần báo cuối mỗi loại (`daBao`) + hàng chờ khi offline.
final class DichVuRasp {
  new({
    required this.nenTang,
    required this.tep,
    required this.gui,
    required this.cauHinh,
    int Function()? dongHo,
    String Function()? taoId,
    this.cho = const Duration(seconds: 2),
  }) : _dongHo = dongHo ?? _gioHeThong,
       _taoId = taoId ?? uuidV4;

  final NenTangThietBi nenTang;
  final KhoTrangThai tep;

  /// Gửi lô (thường là `DichVuDinhDanh.guiSuKien`).
  final Future<Result<int>> Function(List<Map<String, Object?>>) gui;
  final CauHinhRasp cauHinh;

  /// Gom tín hiệu đến dồn dập (freeRASP báo nhiều loại cùng lúc) thành một lô.
  final Duration cho;
  final int Function() _dongHo;
  final String Function() _taoId;

  static int _gioHeThong() => DateTime.now().millisecondsSinceEpoch;

  static const _nhatKy = NhatKy('rasp', che: kReleaseMode);

  /// Mọi tín hiệu đã thấy trong lần chạy này (env.root / env.emulator).
  final _daThay = <LoaiTinHieu, Map<String, Object>>{};
  final _choGui = <LoaiTinHieu, Map<String, Object>>{};
  String? _nguonCai;
  Timer? _hen;
  Future<void>? _dangGui;

  /// Loại đã thấy (test / màn chẩn đoán debug).
  Set<LoaiTinHieu> get daThay => _daThay.keys.toSet();

  /// Nhận một tín hiệu (từ stream freeRASP) - gửi sau [cho].
  void nhan(TinHieu t) {
    _ghiNhan([t]);
    _hen?.cancel();
    _hen = Timer(cho, () => unawaited(xa()));
  }

  /// Một lượt kiểm tra native (mở app, định kỳ, trước thao tác nhạy cảm).
  Future<void> kiemTra() async {
    final k = await nenTang.kiemTraMoiTruong();
    _nguonCai = k.nguonCai;
    _ghiNhan(tinHieuTuNative(k, chungChiHopLe: cauHinh.chungChiHopLe));
    await xa();
  }

  /// Chế độ an toàn / lỗi CSDL / mất khoá (A5) - báo cho SOC thống kê.
  void baoLuuTru({String? lyDo, String? loiCsdl, bool matKhoa = false}) {
    if (lyDo == null && loiCsdl == null && !matKhoa) return;
    _ghiNhan([
      (
        loai: LoaiTinHieu.cheDoAnToan,
        chiTiet: {'ly_do': ?lyDo, 'loi_csdl': ?loiCsdl, 'mat_khoa': matKhoa},
      ),
    ]);
  }

  void _ghiNhan(Iterable<TinHieu> ds) {
    gopTinHieu(ds).forEach((l, ct) {
      (_daThay[l] ??= {}).addAll(ct);
      (_choGui[l] ??= {}).addAll(ct);
    });
  }

  /// Gửi các loại cần báo (lọc theo `daBao`); lỗi mạng giữ lại lần sau.
  Future<void> xa() => _dangGui ??= _xa().whenComplete(() => _dangGui = null);

  Future<void> _xa() async {
    if (_choGui.isEmpty) return;
    final bayGio = _dongHo();
    final daBao = _daBao();
    final lo = <LoaiTinHieu, Map<String, Object>>{
      for (final e in _choGui.entries)
        if (canBao(
          daBao: daBao[e.key.loai] as Map<String, Object?>?,
          dauVet: dauVetTinHieu(e.value),
          bayGio: bayGio,
        ))
          e.key: e.value,
    };
    _choGui.clear();
    if (lo.isEmpty) return;
    if (!cauHinh.guiMayChu) {
      for (final e in lo.entries) {
        _nhatKy('${e.key.loai} ${e.value}');
      }
      return;
    }
    final may = await nenTang.thongTin();
    final suKien = [
      for (final e in lo.entries.take(50))
        taoSuKien(
          id: _taoId(),
          loai: e.key,
          chiTiet: e.value,
          luc: DateTime.fromMillisecondsSinceEpoch(bayGio),
          app: (
            phienBan: cauHinh.phienBanApp,
            build: cauHinh.build,
            nguonCai: _nguonCai,
          ),
          moiTruong: (
            heDieuHanh: may.heDieuHanh,
            model: may.model,
            emulator: _daThay.containsKey(LoaiTinHieu.emulator),
            root: _daThay.containsKey(LoaiTinHieu.root) ? 'suspected' : 'no',
          ),
        ),
    ];
    switch (await gui(suKien)) {
      case Ok():
        await tep.ghi({
          ...tep.duLieu,
          'daBao': {
            ...daBao,
            for (final e in lo.entries)
              e.key.loai: {'luc': bayGio, 'dau': dauVetTinHieu(e.value)},
          },
        });
      case Err():
        // Offline / chưa có phiên: trả lại hàng chờ (tín hiệu mới hơn thắng).
        lo.forEach((l, ct) => _choGui[l] = {...ct, ...?_choGui[l]});
    }
  }

  Map<String, Object?> _daBao() {
    final d = tep.duLieu['daBao'];
    return d is Map<String, Object?> ? d : const {};
  }
}
