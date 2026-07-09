import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart'
    show PrivateKeyParameter, PublicKeyParameter;
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import '../hex.dart';
import 'private_key.dart';
import 'public_key.dart';
import 'signature.dart';
import 'utils.dart';

final ECDomainParameters _domain = ECCurve_secp256r1();

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

/// Represents a Secp256r1 ECDSA public key.
class Secp256r1PublicKey extends PublicKey {
  /// Secp256r1 ecdsa public keys contain a prefix indicating compression and
  /// two 32-byte coordinates.
  static const int length = 65;

  /// If it's compressed, it is only 33 bytes.
  static const int compressedLength = 33;

  /// Hex value of the public key.
  final Hex _key;

  /// Identifier to distinguish from Secp256k1PublicKey.
  final String keyType = 'secp256r1';

  /// Create a new PublicKey instance from a [HexInput], which can be a string
  /// or bytes. Compressed (33-byte) keys are expanded to the uncompressed
  /// (65-byte) form.
  ///
  /// Throws an [ArgumentError] if the length of the public key data is not
  /// equal to [Secp256r1PublicKey.length] or
  /// [Secp256r1PublicKey.compressedLength].
  factory Secp256r1PublicKey(HexInput hexInput) {
    final hex = Hex.fromHexInput(hexInput);
    final keyLength = hex.toUint8List().length;
    if (keyLength != Secp256r1PublicKey.length &&
        keyLength != Secp256r1PublicKey.compressedLength) {
      throw ArgumentError(
        'PublicKey length should be ${Secp256r1PublicKey.length} or '
        '${Secp256r1PublicKey.compressedLength}, received $keyLength',
      );
    }

    if (keyLength == Secp256r1PublicKey.compressedLength) {
      final point = _domain.curve.decodePoint(hex.toUint8List())!;
      return Secp256r1PublicKey._(Hex(point.getEncoded(false)));
    }
    return Secp256r1PublicKey._(hex);
  }

  Secp256r1PublicKey._(this._key);

  /// Get the data as a [Uint8List] representation.
  @override
  Uint8List toUint8Array() => _key.toUint8List();

  /// Get the public key as a hex string with the 0x prefix.
  @override
  String toString() => _key.toString();

  /// Verifies a signature against the exact bytes of [message]. This is the
  /// unambiguous form — the input is interpreted as raw bytes regardless of
  /// what they encode. Pair with [Secp256r1PrivateKey.signBytes].
  ///
  /// The message is SHA3-256 hashed before verification (matching the
  /// Aptos-side Secp256r1 signing convention), and the signature is required
  /// to be in canonical low-S form for malleability resistance.
  bool verifyBytes({required Uint8List message, required Signature signature}) {
    final sha3Message = _sha3256(message);
    final signatureBytes = signature.toUint8Array();
    if (signatureBytes.length != Secp256r1Signature.length) {
      return false;
    }
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
    return verifier.verifySignature(sha3Message, ECSignature(r, s));
  }

  /// Verifies a signature against the UTF-8 encoding of [message]. The input
  /// is always treated as text — there is no hex/text heuristic. Pair with
  /// [Secp256r1PrivateKey.signText].
  bool verifyText({required String message, required Signature signature}) {
    return verifyBytes(
      message: Uint8List.fromList(utf8.encode(message)),
      signature: signature,
    );
  }

  /// Verifies a Secp256r1 signature against the public key.
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
    final messageToVerify = convertSigningMessage(message);
    final msgBytes = Hex.fromHexInput(messageToVerify).toUint8List();
    return verifyBytes(message: msgBytes, signature: signature);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(_key.toUint8List());
  }

  static Secp256r1PublicKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Secp256r1PublicKey(bytes);
  }

  /// Loads a Secp256r1PublicKey from the provided deserializer.
  static Secp256r1PublicKey load(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Secp256r1PublicKey(bytes);
  }

  /// Generates an authentication key from the public key using the Secp256r1
  /// scheme (as a unified `SingleKey` public key).
  AuthenticationKey authKey() {
    final serializer = Serializer();
    serializer.serializeU32AsUleb128(AnyPublicKeyVariant.secp256r1.value);
    serializer.serializeFixedBytes(bcsToBytes());
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.singleKey,
      input: serializer.toUint8List(),
    );
  }
}

