/// Pure-Dart BN254 (alt_bn128) pairing engine.
///
/// Ported from noble-curves 2.2.0 (`bn254.ts`, `abstract/tower.ts`,
/// `abstract/bls.ts`) — the Ethereum (EIP-196/EIP-197) variant of the curve,
/// which is also the variant used by Aptos keyless (Groth16 over BN254).
///
/// Parameters:
/// - Seed (X): 4965661367192848881, ate loop size: 6X+2
/// - G1: y² = x³ + 3 over Fp, generator (1, 2), cofactor 1
/// - G2: y² = x³ + 3/(9+u) over Fp2 (D-type / divisive twist)
/// - Towers: Fp2 = Fp[u]/(u²+1), Fp6 = Fp2[v]/(v³-(9+u)), Fp12 = Fp6[w]/(w²-v)
///
/// Only public inputs are processed here (Groth16 verification); the
/// implementation is NOT constant-time.
library;

import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Curve constants
// ---------------------------------------------------------------------------

/// BN254 base field modulus p.
final BigInt bn254P = BigInt.parse(
  '30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47',
  radix: 16,
);

/// BN254 curve (subgroup) order r.
final BigInt bn254R = BigInt.parse(
  '30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001',
  radix: 16,
);

final BigInt _p = bn254P;

/// BN seed X.
final BigInt _bnX = BigInt.parse('4965661367192848881');

/// Bit length of the seed (noble's X_LEN), used by cyclotomicExp.
final int _bnXLen = _bnX.bitLength;

/// Optimal-ate Miller loop scalar: 6X + 2 (positive, xNegative = false).
final BigInt _ateLoopSize = _bnX * BigInt.from(6) + BigInt.two;

final BigInt _three = BigInt.from(3);

/// 1/2 mod p.
final BigInt _inv2 = BigInt.two.modInverse(_p);

/// G1 curve b = 3.
final BigInt _g1B = BigInt.from(3);

// ---------------------------------------------------------------------------
// Fp helpers (base prime field, plain BigInt)
// ---------------------------------------------------------------------------

BigInt _fpCreate(BigInt a) => a % _p;
BigInt _fpAdd(BigInt a, BigInt b) => (a + b) % _p;
BigInt _fpSub(BigInt a, BigInt b) => (a - b) % _p;
BigInt _fpMul(BigInt a, BigInt b) => (a * b) % _p;
BigInt _fpNeg(BigInt a) => (-a) % _p;
BigInt _fpInv(BigInt a) => a.modInverse(_p);

