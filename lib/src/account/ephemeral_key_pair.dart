import 'dart:math';
import 'dart:typed_data';

import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/ephemeral.dart';
import '../core/crypto/poseidon.dart';
import '../core/crypto/private_key.dart';
import '../core/hex.dart';
import '../types/types.dart';
import '../utils/helpers.dart';

const int _twoWeeksInSeconds = 1209600;

/// Represents an ephemeral key pair used for signing transactions via the
/// Keyless authentication scheme. This key pair is temporary and includes an
/// expiration time. For more details on how this class is used, refer to the
/// documentation:
/// https://aptos.dev/guides/keyless-accounts/#1-present-the-user-with-a-sign-in-with-idp-button-on-the-ui
class EphemeralKeyPair extends Serializable {
  static const int blinderLength = 31;

  /// A byte array of length [blinderLength] used to obfuscate the public key
  /// from the IdP. Used in calculating the nonce passed to the IdP and as a
  /// secret witness in proof generation.
  final Uint8List blinder;

  /// A timestamp in seconds indicating when the ephemeral key pair is
  /// expired. After expiry, a new EphemeralKeyPair must be generated and a
  /// new JWT needs to be created.
  final int expiryDateSecs;

  /// The value passed to the IdP when the user authenticates. It consists of
  /// a hash of the ephemeral public key, expiry date, and blinder.
  ///
  /// SECURITY: This value is NOT secret. It is sent to the IdP in the OIDC
  /// redirect URL, embedded in the returned JWT, and packed into the proof
  /// inputs sent to the prover service. The [clear] lifecycle hook does NOT
  /// zero this field — it is an immutable string. This is acceptable given
  /// that the nonce was always public to begin with.
  final String nonce;

  /// A private key used to sign transactions. This private key is not tied
  /// to any account on the chain as it is ephemeral (not permanent) in
  /// nature.
  final PrivateKey _privateKey;

  /// A public key used to verify transactions. This public key is not tied
  /// to any account on the chain as it is ephemeral (not permanent) in
  /// nature.
  final EphemeralPublicKey _publicKey;

  /// Whether the ephemeral key pair has been cleared from memory.
  bool _cleared = false;

  /// Creates an ephemeral key pair from a [privateKey], deriving the public
  /// key and computing the nonce from the public key, expiry, and blinder.
  ///
  /// [expiryDateSecs] defaults to two weeks from now, floored to the nearest
  /// hour. [blinder] is generated randomly when not supplied.
  factory EphemeralKeyPair({
    required PrivateKey privateKey,
    int? expiryDateSecs,
    HexInput? blinder,
  }) {
    final publicKey = EphemeralPublicKey(privateKey.publicKey());
    // By default, we set the expiry date to be two weeks in the future
    // floored to the nearest hour.
    final expiry = expiryDateSecs ??
        floorToWholeHour(nowInSeconds() + _twoWeeksInSeconds);
    // Generate the blinder if not provided.
    final blinderBytes = blinder != null
        ? Hex.fromHexInput(blinder).toUint8List()
        : _generateBlinder();
    // Calculate the nonce.
    final fields = padAndPackBytesWithLen(publicKey.bcsToBytes(), 93);
    fields.add(BigInt.from(expiry));
    fields.add(bytesToBigIntLE(blinderBytes));
    final nonceHash = poseidonHash(fields);
    return EphemeralKeyPair._(
      privateKey,
      publicKey,
      expiry,
      blinderBytes,
      nonceHash.toString(),
    );
  }

  EphemeralKeyPair._(
    this._privateKey,
    this._publicKey,
    this.expiryDateSecs,
    this.blinder,
    this.nonce,
  );

  /// Returns the public key of the key pair.
  EphemeralPublicKey getPublicKey() => _publicKey;

  /// Checks if the current time has surpassed the expiry date of the key
  /// pair.
  bool isExpired() {
    final currentTimeSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return currentTimeSecs > expiryDateSecs;
  }