/// Represents a Secp256r1 ECDSA private key, providing functionality to
/// create, sign messages, derive public keys, and serialize/deserialize the
/// key.
class Secp256r1PrivateKey extends Serializable implements PrivateKey {
  /// Length of Secp256r1 ecdsa private key.
  static const int length = 32;

  /// The private key bytes.
  final Hex _key;

  /// Whether the key has been cleared from memory.
  bool _cleared = false;

  /// Create a new PrivateKey instance from a [Uint8List] or [String].
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// [hexInput] is a HexInput (string or bytes).
  /// If [strict] is true, the private key must be AIP-80 compliant.
  Secp256r1PrivateKey(HexInput hexInput, [bool? strict])
      : _key = PrivateKey.parseHexInput(
            hexInput, PrivateKeyVariants.secp256r1, strict) {
    final keyLength = _key.toUint8List().length;
    if (keyLength != Secp256r1PrivateKey.length) {
      throw ArgumentError(
        'PrivateKey length should be ${Secp256r1PrivateKey.length}, '
        'received $keyLength',
      );
    }
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
    return PrivateKey.formatPrivateKey(
      _key.toString(),
      PrivateKeyVariants.secp256r1,
    );
  }

  /// Get the private key as a hex string with the 0x prefix.
  ///
  /// SECURITY: Same caveat as [toString] — the returned string cannot be
  /// zeroed by `clear()`.
  String toHexString() {
    _ensureNotCleared();
    return _key.toString();
  }

  /// Sign exactly the bytes of [message]. The input is interpreted as raw
  /// bytes regardless of what they encode. Pair with
  /// [Secp256r1PublicKey.verifyBytes].
  ///
  /// The message is SHA3-256 hashed before signing (matching the Aptos-side
  /// Secp256r1 signing convention), and the produced signature is in
  /// canonical low-S form. Signing is deterministic per RFC 6979
  /// (HMAC-SHA256).
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  Secp256r1Signature signBytes(Uint8List message) {
    _ensureNotCleared();
    final sha3Message = _sha3256(message);
    final d = _bytesToBigInt(_key.toUint8List());
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter(ECPrivateKey(d, _domain)));
    final signature = signer.generateSignature(sha3Message) as ECSignature;
    var s = signature.s;
    // Low-S normalization for signature malleability resistance.
    if (s > (_domain.n >> 1)) {
      s = _domain.n - s;
    }
    final signatureBytes = Uint8List(64);
    signatureBytes.setRange(0, 32, _bigIntTo32Bytes(signature.r));
    signatureBytes.setRange(32, 64, _bigIntTo32Bytes(s));
    return Secp256r1Signature(signatureBytes);
  }

  /// Sign the UTF-8 encoding of [message]. The input is always treated as
  /// text — there is no hex/text heuristic. Pair with
  /// [Secp256r1PublicKey.verifyText].
  Secp256r1Signature signText(String message) {
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
  Secp256r1Signature sign(HexInput message) {
    final messageToSign = convertSigningMessage(message);
    final msgBytes = Hex.fromHexInput(messageToSign).toUint8List();
    return signBytes(msgBytes);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toUint8Array());
  }

  static Secp256r1PrivateKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Secp256r1PrivateKey(bytes);
  }

  /// Generate a new random private key.
  static Secp256r1PrivateKey generate() {
    final random = Random.secure();
    while (true) {
      final bytes = Uint8List.fromList(
        List<int>.generate(
            Secp256r1PrivateKey.length, (_) => random.nextInt(256)),
      );
      final d = _bytesToBigInt(bytes);
      if (d > BigInt.zero && d < _domain.n) {
        return Secp256r1PrivateKey(bytes);
      }
    }
  }

  /// Derive the [Secp256r1PublicKey] from this private key.
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  @override
  Secp256r1PublicKey publicKey() {
    _ensureNotCleared();
    final d = _bytesToBigInt(_key.toUint8List());
    final point = (_domain.G * d)!;
    return Secp256r1PublicKey(point.getEncoded(false));
  }

  /// Throws if the key has already been cleared.
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
  /// zeroization guarantee. See [Ed25519PrivateKey.clear] for the full
  /// enumeration of limits (immutable string copies, `BigInt` intermediates,
  /// register/stack residue, GC-relocated copies).
  void clear() {
    if (!_cleared) {
      final keyBytes = _key.toUint8List();
      final random = Random.secure();
      // Multiple overwrite passes for consistency with the other private-key
      // classes.
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

  /// Returns whether `clear()` has been called.
  bool isCleared() => _cleared;
}

/// A signature produced by a WebAuthn authenticator (e.g. a passkey), which
/// wraps a Secp256r1 signature together with the authenticator data and
/// client data JSON.
class WebAuthnSignature extends Signature {
  final Hex signature;

  final Hex authenticatorData;

  final Hex clientDataJSON;

  WebAuthnSignature({
    required HexInput signature,
    required HexInput authenticatorData,
    required HexInput clientDataJSON,
  })  : signature = Hex.fromHexInput(signature),
        authenticatorData = Hex.fromHexInput(authenticatorData),
        clientDataJSON = Hex.fromHexInput(clientDataJSON);

  @override
  Uint8List toUint8Array() => signature.toUint8List();

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    serializer.serializeBytes(signature.toUint8List());
    serializer.serializeBytes(authenticatorData.toUint8List());
    serializer.serializeBytes(clientDataJSON.toUint8List());
  }

  static WebAuthnSignature deserialize(Deserializer deserializer) {
    final id = deserializer.deserializeUleb128AsU32();
    if (id != 0) {
      throw ArgumentError('Invalid id for WebAuthnSignature: $id');
    }
    final signature = deserializer.deserializeBytes();
    final authenticatorData = deserializer.deserializeBytes();
    final clientDataJSON = deserializer.deserializeBytes();
    return WebAuthnSignature(
      signature: signature,
      authenticatorData: authenticatorData,
      clientDataJSON: clientDataJSON,
    );
  }
}

