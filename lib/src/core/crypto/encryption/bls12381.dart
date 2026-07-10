/// Pure-Dart BLS12-381 pairing engine.
///
/// Provides the field tower (Fp2/Fp6/Fp12), the two point groups (G1 over Fp,
/// G2 over the twist Fp2), the optimal-ate pairing with final exponentiation,
/// ZCash-style compressed point serialization, and RFC 9380 hash-to-curve for
/// G1. These pieces are what the identity-based (BIBE) encryption layer needs
/// to build and verify encrypted transactions.
///
/// Parameters:
/// - Seed x = -0xd201000000010000 (the Miller loop walks the bits of |x|).
/// - G1: y² = x³ + 4 over Fp, cofactor cleared with [x]P + P.
/// - G2: y² = x³ + 4(1 + u) over Fp2, an M-type (multiplicative) twist.
/// - Towers: Fp2 = Fp[u]/(u² + 1), Fp6 = Fp2[v]/(v³ - (1 + u)),
///   Fp12 = Fp6[w]/(w² - v).
///
/// All inputs handled here are public, so no attempt is made to run in
/// constant time; only correctness and byte-exact output matter.
library;

import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

// ---------------------------------------------------------------------------
// Curve constants
// ---------------------------------------------------------------------------

/// BLS12-381 base field prime.
final BigInt blsFq = BigInt.parse(
  '1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab',
  radix: 16,
);

/// BLS12-381 scalar field order (prime subgroup order r).
final BigInt blsFr = BigInt.parse(
  '73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001',
  radix: 16,
);

final BigInt _p = blsFq;

/// The BLS seed magnitude |x|. The real seed is negative.
final BigInt _blsX = BigInt.parse('d201000000010000', radix: 16);

/// Bit length of |x|, used by the cyclotomic exponentiation.
final int _xLen = _blsX.bitLength;

final BigInt _three = BigInt.from(3);
final BigInt _four = BigInt.from(4);
final BigInt _six = BigInt.from(6);

/// 1/2 mod p.
final BigInt _inv2 = BigInt.two.modInverse(_p);

/// G1 curve constant b = 4.
final BigInt _g1B = _four;

// ---------------------------------------------------------------------------
// Fp helpers (base prime field, plain BigInt)
// ---------------------------------------------------------------------------

BigInt _fpCreate(BigInt a) {
  final r = a % _p;
  return r.isNegative ? r + _p : r;
}

BigInt _fpAdd(BigInt a, BigInt b) => _fpCreate(a + b);
BigInt _fpSub(BigInt a, BigInt b) => _fpCreate(a - b);
BigInt _fpMul(BigInt a, BigInt b) => _fpCreate(a * b);
BigInt _fpNeg(BigInt a) => _fpCreate(-a);
BigInt _fpInv(BigInt a) => a.modInverse(_p);

/// Legendre symbol of `a` mod p: 1 (residue), -1 (non-residue), 0 (zero).
int _fpLegendre(BigInt a) {
  final v = a.modPow((_p - BigInt.one) >> 1, _p);
  if (v == BigInt.one) return 1;
  if (v == BigInt.zero) return 0;
  return -1;
}

/// Square root in Fp (p ≡ 3 mod 4, so sqrt = a^((p+1)/4)).
BigInt _fpSqrt(BigInt a) {
  final root = a.modPow((_p + BigInt.one) >> 2, _p);
  if (_fpMul(root, root) != _fpCreate(a)) {
    throw StateError('Fp: value has no square root');
  }
  return root;
}

// ---------------------------------------------------------------------------
// Fp2 = Fp[u] / (u² + 1)
// ---------------------------------------------------------------------------

/// Element of the quadratic extension field Fp2, `c0 + c1·u` with u² = -1.
class Fp2 {
  final BigInt c0;
  final BigInt c1;

  const Fp2._(this.c0, this.c1);

  /// Creates an element, reducing both coordinates mod p.
  factory Fp2(BigInt c0, BigInt c1) => Fp2._(_fpCreate(c0), _fpCreate(c1));

  /// Builds an element from `[c0, c1]`.
  factory Fp2.fromBigTuple(List<BigInt> tuple) {
    if (tuple.length != 2) throw ArgumentError('invalid Fp2.fromBigTuple');
    return Fp2(tuple[0], tuple[1]);
  }

  static final Fp2 zero = Fp2._(BigInt.zero, BigInt.zero);
  static final Fp2 one = Fp2._(BigInt.one, BigInt.zero);

  /// The tower non-residue ξ = 1 + u.
  static final Fp2 nonresidue = Fp2._(BigInt.one, BigInt.one);

  bool get isZero => c0 == BigInt.zero && c1 == BigInt.zero;

  bool eql(Fp2 other) => c0 == other.c0 && c1 == other.c1;

  Fp2 add(Fp2 o) => Fp2._(_fpAdd(c0, o.c0), _fpAdd(c1, o.c1));

  Fp2 sub(Fp2 o) => Fp2._(_fpSub(c0, o.c0), _fpSub(c1, o.c1));

  Fp2 neg() => Fp2._(_fpNeg(c0), _fpNeg(c1));

  /// (a+bu)(c+du) = (ac−bd) + (ad+bc)u.
  Fp2 mul(Fp2 o) {
    final t1 = _fpMul(c0, o.c0);
    final t2 = _fpMul(c1, o.c1);
    final o0 = _fpSub(t1, t2);
    final o1 =
        _fpSub(_fpMul(_fpAdd(c0, c1), _fpAdd(o.c0, o.c1)), _fpAdd(t1, t2));
    return Fp2._(o0, o1);
  }

  /// Multiplies both coordinates by a base-field scalar.
  Fp2 mulScalar(BigInt k) => Fp2._(_fpMul(c0, k), _fpMul(c1, k));

  Fp2 sqr() {
    final a = _fpAdd(c0, c1);
    final b = _fpSub(c0, c1);
    final c = _fpAdd(c0, c0);
    return Fp2._(_fpMul(a, b), _fpMul(c, c1));
  }

  /// (a + bu)⁻¹ = (a - bu) / (a² + b²).
  Fp2 inv() {
    final factor = _fpInv(_fpCreate(c0 * c0 + c1 * c1));
    return Fp2._(_fpMul(factor, c0), _fpMul(factor, _fpNeg(c1)));
  }

  Fp2 conjugate() => Fp2._(c0, _fpNeg(c1));

  /// Multiplies by the tower non-residue ξ = 1 + u.
  Fp2 mulByNonresidue() => mul(nonresidue);

  /// Multiplies by the twist coefficient 4(1 + u).
  Fp2 mulByB() {
    final t0 = _fpMul(c0, _four);
    final t1 = _fpMul(c1, _four);
    return Fp2._(_fpSub(t0, t1), _fpAdd(t0, t1));
  }

  /// Frobenius x → x^(p^power). Odd powers are conjugation (u² = -1).
  Fp2 frobeniusMap(int power) => power.isEven ? this : conjugate();