  /// Overwrites the ephemeral private key and blinder byte buffers with
  /// random bytes and then zeros. After calling this method the key pair can
  /// no longer sign transactions.
  ///
  /// SECURITY: This is a best-effort window-narrowing tool, NOT a true
  /// zeroization guarantee. See `Ed25519PrivateKey.clear()` for the full
  /// enumeration of limits.
  ///
  /// SPECIFIC TO EphemeralKeyPair: the [nonce] field is NOT cleared by this
  /// method. It is the OIDC nonce — already public — and is stored as an
  /// immutable string.
  void clear() {
    if (!_cleared) {
      final random = Random.secure();
      // Clear the underlying private key if it has a clear method.
      final privateKey = _privateKey;
      if (privateKey is Ed25519PrivateKey) {
        privateKey.clear();
      } else {
        // Fallback: multiple overwrite passes for better security.
        final keyBytes = privateKey.toUint8Array();
        for (var i = 0; i < keyBytes.length; i += 1) {
          keyBytes[i] = random.nextInt(256);
        }
        keyBytes.fillRange(0, keyBytes.length, 0xff);
        for (var i = 0; i < keyBytes.length; i += 1) {
          keyBytes[i] = random.nextInt(256);
        }
        keyBytes.fillRange(0, keyBytes.length, 0);
      }
      // Also clear the blinder with multiple passes as it's used in nonce
      // calculation.
      for (var i = 0; i < blinder.length; i += 1) {
        blinder[i] = random.nextInt(256);
      }
      blinder.fillRange(0, blinder.length, 0xff);
      for (var i = 0; i < blinder.length; i += 1) {
        blinder[i] = random.nextInt(256);
      }
      blinder.fillRange(0, blinder.length, 0);
      _cleared = true;
    }
  }

  /// Returns whether the ephemeral key pair has been cleared from memory.
  bool isCleared() => _cleared;

  /// Serializes the object's properties into a format suitable for
  /// transmission or storage.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(_publicKey.variant.value);
    serializer.serializeBytes(_privateKey.toUint8Array());
    serializer.serializeU64(BigInt.from(expiryDateSecs));
    serializer.serializeFixedBytes(blinder);
  }

  /// Deserializes an ephemeral key pair from the provided deserializer.
  ///
  /// Throws a [StateError] for an unknown variant index.
  static EphemeralKeyPair deserialize(Deserializer deserializer) {
    final variantIndex = deserializer.deserializeUleb128AsU32();
    final PrivateKey privateKey;
    if (variantIndex == EphemeralPublicKeyVariant.ed25519.value) {
      privateKey = Ed25519PrivateKey.deserialize(deserializer);
    } else {
      throw StateError(
        'Unknown variant index for EphemeralPublicKey: $variantIndex',
      );
    }
    final expiryDateSecs = deserializer.deserializeU64();
    final blinder = deserializer.deserializeFixedBytes(31);
    return EphemeralKeyPair(
      privateKey: privateKey,
      expiryDateSecs:
          u64ToIntSafe(expiryDateSecs, 'EphemeralKeyPair.expiryDateSecs'),
      blinder: blinder,
    );
  }

  /// Reconstructs an [EphemeralKeyPair] from its serialized [bytes].
  static EphemeralKeyPair fromBytes(Uint8List bytes) {
    return EphemeralKeyPair.deserialize(Deserializer(bytes));
  }

  /// Generates a new ephemeral key pair with an optional expiry date.
  ///
  /// [scheme] is the type of key pair to use for the EphemeralKeyPair; only
  /// Ed25519 is supported for now. [expiryDateSecs] is the date of expiry
  /// for the key pair in seconds.
  static EphemeralKeyPair generate({
    EphemeralPublicKeyVariant? scheme,
    int? expiryDateSecs,
  }) {
    final PrivateKey privateKey;
    switch (scheme) {
      default:
        privateKey = Ed25519PrivateKey.generate();
    }
    return EphemeralKeyPair(
      privateKey: privateKey,
      expiryDateSecs: expiryDateSecs,
    );
  }

  /// Signs [data] with the ephemeral private key and returns the resulting
  /// signature.
  ///
  /// Throws a [StateError] if the EphemeralKeyPair has expired or been
  /// cleared from memory.
  EphemeralSignature sign(HexInput data) {
    if (_cleared) {
      throw StateError(
        'EphemeralKeyPair has been cleared from memory and can no longer be '
        'used',
      );
    }
    if (isExpired()) {
      throw StateError('EphemeralKeyPair has expired');
    }
    return EphemeralSignature(_privateKey.sign(data));
  }
}

/// Generates a random byte array of length [EphemeralKeyPair.blinderLength].
Uint8List _generateBlinder() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(
      EphemeralKeyPair.blinderLength,
      (_) => random.nextInt(256),
    ),
  );
}
