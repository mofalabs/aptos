import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show AEADParameters, KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show HkdfParameters;
import 'package:pointycastle/key_derivators/hkdf.dart';

/// Symmetric and hashing primitives for batch-encryption transaction payloads.
///
/// These mirror the primitives the Aptos batch-encryption scheme layers on top
/// of the BLS12-381 curve operations: AES-128-GCM for the payload body, an
/// HKDF-derived one-time pad over the BIBE key, and the RFC 9380
/// `expand_message_xmd` construction used to hash into the scalar field.

/// AES-128 key length and one-time-pad length, both 16 bytes.
const int symmetricKeyLength = 16;

/// AES-GCM nonce length in bytes.
const int gcmNonceLength = 12;

/// Domain separation tag used when hashing a G2 element to a G1 point.
final Uint8List hashG2ElementDst =
    Uint8List.fromList('APTOS_BATCH_ENCRYPTION_HASH_G2_ELEMENT'.codeUnits);

/// Domain separation tag for `Id::from_verifying_key_and_ad`.
final Uint8List idHashDst =
    Uint8List.fromList('APTOS_BATCH_ENCRYPTION_HASH_ID'.codeUnits);

/// HKDF salt used to derive the one-time pad from the BIBE pairing output.
final Uint8List _hkdfSalt =
    Uint8List.fromList('APTOS_BATCH_ENCRYPTION_OTP'.codeUnits);

/// The order of the BLS12-381 prime-order subgroup (scalar field `Fr`).
///
/// Held here so the symmetric layer can reduce hash outputs and sample random
/// scalars without depending on the curve implementation. The curve module
/// exposes the same value; a test asserts they agree.
final BigInt scalarFieldOrder = BigInt.parse(
  '73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001',
  radix: 16,
);

final Random _secureRandom = Random.secure();

/// Returns [n] cryptographically secure random bytes.
Uint8List randomBytes(int n) {
  final out = Uint8List(n);
  for (var i = 0; i < n; i += 1) {
    out[i] = _secureRandom.nextInt(256);
  }
  return out;
}

/// Interprets [bytes] as a little-endian unsigned integer.
BigInt leBytesToBigint(Uint8List bytes) {
  var result = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i -= 1) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

/// Encodes [value] as [numBytes] little-endian bytes (truncating high bytes).
Uint8List bigintToLEBytes(BigInt value, int numBytes) {
  final out = Uint8List(numBytes);
  var v = value;
  final mask = BigInt.from(0xff);
  for (var i = 0; i < numBytes; i += 1) {
    out[i] = (v & mask).toInt();
    v >>= 8;
  }
  return out;
}

/// Encodes an `Fr` scalar as 32 little-endian bytes.
Uint8List frToLEBytes(BigInt value) => bigintToLEBytes(value, 32);

/// Samples a uniform scalar in `Fr` following the reference scheme: reduce 128
/// random little-endian bytes modulo the subgroup order.
BigInt getRandomFr() => leBytesToBigint(randomBytes(128)) % scalarFieldOrder;

/// HKDF-SHA256 with the batch-encryption salt, returning 32 bytes.
Uint8List hmacKdf(Uint8List otpSource) {
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(otpSource, 32, _hkdfSalt, Uint8List(0)));
  return hkdf.process(Uint8List(0));
}

/// Derives the 16-byte one-time pad from the BIBE pairing output bytes.
Uint8List deriveOneTimePad(Uint8List otpSource) =>
    Uint8List.sublistView(hmacKdf(otpSource), 0, symmetricKeyLength);

/// XORs a 16-byte symmetric [key] with the one-time [pad].
Uint8List padKey(Uint8List key, Uint8List pad) {
  if (key.length != symmetricKeyLength || pad.length != symmetricKeyLength) {
    throw ArgumentError('key and pad must be $symmetricKeyLength bytes');
  }
  final out = Uint8List(symmetricKeyLength);
  for (var i = 0; i < symmetricKeyLength; i += 1) {
    out[i] = key[i] ^ pad[i];
  }
  return out;
}