  /// Square-and-multiply exponentiation (exponent ≥ 0).
  Fp2 pow(BigInt e) {
    if (e < BigInt.zero) throw ArgumentError('negative exponent');
    var result = one;
    var base = this;
    var k = e;
    while (k > BigInt.zero) {
      if (k.isOdd) result = result.mul(base);
      base = base.sqr();
      k >>= 1;
    }
    return result;
  }

  /// RFC 9380 sgn0 for the m = 2 case (used only via [G1Point], kept for
  /// symmetry with the field API).
  bool get isOdd {
    final sign0 = c0.isOdd;
    final zero0 = c0 == BigInt.zero;
    final sign1 = c1.isOdd;
    return sign0 || (zero0 && sign1);
  }

  /// Square root for the quadratic extension (Fp_NONRESIDUE = -1).
  Fp2 sqrt() {
    if (c1 == BigInt.zero) {
      if (_fpLegendre(c0) == 1) return Fp2._(_fpSqrt(c0), BigInt.zero);
      return Fp2._(BigInt.zero, _fpSqrt(_fpNeg(c0)));
    }
    // a = sqrt(c0² - c1²·NONRESIDUE) = sqrt(c0² + c1²).
    final a = _fpSqrt(_fpAdd(_fpMul(c0, c0), _fpMul(c1, c1)));
    var d = _fpMul(_fpAdd(a, c0), _inv2);
    if (_fpLegendre(d) == -1) d = _fpSub(d, a);
    final a0 = _fpSqrt(d);
    final candidate = Fp2._(a0, _fpMul(_fpMul(c1, _inv2), _fpInv(a0)));
    if (!candidate.sqr().eql(this)) throw StateError('Fp2: no square root');
    return candidate;
  }

