import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart'
    show PrivateKeyParameter, PublicKeyParameter;
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../hex.dart';
import 'hd_key.dart';
import 'private_key.dart';
import 'public_key.dart';
import 'signature.dart';
import 'utils.dart';

final ECDomainParameters _domain = ECCurve_secp256k1();

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntTo32Bytes(BigInt value) {
  final bytes = Uint8List(32);
  var v = value;
  for (var i = 31; i >= 0; i -= 1) {
    bytes[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return bytes;
}

Uint8List _sha3256(Uint8List message) => SHA3Digest(256).process(message);

/// Represents a Secp256k1 ECDSA public key.
class Secp256k1PublicKey extends PublicKey {
  /// Secp256k1 ecdsa public keys contain a prefix indicating compression and
  /// two 32-byte coordinates.
  static const int length = 65;

  /// If it's compressed, it is only 33 bytes.
  static const int compressedLength = 33;

  /// Hex value of the public key.
  final Hex _key;

  /// Identifier to distinguish from Secp256r1PublicKey.
  final String keyType = 'secp256k1';

  /// Create a new PublicKey instance from a [HexInput], which can be a string
  /// or bytes. Compressed (33-byte) keys are expanded to the uncompressed
  /// (65-byte) form.
  ///
  /// Throws an [ArgumentError] if the length of the public key data is not
  /// equal to [Secp256k1PublicKey.length] or
  /// [Secp256k1PublicKey.compressedLength].
  factory Secp256k1PublicKey(HexInput hexInput) {
    final hex = Hex.fromHexInput(hexInput);
    final keyLength = hex.toUint8List().length;
    if (keyLength == Secp256k1PublicKey.length) {
      return Secp256k1PublicKey._(hex);
    } else if (keyLength == Secp256k1PublicKey.compressedLength) {
      final point = _domain.curve.decodePoint(hex.toUint8List())!;
      return Secp256k1PublicKey._(Hex(point.getEncoded(false)));
    } else {
      throw ArgumentError(
        'PublicKey length should be ${Secp256k1PublicKey.length} or '
        '${Secp256k1PublicKey.compressedLength}, received $keyLength',
      );
    }
  }

  Secp256k1PublicKey._(this._key);

  // region PublicKey

  /// Verifies a signature against the exact bytes of [message]. This is the
  /// unambiguous form — the input is interpreted as raw bytes regardless of
  /// what they encode. Pair with [Secp256k1PrivateKey.signBytes].
  ///
  /// The message is SHA3-256 hashed before verification (matching the
  /// Aptos-side Secp256k1 signing convention), and the signature is required
  /// to be in canonical low-S form for malleability resistance.
  bool verifyBytes({
    required Uint8List message,
    required Secp256k1Signature signature,
  }) {
    final messageSha3Bytes = _sha3256(message);
    final signatureBytes = signature.toUint8Array();
    final r = _bytesToBigInt(Uint8List.sublistView(signatureBytes, 0, 32));
    final s = _bytesToBigInt(Uint8List.sublistView(signatureBytes, 32));
    // Enforce canonical low-S form for malleability resistance.
    if (s > (_domain.n >> 1)) {
      return false;
    }
    final ECPoint point;
    try {
      point = _domain.curve.decodePoint(_key.toUint8List())!;
    } catch (_) {
      return false;
    }
    final verifier = ECDSASigner()
      ..init(false, PublicKeyParameter(ECPublicKey(point, _domain)));
    return verifier.verifySignature(messageSha3Bytes, ECSignature(r, s));
  }

  /// Verifies a signature against the UTF-8 encoding of [message]. The input
  /// is always treated as text — there is no hex/text heuristic. Pair with
  /// [Secp256k1PrivateKey.signText].
  bool verifyText({
    required String message,
    required Secp256k1Signature signature,
  }) {
    return verifyBytes(
      message: Uint8List.fromList(utf8.encode(message)),
      signature: signature,
    );
  }

  /// Verifies a Secp256k1 signature against the public key.
  ///
  /// NOTE (deprecated): the polymorphic `message: HexInput` input is
  /// ambiguous — a bare even-length string of hex characters (e.g.,
  /// `"cafe"`) is verified against the 2 bytes `[0xCA, 0xFE]`, not 4 UTF-8
  /// text bytes. Use [verifyBytes] for byte input or [verifyText] for string
  /// input; both are unambiguous. See [convertSigningMessage] for the full
  /// legacy rule.
  @override
  bool verifySignature(
      {required HexInput message, required Signature signature}) {
    if (signature is! Secp256k1Signature) return false;
    final messageToVerify = convertSigningMessage(message);
    final messageBytes = Hex.fromHexInput(messageToVerify).toUint8List();
    return verifyBytes(message: messageBytes, signature: signature);
  }

  /// Get the data as a [Uint8List] representation.
  @override
  Uint8List toUint8Array() => _key.toUint8List();

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(_key.toUint8List());
  }

  static Secp256k1PublicKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Secp256k1PublicKey(bytes);
  }

  // endregion
}

