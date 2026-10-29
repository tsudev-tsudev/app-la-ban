import 'dart:convert';

import 'package:network/network.dart';
import 'package:test/test.dart';

List<int> _hex(String h) => [
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
];

List<int> _b64(String s) => base64Url.decode(base64Url.normalize(s));

void main() {
  // RFC 8032 mục 7.1 TEST 1 / TEST 2 (đã đối chiếu node:crypto).
  const k1 = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';
  const s1 =
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8'
      '821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b';
  const k2 = '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c';
  const s2 =
      '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085a'
      'c1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00';

  test('vector RFC 8032', () {
    expect(kiemEd25519(_hex(k1), const [], _hex(s1)), isTrue);
    expect(kiemEd25519(_hex(k2), const [0x72], _hex(s2)), isTrue);
  });

  test('vector ký bằng node:crypto (UTF-8)', () {
    expect(
      kiemEd25519(
        _b64('JmFdUodvNR5A7p3hWZSJUAqvC4bwhopnOWfNdjHb-BY'),
        _b64('eyJ2IjoxLCJ4IjoibGEgYsOgbiJ9'),
        _b64(
          'aBhvwDL2DoW7EkFGoyogfTrgiSEuV_9eNEEPc4QjGvFjih9pZ3Emm2I6xaCoy80Pfw'
          'QQByX0_qb78Xa6wHJ4DQ',
        ),
      ),
      isTrue,
    );
  });

  test('sửa 1 bit ở thông điệp / chữ ký / khoá -> sai', () {
    final k = _hex(k2);
    final s = _hex(s2);
    expect(kiemEd25519(k, const [0x73], s), isFalse);
    expect(
      kiemEd25519(k, const [0x72], [...s.sublist(0, 63), s[63] ^ 1]),
      isFalse,
    );
    expect(kiemEd25519(k, const [0x72], [s[0] ^ 1, ...s.sublist(1)]), isFalse);
    expect(kiemEd25519([k[0] ^ 1, ...k.sublist(1)], const [0x72], s), isFalse);
    expect(kiemEd25519(_hex(k1), const [0x72], s), isFalse);
  });

  test('độ dài sai / S >= L / điểm không hợp lệ -> false, không ném', () {
    expect(kiemEd25519(_hex(k1).sublist(1), const [], _hex(s1)), isFalse);
    expect(kiemEd25519(_hex(k1), const [], _hex(s1).sublist(1)), isFalse);
    final s = _hex(s1);
    // S + L (vẫn < 2^256): biến thể dễ uốn (malleable) phải bị từ chối.
    final l = BigInt.parse(
      '1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed',
      radix: 16,
    );
    var so = BigInt.zero;
    for (var i = 63; i >= 32; i--) {
      so = (so << 8) | BigInt.from(s[i]);
    }
    so += l;
    final sMoi = [
      for (var i = 0; i < 32; i++) ((so >> (8 * i)) & BigInt.from(255)).toInt(),
    ];
    expect(
      kiemEd25519(_hex(k1), const [], [...s.sublist(0, 32), ...sMoi]),
      isFalse,
    );
    // y >= p: không giải nén được.
    expect(kiemEd25519(List.filled(32, 0xff), const [], _hex(s1)), isFalse);
  });
}
