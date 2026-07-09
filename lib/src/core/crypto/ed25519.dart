import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import '../hex.dart';
import 'hd_key.dart';
import 'private_key.dart';
import 'public_key.dart';
import 'signature.dart';
import 'utils.dart';

/// L is the value that greater than or equal to will produce a non-canonical
/// signature, and must be rejected.
const List<int> _l = [
  0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, //
  0xde, 0xf9, 0xde, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
];

/// Checks if an ED25519 signature is non-canonical.
/// This function helps determine the validity of a signature by verifying its
/// canonical form.
///
/// Comes from Aptos Core
/// https://github.com/aptos-labs/aptos-core/blob/main/crates/aptos-crypto/src/ed25519/ed25519_sigs.rs#L47-L85
bool isCanonicalEd25519Signature(Signature signature) {
  final s = signature.toUint8Array().sublist(32);
  for (var i = _l.length - 1; i >= 0; i -= 1) {
    if (s[i] < _l[i]) {
      return true;
    }
    if (s[i] > _l[i]) {
      return false;
    }
  }
  // At this stage S == L which implies a non-canonical S.
  return false;
}

/// Represents the public key of an Ed25519 key pair.
///
/// Since [AIP-55](https://github.com/aptos-foundation/AIPs/pull/263) Aptos
/// supports `Legacy` and `Unified` authentication keys.
///
/// Ed25519 scheme is represented in the SDK as `Legacy authentication key`
/// and also as `AnyPublicKey` that represents any `Unified authentication
/// key`.
class Ed25519PublicKey extends AccountPublicKey {
  /// Length of an Ed25519 public key.
  static const int length = 32;

  /// Bytes of the public key.
  final Hex _key;

  /// Creates an instance of the Ed25519PublicKey class from a hex input.
  /// This constructor validates the length of the key to ensure it meets the
  /// required specifications.
  ///
  /// Throws an [ArgumentError] if the key length is not equal to
  /// [Ed25519PublicKey.length].
  Ed25519PublicKey(HexInput hexInput) : _key = Hex.fromHexInput(hexInput) {
    if (_key.toUint8List().length != Ed25519PublicKey.length) {
      throw ArgumentError(
        'PublicKey length should be ${Ed25519PublicKey.length}',
      );
    }
  }

  // region AccountPublicKey

  /// Verifies a signature against the exact bytes of [message]. This is the
  /// unambiguous form — the input is interpreted as raw bytes regardless of
  /// what they encode. Pair with [Ed25519PrivateKey.signBytes].
  ///
  /// Performs an Ed25519 malleability check (rejects non-canonical S values)
  /// before delegating to the underlying curve verifier.
  bool verifyBytes({required Uint8List message, required Signature signature}) {
    if (!isCanonicalEd25519Signature(signature)) {
      return false;
    }
    try {
      return ed.verify(
        ed.PublicKey(_key.toUint8List()),
        message,
        signature.toUint8Array(),
      );
    } catch (_) {
      return false;
    }
  }

  /// Verifies a signature against the UTF-8 encoding of [message]. The input
  /// is always treated as text — there is no hex/text heuristic. Pair with
  /// [Ed25519PrivateKey.signText].
  bool verifyText({required String message, required Signature signature}) {
    return verifyBytes(
      message: Uint8List.fromList(utf8.encode(message)),
      signature: signature,
    );
  }

  /// Verifies a signed message using the public key.
  ///
  /// NOTE (deprecated): the polymorphic `message: HexInput` input is
  /// ambiguous — a bare even-length string of hex characters (e.g.,
  /// `"cafe"`) is interpreted as the 2 bytes `[0xCA, 0xFE]`, not as 4 UTF-8
  /// text bytes. Use [verifyBytes] for byte input or [verifyText] for string
  /// input; both are unambiguous. See [convertSigningMessage] for the full
  /// legacy rule.
  @override
  bool verifySignature({required HexInput message, required Signature signature}) {
    final messageToVerify = convertSigningMessage(message);
    final messageBytes = Hex.fromHexInput(messageToVerify).toUint8List();
    return verifyBytes(message: messageBytes, signature: signature);
  }

  /// Generates an authentication key from the public key using the Ed25519
  /// scheme.
  @override
  AuthenticationKey authKey() {
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.ed25519,
      input: toUint8Array(),
    );
  }

  /// Convert the internal data representation to a [Uint8List].
  @override
  Uint8List toUint8Array() => _key.toUint8List();

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(_key.toUint8List());
  }

  static Ed25519PublicKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Ed25519PublicKey(bytes);
  }

  // endregion
}

/// Represents the private key of an Ed25519 key pair.
class Ed25519PrivateKey extends Serializable implements PrivateKey {
  /// Length of an Ed25519 private key.
  static const int length = 32;

  /// The Ed25519 key seed to use for BIP-32 compatibility.
  /// See more https://github.com/satoshilabs/slips/blob/master/slip-0010.md
  static const String slip0010Seed = 'ed25519 seed';

  /// The Ed25519 signing key.
  final Hex _signingKey;

  /// Whether the key has been cleared from memory.
  bool _cleared = false;

  // region Constructors

  /// Create a new PrivateKey instance from a [Uint8List] or [String].
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// [hexInput] is a HexInput (string or bytes).
  /// If [strict] is true, the private key must be AIP-80 compliant.
  Ed25519PrivateKey(HexInput hexInput, [bool? strict])
      : _signingKey =
            PrivateKey.parseHexInput(hexInput, PrivateKeyVariants.ed25519, strict) {
    if (_signingKey.toUint8List().length != Ed25519PrivateKey.length) {
      throw ArgumentError(
        'PrivateKey length should be ${Ed25519PrivateKey.length}',
      );
    }
  }

