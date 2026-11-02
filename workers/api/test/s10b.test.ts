import { describe, expect, it } from 'vitest';
import { cauLenhDonDep, LUU_SU_CO_MS } from '../src/thuan/don-dep';
import { coQuyen } from '../src/thuan/soc';
import { chuanHoaKhung, cheThongDiep, dauVetSuCo, schemaLoSuCo, tyLeKhongLoi } from '../src/thuan/su-co-app';

describe('S10b: sự cố app (thuần)', () => {
  it('chuẩn hoá khung: bỏ #nn + abs (ASLR), giữ virt / ký hiệu', () => {
    expect(
      chuanHoaKhung('#00 abs 0000007a1b2c virt 00000000001b2c _kDartIsolateSnapshotInstructions+0x1b2c'),
    ).toBe('virt 00000000001b2c _kDartIsolateSnapshotInstructions+0x1b2c');
    expect(chuanHoaKhung('#3      ManLaBan.build (package:compass_feature/src/man_la_ban.dart:42:7)')).toBe(
      'ManLaBan.build (package:compass_feature/src/man_la_ban.dart:42:7)',
    );
  });

  it('dấu vết: 16 hex, cùng 5 khung đầu -> cùng nhóm, khác kiểu -> khác', async () => {
    const nx = '*** header ***\n#0 a (x.dart:1)\n#1 b (x.dart:2)\n#2 c\n#3 d\n#4 e';
    const d = await dauVetSuCo('StateError', nx);
    expect(d).toMatch(/^[0-9a-f]{16}$/);
    expect(await dauVetSuCo('StateError', `${nx}\n#5 khac`)).toBe(d);
    expect(await dauVetSuCo('RangeError', nx)).not.toBe(d);
  });

  it('che thông điệp, tỷ lệ không lỗi, schema chặn trường lạ / phiên bản lạ', () => {
    expect(cheThongDiep('x@y.com 10.1.2.3')).toBe('<email> 10.1.2.x');
    expect(tyLeKhongLoi(0, 0)).toBeNull();
    expect(tyLeKhongLoi(2000, 3)).toBe(99.85);
    const s = { loai: 'dart', kieu: 'E', thongDiep: '', nganXep: '', phienBan: '0.1.0+1', luc: 1 };
    expect(schemaLoSuCo.safeParse({ suCo: [s] }).success).toBe(true);
    expect(schemaLoSuCo.safeParse({ suCo: [{ ...s, phienBan: 'a b' }] }).success).toBe(false);
    expect(schemaLoSuCo.safeParse({ suCo: [{ ...s, them: 1 }] }).success).toBe(false);
  });

  it('dọn 90 ngày, quyền viewer xem nhóm / analyst xem mẫu', () => {
    const l = cauLenhDonDep(LUU_SU_CO_MS + 5).find((x) => x.sql.includes('app_crashes'));
    expect(l?.thamSo).toEqual([5]);
    expect(coQuyen('viewer', 'su-co:xem')).toBe(true);
    expect(coQuyen('viewer', 'su-co:chi-tiet')).toBe(false);
    expect(coQuyen('analyst', 'su-co:chi-tiet')).toBe(true);
  });
});

describe('docPhienBanApp', () => {
  it('nhận dạng pubspec, từ chối dạng lạ', async () => {
    const { docPhienBanApp } = await import('../src/thuan/kenh');
    expect(docPhienBanApp('0.1.0-beta.12+12')).toEqual({ phienBan: '0.1.0-beta.12', build: 12 });
    expect(docPhienBanApp('1.0.0+100')).toEqual({ phienBan: '1.0.0', build: 100 });
    expect(docPhienBanApp('1.0.0')).toBeNull();
    expect(docPhienBanApp(undefined)).toBeNull();
    expect(docPhienBanApp("1.0.0+1'")).toBeNull();
  });
});