/// Legendre symbol of `a` mod p: 1 (QR), -1 (non-residue), 0 (zero).
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
    throw StateError('Cannot find square root');
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

  /// Creates an element, reducing coordinates mod p (mirrors noble Fp.create).
  factory Fp2(BigInt c0, BigInt c1) => Fp2._(_fpCreate(c0), _fpCreate(c1));

  /// Builds an element from `[c0, c1]` (noble's `Fp2.fromBigTuple`).
  factory Fp2.fromBigTuple(List<BigInt> tuple) {
    if (tuple.length != 2) throw ArgumentError('invalid Fp2.fromBigTuple');
    return Fp2(tuple[0], tuple[1]);
  }

  static final Fp2 zero = Fp2._(BigInt.zero, BigInt.zero);
  static final Fp2 one = Fp2._(BigInt.one, BigInt.zero);

  /// Sextic non-residue of the tower: 9 + u.
  static final Fp2 nonresidue = Fp2._(BigInt.from(9), BigInt.one);

  bool get isZero => c0 == BigInt.zero && c1 == BigInt.zero;

  bool eql(Fp2 other) => c0 == other.c0 && c1 == other.c1;

  Fp2 add(Fp2 o) => Fp2._(_fpAdd(c0, o.c0), _fpAdd(c1, o.c1));

  Fp2 sub(Fp2 o) => Fp2._(_fpSub(c0, o.c0), _fpSub(c1, o.c1));

  Fp2 neg() => Fp2._(_fpNeg(c0), _fpNeg(c1));

  /// (a+bu)(c+du) = (ac−bd) + (ad+bc)u — noble's Karatsuba-style formula.
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

  /// Multiplies by the tower non-residue 9 + u.
  Fp2 mulByNonresidue() => mul(nonresidue);

  /// Frobenius map x → x^(p^power). For u²=-1 the coefficient row is [1, -1],
  /// so odd powers are conjugation.
  Fp2 frobeniusMap(int power) => power % 2 == 0 ? this : conjugate();

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

  /// Square root for quadratic extensions, ported from noble tower.ts.
  /// Root is normalized exactly like noble (larger imaginary part loses).
  Fp2 sqrt() {
    if (c1 == BigInt.zero) {
      // Fp_NONRESIDUE = -1 for this tower.
      if (_fpLegendre(c0) == 1) return Fp2._(_fpSqrt(c0), BigInt.zero);
      return Fp2._(BigInt.zero, _fpSqrt(_fpNeg(c0)));
    }
    // a = sqrt(c0² - c1² * Fp_NONRESIDUE) = sqrt(c0² + c1²)
    final a = _fpSqrt(
        _fpSub(_fpMul(c0, c0), _fpMul(_fpMul(c1, c1), _fpNeg(BigInt.one))));
    var d = _fpMul(_fpAdd(a, c0), _inv2);
    if (_fpLegendre(d) == -1) d = _fpSub(d, a);
    final a0 = _fpSqrt(d);
    final candidate = Fp2._(a0, _fpMul(_fpMul(c1, _inv2), _fpInv(a0)));
    if (!candidate.sqr().eql(this)) throw StateError('Cannot find square root');
    final x1 = candidate;
    final x2 = x1.neg();
    if (x1.c1 > x2.c1 || (x1.c1 == x2.c1 && x1.c0 > x2.c0)) return x1;
    return x2;
  }

  /// Helper for cyclotomic squaring (noble's `Fp4Square`).
  /// Returns (b²·ξ + a², (a+b)² - a² - b²).
  static (Fp2, Fp2) fp4Square(Fp2 a, Fp2 b) {
    final a2 = a.sqr();
    final b2 = b.sqr();
    return (
      b2.mulByNonresidue().add(a2),
      a.add(b).sqr().sub(a2).sub(b2),
    );
  }

  @override
  String toString() => 'Fp2($c0, $c1)';
}

/// Big-endian bytes to a non-negative [BigInt].
BigInt _beToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Decodes one 32-byte Aptos-compressed field coordinate: reverses from
/// little-endian to big-endian, extracts the y-sign flag from the top bit,
/// clears the top two (flag) bits, and returns the coordinate value.
({BigInt coord, int yFlag}) _decodeCompressedCoord(List<int> data32) {
  final be = Uint8List.fromList(data32.reversed.toList());
  final yFlag = (be[0] & 0x80) >> 7;
  be[0] &= 0x3f; // clear the two flag bits
  return (coord: _beToBigInt(be), yFlag: yFlag);
}

/// G2 twist constant b = 3/(9+u), in noble's internal (c0, c1) order.
final Fp2 _fp2B = Fp2(
  BigInt.parse(
      '19485874751759354771024239261021720505790618469301721065564631296452457478373'),
  BigInt.parse(
      '266929791119991161246907387137283842545076965332900288569378510910307636690'),
);

Fp2 _fp2MulByB(Fp2 num) => num.mul(_fp2B);

// ---------------------------------------------------------------------------
// Frobenius coefficient tables (computed like noble's calcFrobeniusCoefficients)
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
    Fp2.nonresidue.pow((_p.pow(j) - BigInt.one) ~/ BigInt.from(6)),
]);

/// psi (untwist-Frobenius-twist) constants: ξ^((p-1)/3) and ξ^((p-1)/2).
final Fp2 _psiX = Fp2.nonresidue.pow((_p - BigInt.one) ~/ _three);
final Fp2 _psiY = Fp2.nonresidue.pow((_p - BigInt.one) ~/ BigInt.two);