/// Represents a signature of a message signed using a Secp256r1 ECDSA private
/// key.
class Secp256r1Signature extends Signature {
  /// Secp256r1 ecdsa signatures are 256-bit.
  static const int length = 64;

  /// The signature bytes.
  final Hex _data;

  /// Create a new Signature instance from a [Uint8List] or [String].
  /// The signature is validated (r and s must be in `[1, n-1]`) and
  /// re-encoded to the canonical 64-byte compact form.
  factory Secp256r1Signature(HexInput hexInput) {
    final hex = Hex.fromHexInput(hexInput);
    final signatureLength = hex.toUint8List().length;
    if (signatureLength != Secp256r1Signature.length) {
      throw ArgumentError(
        'Signature length should be ${Secp256r1Signature.length}, '
        'received $signatureLength',
      );
    }
    final bytes = hex.toUint8List();
    final r = _bytesToBigInt(Uint8List.sublistView(bytes, 0, 32));
    final s = _bytesToBigInt(Uint8List.sublistView(bytes, 32));
    if (r <= BigInt.zero ||
        r >= _domain.n ||
        s <= BigInt.zero ||
        s >= _domain.n) {
      throw ArgumentError('Invalid Secp256r1 signature: r/s out of range');
    }
    final normalized = Uint8List(64);
    normalized.setRange(0, 32, _bigIntTo32Bytes(r));
    normalized.setRange(32, 64, _bigIntTo32Bytes(s));
    return Secp256r1Signature._(Hex(normalized));
  }

  Secp256r1Signature._(this._data);

  /// Get the signature in bytes.
  @override
  Uint8List toUint8Array() => _data.toUint8List();

  /// Get the signature as a hex string with the 0x prefix.
  @override
  String toString() => _data.toString();

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(_data.toUint8List());
  }

  static Secp256r1Signature deserialize(Deserializer deserializer) {
    final hex = deserializer.deserializeBytes();
    return Secp256r1Signature(hex);
  }
}
