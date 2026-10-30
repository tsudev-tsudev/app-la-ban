import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freerasp/freerasp.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

import 'dinh_danh_test.dart' show KhoTep, NenTangGia;

const _chungChi =
    'cf09e7243bca9ab5d29dc788bbd31ba71efaebab7d69583d98bbfc5184a7f6bd';

// Khớp workers/api/src/thuan/su-kien.ts (schemaSuKien).
final _mauLoai = RegExp(r'^[A-Z][A-Z0-9_]{2,47}$');
final _mauKhoa = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

void main() {
  group('tín hiệu native', () {
    test('máy sạch, đúng chứng chỉ -> không tín hiệu', () {
      const k = KetQuaNative(coNative: true, chungChi: [_chungChi]);
      expect(tinHieuTuNative(k, chungChiHopLe: [_chungChi]), isEmpty);
    });

    test('mỗi bit C++ -> đúng loại sự kiện của bảng điểm server', () {
      const k = KetQuaNative(
        coNative: true,
        bitNative:
            KetQuaNative.bitTracer |
            KetQuaNative.bitFridaCong |
            KetQuaNative.bitXposedLop |
            KetQuaNative.bitMagisk |
            KetQuaNative.bitQemu,
        chungChi: [_chungChi],
      );
      final ds = {
        for (final t in tinHieuTuNative(k, chungChiHopLe: [_chungChi]))
          t.loai: t.chiTiet,
      };
      expect(ds.keys.map((l) => l.loai).toSet(), {
        'DEBUGGER_ATTACHED',
        'HOOK_FRIDA',
        'HOOK_XPOSED',
        'ROOT',
        'EMULATOR',
      });
      expect(ds[LoaiTinHieu.hookFrida], containsPair('port', true));
      expect(ds[LoaiTinHieu.root], containsPair('magisk', true));
      expect(ds[LoaiTinHieu.root], containsPair('su', false));
    });

    test('APP-03: chứng chỉ lạ / thiếu / app debuggable -> APP_REPACKAGED', () {
      List<LoaiTinHieu> loai(KetQuaNative k) => [
        for (final t in tinHieuTuNative(k, chungChiHopLe: [_chungChi])) t.loai,
      ];
      expect(loai(KetQuaNative(coNative: true, chungChi: ['ab' * 32])), [
        LoaiTinHieu.dongGoiLai,
      ]);
      expect(loai(const KetQuaNative(coNative: true)), [
        LoaiTinHieu.dongGoiLai,
      ]);
      expect(
        loai(
          const KetQuaNative(
            coNative: true,
            appDebuggable: true,
            chungChi: [_chungChi],
          ),
        ),
        [LoaiTinHieu.dongGoiLai],
      );
      // Bản debug: không có chứng chỉ hợp lệ để so -> không kiểm.
      expect(
        tinHieuTuNative(
          KetQuaNative(coNative: true, chungChi: ['ab' * 32]),
          chungChiHopLe: const [],
        ),
        isEmpty,
      );
    });

    test('mất thư viện C++ -> RASP_NATIVE_MISSING; map hỏng an toàn', () {
      final k = KetQuaNative.tuMap({
        'native': -1,
        'chungChi': ['x', 3],
      });
      expect(k.coNative, isFalse);
      expect(k.chungChi, ['x']);
      expect(
        tinHieuTuNative(k, chungChiHopLe: const []).single.loai,
        LoaiTinHieu.thieuKiemTraNative,
      );
      expect(KetQuaNative.tuMap(null).coNative, isFalse);
      final day = KetQuaNative.tuMap({
        'native': KetQuaNative.bitSu,
        'jdwp': true,
        'testKeys': true,
        'nguonCai': 'com.android.vending',
      });
      expect(day.nguonCai, 'com.android.vending');
      expect(
        gopTinHieu(tinHieuTuNative(day, chungChiHopLe: const [])).keys,
        unorderedEquals([LoaiTinHieu.root, LoaiTinHieu.debugger]),
      );
    });
  });

  test('freeRASP: mọi Threat có loại hợp lệ + khoá rasp_<tên>', () {
    for (final t in Threat.values) {
      final th = tinHieuTuThreat(t);
      expect(_mauLoai.hasMatch(th.loai.loai), isTrue, reason: '$t');
      expect(th.chiTiet.keys.every(_mauKhoa.hasMatch), isTrue, reason: '$t');
    }
    expect(tinHieuTuThreat(Threat.privilegedAccess).loai, LoaiTinHieu.root);
    expect(tinHieuTuThreat(Threat.screenRecording).chiTiet, {
      'rasp_screen_recording': true,
    });
  });

  test('freeRASP: chứng chỉ hex -> base64 như Talsec yêu cầu', () {
    final c = cauHinhFreeRasp(
      goi: 'com.tsudev.laban',
      chungChi: [_chungChi],
      banThat: true,
    );
    expect(c.androidConfig?.signingCertHashes, [
      'zwnnJDvKmrXSnceIu9Mbpx7666t9aVg9mLv8UYSn9r0=',
    ]);
    expect(c.watcherMail, 'security@tsudev.com');
  });

  group('sự kiện + lọc', () {
    test('taoSuKien đúng schema server, cắt chuỗi dài, bỏ khoá sai', () {
      final e = taoSuKien(
        id: '0f8fad5b-d9cb-469f-a165-70867728950e',
        loai: LoaiTinHieu.hookFrida,
        chiTiet: {'port': true, 'Sai-Khoa': true, 'dai': 'x' * 300},
        luc: DateTime.utc(2026, 10, 30, 8),
        app: (phienBan: '0.1.0-beta.7', build: 0, nguonCai: 'g' * 100),
        moiTruong: (
          heDieuHanh: '13',
          model: 'M' * 80,
          emulator: false,
          root: 'no',
        ),
      );
      expect(e['type'], 'HOOK_FRIDA');
      expect(e['severity'], 'high');
      expect(e['ts'], '2026-10-30T08:00:00.000Z');
      final sig = e['signals']! as Map<String, Object?>;
      expect(sig.keys, ['port', 'dai']);
      expect((sig['dai']! as String).length, 128);
      final app = e['app']! as Map<String, Object?>;
      expect(app['version'], '0.1.0');
      expect(app['build'], 1);
      expect((app['install_source']! as String).length, 64);
      expect(((e['env']! as Map)['model'] as String).length, 64);
    });

    test('canBao: chưa báo / đổi chi tiết / quá 24 h / đồng hồ lùi', () {
      const ngay = 24 * 60 * 60 * 1000;
      final da = {'luc': 1000, 'dau': 'a=true'};
      expect(canBao(daBao: null, dauVet: 'a=true', bayGio: 1), isTrue);
      expect(canBao(daBao: da, dauVet: 'a=true', bayGio: 2000), isFalse);
      expect(canBao(daBao: da, dauVet: 'b=true', bayGio: 2000), isTrue);
      expect(canBao(daBao: da, dauVet: 'a=true', bayGio: 1000 + ngay), isTrue);
      expect(canBao(daBao: da, dauVet: 'a=true', bayGio: 10), isTrue);
      expect(dauVetTinHieu({'b': 1, 'a': true}), 'a=true&b=1');
    });
  });

  test('MucRuiRo theo trạng thái server (Spec §7.3 bảng phản ứng)', () {
    expect(MucRuiRo.tu(null, null), MucRuiRo.thap);
    expect(MucRuiRo.tu(TrangThaiThietBi.clean, MucTin.device), MucRuiRo.thap);
    expect(
      MucRuiRo.tu(TrangThaiThietBi.clean, MucTin.unverified),
      MucRuiRo.trungBinh,
    );
    expect(
      MucRuiRo.tu(TrangThaiThietBi.suspicious, MucTin.strong),
      MucRuiRo.trungBinh,
    );
    expect(
      MucRuiRo.tu(TrangThaiThietBi.restricted, MucTin.device),
      MucRuiRo.cao,
    );
    final ct = MucRuiRo.tu(TrangThaiThietBi.banned, MucTin.device);
    expect(ct, MucRuiRo.nghiemTrong);
    expect(ct.khoaApp, isTrue);
    expect(MucRuiRo.cao.choApi, isFalse);
    expect(MucRuiRo.trungBinh.choApi, isTrue);
    expect(MucRuiRo.trungBinh.choTinhNangNhayCam, isFalse);
  });

  group('DichVuRasp', () {
    late Directory thuMuc;
    late NenTangGia nt;
    late List<List<Map<String, Object?>>> daGui;
    var loiMang = false;
    var bayGio = 1000000;

    DichVuRasp dv({bool guiMayChu = true}) => DichVuRasp(
      nenTang: nt,
      tep: KhoTep(TepJson.mo('${thuMuc.path}/rasp.json')),
      gui: (lo) async {
        if (loiMang) return const Err(Failure('dinhDanh.mang'));
        daGui.add(lo);
        return Ok(lo.length);
      },
      cauHinh: CauHinhRasp(
        phienBanApp: '0.1.0-beta.7',
        build: 7,
        chungChiHopLe: const [_chungChi],
        guiMayChu: guiMayChu,
      ),
      dongHo: () => bayGio,
      cho: Duration.zero,
    );

    setUp(() {
      thuMuc = Directory.systemTemp.createTempSync('rasp');
      nt = NenTangGia()
        ..moiTruong = const KetQuaNative(
          coNative: true,
          bitNative: KetQuaNative.bitSu,
          chungChi: [_chungChi],
          nguonCai: 'com.android.vending',
        );
      daGui = [];
      loiMang = false;
    });
    tearDown(() => thuMuc.deleteSync(recursive: true));

    test('kiểm tra -> một lô đã gom; env.root = suspected; mở lại app '
        'trong 24 h không báo lại', () async {
      final a = dv();
      await a.kiemTra();
      expect(daGui, hasLength(1));
      final e = daGui.single.single;
      expect(e['type'], 'ROOT');
      expect((e['env']! as Map)['root'], 'suspected');
      expect((e['app']! as Map)['install_source'], 'com.android.vending');
      await dv().kiemTra();
      expect(daGui, hasLength(1));
      bayGio += 25 * 60 * 60 * 1000;
      await dv().kiemTra();
      expect(daGui, hasLength(2));
    });

    test('offline -> giữ hàng chờ, có mạng gửi lại', () async {
      final a = dv();
      loiMang = true;
      await a.kiemTra();
      expect(daGui, isEmpty);
      loiMang = false;
      await a.xa();
      expect(daGui.single.single['type'], 'ROOT');
    });

    test('freeRASP dồn dập gộp một lô; chế độ an toàn báo kèm', () async {
      final a = dv()
        ..baoLuuTru(loiCsdl: 'storage.migration')
        ..nhan(tinHieuTuThreat(Threat.hooks))
        ..nhan(tinHieuTuThreat(Threat.devMode));
      await Future<void>.delayed(Duration.zero);
      await a.xa();
      expect(daGui.single.map((e) => e['type']).toSet(), {
        'APP_SAFE_MODE',
        'HOOK_FRIDA',
        'DEV_MODE',
      });
      expect(a.daThay, contains(LoaiTinHieu.hookFrida));
    });

    test('bản debug: kiểm tra nhưng KHÔNG gửi server', () async {
      final a = dv(guiMayChu: false);
      await a.kiemTra();
      expect(daGui, isEmpty);
      expect(a.daThay, {LoaiTinHieu.root});
    });

    test('baoLuuTru không có gì -> không sinh sự kiện', () async {
      final a = dv()..baoLuuTru();
      nt.moiTruong = const KetQuaNative(coNative: true, chungChi: [_chungChi]);
      await a.kiemTra();
      expect(daGui, isEmpty);
    });
  });
}