/// Ψ(x, y) endomorphism on (untwisted) G2 coordinates.
(Fp2, Fp2) _psi(Fp2 x, Fp2 y) =>
    (x.frobeniusMap(1).mul(_psiX), y.frobeniusMap(1).mul(_psiY));

// ---------------------------------------------------------------------------
// Fp6 = Fp2[v] / (v³ - (9 + u))
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
      // t0 + ((c1 + c2) * (r1 + r2) - (t1 + t2)) * ξ
      t0.add(c1.add(c2).mul(o.c1.add(o.c2)).sub(t1.add(t2)).mulByNonresidue()),
      // (c0 + c1) * (r0 + r1) - (t0 + t1) + t2 * ξ
      c0.add(c1).mul(o.c0.add(o.c1)).sub(t0.add(t1)).add(t2.mulByNonresidue()),
      // t1 + (c0 + c2) * (r0 + r2) - (t0 + t2)
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
      // t1 + (c0 - c1 + c2)² + t3 - t0 - t4
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

  /// Multiplies every coefficient by one Fp2 element.
  Fp6 mulByFp2(Fp2 rhs) => Fp6(c0.mul(rhs), c1.mul(rhs), c2.mul(rhs));

  /// Sparse multiplication by (0, b1, 0).
  Fp6 mul1(Fp2 b1) => Fp6(c2.mul(b1).mulByNonresidue(), c0.mul(b1), c1.mul(b1));

  /// Sparse multiplication by (b0, b1, 0).
  Fp6 mul01(Fp2 b0, Fp2 b1) {
    final t0 = c0.mul(b0);
    final t1 = c1.mul(b1);
    return Fp6(
      // ((c1 + c2) * b1 - t1) * ξ + t0
      c1.add(c2).mul(b1).sub(t1).mulByNonresidue().add(t0),
      // (b0 + b1) * (c0 + c1) - t0 - t1
      b0.add(b1).mul(c0.add(c1)).sub(t0).sub(t1),
      // (c0 + c2) * b0 - t0 + t1
      c0.add(c2).mul(b0).sub(t0).add(t1),
    );
  }

  Fp6 frobeniusMap(int power) => Fp6(
        c0.frobeniusMap(power),
        c1.frobeniusMap(power).mul(_frob6C1[power % 6]),
        c2.frobeniusMap(power).mul(_frob6C2[power % 6]),
      );

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
      // (c1·v + c0) * (c0 + c1) - ab - ab·v
      c1
          .mulByNonresidue()
          .add(c0)
          .mul(c0.add(c1))
          .sub(ab)
          .sub(ab.mulByNonresidue()),
      ab.add(ab),
    );
  }

  Fp12 inv() {
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

  /// Sparse multiplication by (o0, 0, 0, o3, o4, 0), used by the divisive
  /// twist line function.
  Fp12 mul034(Fp2 o0, Fp2 o3, Fp2 o4) {
    final a = Fp6(c0.c0.mul(o0), c0.c1.mul(o0), c0.c2.mul(o0));
    final b = c1.mul01(o3, o4);
    final e = c0.add(c1).mul01(o0.add(o3), o4);
    return Fp12(
      b.mulByNonresidue().add(a),
      e.sub(a.add(b)),
    );
  }

  /// Cyclotomic squaring (Granger-Scott), for elements of the cyclotomic
  /// subgroup (i.e. pairing outputs after the easy part of the final exp).
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

  /// Cyclotomic exponentiation by `n` (consumes exactly X_LEN bits, like noble).
  Fp12 cyclotomicExp(BigInt n) {
    if (n < BigInt.zero || n >= (BigInt.one << _bnXLen)) {
      throw ArgumentError('cyclotomic exponent out of range');
    }
    var z = one;
    for (var i = _bnXLen - 1; i >= 0; i--) {
      z = z.cyclotomicSquare();
      if ((n >> i).isOdd) z = z.mul(this);
    }
    return z;
  }

  /// BN254 final exponentiation, exact port of noble's
  /// `Fp12finalExponentiate` (hard part uses the seed X).
  Fp12 finalExponentiate() {
    Fp12 powMinusX(Fp12 num) => num.cyclotomicExp(_bnX).conjugate();
    final r0 = conjugate().mul(inv());
    final r = r0.frobeniusMap(2).mul(r0);
    final y1 = powMinusX(r).cyclotomicSquare();
    final y2 = y1.cyclotomicSquare().mul(y1);
    final y4 = powMinusX(y2);
    final y6 = powMinusX(y4.cyclotomicSquare());
    final y8 = y6.conjugate().mul(y4).mul(y2.conjugate());
    final y9 = y8.mul(y1);
    return r.conjugate().mul(y9).frobeniusMap(3).mul(
          y8.frobeniusMap(2).mul(
                y9.frobeniusMap(1).mul(y8.mul(y4).mul(r)),
              ),
        );
  }

  @override
  String toString() => 'Fp12($c0, $c1)';
}

