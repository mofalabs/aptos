import 'dart:typed_data';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import 'any_key_registry.dart';
import 'ed25519.dart';
import 'public_key.dart';
import 'secp256k1.dart';
import 'secp256r1.dart';
import 'signature.dart';

/// A private key that can be used with the SingleKey authentication scheme:
/// `Ed25519PrivateKey` or `Secp256k1PrivateKey`.
///
/// Dart has no union types, so this is an alias of [Object]; values of any
/// other type are rejected at runtime by the consuming APIs.
typedef PrivateKeyInput = Object;

/// Options accepted by `verifySignatureAsync` implementations
/// (`{ throwErrorWithReason?: boolean }`).
///
/// Pass an instance as the `options` argument of
/// `PublicKey.verifySignatureAsync`.
class VerifySignatureAsyncOptions {
  /// When true, verification failures throw an error with the failure reason
  /// instead of returning false.
  final bool throwErrorWithReason;

  const VerifySignatureAsyncOptions({this.throwErrorWithReason = false});
}

/// Returns whether [options] requests throw-with-reason behavior.
bool _shouldThrowWithReason(Object? options) =>
    options is VerifySignatureAsyncOptions && options.throwErrorWithReason;

/// Represents any public key supported by Aptos.
///
/// Since [AIP-55](https://github.com/aptos-foundation/AIPs/pull/263) Aptos
/// supports `Legacy` and `Unified` authentication keys.
///
/// Any unified authentication key is represented in the SDK as `AnyPublicKey`.
class AnyPublicKey extends AccountPublicKey {
  /// Reference to the inner public key.
  final PublicKey publicKey;

  /// Index of the underlying enum variant.
  final AnyPublicKeyVariant variant;

  // region Constructors

  /// Creates an instance based on the provided public key type.
  /// This allows for the handling of different key variants such as Ed25519,
  /// Secp256k1, and Keyless.
  ///
  /// If [variant] is omitted it is inferred from the runtime type of
  /// [publicKey]; keyless variants are looked up in the AnyKey registry.
  ///
  /// Throws an [ArgumentError] if the provided public key type is unsupported.
  AnyPublicKey(this.publicKey, [AnyPublicKeyVariant? variant])
      : variant = variant ?? _detectVariant(publicKey);

  static AnyPublicKeyVariant _detectVariant(PublicKey publicKey) {
    if (publicKey is Ed25519PublicKey) {
      return AnyPublicKeyVariant.ed25519;
    } else if (publicKey is Secp256k1PublicKey) {
      return AnyPublicKeyVariant.secp256k1;
    } else if (publicKey is Secp256r1PublicKey) {
      return AnyPublicKeyVariant.secp256r1;
    }
    // Check registered variants (e.g., keyless, federated keyless).
    final registeredVariant = detectAnyPublicKeyVariant(publicKey);
    if (registeredVariant != null) {
      return registeredVariant;
    }
    throw ArgumentError('Unsupported public key type');
  }

  // endregion

  // region AccountPublicKey

  /// Verifies the provided signature against the given message.
  ///
  /// Throws a [StateError] if this is a keyless public key — use
  /// `verifySignatureAsync` to verify keyless signatures.
  @override
  bool verifySignature({
    required HexInput message,
    required covariant AnySignature signature,
  }) {
    if (variant == AnyPublicKeyVariant.keyless ||
        variant == AnyPublicKeyVariant.federatedKeyless) {
      throw StateError('Use verifySignatureAsync to verify Keyless signatures');
    }
    return publicKey.verifySignature(
      message: message,
      signature: signature.signature,
    );
  }