/// Encrypts [plaintext] with AES-128-GCM under [key] and [nonce], returning the
/// ciphertext body (ciphertext followed by the 16-byte authentication tag).
Uint8List aesGcmEncrypt(Uint8List key, Uint8List nonce, Uint8List plaintext) {
  if (key.length != symmetricKeyLength) {
    throw ArgumentError('key must be $symmetricKeyLength bytes');
  }
  if (nonce.length != gcmNonceLength) {
    throw ArgumentError('nonce must be $gcmNonceLength bytes');
  }
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  return cipher.process(plaintext);
}

/// RFC 9380 `expand_message_xmd` using SHA-256.
///
/// Expands [msg] and the domain separation tag [dst] into [lenInBytes] bytes.
Uint8List expandMessageXmd(Uint8List msg, Uint8List dst, int lenInBytes) {
  const bInBytes = 32; // SHA-256 output size.
  const rInBytes = 64; // SHA-256 block size.

  // Oversized DSTs are themselves hashed, per the spec.
  var dstPrimeBase = dst;
  if (dst.length > 255) {
    final d = SHA256Digest();
    d.update(
      Uint8List.fromList('H2C-OVERSIZE-DST-'.codeUnits),
      0,
      'H2C-OVERSIZE-DST-'.length,
    );
    d.update(dst, 0, dst.length);
    final hashed = Uint8List(bInBytes);
    d.doFinal(hashed, 0);
    dstPrimeBase = hashed;
  }

  final ell = (lenInBytes + bInBytes - 1) ~/ bInBytes;
  if (ell > 255 || lenInBytes > 65535 || dstPrimeBase.length > 255) {
    throw ArgumentError('expand_message_xmd: invalid length');
  }

  final dstPrime = Uint8List.fromList([...dstPrimeBase, dstPrimeBase.length]);
  final zPad = Uint8List(rInBytes);
  final libStr = Uint8List.fromList([
    (lenInBytes >> 8) & 0xff,
    lenInBytes & 0xff,
  ]);

  Uint8List sha256(Uint8List data) {
    final d = SHA256Digest();
    final out = Uint8List(bInBytes);
    d.update(data, 0, data.length);
    d.doFinal(out, 0);
    return out;
  }

  final b0 = sha256(Uint8List.fromList([
    ...zPad,
    ...msg,
    ...libStr,
    0,
    ...dstPrime,
  ]));

  final blocks = <Uint8List>[];
  blocks.add(sha256(Uint8List.fromList([...b0, 1, ...dstPrime])));
  for (var i = 2; i <= ell; i += 1) {
    final xored = Uint8List(bInBytes);
    final prev = blocks[i - 2];
    for (var j = 0; j < bInBytes; j += 1) {
      xored[j] = b0[j] ^ prev[j];
    }
    blocks.add(sha256(Uint8List.fromList([...xored, i, ...dstPrime])));
  }

  final uniform = Uint8List(ell * bInBytes);
  for (var i = 0; i < ell; i += 1) {
    uniform.setRange(i * bInBytes, (i + 1) * bInBytes, blocks[i]);
  }
  return Uint8List.sublistView(uniform, 0, lenInBytes);
}

/// Hashes [input] to a scalar field element following the reference scheme:
/// `hash_to_field` with `m = 1` over `Fr` (`expand_message_xmd`, SHA-256,
/// `k = 128`), interpreting the 48-byte expansion as a big-endian integer.
BigInt hashToFr(Uint8List input, Uint8List dst) {
  // L = ceil((ceil(log2(p)) + k) / 8) = ceil((255 + 128) / 8) = 48.
  const l = 48;
  final uniform = expandMessageXmd(input, dst, l);
  var value = BigInt.zero;
  for (final byte in uniform) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value % scalarFieldOrder;
}
