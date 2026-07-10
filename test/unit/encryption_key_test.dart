import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/encryption/bls12381.dart';
import 'package:aptos/src/core/crypto/encryption/ciphertext.dart';
import 'package:aptos/src/core/crypto/encryption/symmetric.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) => Hex.fromHexInput(s).toUint8List();
String _toHex(Uint8List b) => Hex.fromHexInput(b).toStringWithoutPrefix();
BigInt _big(String hex) => BigInt.parse(hex, radix: 16);

/// A minimal BCS-serializable wrapper used as an opaque plaintext.
class _Bytes extends Serializable {
  final Uint8List data;
  _Bytes(this.data);
  @override
  void serialize(Serializer serializer) => serializer.serializeBytes(data);
}

void main() {
  final v = jsonDecode(
    File('test/vectors/bls12381_bibe.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final encryptionKey =
      EncryptionKey.deserialize(Deserializer(_hex(v['enc_bcs'] as String)));

  group('EncryptionKey', () {
    test('deserializes from BCS and re-serializes byte-exactly', () {
      expect(_toHex(encryptionKey.bcsToBytes()), v['enc_bcs']);
      expect(_toHex(encryptionKey.sigMpkG2.toCompressedBytes()),
          v['enc_sigMpkG2']);
      expect(_toHex(encryptionKey.tauG2.toCompressedBytes()), v['enc_tauG2']);
    });

    test('bibeEncrypt is byte-exact against the reference for fixed randomness',
        () {
      final id = _big(v['bibe_id'] as String);
      final bibe = encryptionKey.bibeEncrypt(
        _Bytes(Uint8List.fromList(utf8.encode('anything'))),
        id,
        r0: _big(v['bibe_r0'] as String),
        r1: _big(v['bibe_r1'] as String),
        symmetricKey: _hex(v['bibe_symKey'] as String),
        nonce: Uint8List(12),
      );

      // The Fr id and the three blinded G2 points are the security-critical
      // curve outputs; they must match the reference exactly.
      expect(_toHex(bibe.idBytes), _toHex(frToLEBytes(id)));
      final expectedCtG2 = (v['bibe_ctG2'] as List).cast<String>().join();
      expect(_toHex(bibe.ctG2Bytes), expectedCtG2);
      // paddedKey = symKey XOR OTP(pairing); validates the pairing + pad path.
      expect(_toHex(bibe.paddedKey), v['bibe_paddedKey']);
    });

    test('encrypt produces a Ciphertext that BCS round-trips and self-verifies',
        () {
      final plaintext = _Bytes(Uint8List.fromList(utf8.encode('hello tx')));
      final ad = _Bytes(Uint8List.fromList(utf8.encode('associated')));
      final ct = encryptionKey.encrypt(plaintext, ad);

      // BCS round-trip is stable.
      final bytes = ct.bcsToBytes();
      final restored = Ciphertext.deserialize(Deserializer(bytes));
      expect(_toHex(restored.bcsToBytes()), _toHex(bytes));

      // The three ctG2 elements decode as valid, torsion-free G2 points.
      expect(ct.bibeCt.ctG2Bytes.length, 96 * 3);
      for (var i = 0; i < 3; i += 1) {
        final p = G2Point.fromCompressedBytes(
          Uint8List.sublistView(ct.bibeCt.ctG2Bytes, i * 96, (i + 1) * 96),
        );
        expect(p.isTorsionFree(), isTrue);
      }

      // The ed25519 signature covers (bibeCt, associatedDataBytes) and
      // verifies under the embedded verification key.
      final toSign = Serializer();
      ct.bibeCt.serialize(toSign);
      toSign.serializeBytes(ct.associatedDataBytes);
      final ok = Ed25519PublicKey(ct.vk).verifySignature(
        message: toSign.toUint8List(),
        signature: Ed25519Signature(ct.signature),
      );
      expect(ok, isTrue);
    });
  });
}