  /// Generate a new random private key.
  static Ed25519PrivateKey generate() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(Ed25519PrivateKey.length, (_) => random.nextInt(256)),
    );
    return Ed25519PrivateKey(bytes, false);
  }

  /// Derives a private key from a mnemonic seed phrase using a specified
  /// BIP44 path. To derive multiple keys from the same phrase, change the
  /// path.
  ///
  /// IMPORTANT: Ed25519 supports hardened derivation only, as it lacks a key
  /// homomorphism, making non-hardened derivation impossible.
  ///
  /// Throws an [ArgumentError] if the provided path is not a valid hardened
  /// path.
  static Ed25519PrivateKey fromDerivationPath(String path, String mnemonics) {
    if (!isValidHardenedPath(path)) {
      throw ArgumentError('Invalid derivation path $path');
    }
    return Ed25519PrivateKey.fromDerivationPathInner(
      path,
      mnemonicToSeed(mnemonics),
    );
  }

  /// Derives a child private key from a given BIP44 path and seed.
  ///
  /// NOTE: exposed for testing so the SLIP-0010 key derivation can be
  /// verified against the official test vectors; not part of the public API.
  static Ed25519PrivateKey fromDerivationPathInner(
    String path,
    Uint8List seed, {
    int offset = hardenedOffset,
  }) {
    final derived = deriveKey(Ed25519PrivateKey.slip0010Seed, seed);

    final segments = splitPath(path).map(int.parse);

    // Derive the child key based on the path.
    var parentKeys = derived;
    for (final segment in segments) {
      parentKeys = ckdPriv(parentKeys, segment + offset);
    }
    return Ed25519PrivateKey(parentKeys.key, false);
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
  /// residue, and in GC-relocated heap copies. Avoid calling
  /// `toString()`/`toHexString()` on private keys in long-lived processes —
  /// the byte form is what gets cleared.
  void clear() {
    if (!_cleared) {
      final keyBytes = _signingKey.toUint8List();
      final random = Random.secure();
      // Multiple overwrite passes for better security.
      // Pass 1: Random data.
      for (var i = 0; i < keyBytes.length; i += 1) {
        keyBytes[i] = random.nextInt(256);
      }
      // Pass 2: Ones pattern (0xFF).
      keyBytes.fillRange(0, keyBytes.length, 0xff);
      // Pass 3: Random data again.
      for (var i = 0; i < keyBytes.length; i += 1) {
        keyBytes[i] = random.nextInt(256);
      }
      // Pass 4: Zeros pattern (final state).
      keyBytes.fillRange(0, keyBytes.length, 0);
      _cleared = true;
    }
  }

  /// Returns whether the private key has been cleared from memory.
  bool isCleared() => _cleared;

  /// Derive the Ed25519PublicKey for this private key.
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  @override
  Ed25519PublicKey publicKey() {
    _ensureNotCleared();
    final bytes =
        ed.public(ed.newKeyFromSeed(_signingKey.toUint8List())).bytes;
    return Ed25519PublicKey(Uint8List.fromList(bytes));
  }

  /// Sign exactly the bytes of [message]. The input is interpreted as raw
  /// bytes regardless of what they encode. Pair with
  /// [Ed25519PublicKey.verifyBytes].
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  Ed25519Signature signBytes(Uint8List message) {
    _ensureNotCleared();
    final signatureBytes =
        ed.sign(ed.newKeyFromSeed(_signingKey.toUint8List()), message);
    return Ed25519Signature(signatureBytes);
  }

  /// Sign the UTF-8 encoding of [message]. The input is always treated as
  /// text — there is no hex/text heuristic. Pair with
  /// [Ed25519PublicKey.verifyText].
  Ed25519Signature signText(String message) {
    return signBytes(Uint8List.fromList(utf8.encode(message)));
  }

  /// Sign the given message with the private key.
  ///
  /// NOTE (deprecated): the polymorphic `message: HexInput` input is
  /// ambiguous — a bare even-length string of hex characters (e.g.,
  /// `"cafe"`) is signed as the 2 bytes `[0xCA, 0xFE]`, not as 4 UTF-8 text
  /// bytes. Use [signBytes] for byte input or [signText] for string input;
  /// both are unambiguous. See [convertSigningMessage] for the full legacy
  /// rule.
  @override
  Ed25519Signature sign(HexInput message) {
    final messageToSign = convertSigningMessage(message);
    final messageBytes = Hex.fromHexInput(messageToSign).toUint8List();
    return signBytes(messageBytes);
  }

  /// Get the private key in bytes.
  ///
  /// Throws a [StateError] if the private key has been cleared from memory.
  @override
  Uint8List toUint8Array() {
    _ensureNotCleared();
    return _signingKey.toUint8List();
  }

  /// Get the private key as an AIP-80 compliant hex string.
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
    return _signingKey.toString();
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
      _signingKey.toString(),
      PrivateKeyVariants.ed25519,
    );
  }

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toUint8Array());
  }

  static Ed25519PrivateKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Ed25519PrivateKey(bytes, false);
  }

  // endregion
}

/// Represents a signature of a message signed using an Ed25519 private key.
class Ed25519Signature extends Signature {
  /// Length of an Ed25519 signature, which is 64 bytes.
  static const int length = 64;

  /// The signature bytes.
  final Hex _data;

  // region Constructors

  Ed25519Signature(HexInput hexInput) : _data = Hex.fromHexInput(hexInput) {
    if (_data.toUint8List().length != Ed25519Signature.length) {
      throw ArgumentError(
        'Signature length should be ${Ed25519Signature.length}',
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

  static Ed25519Signature deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return Ed25519Signature(bytes);
  }

  // endregion
}
