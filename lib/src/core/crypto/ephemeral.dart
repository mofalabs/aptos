import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../hex.dart';
import 'ed25519.dart';
import 'public_key.dart';
import 'signature.dart';

/// Represents ephemeral public keys for Aptos Keyless accounts.
///
/// These keys are used only temporarily within Keyless accounts and are not
/// utilized as public keys for account identification.
class EphemeralPublicKey extends PublicKey {
  /// The public key itself.
  final PublicKey publicKey;

  /// An enum indicating the scheme of the ephemeral public key.
  final EphemeralPublicKeyVariant variant;

  /// Creates an instance of EphemeralPublicKey using the provided public key.
  /// This constructor ensures that only supported key types are accepted.
  ///
  /// Throws an [ArgumentError] if the public key type is unsupported.
  EphemeralPublicKey(this.publicKey)
      : variant = _variantOf(publicKey);

  static EphemeralPublicKeyVariant _variantOf(PublicKey publicKey) {
    if (publicKey is Ed25519PublicKey) {
      return EphemeralPublicKeyVariant.ed25519;
    }
    throw ArgumentError(
      'Unsupported key for EphemeralPublicKey - ${publicKey.runtimeType}',
    );
  }

  /// Verifies a signed [message] using the ephemeral public key.
  ///
  /// Returns true if the [signature] was signed by the private key of the
  /// ephemeral public key, otherwise false.
  @override
  bool verifySignature({required HexInput message, required Signature signature}) {
    if (signature is! EphemeralSignature) {
      throw ArgumentError(
        'Signature must be an EphemeralSignature, got ${signature.runtimeType}',
      );
    }
    return publicKey.verifySignature(
      message: message,
      signature: signature.signature,
    );
  }

  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    return verifySignature(message: message, signature: signature);
  }

  /// Serializes the current instance, specifically handling the Ed25519 key
  /// type.
  ///
  /// Throws a [StateError] if the public key type is unknown.
  @override
  void serialize(Serializer serializer) {
    final publicKey = this.publicKey;
    if (publicKey is Ed25519PublicKey) {
      serializer.serializeU32AsUleb128(EphemeralPublicKeyVariant.ed25519.value);
      publicKey.serialize(serializer);
    } else {
      throw StateError('Unknown public key type');
    }
  }

  /// Deserializes an EphemeralPublicKey from the provided deserializer.
  static EphemeralPublicKey deserialize(Deserializer deserializer) {
    final index = deserializer.deserializeUleb128AsU32();
    if (index == EphemeralPublicKeyVariant.ed25519.value) {
      return EphemeralPublicKey(Ed25519PublicKey.deserialize(deserializer));
    }
    throw ArgumentError('Unknown variant index for EphemeralPublicKey: $index');
  }

  /// Determines if the provided public key is an instance of
  /// [EphemeralPublicKey].
  static bool isPublicKey(PublicKey publicKey) =>
      publicKey is EphemeralPublicKey;
}

/// Represents ephemeral signatures used in Aptos Keyless accounts.
///
/// These signatures are utilized within the KeylessSignature framework.
class EphemeralSignature extends Signature {
  /// The signature signed by the private key of an EphemeralKeyPair.
  final Signature signature;

  /// Creates an instance of EphemeralSignature using the provided signature.
  ///
  /// Throws an [ArgumentError] if the signature type is unsupported.
  EphemeralSignature(this.signature) {
    if (signature is! Ed25519Signature) {
      throw ArgumentError(
        'Unsupported signature for EphemeralSignature - ${signature.runtimeType}',
      );
    }
  }

  /// Deserializes an ephemeral signature from a hexadecimal input.
  static EphemeralSignature fromHex(HexInput hexInput) {
    final data = Hex.fromHexInput(hexInput);
    final deserializer = Deserializer(data.toUint8List());
    return EphemeralSignature.deserialize(deserializer);
  }

  @override
  void serialize(Serializer serializer) {
    final signature = this.signature;
    if (signature is Ed25519Signature) {
      serializer.serializeU32AsUleb128(EphemeralSignatureVariant.ed25519.value);
      signature.serialize(serializer);
    } else {
      throw StateError('Unknown signature type');
    }
  }

  static EphemeralSignature deserialize(Deserializer deserializer) {
    final index = deserializer.deserializeUleb128AsU32();
    if (index == EphemeralSignatureVariant.ed25519.value) {
      return EphemeralSignature(Ed25519Signature.deserialize(deserializer));
    }
    throw ArgumentError('Unknown variant index for EphemeralSignature: $index');
  }
}
