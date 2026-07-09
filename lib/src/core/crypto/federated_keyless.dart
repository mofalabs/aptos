import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../account_address.dart';
import '../authentication_key.dart';
import 'keyless.dart';
import 'public_key.dart';
import 'signature.dart';

// NOTE: registration of the keyless variants into the
// AnyPublicKey/AnySignature registry is intentionally NOT done in this
// file — it is handled where the AnyPublicKey registry is defined.

/// Represents the FederatedKeylessPublicKey public key
///
/// These keys use an on-chain address as a source of truth for the JWK used
/// to verify signatures.
///
/// FederatedKeylessPublicKey authentication key is represented in the SDK as
/// `AnyPublicKey`.
class FederatedKeylessPublicKey extends AccountPublicKey {
  /// The address that contains the JWK set to be used for verification.
  final AccountAddress jwkAddress;

  /// The inner public key which contains the standard Keyless public key.
  final KeylessPublicKey keylessPublicKey;

  FederatedKeylessPublicKey(
    AccountAddressInput jwkAddress,
    this.keylessPublicKey,
  ) : jwkAddress = AccountAddress.from(jwkAddress);

  /// Get the authentication key for the federated keyless public key.
  @override
  AuthenticationKey authKey() {
    final serializer = Serializer();
    serializer
        .serializeU32AsUleb128(AnyPublicKeyVariant.federatedKeyless.value);
    serializer.serializeFixedBytes(bcsToBytes());
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.singleKey,
      input: serializer.toUint8List(),
    );
  }

  /// Verifies a signed data with a public key.
  ///
  /// [jwk] is the JWK to use for verification and [keylessConfig] the keyless
  /// configuration to use for verification. Both are required; they are
  /// optional named parameters only to satisfy the base [PublicKey]
  /// interface.
  ///
  /// NOTE: full verification requires BN254 pairings for the Groth16
  /// proof check, which are not yet available in pure Dart. See
  /// [Groth16VerificationKey.verifyProof].
  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
    MoveJWK? jwk,
    KeylessConfiguration? keylessConfig,
  }) {
    if (jwk == null || keylessConfig == null) {
      throw ArgumentError(
        'FederatedKeylessPublicKey.verifySignature requires jwk and '
        'keylessConfig',
      );
    }
    try {
      verifyKeylessSignatureWithJwkAndConfig(
        publicKey: this,
        message: message,
        signature: signature,
        jwk: jwk,
        keylessConfig: keylessConfig,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // TODO: verifySignatureAsync requires the api/aptosConfig module
  // (fetches the keyless configuration and JWKs from the network); add it
  // together with the client.

  @override
  void serialize(Serializer serializer) {
    jwkAddress.serialize(serializer);
    keylessPublicKey.serialize(serializer);
  }

  static FederatedKeylessPublicKey deserialize(Deserializer deserializer) {
    final jwkAddress = AccountAddress.deserialize(deserializer);
    final keylessPublicKey = KeylessPublicKey.deserialize(deserializer);
    return FederatedKeylessPublicKey(jwkAddress, keylessPublicKey);
  }

  static bool isPublicKey(PublicKey publicKey) =>
      publicKey is FederatedKeylessPublicKey;

  /// Creates a FederatedKeylessPublicKey from the JWT components plus pepper.
  ///
  /// [iss] is the iss of the identity, [uidKey] the key used to get the
  /// uidVal in the JWT token, [uidVal] the value of the uidKey in the JWT
  /// token, [aud] the client ID of the application, and [pepper] the pepper
  /// used to maintain privacy of the account.
  static FederatedKeylessPublicKey create({
    required String iss,
    required String uidKey,
    required String uidVal,
    required String aud,
    required HexInput pepper,
    required AccountAddressInput jwkAddress,
  }) {
    return FederatedKeylessPublicKey(
      jwkAddress,
      KeylessPublicKey.create(
        iss: iss,
        uidKey: uidKey,
        uidVal: uidVal,
        aud: aud,
        pepper: pepper,
      ),
    );
  }

  static FederatedKeylessPublicKey fromJwtAndPepper({
    required String jwt,
    required HexInput pepper,
    required AccountAddressInput jwkAddress,
    String uidKey = 'sub',
  }) {
    return FederatedKeylessPublicKey(
      jwkAddress,
      KeylessPublicKey.fromJwtAndPepper(
        jwt: jwt,
        pepper: pepper,
        uidKey: uidKey,
      ),
    );
  }

  static bool isInstance(PublicKey publicKey) =>
      publicKey is FederatedKeylessPublicKey;
}