/// Represents a Secp256k1 ECDSA private key, providing functionality to
/// create, sign messages, derive public keys, and serialize/deserialize the
/// key.
class Secp256k1PrivateKey extends Serializable implements PrivateKey {
  /// Length of Secp256k1 ecdsa private key.
  static const int length = 32;

  /// The private key bytes.
  final Hex _key;

  /// Whether the key has been cleared from memory.
  bool _cleared = false;

  // region Constructors

  /// Create a new PrivateKey instance from a [Uint8List] or [String].
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// [hexInput] is a HexInput (string or bytes).
  /// If [strict] is true, the private key must be AIP-80 compliant.
  Secp256k1PrivateKey(HexInput hexInput, [bool? strict])
      : _key = PrivateKey.parseHexInput(
            hexInput, PrivateKeyVariants.secp256k1, strict) {
    if (_key.toUint8List().length != Secp256k1PrivateKey.length) {
      throw ArgumentError(
        'PrivateKey length should be ${Secp256k1PrivateKey.length}',
      );
    }
  }

  /// Generate a new random private key.
  static Secp256k1PrivateKey generate() {
    final random = Random.secure();
    while (true) {
      final bytes = Uint8List.fromList(
        List<int>.generate(
            Secp256k1PrivateKey.length, (_) => random.nextInt(256)),
      );
      final d = _bytesToBigInt(bytes);
      if (d > BigInt.zero && d < _domain.n) {
        return Secp256k1PrivateKey(bytes, false);
      }
    }
  }

  /// Derives a private key from a mnemonic seed phrase using a specified
  /// BIP44 path.
  ///
  /// Throws an [ArgumentError] if the provided path is not a valid BIP44
  /// path.
  static Secp256k1PrivateKey fromDerivationPath(String path, String mnemonics) {
    if (!isValidBIP44Path(path)) {
      throw ArgumentError('Invalid derivation path $path');
    }
    return Secp256k1PrivateKey.fromDerivationPathInner(
      path,
      mnemonicToSeed(mnemonics),
    );
  }

  /// Derives a private key from a specified BIP44 path using a given seed.
  ///
  /// NOTE: exposed for testing so the BIP32 key derivation can be verified
  /// against the official test vectors; not part of the public API.
  static Secp256k1PrivateKey fromDerivationPathInner(
      String path, Uint8List seed) {
    final privateKey = bip32DerivePrivateKey(seed, path);
    return Secp256k1PrivateKey(privateKey, false);
  }

  // endregion

  // region PrivateKey

  /// Checks if the key has been cleared and throws an error if so.
  void _ensureNotCleared() {
    if (_cleared) {
      throw StateError(
        'Private key has been cleared from memory and can no longer be used',
      );
    }
  }

  /// Overwrites the underlying private-key byte buffer with random bytes and
  /// then zeros. After calling this method the key can no longer sign or
  /// derive a public key.
  ///
  /// SECURITY: This is a best-effort window-narrowing tool, NOT a true
  /// zeroization guarantee. Copies of the key material may survive in
  /// immutable strings previously produced by `toString()`/`toHexString()`,
  /// in `BigInt` intermediates inside the crypto library, in registers/stack
  /// residue, and in GC-relocated heap copies.
  void clear() {
    if (!_cleared) {
      final keyBytes = _key.toUint8List();
      final random = Random.secure();
      for (var i = 0; i < keyBytes.length; i += 1) {
        keyBytes[i] = random.nextInt(256);
      }
      keyBytes.fillRange(0, keyBytes.length, 0xff);
      for (var i = 0; i < keyBytes.length; i += 1) {
        keyBytes[i] = random.nextInt(256);
      }
      keyBytes.fillRange(0, keyBytes.length, 0);
      _cleared = true;
    }
  }

  /// Returns whether the private key has been cleared from memory.
  bool isCleared() => _cleared;

