import 'dart:convert';
import 'dart:io';

import 'package:aptos/src/core/crypto/bn254.dart';
import 'package:test/test.dart';

// Test-vector parsing mirrors noble-curves 2.2.0 `test/bn254.test.ts`
// (`sedaprotocol` and the ETH `ethPairing` helpers) exactly.

Map<String, dynamic> _loadJson(String name) {
  final file = File('test/vectors/bn254/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

BigInt _hexToBigInt(String hex) =>
    hex.isEmpty ? BigInt.zero : BigInt.parse(hex, radix: 16);

String _fixHex(String hex) => hex.startsWith('0x') ? hex.substring(2) : hex;

/// Port of noble's `ethNums`: pads input to a multiple of 64 hex chars with
/// trailing zeros, splits into 256-bit big-endian words, then right-pads the
/// list with zeros up to `count`.
List<BigInt> _ethNums(String input, int count) {
  var hex = _fixHex(input);
  if (hex.isEmpty) return List.filled(count, BigInt.zero);
  if (hex.length % 64 != 0) {
    hex = hex.padRight(hex.length + (64 - hex.length % 64), '0');
  }
  final res = <BigInt>[];
  for (var i = 0; i < hex.length; i += 64) {
    res.add(_hexToBigInt(hex.substring(i, i + 64)));
  }
  while (res.length < count) {
    res.add(BigInt.zero);
  }
  return res;
}

/// Port of noble's `ethPairing`: parses EIP-197 ECPAIRING input tape and
/// returns whether the pairing product equals one. Any parse/validity error
/// yields `false` (noble sets f = Fp12.ZERO).
bool _ethPairing(String rawInput) {
  final input = _fixHex(rawInput);
  final elements = (input.length + 63) ~/ 64;
  final p = _ethNums(input, elements);
  try {
    if (elements % 6 != 0) throw StateError('error');
    final pairs = <({G1Point g1, G2Point g2})>[];
    for (var i = 0; i < p.length; i += 6) {
      final ax = p[i];
      final ay = p[i + 1];
      final bay = p[i + 2];
      final bax = p[i + 3];
      final bby = p[i + 4];
      final bbx = p[i + 5];
      // Range check exactly like noble (note: Bax is not checked there).
      for (final v in [ax, ay, bay, bby, bbx]) {
        if (v % bn254P != v) throw StateError('failed');
      }
      final a = (ax == BigInt.zero && ay == BigInt.zero)
          ? G1Point.zero
          : G1Point.fromAffine(ax, ay);
      final ba = Fp2.fromBigTuple([bax, bay]);
      final bb = Fp2.fromBigTuple([bbx, bby]);
      final b =
          (ba.isZero && bb.isZero) ? G2Point.zero : G2Point.fromAffine(ba, bb);
      a.assertValidity();
      b.assertValidity();
      // Zero terms contribute the identity and are skipped.
      if (a.isZero || b.isZero) continue;
      pairs.add((g1: a, g2: b));
    }
    final f = bn254PairingBatch(pairs);
    return f.eql(Fp12.one);
  } catch (_) {
    return false;
  }
}

Fp12 _fp12FromBigTwelve(List<BigInt> t) {
  Fp6 fp6(int o) => Fp6(
        Fp2(t[o], t[o + 1]),
        Fp2(t[o + 2], t[o + 3]),
        Fp2(t[o + 4], t[o + 5]),
      );
  return Fp12(fp6(0), fp6(6));
}

void main() {
  group('bn254 field tower sanity', () {
    test('Fp2 mul/inv/frobenius/nonresidue match noble vectors', () {
      final x = Fp2(
        BigInt.parse(
            '9175274256610746571769806138441460978067247223835479920885065774008687444157'),
        BigInt.parse(
            '20773477212147349335400672939850062067877721538384265447234655811868542594493'),
      );
      final y = Fp2(
        BigInt.parse(
            '18745010300259074081467171901089189864928626882998930881106784720284549917403'),
        BigInt.parse(
            '6755404584462298611753346784665337222239198745905936344431516651379215797104'),
      );
      final mul = x.mul(y);
      expect(
          mul.c0,
          BigInt.parse(
              '14915367931151687313527782314310395056617474070176176799315072532155545111131'));
      expect(
          mul.c1,
          BigInt.parse(
              '21234748560869198098271980834340238051100753263426135951820710752881888827685'));
      final inv = mul.inv();
      expect(
          inv.c0,
          BigInt.parse(
              '14059357043488439067899523657279480228325398861171369736421103353153531444488'));
      expect(
          inv.c1,
          BigInt.parse(
              '10653662974983088626765328812465558213584029561070266019112600033405785100357'));
      final pow = mul.pow(BigInt.from(123));
      expect(
          pow.c0,
          BigInt.parse(
              '10215561122296849292546524321406303162476266646558890975893280707450285855932'));
      expect(
          pow.c1,
          BigInt.parse(
              '4537324909364976254935527093258254296114714749851039294808365654432443471764'));
      final nr = mul.mulByNonresidue();
      expect(
          nr.c0,
          BigInt.parse(
              '07e037c032c72fca1ad3101fe7826263823ca54d39d091e6396a2919752311ab',
              radix: 16));
      expect(
          nr.c1,
          BigInt.parse(
              '13f9045c1b9e7f1ef3aa2daa5d59e7e7ca826cf63a9b4ce115e4ab8f34e4c529',
              radix: 16));
      final fr1 = mul.frobeniusMap(1);
      expect(fr1.c0, mul.c0);
      expect(
          fr1.c1,
          BigInt.parse(
              '0171dd5b2d48f4fbe0568cc5f8b00410f67287385c7394a6637a301df8bb6422',
              radix: 16));
      expect(mul.frobeniusMap(2).eql(mul), isTrue);
      final sq = mul.sqr();
      expect(sq.eql(mul.mul(mul)), isTrue);
    });

    test('Fp2 sqrt matches noble vector', () {
      final n = Fp2.fromBigTuple([
        BigInt.parse(
            '9539370033468661209380275700986402421887789242020002300585859967789873971892'),
        BigInt.parse(
            '2408207196858065672509024269166317846107134392635521956359186237465509592685'),
      ]);
      final root = n.sqrt();
      expect(
          root.c0,
          BigInt.parse(
              '11735470634387873799477049885533764022761384076526147647478746466286296399544'));
      expect(
          root.c1,
          BigInt.parse(
              '13618633949391667835520719449938342187292725425802172484249840050686954616369'));
      expect(root.sqr().eql(n), isTrue);
    });

    test('pairing of fixed points matches noble known answer', () {
      final g1 = G1Point.base.multiply(
        BigInt.parse(
            '18097487326282793650237947474982649264364522469319914492172746413872781676'),
      );
      g1.assertValidity();
      expect(
          g1.x,
          BigInt.parse(
              '16f7535f91f50bb2227f483b54850a63b38206f28e0a1a65c83d0c90762442a9',
              radix: 16));
      expect(
          g1.y,
          BigInt.parse(
              '0b46dd0c40725b6b4a298576629d77b41a545060adb4358eabec939e80691a05',
              radix: 16));
      final g2 = G2Point.base.multiply(
        BigInt.parse(
            '20390255904278144451778773028944684152769293537511418234311120800877067946'),
      );
      g2.assertValidity();
      expect(
          g2.x.c0,
          BigInt.parse(
              '1ecfd2dff2aad18798b64bdb0c2b50c9d73e6c05619e04cbf5b448fd98726880',
              radix: 16));
      expect(
          g2.x.c1,
          BigInt.parse(
              '0e16c8d96362720af0916592be1b839a26f5e6b710f3ede0d8840d9a70eaf97f',
              radix: 16));
      expect(
          g2.y.c0,
          BigInt.parse(
              '2aa778acda9e7d4925c60ad84c12fb3b4f2b9539d5699934b0e6fdd10cc2c0e1',
              radix: 16));
      expect(
          g2.y.c1,
          BigInt.parse(
              '1e8f2c1f441fed039bb46d6bfb91236cf7ba240c75080cedbe40e049c46b26be',
              radix: 16));
      final gt = bn254Pairing(g1, g2);
      final expected = _fp12FromBigTwelve([
        BigInt.parse(
            '7520311483001723614143802378045727372643587653754534704390832890681688842501'),
        BigInt.parse(
            '20265650864814324826731498061022229653175757397078253377158157137251452249882'),
        BigInt.parse(
            '11942254371042183455193243679791334797733902728447312943687767053513298221130'),
        BigInt.parse(
            '759657045325139626991751731924144629256296901790485373000297868065176843620'),
        BigInt.parse(
            '16045761475400271697821392803010234478356356448940805056528536884493606035236'),
        BigInt.parse(
            '4715626119252431692316067698189337228571577552724976915822652894333558784086'),
        BigInt.parse(
            '14901948363362882981706797068611719724999331551064314004234728272909570402962'),
        BigInt.parse(
            '11093203747077241090565767003969726435272313921345853819385060670210834379103'),
        BigInt.parse(
            '17897835398184801202802503586172351707502775171934235751219763553166796820753'),
        BigInt.parse(
            '1344517825169318161285758374052722008806261739116142912817807653057880346554'),
        BigInt.parse(
            '11123896897251094532909582772961906225000817992624500900708432321664085800838'),
        BigInt.parse(
            '17453370448280081813275586256976217762629631160552329276585874071364454854650'),
      ]);
      expect(gt.eql(expected), isTrue);
    });
  });

  group('bn254 gates', () {
    final seda = _loadJson('seda.json');
    final ethDump = _loadJson('eth-dump.json');

    test('gate 1: seda.json G1 addition', () {
      final vectors = seda['add'] as List<dynamic>;
      expect(vectors, isNotEmpty);
      for (final raw in vectors) {
        final t = raw as Map<String, dynamic>;
        final a = G1Point.fromAffine(
          _hexToBigInt(t['x1'] as String),
          _hexToBigInt(t['y1'] as String),
        );
        final b = G1Point.fromAffine(
          _hexToBigInt(t['x2'] as String),
          _hexToBigInt(t['y2'] as String),
        );
        final result = t['result'] as String;
        final cx = _hexToBigInt(result.substring(0, 64));
        final cy = _hexToBigInt(result.substring(64));
        final (x, y) = a.add(b).toAffine();
        expect(x, cx, reason: 'add x mismatch: $t');
        expect(y, cy, reason: 'add y mismatch: $t');
      }
    });

    test('gate 2: seda.json G1 scalar multiplication', () {
      final vectors = seda['mul'] as List<dynamic>;
      expect(vectors, isNotEmpty);
      for (final raw in vectors) {
        final t = raw as Map<String, dynamic>;
        final a = G1Point.fromAffine(
          _hexToBigInt(t['x'] as String),
          _hexToBigInt(t['y'] as String),
        );
        final scalar = _hexToBigInt(t['scalar'] as String) % bn254R;
        final result = t['result'] as String;
        final cx = _hexToBigInt(result.substring(0, 64));
        final cy = _hexToBigInt(result.substring(64));
        final (x, y) = a.multiply(scalar).toAffine();
        expect(x, cx, reason: 'mul x mismatch: $t');
        expect(y, cy, reason: 'mul y mismatch: $t');
      }
    });

    test('gate 3: eth-dump.json EIP-197 pairing (34 vectors)', () {
      final vectors = ethDump['NOBLE_DUMP_EC_PAIRING'] as List<dynamic>;
      expect(vectors.length, 34);
      for (var i = 0; i < vectors.length; i++) {
        final v = vectors[i] as List<dynamic>;
        final input = v[0] as String;
        final output = v[1] as String;
        final expected = _ethNums(_fixHex(output), 1)[0] == BigInt.one;
        final actual = _ethPairing(input);
        expect(actual, expected, reason: 'pairing vector #$i');
      }
    });
  });
}
