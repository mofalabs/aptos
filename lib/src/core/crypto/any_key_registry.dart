/// Registry for `AnyPublicKey` and `AnySignature` variant handlers.
///
/// This allows keyless (and future) variants to register themselves at
/// runtime, so that `single_key.dart` does not need a compile-time dependency
/// on keyless/poseidon. When the keyless module registers its deserializers
/// and variant detectors here, `AnyPublicKey`/`AnySignature` can wrap and
/// deserialize keyless keys. If keyless is never registered, those variants
/// remain unknown and deserialization throws a clear error.
///
/// The ed25519, secp256k1 and secp256r1 (WebAuthn) variants are registered
/// eagerly by this library.
library;

import '../../bcs/deserializer.dart';
import '../../types/types.dart';
import 'ed25519.dart';
import 'keyless_registration.dart';
import 'public_key.dart';
import 'secp256k1.dart';
import 'secp256r1.dart';
import 'signature.dart';

/// A function that deserializes the *inner* public key of an `AnyPublicKey`
/// variant (the variant index has already been consumed).
typedef PublicKeyDeserializer = PublicKey Function(Deserializer deserializer);

/// A function that deserializes the *inner* signature of an `AnySignature`
/// variant (the variant index has already been consumed).
typedef SignatureDeserializer = Signature Function(Deserializer deserializer);

/// Returns the [AnyPublicKeyVariant] for [key] if the detector recognizes it,
/// or `null` otherwise.
typedef PublicKeyVariantDetector = AnyPublicKeyVariant? Function(PublicKey key);

/// Returns the [AnySignatureVariant] for [signature] if the detector
/// recognizes it, or `null` otherwise.
typedef SignatureVariantDetector = AnySignatureVariant? Function(
  Signature signature,
);

final Map<int, PublicKeyDeserializer> _publicKeyDeserializers = {
  AnyPublicKeyVariant.ed25519.value: Ed25519PublicKey.deserialize,
  AnyPublicKeyVariant.secp256k1.value: Secp256k1PublicKey.deserialize,
  AnyPublicKeyVariant.secp256r1.value: Secp256r1PublicKey.deserialize,
};

final Map<int, SignatureDeserializer> _signatureDeserializers = {
  AnySignatureVariant.ed25519.value: Ed25519Signature.deserialize,
  AnySignatureVariant.secp256k1.value: Secp256k1Signature.deserialize,
  AnySignatureVariant.webAuthn.value: WebAuthnSignature.deserialize,
};

final List<PublicKeyVariantDetector> _publicKeyVariantDetectors = [
  (key) => key is Ed25519PublicKey ? AnyPublicKeyVariant.ed25519 : null,
  (key) => key is Secp256k1PublicKey ? AnyPublicKeyVariant.secp256k1 : null,
  (key) => key is Secp256r1PublicKey ? AnyPublicKeyVariant.secp256r1 : null,
];

final List<SignatureVariantDetector> _signatureVariantDetectors = [
  (sig) => sig is Ed25519Signature ? AnySignatureVariant.ed25519 : null,
  (sig) => sig is Secp256k1Signature ? AnySignatureVariant.secp256k1 : null,
  (sig) => sig is WebAuthnSignature ? AnySignatureVariant.webAuthn : null,
];

/// Registers a deserializer and a variant detector for an `AnyPublicKey`
/// variant.
///
/// Called by modules that define new `AnyPublicKey` variants (e.g. keyless):
///
/// ```dart
/// registerAnyPublicKeyVariant(
///   AnyPublicKeyVariant.keyless,
///   KeylessPublicKey.deserialize,
///   (key) => key is KeylessPublicKey ? AnyPublicKeyVariant.keyless : null,
/// );
/// ```
void registerAnyPublicKeyVariant(
  AnyPublicKeyVariant variant,
  PublicKeyDeserializer deserializer,
  PublicKeyVariantDetector detector,
) {
  _publicKeyDeserializers[variant.value] = deserializer;
  _publicKeyVariantDetectors.add(detector);
}

/// Registers a deserializer and a variant detector for an `AnySignature`
/// variant.
///
/// Called by modules that define new `AnySignature` variants (e.g. keyless).
void registerAnySignatureVariant(
  AnySignatureVariant variant,
  SignatureDeserializer deserializer,
  SignatureVariantDetector detector,
) {
  _signatureDeserializers[variant.value] = deserializer;
  _signatureVariantDetectors.add(detector);
}

/// Looks up a registered public key deserializer by variant index.
PublicKeyDeserializer? getAnyPublicKeyDeserializer(int variantIndex) {
  registerKeylessCrypto();
  return _publicKeyDeserializers[variantIndex];
}

/// Looks up a registered signature deserializer by variant index.
SignatureDeserializer? getAnySignatureDeserializer(int variantIndex) {
  registerKeylessCrypto();
  return _signatureDeserializers[variantIndex];
}

/// Detects the `AnyPublicKey` variant for [key] using the registered
/// detectors. Returns `null` if no detector matches.
AnyPublicKeyVariant? detectAnyPublicKeyVariant(PublicKey key) {
  registerKeylessCrypto();
  for (final detector in _publicKeyVariantDetectors) {
    final variant = detector(key);
    if (variant != null) return variant;
  }
  return null;
}

/// Detects the `AnySignature` variant for [signature] using the registered
/// detectors. Returns `null` if no detector matches.
AnySignatureVariant? detectAnySignatureVariant(Signature signature) {
  registerKeylessCrypto();
  for (final detector in _signatureVariantDetectors) {
    final variant = detector(signature);
    if (variant != null) return variant;
  }
  return null;
}