// ---------------------------------------------------------------------------
// G1: y² = x³ + 3 over Fp
// ---------------------------------------------------------------------------

/// Affine point on the BN254 G1 curve. `(0, 0)` encodes the point at infinity
/// (Ethereum convention, noble's `allowInfinityPoint`).
class G1Point {
  final BigInt x;
  final BigInt y;
  final bool isInfinity;

  const G1Point._(this.x, this.y, this.isInfinity);

  /// The point at infinity (zero).
  static final G1Point zero = G1Point._(BigInt.zero, BigInt.zero, true);

  /// G1 generator (1, 2).
  static final G1Point base = G1Point._(BigInt.one, BigInt.two, false);

  /// Lazy construction: coordinates are reduced mod p but NOT validated;
  /// call [assertValidity] on untrusted input. `(0, 0)` maps to [zero].
  factory G1Point.fromAffine(BigInt x, BigInt y) {
    final xm = _fpCreate(x);
    final ym = _fpCreate(y);
    if (xm == BigInt.zero && ym == BigInt.zero) return zero;
    return G1Point._(xm, ym, false);
  }

  /// Decodes a 32-byte Aptos-compressed G1 point (little-endian x with the
  /// y-sign flag in the top bit) into an affine point, recovering
  /// y = ±√(x³ + 3) and selecting the root indicated by the flag.
  factory G1Point.fromAptosCompressed(Uint8List data) {
    if (data.length != 32) {
      throw ArgumentError('G1 point needs to be 32 bytes');
    }
    final d = _decodeCompressedCoord(data);
    final x = d.coord;
    final y = _fpSqrt(_fpAdd(_fpMul(_fpMul(x, x), x), _g1B));
    final negY = _fpNeg(y);
    final yToUse = (y > negY) == (d.yFlag == 1) ? y : negY;
    return G1Point.fromAffine(x, yToUse);
  }

  bool get isZero => isInfinity;

  /// Affine coordinates; infinity is `(0, 0)`.
  (BigInt, BigInt) toAffine() =>
      isInfinity ? (BigInt.zero, BigInt.zero) : (x, y);

  G1Point negate() => isInfinity ? this : G1Point._(x, _fpNeg(y), false);