  /// Verifies the provided signature against the given message, making any
  /// network calls required to get state needed to verify the signature.
  ///
  /// [options] may be a [VerifySignatureAsyncOptions]; when
  /// `throwErrorWithReason` is set, a non-[AnySignature] input throws instead
  /// of returning false.
  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    if (signature is! AnySignature) {
      if (_shouldThrowWithReason(options)) {
        throw ArgumentError('Signature must be an instance of AnySignature');
      }
      return false;
    }
    return publicKey.verifySignatureAsync(
      aptosConfig: aptosConfig,
      message: message,
      signature: signature.signature,
      options: options,
    );
  }

  /// Generates an authentication key from the current instance's byte
  /// representation using the SingleKey scheme.
  @override
  AuthenticationKey authKey() {
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.singleKey,
      input: toUint8Array(),
    );
  }

  /// Get the BCS bytes of this public key (variant index + inner key).
  @override
  Uint8List toUint8Array() => bcsToBytes();

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(variant.value);
    publicKey.serialize(serializer);
  }

  /// Deserializes an AnyPublicKey from the provided deserializer.
  ///
  /// Throws a [StateError] for an unknown variant index — for keyless
  /// variants, ensure the keyless module has registered its deserializers via
  /// `registerAnyPublicKeyVariant`.
  static AnyPublicKey deserialize(Deserializer deserializer) {
    final variantIndex = deserializer.deserializeUleb128AsU32();
    PublicKey publicKey;
    if (variantIndex == AnyPublicKeyVariant.ed25519.value) {
      publicKey = Ed25519PublicKey.deserialize(deserializer);
    } else if (variantIndex == AnyPublicKeyVariant.secp256k1.value) {
      publicKey = Secp256k1PublicKey.deserialize(deserializer);
    } else if (variantIndex == AnyPublicKeyVariant.secp256r1.value) {
      publicKey = Secp256r1PublicKey.deserialize(deserializer);
    } else {
      // Check registered variant deserializers (e.g., keyless, federated
      // keyless).
      final registeredDeserializer = getAnyPublicKeyDeserializer(variantIndex);
      if (registeredDeserializer == null) {
        throw StateError(
          'Unknown variant index for AnyPublicKey: $variantIndex. '
          'If this is a keyless key, ensure the keyless variant is '
          'registered via registerAnyPublicKeyVariant.',
        );
      }
      publicKey = registeredDeserializer(deserializer);
    }
    return AnyPublicKey(publicKey);
  }

  // endregion

  /// Determines if the provided public key is an instance of AnyPublicKey.
  ///
  /// Deprecated: use `publicKey is AnyPublicKey` instead.
  static bool isPublicKey(AccountPublicKey publicKey) =>
      publicKey is AnyPublicKey;

  /// Determines if the inner public key is an instance of Ed25519PublicKey.
  ///
  /// Deprecated: use `publicKey.publicKey is Ed25519PublicKey` instead.
  bool isEd25519() => publicKey is Ed25519PublicKey;

  /// Checks if the inner public key is an instance of Secp256k1PublicKey.
  ///
  /// Deprecated: use `publicKey.publicKey is Secp256k1PublicKey` instead.
  bool isSecp256k1PublicKey() => publicKey is Secp256k1PublicKey;

  /// Determines if the provided publicKey is an AnyPublicKey instance.
  static bool isInstance(PublicKey publicKey) => publicKey is AnyPublicKey;
}

/// Represents a signature that utilizes the SingleKey authentication scheme.
/// This class is designed to encapsulate various types of signatures, which
/// can only be generated by a `SingleKeySigner` due to the shared
/// authentication mechanism.
class AnySignature extends Signature {
  /// The inner signature.
  final Signature signature;

  /// Index of the underlying enum variant.
  final AnySignatureVariant _variant;

  // region Constructors

  /// Creates an AnySignature wrapping [signature]; the variant is inferred
  /// from the runtime type of the signature (keyless variants are looked up
  /// in the AnyKey registry).
  ///
  /// Throws an [ArgumentError] if the provided signature type is unsupported.
  AnySignature(this.signature) : _variant = _detectVariant(signature);

  static AnySignatureVariant _detectVariant(Signature signature) {
    if (signature is Ed25519Signature) {
      return AnySignatureVariant.ed25519;
    } else if (signature is Secp256k1Signature) {
      return AnySignatureVariant.secp256k1;
    } else if (signature is WebAuthnSignature) {
      return AnySignatureVariant.webAuthn;
    }
    // Check registered variants (e.g., keyless).
    final registeredVariant = detectAnySignatureVariant(signature);
    if (registeredVariant != null) {
      return registeredVariant;
    }
    throw ArgumentError('Unsupported signature type');
  }

  // endregion

  // region Signature

  /// Get the BCS bytes of this signature (variant index + inner signature).
  ///
  /// NOTE: deprecated in favor of `bcsToBytes()`; may eventually return the
  /// underlying signature bytes instead.
  @override
  Uint8List toUint8Array() => bcsToBytes();

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(_variant.value);
    signature.serialize(serializer);
  }

  /// Deserializes an AnySignature from the provided deserializer.
  ///
  /// Throws a [StateError] for an unknown variant index — for the keyless
  /// variant, ensure the keyless module has registered its deserializers via
  /// `registerAnySignatureVariant`.
  static AnySignature deserialize(Deserializer deserializer) {
    final variantIndex = deserializer.deserializeUleb128AsU32();
    Signature signature;
    if (variantIndex == AnySignatureVariant.ed25519.value) {
      signature = Ed25519Signature.deserialize(deserializer);
    } else if (variantIndex == AnySignatureVariant.secp256k1.value) {
      signature = Secp256k1Signature.deserialize(deserializer);
    } else if (variantIndex == AnySignatureVariant.webAuthn.value) {
      signature = WebAuthnSignature.deserialize(deserializer);
    } else {
      // Check registered variant deserializers (e.g., keyless).
      final registeredDeserializer = getAnySignatureDeserializer(variantIndex);
      if (registeredDeserializer == null) {
        throw StateError(
          'Unknown variant index for AnySignature: $variantIndex. '
          'If this is a keyless signature, ensure the keyless variant is '
          'registered via registerAnySignatureVariant.',
        );
      }
      signature = registeredDeserializer(deserializer);
    }
    return AnySignature(signature);
  }

  // endregion

  /// Determines if the provided signature is an AnySignature instance.
  static bool isInstance(Signature signature) => signature is AnySignature;
}