  /// Sign exactly the bytes of [message]. The input is interpreted as raw
  /// bytes regardless of what they encode. Pair with
  /// [Secp256k1PublicKey.verifyBytes].
  ///
  /// The message is SHA3-256 hashed before signing (matching the Aptos-side
  /// Secp256k1 signing convention), and the produced signature is in
  /// canonical low-S form for malleability resistance. Signing is
  /// deterministic per RFC 6979 (HMAC-SHA256).
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  Secp256k1Signature signBytes(Uint8List message) {
    _ensureNotCleared();
    final messageHashBytes = _sha3256(message);
    final d = _bytesToBigInt(_key.toUint8List());
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter(ECPrivateKey(d, _domain)));
    final signature = signer.generateSignature(messageHashBytes) as ECSignature;
    var s = signature.s;
    // Low-S normalization (secp256k1 half-order).
    if (s > (_domain.n >> 1)) {
      s = _domain.n - s;
    }
    final signatureBytes = Uint8List(64);
    signatureBytes.setRange(0, 32, _bigIntTo32Bytes(signature.r));
    signatureBytes.setRange(32, 64, _bigIntTo32Bytes(s));
    return Secp256k1Signature(signatureBytes);
  }

  /// Sign the UTF-8 encoding of [message]. The input is always treated as
  /// text — there is no hex/text heuristic. Pair with
  /// [Secp256k1PublicKey.verifyText].
  Secp256k1Signature signText(String message) {
    return signBytes(Uint8List.fromList(utf8.encode(message)));
  }

  /// Sign the given message with the private key.
  ///
  /// NOTE (deprecated): the polymorphic `message: HexInput` input is
  /// ambiguous — a bare even-length string of hex characters (e.g.,
  /// `"cafe"`) is signed as the 2 bytes `[0xCA, 0xFE]`, not 4 UTF-8 text
  /// bytes. Use [signBytes] for byte input or [signText] for string input;
  /// both are unambiguous. See [convertSigningMessage] for the full legacy
  /// rule.
  @override
  Secp256k1Signature sign(HexInput message) {
    final messageToSign = convertSigningMessage(message);
    final messageBytes = Hex.fromHexInput(messageToSign).toUint8List();
    return signBytes(messageBytes);
  }

  /// Derive the [Secp256k1PublicKey] from this private key.
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  @override
  Secp256k1PublicKey publicKey() {
    _ensureNotCleared();
    final d = _bytesToBigInt(_key.toUint8List());
    final point = (_domain.G * d)!;
    return Secp256k1PublicKey(point.getEncoded(false));
  }

  /// Get the private key in bytes.
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  @override
  Uint8List toUint8Array() {
    _ensureNotCleared();
    return _key.toUint8List();
  }

  /// Get the private key as an AIP-80 compliant string representation.
  ///
  /// SECURITY: This produces an immutable string containing the key material
  /// that cannot be zeroed by `clear()`. Prefer [toUint8Array] where memory
  /// hygiene matters.
  @override
  String toString() {
    _ensureNotCleared();
    return toAIP80String();
  }

  /// Get the private key as a hex string with the 0x prefix.
  ///
  /// SECURITY: Same caveat as [toString] — the returned string cannot be
  /// zeroed by `clear()`.
  String toHexString() {
    _ensureNotCleared();
    return _key.toString();
  }

  /// Get the private key as an AIP-80 compliant hex string.
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// SECURITY: Same caveat as [toString] — produces an immutable string
  /// containing the key material; cannot be zeroed by `clear()`.
  String toAIP80String() {
    _ensureNotCleared();
    return PrivateKey.formatPrivateKey(
      _key.toString(),
      PrivateKeyVariants.secp256k1,
    );
  }

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toUint8Array());
  }

  static Secp256k1PrivateKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Secp256k1PrivateKey(bytes, false);
  }

  // endregion
}

/// Represents a signature of a message signed using a Secp256k1 ECDSA private
/// key.
class Secp256k1Signature extends Signature {
  /// Secp256k1 ecdsa signatures are 256-bit.
  static const int length = 64;

  /// The signature bytes.
  final Hex _data;

  // region Constructors

  /// Create a new Signature instance from a [Uint8List] or [String].
  Secp256k1Signature(HexInput hexInput) : _data = Hex.fromHexInput(hexInput) {
    if (_data.toUint8List().length != Secp256k1Signature.length) {
      throw ArgumentError(
        'Signature length should be ${Secp256k1Signature.length}, '
        'received ${_data.toUint8List().length}',
      );
    }
  }

  // endregion

  // region Signature

  @override
  Uint8List toUint8Array() => _data.toUint8List();

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(_data.toUint8List());
  }

  static Secp256k1Signature deserialize(Deserializer deserializer) {
    final hex = deserializer.deserializeBytes();
    return Secp256k1Signature(hex);
  }

  // endregion
}