  /// Throws if the point is not on the curve (infinity is accepted).
  void assertValidity() {
    if (isInfinity) return;
    final left = _fpMul(y, y);
    final right = _fpAdd(_fpMul(_fpMul(x, x), x), _g1B);
    if (left != right) {
      throw StateError('bad G1 point: equation left != right');
    }
    // G1 cofactor is 1: on-curve implies in-subgroup.
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

  /// Scalar multiplication (double-and-add, not constant-time).
  G1Point multiply(BigInt k) {
    if (k < BigInt.zero) throw ArgumentError('negative scalar');
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

  @override
  String toString() => isInfinity ? 'G1(infinity)' : 'G1($x, $y)';
}

// ---------------------------------------------------------------------------
// G2: y² = x³ + 3/(9+u) over Fp2
// ---------------------------------------------------------------------------

/// Affine point on the BN254 G2 twist curve. `((0,0), (0,0))` encodes the
/// point at infinity.
class G2Point {
  final Fp2 x;
  final Fp2 y;
  final bool isInfinity;

  const G2Point._(this.x, this.y, this.isInfinity);

  /// The point at infinity (zero).
  static final G2Point zero = G2Point._(Fp2.zero, Fp2.zero, true);

  /// G2 generator, in noble's (c0, c1) coordinate order.
  static final G2Point base = G2Point._(
    Fp2.fromBigTuple([
      BigInt.parse(
          '10857046999023057135944570762232829481370756359578518086990519993285655852781'),
      BigInt.parse(
          '11559732032986387107991004021392285783925812861821192530917403151452391805634'),
    ]),
    Fp2.fromBigTuple([
      BigInt.parse(
          '8495653923123431417604973247489272438418190587263600148770280649306958101930'),
      BigInt.parse(
          '4082367875863433681332203403145435568316851327593401208105741076214120093531'),
    ]),
    false,
  );

  /// Lazy construction: NOT validated; call [assertValidity] on untrusted
  /// input. `((0,0), (0,0))` maps to [zero].
  factory G2Point.fromAffine(Fp2 x, Fp2 y) {
    if (x.isZero && y.isZero) return zero;
    return G2Point._(x, y, false);
  }

  /// Decodes a 64-byte Aptos-compressed G2 point: two little-endian Fp
  /// coordinates (real then imaginary) forming x, with the y-sign flag in the
  /// top bit of the imaginary part. Recovers y = ±√(x³ + b2) and selects the
  /// root indicated by the flag.
  factory G2Point.fromAptosCompressed(Uint8List data) {
    if (data.length != 64) {
      throw ArgumentError('G2 point needs to be 64 bytes');
    }
    final d0 = _decodeCompressedCoord(data.sublist(0, 32));
    final d1 = _decodeCompressedCoord(data.sublist(32, 64));
    final yFlag = d1.yFlag; // the flag lives in the imaginary part
    final x = Fp2(d0.coord, d1.coord);
    final y = x.pow(BigInt.from(3)).add(_fp2B).sqrt();
    final negY = y.neg();
    final isYGreater = y.c1 > negY.c1 || (y.c1 == negY.c1 && y.c0 > negY.c0);
    final yToUse = isYGreater == (yFlag == 1) ? y : negY;
    return G2Point.fromAffine(x, yToUse);
  }

  bool get isZero => isInfinity;

  (Fp2, Fp2) toAffine() => isInfinity ? (Fp2.zero, Fp2.zero) : (x, y);

  G2Point negate() => isInfinity ? this : G2Point._(x, y.neg(), false);

  /// Throws if the point is not on the twist curve or not in the r-order
  /// subgroup (equivalent to noble's `[6X²]P == Ψ(P)` check; both
  /// characterize the unique order-r subgroup of E'(Fp2)).
  void assertValidity() {
    if (isInfinity) return;
    final left = y.sqr();
    final right = x.sqr().mul(x).add(_fp2B);
    if (!left.eql(right)) {
      throw StateError('bad G2 point: equation left != right');
    }
    if (!multiplyUnsafe(bn254R).isZero) {
      throw StateError('bad G2 point: not in prime-order subgroup');
    }
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

  /// Scalar multiplication without subgroup checks (double-and-add).
  G2Point multiplyUnsafe(BigInt k) {
    if (k < BigInt.zero) throw ArgumentError('negative scalar');
    var acc = zero;
    for (var i = k.bitLength - 1; i >= 0; i--) {
      acc = acc.doublePoint();
      if ((k >> i).isOdd) acc = acc.add(this);
    }
    return acc;
  }

  /// Scalar multiplication.
  G2Point multiply(BigInt k) => multiplyUnsafe(k);

  bool equals(G2Point other) {
    if (isInfinity || other.isInfinity) return isInfinity == other.isInfinity;
    return x.eql(other.x) && y.eql(other.y);
  }

  @override
  String toString() => isInfinity ? 'G2(infinity)' : 'G2($x, $y)';
}

// ---------------------------------------------------------------------------
// Optimal-ate pairing: Miller loop (6X+2 NAF) + final exponentiation
// ---------------------------------------------------------------------------

/// Line-function coefficients (c0, c1, c2) in noble's precompute order.
typedef _Line = (Fp2, Fp2, Fp2);

/// Signed NAF decomposition of the ate loop scalar (noble's
/// `NAfDecomposition`); MSB-first, top marker bit dropped.
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

final List<int> _ateNaf = _nafDecomposition(_ateLoopSize);

/// Doubles R (projective) and records the line coefficients.
(Fp2, Fp2, Fp2) _pointDoubleLine(List<_Line> ell, Fp2 rx, Fp2 ry, Fp2 rz) {
  final t0 = ry.sqr();
  final t1 = rz.sqr();
  final t2 = _fp2MulByB(t1.mulScalar(_three));
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

/// Miller-loop precomputes for one G2 point, including the two extra
/// Ψ-Frobenius additions BN254 needs after the loop (noble's
/// `_postPrecompute`).
List<List<_Line>> _calcPairingPrecomputes(G2Point point) {
  final (qx, qy) = point.toAffine();
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
  // BN254 postPrecompute: add Ψ(Q), then Ψ²(Q) with negated y.
  final last = ell.last;
  final (q1x, q1y) = _psi(qx, qy);
  (rx, ry, rz) = _pointAddLine(last, rx, ry, rz, q1x, q1y);
  final (q2x, q2y) = _psi(q1x, q1y);
  _pointAddLine(last, rx, ry, rz, q2x, q2y.neg());
  return ell;
}

/// Product of Miller loops over precomputed lines (shared Fp12 squarings).
Fp12 _millerLoopBatch(List<(List<List<_Line>>, BigInt, BigInt)> pairs) {
  var f12 = Fp12.one;
  if (pairs.isNotEmpty) {
    final ellLen = pairs[0].$1.length;
    for (var i = 0; i < ellLen; i++) {
      f12 = f12.sqr();
      for (final (ell, px, py) in pairs) {
        for (final (c0, c1, c2) in ell[i]) {
          // Divisive-twist line function: mul034(f, c2*Py, c1*Px, c0).
          f12 = f12.mul034(c2.mulScalar(py), c1.mulScalar(px), c0);
        }
      }
    }
  }
  // xNegative == false for bn254: no conjugation.
  return f12;
}

/// Computes the product of pairings `∏ e(g1ᵢ, g2ᵢ)`.
///
/// Matches noble's `pairingBatch`: throws on infinity inputs and on invalid
/// points; an empty list returns [Fp12.one]. Set [withFinalExponent] to
/// `false` to get the raw Miller loop product.
Fp12 bn254PairingBatch(List<({G1Point g1, G2Point g2})> pairs,
    {bool withFinalExponent = true}) {
  final input = <(List<List<_Line>>, BigInt, BigInt)>[];
  for (final pair in pairs) {
    if (pair.g1.isZero || pair.g2.isZero) {
      throw StateError('pairing is not available for ZERO point');
    }
    pair.g1.assertValidity();
    pair.g2.assertValidity();
    final (px, py) = pair.g1.toAffine();
    input.add((_calcPairingPrecomputes(pair.g2), px, py));
  }
  final f12 = _millerLoopBatch(input);
  return withFinalExponent ? f12.finalExponentiate() : f12;
}

/// Computes the optimal-ate pairing `e(p, q)` on BN254.
///
/// Throws on infinity or invalid points. Set [withFinalExponent] to `false`
/// to get the raw Miller loop output.
Fp12 bn254Pairing(G1Point p, G2Point q, {bool withFinalExponent = true}) =>
    bn254PairingBatch([(g1: p, g2: q)], withFinalExponent: withFinalExponent);