  /// Helper for cyclotomic squaring (noble's `Fp4Square`): returns
  /// `(b²·ξ + a², (a+b)² - a² - b²)`.
  static (Fp2, Fp2) fp4Square(Fp2 a, Fp2 b) {
    final a2 = a.sqr();
    final b2 = b.sqr();
    return (
      b2.mulByNonresidue().add(a2),
      a.add(b).sqr().sub(a2).sub(b2),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fp2 && c0 == other.c0 && c1 == other.c1;

  @override
  int get hashCode => Object.hash(c0, c1);

  @override
  String toString() => 'Fp2($c0, $c1)';
}

// ---------------------------------------------------------------------------
// Frobenius coefficient tables (as noble's calcFrobeniusCoefficients)
// ---------------------------------------------------------------------------

/// Fp6 c1 coefficients: ξ^((p^j - 1)/3), j = 0..5.
final List<Fp2> _frob6C1 = List.unmodifiable(<Fp2>[
  for (var j = 0; j < 6; j++)
    Fp2.nonresidue.pow((_p.pow(j) - BigInt.one) ~/ _three),
]);

/// Fp6 c2 coefficients: ξ^((2·p^j - 2)/3), j = 0..5.
final List<Fp2> _frob6C2 = List.unmodifiable(<Fp2>[
  for (var j = 0; j < 6; j++)
    Fp2.nonresidue.pow((BigInt.two * _p.pow(j) - BigInt.two) ~/ _three),
]);

/// Fp12 coefficients: ξ^((p^j - 1)/6), j = 0..11.
final List<Fp2> _frob12 = List.unmodifiable(<Fp2>[
  for (var j = 0; j < 12; j++)
    Fp2.nonresidue.pow((_p.pow(j) - BigInt.one) ~/ _six),
]);

/// Base of the ψ endomorphism: 1/(1 + u).
final Fp2 _psiBase = Fp2.nonresidue.inv();

/// ψ constants: base^((p-1)/3) and base^((p-1)/2).
final Fp2 _psiX = _psiBase.pow((_p - BigInt.one) ~/ _three);
final Fp2 _psiY = _psiBase.pow((_p - BigInt.one) ~/ BigInt.two);

/// ψ(x, y) untwist-Frobenius-twist endomorphism on affine twist coordinates.
(Fp2, Fp2) _psi(Fp2 x, Fp2 y) =>
    (x.frobeniusMap(1).mul(_psiX), y.frobeniusMap(1).mul(_psiY));

// ---------------------------------------------------------------------------
// Fp6 = Fp2[v] / (v³ - (1 + u))
// ---------------------------------------------------------------------------

/// Element of the sextic extension field Fp6, `c0 + c1·v + c2·v²`.
class Fp6 {
  final Fp2 c0;
  final Fp2 c1;
  final Fp2 c2;

  const Fp6(this.c0, this.c1, this.c2);

  static final Fp6 zero = Fp6(Fp2.zero, Fp2.zero, Fp2.zero);
  static final Fp6 one = Fp6(Fp2.one, Fp2.zero, Fp2.zero);

  bool get isZero => c0.isZero && c1.isZero && c2.isZero;

  bool eql(Fp6 o) => c0.eql(o.c0) && c1.eql(o.c1) && c2.eql(o.c2);

  Fp6 add(Fp6 o) => Fp6(c0.add(o.c0), c1.add(o.c1), c2.add(o.c2));

  Fp6 sub(Fp6 o) => Fp6(c0.sub(o.c0), c1.sub(o.c1), c2.sub(o.c2));

  Fp6 neg() => Fp6(c0.neg(), c1.neg(), c2.neg());

  Fp6 mul(Fp6 o) {
    final t0 = c0.mul(o.c0);
    final t1 = c1.mul(o.c1);
    final t2 = c2.mul(o.c2);
    return Fp6(
      t0.add(c1.add(c2).mul(o.c1.add(o.c2)).sub(t1.add(t2)).mulByNonresidue()),
      c0.add(c1).mul(o.c0.add(o.c1)).sub(t0.add(t1)).add(t2.mulByNonresidue()),
      t1.add(c0.add(c2).mul(o.c0.add(o.c2))).sub(t0.add(t2)),
    );
  }

  Fp6 sqr() {
    final t0 = c0.sqr();
    final t1 = c0.mul(c1).mulScalar(BigInt.two);
    final t3 = c1.mul(c2).mulScalar(BigInt.two);
    final t4 = c2.sqr();
    return Fp6(
      t3.mulByNonresidue().add(t0),
      t4.mulByNonresidue().add(t1),
      t1.add(c0.sub(c1).add(c2).sqr()).add(t3).sub(t0).sub(t4),
    );
  }

  Fp6 inv() {
    final t0 = c0.sqr().sub(c2.mul(c1).mulByNonresidue());
    final t1 = c2.sqr().mulByNonresidue().sub(c0.mul(c1));
    final t2 = c1.sqr().sub(c0.mul(c2));
    final t4 =
        c2.mul(t1).add(c1.mul(t2)).mulByNonresidue().add(c0.mul(t0)).inv();
    return Fp6(t4.mul(t0), t4.mul(t1), t4.mul(t2));
  }

  /// Multiplication by v: (c0, c1, c2) → (c2·ξ, c0, c1).
  Fp6 mulByNonresidue() => Fp6(c2.mulByNonresidue(), c0, c1);

  /// Sparse multiplication by (0, b1, 0).
  Fp6 mul1(Fp2 b1) => Fp6(c2.mul(b1).mulByNonresidue(), c0.mul(b1), c1.mul(b1));

  /// Sparse multiplication by (b0, b1, 0).
  Fp6 mul01(Fp2 b0, Fp2 b1) {
    final t0 = c0.mul(b0);
    final t1 = c1.mul(b1);
    return Fp6(
      c1.add(c2).mul(b1).sub(t1).mulByNonresidue().add(t0),
      b0.add(b1).mul(c0.add(c1)).sub(t0).sub(t1),
      c0.add(c2).mul(b0).sub(t0).add(t1),
    );
  }

  Fp6 frobeniusMap(int power) => Fp6(
        c0.frobeniusMap(power),
        c1.frobeniusMap(power).mul(_frob6C1[power % 6]),
        c2.frobeniusMap(power).mul(_frob6C2[power % 6]),
      );

  @override
  bool operator ==(Object other) =>
      other is Fp6 && c0 == other.c0 && c1 == other.c1 && c2 == other.c2;

  @override
  int get hashCode => Object.hash(c0, c1, c2);

  @override
  String toString() => 'Fp6($c0, $c1, $c2)';
}

// ---------------------------------------------------------------------------
// Fp12 = Fp6[w] / (w² - v)
// ---------------------------------------------------------------------------

/// Element of the degree-12 extension field Fp12, `c0 + c1·w`.
class Fp12 {
  final Fp6 c0;
  final Fp6 c1;

  const Fp12(this.c0, this.c1);

  static final Fp12 one = Fp12(Fp6.one, Fp6.zero);
  static final Fp12 zero = Fp12(Fp6.zero, Fp6.zero);

  bool get isZero => c0.isZero && c1.isZero;

  bool eql(Fp12 o) => c0.eql(o.c0) && c1.eql(o.c1);

  Fp12 mul(Fp12 o) {
    final t1 = c0.mul(o.c0);
    final t2 = c1.mul(o.c1);
    return Fp12(
      t1.add(t2.mulByNonresidue()),
      c0.add(c1).mul(o.c0.add(o.c1)).sub(t1.add(t2)),
    );
  }

  Fp12 sqr() {
    final ab = c0.mul(c1);
    return Fp12(
      c1
          .mulByNonresidue()
          .add(c0)
          .mul(c0.add(c1))
          .sub(ab)
          .sub(ab.mulByNonresidue()),
      ab.add(ab),
    );
  }

  /// Multiplicative inverse.
  Fp12 inverse() {
    final t = c0.sqr().sub(c1.sqr().mulByNonresidue()).inv();
    return Fp12(c0.mul(t), c1.mul(t).neg());
  }

  Fp12 conjugate() => Fp12(c0, c1.neg());

  Fp12 frobeniusMap(int power) {
    final r0 = c0.frobeniusMap(power);
    final t = c1.frobeniusMap(power);
    final coeff = _frob12[power % 12];
    return Fp12(
      r0,
      Fp6(t.c0.mul(coeff), t.c1.mul(coeff), t.c2.mul(coeff)),
    );
  }

  /// Sparse multiplication by (o0, o1, 0, 0, o4, 0), used by the M-type twist
  /// line function.
  Fp12 mul014(Fp2 o0, Fp2 o1, Fp2 o4) {
    final t0 = c0.mul01(o0, o1);
    final t1 = c1.mul1(o4);
    return Fp12(
      t1.mulByNonresidue().add(t0),
      c1.add(c0).mul01(o0, o1.add(o4)).sub(t0).sub(t1),
    );
  }

  /// Cyclotomic squaring (Granger-Scott), valid for elements of the
  /// cyclotomic subgroup.
  Fp12 cyclotomicSquare() {
    final c0c0 = c0.c0, c0c1 = c0.c1, c0c2 = c0.c2;
    final c1c0 = c1.c0, c1c1 = c1.c1, c1c2 = c1.c2;
    final (t3, t4) = Fp2.fp4Square(c0c0, c1c1);
    final (t5, t6) = Fp2.fp4Square(c1c0, c0c2);
    final (t7, t8) = Fp2.fp4Square(c0c1, c1c2);
    final t9 = t8.mulByNonresidue();
    return Fp12(
      Fp6(
        t3.sub(c0c0).mulScalar(BigInt.two).add(t3),
        t5.sub(c0c1).mulScalar(BigInt.two).add(t5),
        t7.sub(c0c2).mulScalar(BigInt.two).add(t7),
      ),
      Fp6(
        t9.add(c1c0).mulScalar(BigInt.two).add(t9),
        t4.add(c1c1).mulScalar(BigInt.two).add(t4),
        t6.add(c1c2).mulScalar(BigInt.two).add(t6),
      ),
    );
  }

  /// Cyclotomic exponentiation by `n` (consumes exactly |x| bits).
  Fp12 cyclotomicExp(BigInt n) {
    var z = one;
    for (var i = _xLen - 1; i >= 0; i--) {
      z = z.cyclotomicSquare();
      if ((n >> i).isOdd) z = z.mul(this);
    }
    return z;
  }

  /// BLS12-381 final exponentiation (easy part followed by the seed-driven
  /// hard part).
  Fp12 finalExponentiate() {
    final x = _blsX;
    // Easy part: this^(q⁶ - 1)^(q² + 1).
    final t0 = frobeniusMap(6).mul(inverse());
    final t1 = t0.frobeniusMap(2).mul(t0);
    // Hard part.
    final t2 = t1.cyclotomicExp(x).conjugate();
    final t3 = t1.cyclotomicSquare().conjugate().mul(t2);
    final t4 = t3.cyclotomicExp(x).conjugate();
    final t5 = t4.cyclotomicExp(x).conjugate();
    final t6 = t5.cyclotomicExp(x).conjugate().mul(t2.cyclotomicSquare());
    final t7 = t6.cyclotomicExp(x).conjugate();
    final t2t5q2 = t2.mul(t5).frobeniusMap(2);
    final t4t1q3 = t4.mul(t1).frobeniusMap(3);
    final t6t1cq1 = t6.mul(t1.conjugate()).frobeniusMap(1);
    final t7t3ct1 = t7.mul(t3.conjugate()).mul(t1);
    return t2t5q2.mul(t4t1q3).mul(t6t1cq1).mul(t7t3ct1);
  }

  /// Serializes to 576 little-endian bytes: c0 then c1 (each an Fp6 of three
  /// Fp2 = two 48-byte little-endian Fq coordinates).
  Uint8List toLEBytes() {
    final out = Uint8List(576);
    var offset = 0;
    void put(BigInt v) {
      final le = _toLEBytes(v, 48);
      out.setRange(offset, offset + 48, le);
      offset += 48;
    }

    void putFp6(Fp6 e) {
      put(e.c0.c0);
      put(e.c0.c1);
      put(e.c1.c0);
      put(e.c1.c1);
      put(e.c2.c0);
      put(e.c2.c1);
    }

    putFp6(c0);
    putFp6(c1);
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is Fp12 && c0 == other.c0 && c1 == other.c1;

  @override
  int get hashCode => Object.hash(c0, c1);

  @override
  String toString() => 'Fp12($c0, $c1)';
}

// ---------------------------------------------------------------------------
// Byte helpers
// ---------------------------------------------------------------------------

/// Big-endian bytes to a non-negative [BigInt].
BigInt _beToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Encodes a non-negative [BigInt] as `length` big-endian bytes.
Uint8List _toBEBytes(BigInt v, int length) {
  final out = Uint8List(length);
  var x = v;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

/// Encodes a non-negative [BigInt] as `length` little-endian bytes.
Uint8List _toLEBytes(BigInt v, int length) {
  final out = Uint8List(length);
  var x = v;
  for (var i = 0; i < length; i++) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

// ZCash compressed-point flag bits (top byte of the big-endian encoding).
const int _flagCompressed = 0x80;
const int _flagInfinity = 0x40;
const int _flagSort = 0x20;

/// True when the "sort" (lexicographic y-sign) flag should be set for a G1 y.
bool _g1SortFlag(BigInt y) => (y * BigInt.two) >= _p;

/// True when the sort flag should be set for a G2 y (imaginary part decides,
/// falling back to the real part when the imaginary part is zero).
bool _g2SortFlag(Fp2 y) {
  final ref = y.c1 == BigInt.zero ? y.c0 : y.c1;
  return (ref * BigInt.two) >= _p;
}

// ---------------------------------------------------------------------------
// G1: y² = x³ + 4 over Fp
// ---------------------------------------------------------------------------

/// Affine point on the BLS12-381 G1 curve.
class G1Point {
  final BigInt x;
  final BigInt y;
  final bool isInfinity;

  const G1Point._(this.x, this.y, this.isInfinity);

  /// The point at infinity.
  static final G1Point zero = G1Point._(BigInt.zero, BigInt.zero, true);

  /// G1 generator.
  static final G1Point base = G1Point._(
    BigInt.parse(
      '17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb',
      radix: 16,
    ),
    BigInt.parse(
      '08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1',
      radix: 16,
    ),
    false,
  );

  /// Builds an affine point, reducing coordinates mod p (no validation).
  factory G1Point.fromAffine(BigInt x, BigInt y) =>
      G1Point._(_fpCreate(x), _fpCreate(y), false);

  bool get isZero => isInfinity;

  /// Affine coordinates; throws for infinity.
  ({BigInt x, BigInt y}) toAffine() {
    if (isInfinity) throw StateError('G1: point at infinity has no affine');
    return (x: x, y: y);
  }

  G1Point negate() => isInfinity ? this : G1Point._(x, _fpNeg(y), false);

  G1Point subtract(G1Point other) => add(other.negate());

  /// Curve equation check (does not include the subgroup test).
  bool isOnCurve() {
    if (isInfinity) return true;
    final left = _fpMul(y, y);
    final right = _fpAdd(_fpMul(_fpMul(x, x), x), _g1B);
    return left == right;
  }

  /// True when the point lies in the prime-order subgroup.
  bool isTorsionFree() {
    if (isInfinity) return true;
    // ψ(P) via the GLV endomorphism (x·β, y).
    final phi = G1Point._(_fpMul(x, _g1Beta), y, false);
    final xP = multiply(_blsX).negate();
    final u2P = xP.multiply(_blsX);
    return u2P.equals(phi);
  }

  G1Point doublePoint() {
    if (isInfinity) return this;
    if (y == BigInt.zero) return zero;
    final lam = _fpMul(_fpMul(_three, _fpMul(x, x)), _fpInv(_fpAdd(y, y)));
    final x3 = _fpSub(_fpMul(lam, lam), _fpAdd(x, x));
    final y3 = _fpSub(_fpMul(lam, _fpSub(x, x3)), y);
    return G1Point._(x3, y3, false);
  }

  G1Point add(G1Point other) {
    if (isInfinity) return other;
    if (other.isInfinity) return this;
    if (x == other.x) {
      if (_fpAdd(y, other.y) == BigInt.zero) return zero;
      return doublePoint();
    }
    final lam = _fpMul(_fpSub(other.y, y), _fpInv(_fpSub(other.x, x)));
    final x3 = _fpSub(_fpSub(_fpMul(lam, lam), x), other.x);
    final y3 = _fpSub(_fpMul(lam, _fpSub(x, x3)), y);
    return G1Point._(x3, y3, false);
  }

  /// Scalar multiplication (double-and-add).
  G1Point multiply(BigInt k) {
    if (k < BigInt.zero) return negate().multiply(-k);
    var acc = zero;
    for (var i = k.bitLength - 1; i >= 0; i--) {
      acc = acc.doublePoint();
      if ((k >> i).isOdd) acc = acc.add(this);
    }
    return acc;
  }

  bool equals(G1Point other) {
    if (isInfinity || other.isInfinity) return isInfinity == other.isInfinity;
    return x == other.x && y == other.y;
  }

  /// 48-byte ZCash compressed encoding.
  Uint8List toCompressedBytes() {
    if (isInfinity) {
      final out = Uint8List(48);
      out[0] = _flagCompressed | _flagInfinity;
      return out;
    }
    final out = _toBEBytes(x, 48);
    out[0] |= _flagCompressed;
    if (_g1SortFlag(y)) out[0] |= _flagSort;
    return out;
  }

  /// Decodes a 48-byte ZCash compressed G1 point, validating that it is on
  /// the curve and in the prime-order subgroup.
  static G1Point fromCompressedBytes(Uint8List bytes) {
    if (bytes.length != 48) {
      throw ArgumentError('G1 compressed point must be 48 bytes');
    }
    final first = bytes[0];
    if (first & _flagCompressed == 0) {
      throw ArgumentError('G1: expected compressed encoding');
    }
    final infinity = first & _flagInfinity != 0;
    final sort = first & _flagSort != 0;
    final stripped = Uint8List.fromList(bytes);
    stripped[0] &= 0x1f;
    final xVal = _fpCreate(_beToBigInt(stripped));
    if (infinity) {
      if (xVal != BigInt.zero) {
        throw ArgumentError('G1: non-zero coordinate for infinity');
      }
      return zero;
    }
    final rhs = _fpAdd(_fpMul(_fpMul(xVal, xVal), xVal), _g1B);
    var yVal = _fpSqrt(rhs);
    if (_g1SortFlag(yVal) != sort) yVal = _fpNeg(yVal);
    final point = G1Point._(xVal, yVal, false);
    if (!point.isOnCurve()) throw StateError('G1: point is not on curve');
    if (!point.isTorsionFree()) {
      throw StateError('G1: point is not in prime-order subgroup');
    }
    return point;
  }

  @override
  String toString() => isInfinity ? 'G1(infinity)' : 'G1($x, $y)';
}

/// GLV endomorphism constant β for G1 (a nontrivial cube root of unity mod p).
final BigInt _g1Beta = BigInt.parse(
  '5f19672fdf76ce51ba69c6076a0f77eaddb3a93be6f89688de17d813620a00022e01fffffffefffe',
  radix: 16,
);

// ---------------------------------------------------------------------------
// G2: y² = x³ + 4(1 + u) over Fp2
// ---------------------------------------------------------------------------

/// Twist curve constant b = 4(1 + u).
final Fp2 _g2B = Fp2(_four, _four);

/// Affine point on the BLS12-381 G2 twist curve.
class G2Point {
  final Fp2 x;
  final Fp2 y;
  final bool isInfinity;

  const G2Point._(this.x, this.y, this.isInfinity);

  /// The point at infinity.
  static final G2Point zero = G2Point._(Fp2.zero, Fp2.zero, true);

  /// G2 generator.
  static final G2Point base = G2Point._(
    Fp2.fromBigTuple([
      BigInt.parse(
        '024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8',
        radix: 16,
      ),
      BigInt.parse(
        '13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e',
        radix: 16,
      ),
    ]),
    Fp2.fromBigTuple([
      BigInt.parse(
        '0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801',
        radix: 16,
      ),
      BigInt.parse(
        '0606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be',
        radix: 16,
      ),
    ]),
    false,
  );

  /// Builds an affine point (no validation). `((0,0),(0,0))` maps to infinity.
  factory G2Point.fromAffine(Fp2 x, Fp2 y) {
    if (x.isZero && y.isZero) return zero;
    return G2Point._(x, y, false);
  }

  bool get isZero => isInfinity;

  /// Affine coordinates; throws for infinity.
  ({Fp2 x, Fp2 y}) toAffine() {
    if (isInfinity) throw StateError('G2: point at infinity has no affine');
    return (x: x, y: y);
  }

  G2Point negate() => isInfinity ? this : G2Point._(x, y.neg(), false);

  G2Point subtract(G2Point other) => add(other.negate());

  /// Curve equation check (does not include the subgroup test).
  bool isOnCurve() {
    if (isInfinity) return true;
    final left = y.sqr();
    final right = x.sqr().mul(x).add(_g2B);
    return left.eql(right);
  }

  /// True when the point lies in the prime-order subgroup: ψ(P) == [x]P.
  bool isTorsionFree() {
    if (isInfinity) return true;
    final xP = multiply(_blsX).negate();
    final (px, py) = _psi(x, y);
    final psiP = G2Point._(px, py, false);
    return xP.equals(psiP);
  }

  G2Point doublePoint() {
    if (isInfinity) return this;
    if (y.isZero) return zero;
    final lam = x.sqr().mulScalar(_three).mul(y.add(y).inv());
    final x3 = lam.sqr().sub(x.add(x));
    final y3 = lam.mul(x.sub(x3)).sub(y);
    return G2Point._(x3, y3, false);
  }

  G2Point add(G2Point other) {
    if (isInfinity) return other;
    if (other.isInfinity) return this;
    if (x.eql(other.x)) {
      if (y.add(other.y).isZero) return zero;
      return doublePoint();
    }
    final lam = other.y.sub(y).mul(other.x.sub(x).inv());
    final x3 = lam.sqr().sub(x).sub(other.x);
    final y3 = lam.mul(x.sub(x3)).sub(y);
    return G2Point._(x3, y3, false);
  }

  /// Scalar multiplication (double-and-add).
  G2Point multiply(BigInt k) {
    if (k < BigInt.zero) return negate().multiply(-k);
    var acc = zero;
    for (var i = k.bitLength - 1; i >= 0; i--) {
      acc = acc.doublePoint();
      if ((k >> i).isOdd) acc = acc.add(this);
    }
    return acc;
  }

  bool equals(G2Point other) {
    if (isInfinity || other.isInfinity) return isInfinity == other.isInfinity;
    return x.eql(other.x) && y.eql(other.y);
  }

  /// 96-byte ZCash compressed encoding: x.c1 (with flags) then x.c0.
  Uint8List toCompressedBytes() {
    final out = Uint8List(96);
    if (isInfinity) {
      out[0] = _flagCompressed | _flagInfinity;
      return out;
    }
    out.setRange(0, 48, _toBEBytes(x.c1, 48));
    out.setRange(48, 96, _toBEBytes(x.c0, 48));
    out[0] |= _flagCompressed;
    if (_g2SortFlag(y)) out[0] |= _flagSort;
    return out;
  }

  /// Decodes a 96-byte ZCash compressed G2 point, validating that it is on
  /// the curve and in the prime-order subgroup.
  static G2Point fromCompressedBytes(Uint8List bytes) {
    if (bytes.length != 96) {
      throw ArgumentError('G2 compressed point must be 96 bytes');
    }
    final first = bytes[0];
    if (first & _flagCompressed == 0) {
      throw ArgumentError('G2: expected compressed encoding');
    }
    final infinity = first & _flagInfinity != 0;
    final sort = first & _flagSort != 0;
    final c1Bytes = Uint8List.fromList(bytes.sublist(0, 48));
    c1Bytes[0] &= 0x1f;
    final xc1 = _fpCreate(_beToBigInt(c1Bytes));
    final xc0 = _fpCreate(_beToBigInt(bytes.sublist(48, 96)));
    if (infinity) {
      if (xc0 != BigInt.zero || xc1 != BigInt.zero) {
        throw ArgumentError('G2: non-zero coordinate for infinity');
      }
      return zero;
    }
    final xVal = Fp2(xc0, xc1);
    final rhs = xVal.sqr().mul(xVal).add(_g2B);
    var yVal = rhs.sqrt();
    if (_g2SortFlag(yVal) != sort) yVal = yVal.neg();
    final point = G2Point._(xVal, yVal, false);
    if (!point.isOnCurve()) throw StateError('G2: point is not on curve');
    if (!point.isTorsionFree()) {
      throw StateError('G2: point is not in prime-order subgroup');
    }
    return point;
  }

  @override
  String toString() => isInfinity ? 'G2(infinity)' : 'G2($x, $y)';
}

// ---------------------------------------------------------------------------
// Optimal-ate pairing: Miller loop (bits of |x|) + final exponentiation
// ---------------------------------------------------------------------------

/// Line-function coefficients (c0, c1, c2).
typedef _Line = (Fp2, Fp2, Fp2);

/// Signed NAF decomposition of `a` (MSB-first, top marker bit dropped).
List<int> _nafDecomposition(BigInt a0) {
  final res = <int>[];
  var a = a0;
  final threeB = BigInt.from(3);
  while (a > BigInt.one) {
    if ((a & BigInt.one) == BigInt.zero) {
      res.add(0);
    } else if ((a & threeB) == threeB) {
      res.add(-1);
      a += BigInt.one;
    } else {
      res.add(1);
    }
    a >>= 1;
  }
  return res.reversed.toList();
}

final List<int> _ateNaf = _nafDecomposition(_blsX);

/// Doubles R (projective) and records the line coefficients.
(Fp2, Fp2, Fp2) _pointDoubleLine(List<_Line> ell, Fp2 rx, Fp2 ry, Fp2 rz) {
  final t0 = ry.sqr();
  final t1 = rz.sqr();
  final t2 = t1.mulScalar(_three).mulByB();
  final t3 = t2.mulScalar(_three);
  final t4 = ry.add(rz).sqr().sub(t1).sub(t0);
  final c0 = t2.sub(t0);
  final c1 = rx.sqr().mulScalar(_three);
  final c2 = t4.neg();
  ell.add((c0, c1, c2));
  final nrx = t0.sub(t3).mul(rx).mul(ry).mulScalar(_inv2);
  final nry = t0.add(t3).mulScalar(_inv2).sqr().sub(t2.sqr().mulScalar(_three));
  final nrz = t0.mul(t4);
  return (nrx, nry, nrz);
}

/// Adds Q to R (projective) and records the line coefficients.
(Fp2, Fp2, Fp2) _pointAddLine(
    List<_Line> ell, Fp2 rx, Fp2 ry, Fp2 rz, Fp2 qx, Fp2 qy) {
  final t0 = ry.sub(qy.mul(rz));
  final t1 = rx.sub(qx.mul(rz));
  final c0 = t0.mul(qx).sub(t1.mul(qy));
  final c1 = t0.neg();
  final c2 = t1;
  ell.add((c0, c1, c2));
  final t2 = t1.sqr();
  final t3 = t2.mul(t1);
  final t4 = t2.mul(rx);
  final t5 = t3.sub(t4.mulScalar(BigInt.two)).add(t0.sqr().mul(rz));
  final nrx = t1.mul(t5);
  final nry = t4.sub(t5).mul(t0).sub(t3.mul(ry));
  final nrz = rz.mul(t3);
  return (nrx, nry, nrz);
}

/// Precomputes the Miller-loop line coefficients for one G2 point.
List<List<_Line>> _calcPairingPrecomputes(G2Point point) {
  final qx = point.x, qy = point.y;
  final negQy = qy.neg();
  var rx = qx, ry = qy, rz = Fp2.one;
  final ell = <List<_Line>>[];
  for (final bit in _ateNaf) {
    final cur = <_Line>[];
    (rx, ry, rz) = _pointDoubleLine(cur, rx, ry, rz);
    if (bit != 0) {
      (rx, ry, rz) = _pointAddLine(cur, rx, ry, rz, qx, bit == -1 ? negQy : qy);
    }
    ell.add(cur);
  }
  return ell;
}

/// Runs the Miller loop over precomputed lines. The seed is negative, so the
/// accumulated value is conjugated at the end.
Fp12 _millerLoop(List<List<_Line>> ell, BigInt px, BigInt py) {
  var f = Fp12.one;
  for (var i = 0; i < ell.length; i++) {
    f = f.sqr();
    for (final (c0, c1, c2) in ell[i]) {
      // M-type twist line function: mul014(f, c0, c1·Px, c2·Py).
      f = f.mul014(c0, c1.mulScalar(px), c2.mulScalar(py));
    }
  }
  return f.conjugate();
}

/// Computes the optimal-ate pairing e(p, q) with the final exponentiation.
///
/// Throws for infinity or off-subgroup inputs, matching the reference
/// pairing's precondition checks.
Fp12 blsPairing(G1Point p, G2Point q) {
  if (p.isInfinity || q.isInfinity) {
    throw StateError('pairing is not defined for the point at infinity');
  }
  final (px, py) = (p.x, p.y);
  final ell = _calcPairingPrecomputes(q);
  final f = _millerLoop(ell, px, py);
  return f.finalExponentiate();
}

// ---------------------------------------------------------------------------
// Hash-to-curve for G1 (RFC 9380 BLS12381G1_XMD:SHA-256_SSWU_RO_)
// ---------------------------------------------------------------------------

Uint8List _sha256(Uint8List data) => SHA256Digest().process(data);

/// RFC 9380 expand_message_xmd with SHA-256 (32-byte output, 64-byte blocks).
Uint8List _expandMessageXmd(Uint8List msg, Uint8List dst, int lenInBytes) {
  const bInBytes = 32;
  const rInBytes = 64;
  var dstPrime = dst;
  if (dst.length > 255) {
    dstPrime = _sha256(_concat([_utf8('H2C-OVERSIZE-DST-'), dst]));
  }
  final ell = (lenInBytes + bInBytes - 1) ~/ bInBytes;
  if (lenInBytes > 65535 || ell > 255) {
    throw ArgumentError('expand_message_xmd: invalid length');
  }
  final dstWithLen = _concat([
    dstPrime,
    Uint8List.fromList([dstPrime.length])
  ]);
  final zPad = Uint8List(rInBytes);
  final lStr = Uint8List(2)
    ..[0] = (lenInBytes >> 8) & 0xff
    ..[1] = lenInBytes & 0xff;
  final b0 = _sha256(_concat([
    zPad,
    msg,
    lStr,
    Uint8List.fromList([0]),
    dstWithLen,
  ]));
  final blocks = <Uint8List>[];
  blocks.add(_sha256(_concat([
    b0,
    Uint8List.fromList([1]),
    dstWithLen,
  ])));
  for (var i = 1; i <= ell; i++) {
    final xored = Uint8List(bInBytes);
    for (var j = 0; j < bInBytes; j++) {
      xored[j] = b0[j] ^ blocks[i - 1][j];
    }
    blocks.add(_sha256(_concat([
      xored,
      Uint8List.fromList([i + 1]),
      dstWithLen,
    ])));
  }
  final all = _concat(blocks);
  return Uint8List.sublistView(all, 0, lenInBytes);
}

/// RFC 9380 hash_to_field producing `count` Fp elements (m = 1, k = 128).
List<BigInt> _hashToFieldFp(Uint8List msg, Uint8List dst, int count) {
  const k = 128;
  final log2p = _p.bitLength;
  final l = (log2p + k + 7) ~/ 8; // ceil((log2p + k) / 8)
  final lenInBytes = count * l;
  final prb = _expandMessageXmd(msg, dst, lenInBytes);
  final out = <BigInt>[];
  for (var i = 0; i < count; i++) {
    final tv = prb.sublist(i * l, i * l + l);
    out.add(_beToBigInt(tv) % _p);
  }
  return out;
}

/// SSWU + isogeny map from Fp to a point on E (before cofactor clearing).
({BigInt x, BigInt y}) _mapToCurveG1(BigInt u) {
  final (xp, yp) = _sswuG1(u);
  return _isogenyMapG1(xp, yp);
}

// Simplified SWU parameters for the G1 3-isogenous curve.
final BigInt _swuA = BigInt.parse(
  '00144698a3b8e9433d693a02c96d4982b0ea985383ee66a8d8e8981aefd881ac98936f8da0e0f97f5cf428082d584c1d',
  radix: 16,
);
final BigInt _swuB = BigInt.parse(
  '12e2908d11688030018b12e8753eee3b2016c1f0f24f4070a0b9c14fcef35ef55a23215a316ceaa5d1cc48e98e172be0',
  radix: 16,
);
final BigInt _swuZ = BigInt.from(11);

/// sqrt_ratio for p ≡ 3 mod 4: returns `(isSquare, y)` with y = sqrt(u/v) when
/// u/v is a square, otherwise sqrt(Z·u/v).
(bool, BigInt) _sqrtRatio3mod4(BigInt u, BigInt v) {
  final c1 = (_p - _three) ~/ _four;
  final c2 = _fpSqrt(_fpNeg(_swuZ));
  final tv1a = _fpMul(v, v);
  final tv2 = _fpMul(u, v);
  final tv1 = _fpMul(tv1a, tv2);
  var y1 = tv1.modPow(c1, _p);
  y1 = _fpMul(y1, tv2);
  final y2 = _fpMul(y1, c2);
  final tv3 = _fpMul(_fpMul(y1, y1), v);
  final isQr = tv3 == _fpCreate(u);
  final y = isQr ? y1 : y2;
  return (isQr, y);
}

/// Simplified SWU map into the 3-isogenous curve of G1.
(BigInt, BigInt) _sswuG1(BigInt u) {
  final one = BigInt.one;
  var tv1 = _fpMul(_fpMul(u, u), _swuZ);
  var tv2 = _fpMul(tv1, tv1);
  tv2 = _fpAdd(tv2, tv1);
  var tv3 = _fpAdd(tv2, one);
  tv3 = _fpMul(tv3, _swuB);
  final tv4 = tv2 == BigInt.zero ? _swuZ : _fpNeg(tv2);
  final tv4a = _fpMul(tv4, _swuA);
  tv2 = _fpMul(tv3, tv3);
  var tv6 = _fpMul(tv4a, tv4a);
  var tv5 = _fpMul(tv6, _swuA);
  tv2 = _fpAdd(tv2, tv5);
  tv2 = _fpMul(tv2, tv3);
  tv6 = _fpMul(tv6, tv4a);
  tv5 = _fpMul(tv6, _swuB);
  tv2 = _fpAdd(tv2, tv5);
  var x = _fpMul(tv1, tv3);
  final (isValid, value) = _sqrtRatio3mod4(tv2, tv6);
  var y = _fpMul(tv1, u);
  y = _fpMul(y, value);
  if (isValid) {
    x = tv3;
    y = value;
  }
  final e1 = u.isOdd == y.isOdd;
  if (!e1) y = _fpNeg(y);
  x = _fpMul(x, _fpInv(tv4a));
  return (x, y);
}

/// 11-isogeny map coefficients (xNum, xDen, yNum, yDen), constants first.
final List<List<BigInt>> _isoG1Coeffs = _buildIsoG1Coeffs();

List<List<BigInt>> _buildIsoG1Coeffs() {
  List<BigInt> h(List<String> xs) =>
      xs.map((s) => BigInt.parse(s, radix: 16)).toList();
  return [
    // xNum
    h([
      '11a05f2b1e833340b809101dd99815856b303e88a2d7005ff2627b56cdb4e2c85610c2d5f2e62d6eaeac1662734649b7',
      '17294ed3e943ab2f0588bab22147a81c7c17e75b2f6a8417f565e33c70d1e86b4838f2a6f318c356e834eef1b3cb83bb',
      'd54005db97678ec1d1048c5d10a9a1bce032473295983e56878e501ec68e25c958c3e3d2a09729fe0179f9dac9edcb0',
      '1778e7166fcc6db74e0609d307e55412d7f5e4656a8dbf25f1b33289f1b330835336e25ce3107193c5b388641d9b6861',
      'e99726a3199f4436642b4b3e4118e5499db995a1257fb3f086eeb65982fac18985a286f301e77c451154ce9ac8895d9',
      '1630c3250d7313ff01d1201bf7a74ab5db3cb17dd952799b9ed3ab9097e68f90a0870d2dcae73d19cd13c1c66f652983',
      'd6ed6553fe44d296a3726c38ae652bfb11586264f0f8ce19008e218f9c86b2a8da25128c1052ecaddd7f225a139ed84',
      '17b81e7701abdbe2e8743884d1117e53356de5ab275b4db1a682c62ef0f2753339b7c8f8c8f475af9ccb5618e3f0c88e',
      '80d3cf1f9a78fc47b90b33563be990dc43b756ce79f5574a2c596c928c5d1de4fa295f296b74e956d71986a8497e317',
      '169b1f8e1bcfa7c42e0c37515d138f22dd2ecb803a0c5c99676314baf4bb1b7fa3190b2edc0327797f241067be390c9e',
      '10321da079ce07e272d8ec09d2565b0dfa7dccdde6787f96d50af36003b14866f69b771f8c285decca67df3f1605fb7b',
      '6e08c248e260e70bd1e962381edee3d31d79d7e22c837bc23c0bf1bc24c6b68c24b1b80b64d391fa9c8ba2e8ba2d229',
    ]),
    // xDen
    h([
      '8ca8d548cff19ae18b2e62f4bd3fa6f01d5ef4ba35b48ba9c9588617fc8ac62b558d681be343df8993cf9fa40d21b1c',
      '12561a5deb559c4348b4711298e536367041e8ca0cf0800c0126c2588c48bf5713daa8846cb026e9e5c8276ec82b3bff',
      'b2962fe57a3225e8137e629bff2991f6f89416f5a718cd1fca64e00b11aceacd6a3d0967c94fedcfcc239ba5cb83e19',
      '3425581a58ae2fec83aafef7c40eb545b08243f16b1655154cca8abc28d6fd04976d5243eecf5c4130de8938dc62cd8',
      '13a8e162022914a80a6f1d5f43e7a07dffdfc759a12062bb8d6b44e833b306da9bd29ba81f35781d539d395b3532a21e',
      'e7355f8e4e667b955390f7f0506c6e9395735e9ce9cad4d0a43bcef24b8982f7400d24bc4228f11c02df9a29f6304a5',
      '772caacf16936190f3e0c63e0596721570f5799af53a1894e2e073062aede9cea73b3538f0de06cec2574496ee84a3a',
      '14a7ac2a9d64a8b230b3f5b074cf01996e7f63c21bca68a81996e1cdf9822c580fa5b9489d11e2d311f7d99bbdcc5a5e',
      'a10ecf6ada54f825e920b3dafc7a3cce07f8d1d7161366b74100da67f39883503826692abba43704776ec3a79a1d641',
      '95fc13ab9e92ad4476d6e3eb3a56680f682b4ee96f7d03776df533978f31c1593174e4b4b7865002d6384d168ecdd0a',
      '1',
    ]),
    // yNum
    h([
      '90d97c81ba24ee0259d1f094980dcfa11ad138e48a869522b52af6c956543d3cd0c7aee9b3ba3c2be9845719707bb33',
      '134996a104ee5811d51036d776fb46831223e96c254f383d0f906343eb67ad34d6c56711962fa8bfe097e75a2e41c696',
      'cc786baa966e66f4a384c86a3b49942552e2d658a31ce2c344be4b91400da7d26d521628b00523b8dfe240c72de1f6',
      '1f86376e8981c217898751ad8746757d42aa7b90eeb791c09e4a3ec03251cf9de405aba9ec61deca6355c77b0e5f4cb',
      '8cc03fdefe0ff135caf4fe2a21529c4195536fbe3ce50b879833fd221351adc2ee7f8dc099040a841b6daecf2e8fedb',
      '16603fca40634b6a2211e11db8f0a6a074a7d0d4afadb7bd76505c3d3ad5544e203f6326c95a807299b23ab13633a5f0',
      '4ab0b9bcfac1bbcb2c977d027796b3ce75bb8ca2be184cb5231413c4d634f3747a87ac2460f415ec961f8855fe9d6f2',
      '987c8d5333ab86fde9926bd2ca6c674170a05bfe3bdd81ffd038da6c26c842642f64550fedfe935a15e4ca31870fb29',
      '9fc4018bd96684be88c9e221e4da1bb8f3abd16679dc26c1e8b6e6a1f20cabe69d65201c78607a360370e577bdba587',
      'e1bba7a1186bdb5223abde7ada14a23c42a0ca7915af6fe06985e7ed1e4d43b9b3f7055dd4eba6f2bafaaebca731c30',
      '19713e47937cd1be0dfd0b8f1d43fb93cd2fcbcb6caf493fd1183e416389e61031bf3a5cce3fbafce813711ad011c132',
      '18b46a908f36f6deb918c143fed2edcc523559b8aaf0c2462e6bfe7f911f643249d9cdf41b44d606ce07c8a4d0074d8e',
      'b182cac101b9399d155096004f53f447aa7b12a3426b08ec02710e807b4633f06c851c1919211f20d4c04f00b971ef8',
      '245a394ad1eca9b72fc00ae7be315dc757b3b080d4c158013e6632d3c40659cc6cf90ad1c232a6442d9d3f5db980133',
      '5c129645e44cf1102a159f748c4a3fc5e673d81d7e86568d9ab0f5d396a7ce46ba1049b6579afb7866b1e715475224b',
      '15e6be4e990f03ce4ea50b3b42df2eb5cb181d8f84965a3957add4fa95af01b2b665027efec01c7704b456be69c8b604',
    ]),
    // yDen
    h([
      '16112c4c3a9c98b252181140fad0eae9601a6de578980be6eec3232b5be72e7a07f3688ef60c206d01479253b03663c1',
      '1962d75c2381201e1a0cbd6c43c348b885c84ff731c4d59ca4a10356f453e01f78a4260763529e3532f6102c2e49a03d',
      '58df3306640da276faaae7d6e8eb15778c4855551ae7f310c35a5dd279cd2eca6757cd636f96f891e2538b53dbf67f2',
      '16b7d288798e5395f20d23bf89edb4d1d115c5dbddbcd30e123da489e726af41727364f2c28297ada8d26d98445f5416',
      'be0e079545f43e4b00cc912f8228ddcc6d19c9f0f69bbb0542eda0fc9dec916a20b15dc0fd2ededda39142311a5001d',
      '8d9e5297186db2d9fb266eaac783182b70152c65550d881c5ecd87b6f0f5a6449f38db9dfa9cce202c6477faaf9b7ac',
      '166007c08a99db2fc3ba8734ace9824b5eecfdfa8d0cf8ef5dd365bc400a0051d5fa9c01a58b1fb93d1a1399126a775c',
      '16a3ef08be3ea7ea03bcddfabba6ff6ee5a4375efa1f4fd7feb34fd206357132b920f5b00801dee460ee415a15812ed9',
      '1866c8ed336c61231a1be54fd1d74cc4f9fb0ce4c6af5920abc5750c4bf39b4852cfe2f7bb9248836b233d9d55535d4a',
      '167a55cda70a6e1cea820597d94a84903216f763e13d87bb5308592e7ea7d4fbc7385ea3d529b35e346ef48bb8913f55',
      '4d2f259eea405bd48f010a01ad2911d9c6dd039bb61a6290e591b36e636a5c871a5c29f4f83060400f8b49cba8f6aa8',
      'accbb67481d033ff5852c1e48c50c477f94ff8aefce42d28c0f9a88cea7913516f968986f7ebbea9684b529e2561092',
      'ad6b9514c767fe3c3613144b45f1496543346d98adf02267d5ceef9a00d9b8693000763e3b90ac11e99b138573345cc',
      '2660400eb2e4f3b628bdd0d53cd76f2bf565b94e72927c1cb748df27942480e420517bd8714cc80d1fadc1326ed06f7',
      'e0fa1d816ddc03e6b24255e0d7819c171c40f65e273b853324efcd6356caa205ca2f570f13497804415473a1d634b8f',
      '1',
    ]),
  ];
}

/// Evaluates the 11-isogeny map, taking (x, y) on E' to (x, y) on E.
({BigInt x, BigInt y}) _isogenyMapG1(BigInt x, BigInt y) {
  BigInt horner(List<BigInt> coeffs) {
    // Coefficients are stored constant-first; evaluate high-to-low.
    var acc = coeffs.last;
    for (var i = coeffs.length - 2; i >= 0; i--) {
      acc = _fpAdd(_fpMul(acc, x), coeffs[i]);
    }
    return acc;
  }

  final xn = horner(_isoG1Coeffs[0]);
  final xd = horner(_isoG1Coeffs[1]);
  final yn = horner(_isoG1Coeffs[2]);
  final yd = horner(_isoG1Coeffs[3]);
  final nx = _fpMul(xn, _fpInv(xd));
  final ny = _fpMul(y, _fpMul(yn, _fpInv(yd)));
  return (x: nx, y: ny);
}

/// Clears the G1 cofactor: [x]P + P.
G1Point _clearCofactorG1(G1Point p) => p.multiply(_blsX).add(p);

/// Hashes `msg` to a G1 point using RFC 9380
/// BLS12381G1_XMD:SHA-256_SSWU_RO_ with the supplied domain separation tag.
G1Point hashToCurveG1(Uint8List msg, Uint8List dst) {
  final u = _hashToFieldFp(msg, dst, 2);
  final m0 = _mapToCurveG1(u[0]);
  final m1 = _mapToCurveG1(u[1]);
  final p0 = G1Point.fromAffine(m0.x, m0.y);
  final p1 = G1Point.fromAffine(m1.x, m1.y);
  return _clearCofactorG1(p0.add(p1));
}

// ---------------------------------------------------------------------------
// Small byte utilities
// ---------------------------------------------------------------------------

Uint8List _utf8(String s) => Uint8List.fromList(s.codeUnits);

Uint8List _concat(List<Uint8List> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}
