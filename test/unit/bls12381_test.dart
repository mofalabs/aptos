import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aptos/src/core/crypto/encryption/bls12381.dart';
import 'package:test/test.dart';

Map<String, dynamic> _loadVectors() {
  final file = File('test/vectors/bls12381_bibe.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

BigInt _hexToBigInt(String hex) => BigInt.parse(hex, radix: 16);

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _fromHex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

const _hashG2Dst = 'APTOS_BATCH_ENCRYPTION_HASH_G2_ELEMENT';

void main() {
  final v = _loadVectors();

  test('field orders', () {
    expect(blsFq, _hexToBigInt(v['fq_order'] as String));
    expect(blsFr, _hexToBigInt(v['fr_order'] as String));
  });

  test('generators serialize to the expected compressed bytes', () {
    expect(_hex(G1Point.base.toCompressedBytes()), v['g1_base']);
    expect(_hex(G2Point.base.toCompressedBytes()), v['g2_base']);
  });

  test('base pairing and its inverse', () {
    final e = blsPairing(G1Point.base, G2Point.base);
    expect(_hex(e.toLEBytes()), v['pairing_base']);
    expect(_hex(e.inverse().toLEBytes()), v['pairing_base_inv']);
  });

  test('G2 scalar multiplication, round-trip and affine coordinates', () {
    final s = BigInt.parse('1234567890abcdef', radix: 16);
    final p = G2Point.base.multiply(s);
    final bytes = p.toCompressedBytes();
    expect(_hex(bytes), v['g2_s1']);

    final decoded = G2Point.fromCompressedBytes(_fromHex(v['g2_s1'] as String));
    expect(_hex(decoded.toCompressedBytes()), v['g2_s1']);

    final affine = decoded.toAffine();
    final xs = (v['g2_s1_x'] as List).cast<String>();
    final ys = (v['g2_s1_y'] as List).cast<String>();
    expect(affine.x.c0, _hexToBigInt(xs[0]));
    expect(affine.x.c1, _hexToBigInt(xs[1]));
    expect(affine.y.c0, _hexToBigInt(ys[0]));
    expect(affine.y.c1, _hexToBigInt(ys[1]));
  });

  test('hash-to-curve G1', () {
    final msg = Uint8List.fromList(utf8.encode('hello world'));
    final dst = Uint8List.fromList(utf8.encode(_hashG2Dst));
    final p = hashToCurveG1(msg, dst);
    expect(_hex(p.toCompressedBytes()), v['hashG1_hello']);
  });

  test('full BIBE recomputation', () {
    final r0 = _hexToBigInt(v['bibe_r0'] as String);
    final r1 = _hexToBigInt(v['bibe_r1'] as String);
    final id = _hexToBigInt(v['bibe_id'] as String);
    final sigMpkG2 =
        G2Point.fromCompressedBytes(_fromHex(v['enc_sigMpkG2'] as String));
    final tauG2 =
        G2Point.fromCompressedBytes(_fromHex(v['enc_tauG2'] as String));
    final ctExpected = (v['bibe_ctG2'] as List).cast<String>();
    final dst = Uint8List.fromList(utf8.encode(_hashG2Dst));

    final ct0 = G2Point.base.multiply(r0).add(sigMpkG2.multiply(r1));
    expect(_hex(ct0.toCompressedBytes()), ctExpected[0]);

    final ct1 = G2Point.base.multiply(id).subtract(tauG2).multiply(r0);
    expect(_hex(ct1.toCompressedBytes()), ctExpected[1]);

    final ct2 = G2Point.base.negate().multiply(r1);
    expect(_hex(ct2.toCompressedBytes()), ctExpected[2]);

    final hashedEncKey = hashToCurveG1(sigMpkG2.toCompressedBytes(), dst);
    expect(_hex(hashedEncKey.toCompressedBytes()), v['bibe_hashedEncKey']);

    final g1Point = hashedEncKey.multiply(r1);
    expect(_hex(g1Point.toCompressedBytes()), v['bibe_g1Point']);

    final otpSource = blsPairing(g1Point, sigMpkG2).inverse().toLEBytes();
    expect(_hex(otpSource), v['bibe_otpSource']);
  });

  group('compressed-point decoding rejects invalid encodings', () {
    test('G1/G2 reject the infinity flag combined with the sort flag', () {
      // 0xE0 = compressed | infinity | sort — an illegal flag combination.
      final g1 = Uint8List(48)..[0] = 0xe0;
      final g2 = Uint8List(96)..[0] = 0xe0;
      expect(() => G1Point.fromCompressedBytes(g1), throwsArgumentError);
      expect(() => G2Point.fromCompressedBytes(g2), throwsArgumentError);
    });

    test('G1/G2 still accept the canonical infinity encoding', () {
      // 0xC0 = compressed | infinity, remaining bytes zero.
      final g1 = Uint8List(48)..[0] = 0xc0;
      final g2 = Uint8List(96)..[0] = 0xc0;
      expect(G1Point.fromCompressedBytes(g1).isInfinity, isTrue);
      expect(G2Point.fromCompressedBytes(g2).isInfinity, isTrue);
    });

    test('G1/G2 reject a wrong length', () {
      expect(() => G1Point.fromCompressedBytes(Uint8List(47)),
          throwsArgumentError);
      expect(() => G2Point.fromCompressedBytes(Uint8List(95)),
          throwsArgumentError);
    });
  });
}
