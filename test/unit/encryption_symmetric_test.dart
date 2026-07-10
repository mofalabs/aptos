import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aptos/src/core/crypto/encryption/symmetric.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) => Hex.fromHexInput(s).toUint8List();
String _toHex(Uint8List b) => Hex.fromHexInput(b).toStringWithoutPrefix();

void main() {
  final vectors = jsonDecode(
    File('test/vectors/bls12381_bibe.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('batch-encryption symmetric primitives', () {
    test('AES-128-GCM matches the reference (ciphertext || tag)', () {
      final ct = aesGcmEncrypt(
        _hex(vectors['gcm_key'] as String),
        _hex(vectors['gcm_nonce'] as String),
        _hex(vectors['gcm_pt'] as String),
      );
      expect(_toHex(ct), vectors['gcm_ct']);
    });

    test('HKDF one-time pad derivation matches the reference', () {
      final otp = deriveOneTimePad(_hex(vectors['bibe_otpSource'] as String));
      expect(_toHex(otp), vectors['bibe_otp']);
    });

    test('padKey XORs the symmetric key with the one-time pad', () {
      final padded = padKey(
        _hex(vectors['bibe_symKey'] as String),
        _hex(vectors['bibe_otp'] as String),
      );
      expect(_toHex(padded), vectors['bibe_paddedKey']);
    });

    test('hashToFr matches the reference for known inputs', () {
      final hello = hashToFr(
        Uint8List.fromList(utf8.encode('hello world')),
        idHashDst,
      );
      expect(hello.toRadixString(16), vectors['hashToFr_hello']);

      final empty = hashToFr(Uint8List(0), idHashDst);
      expect(empty.toRadixString(16), vectors['hashToFr_empty']);
    });

    test('Fr reduction of 128 little-endian bytes matches the reference', () {
      final le = _hex(vectors['frreduce_le'] as String);
      final reduced = leBytesToBigint(le) % scalarFieldOrder;
      expect(reduced.toRadixString(16), vectors['frreduce_out']);
    });

    test('frToLEBytes round-trips through leBytesToBigint', () {
      final value = BigInt.parse(vectors['bibe_id'] as String, radix: 16);
      final bytes = frToLEBytes(value);
      expect(bytes.length, 32);
      expect(leBytesToBigint(bytes), value);
    });

    test('getRandomFr is in range and non-repeating', () {
      final a = getRandomFr();
      final b = getRandomFr();
      expect(a, lessThan(scalarFieldOrder));
      expect(b, lessThan(scalarFieldOrder));
      expect(a, isNot(b));
    });
  });
}
