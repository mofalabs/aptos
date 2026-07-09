import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../core/account_address.dart';
import '../core/crypto/federated_keyless.dart';
import '../core/crypto/keyless.dart';
import '../types/types.dart';
import 'abstract_keyless_account.dart';
import 'ephemeral_key_pair.dart';

/// Account implementation for the FederatedKeyless authentication scheme.
///
/// Used to represent a FederatedKeyless based account and sign transactions
/// with it.
///
/// Use `FederatedKeylessAccount.create()` to instantiate a KeylessAccount
/// with a JSON Web Token (JWT), proof, EphemeralKeyPair and the address the
/// JSON Web Key Set (JWKS) are installed that will be used to verify the
/// JWT.
///
/// When the proof expires or the JWT becomes invalid, the KeylessAccount
/// must be instantiated again with a new JWT, EphemeralKeyPair, and
/// corresponding proof.
class FederatedKeylessAccount extends AbstractKeylessAccount {
  /// The FederatedKeylessPublicKey associated with the account.
  @override
  final FederatedKeylessPublicKey publicKey;

  /// Whether the account derivation ignores the 'aud' claim.
  final bool audless;

  /// Use the static generator `FederatedKeylessAccount.create(...)` instead.
  /// Creates a KeylessAccount instance using the provided parameters.
  ///
  /// [address] is the optional account address associated with the
  /// KeylessAccount. [ephemeralKeyPair] is the ephemeral key pair used in
  /// the account creation. [iss] is a JWT issuer. [uidKey] is the claim on
  /// the JWT to identify a user (typically 'sub' or 'email'). [uidVal] is
  /// the unique id for this user. [aud] is the value of the 'aud' claim on
  /// the JWT (client ID). [pepper] is a hexadecimal input used for
  /// additional security. [jwkAddress] is the address which stores the JSON
  /// Web Key Set (JWKS) used to verify the JWT. [proof] is a
  /// [ZeroKnowledgeSig] or a `Future<ZeroKnowledgeSig>`.
  /// [proofFetchCallback] is an optional callback function for fetching
  /// proof. [jwt] is a JSON Web Token used for authentication.
  factory FederatedKeylessAccount({
    AccountAddress? address,
    required EphemeralKeyPair ephemeralKeyPair,
    required String iss,
    required String uidKey,
    required String uidVal,
    required String aud,
    required HexInput pepper,
    required AccountAddress jwkAddress,
    required Object proof,
    ProofFetchCallback? proofFetchCallback,
    required String jwt,
    HexInput? verificationKeyHash,
    bool audless = false,
  }) {
    final publicKey = FederatedKeylessPublicKey.create(
      iss: iss,
      uidKey: uidKey,
      uidVal: uidVal,
      aud: aud,
      pepper: pepper,
      jwkAddress: jwkAddress,
    );
    return FederatedKeylessAccount._(
      publicKey: publicKey,
      audless: audless,
      address: address,
      ephemeralKeyPair: ephemeralKeyPair,
      iss: iss,
      uidKey: uidKey,
      uidVal: uidVal,
      aud: aud,
      pepper: pepper,
      proof: proof,
      proofFetchCallback: proofFetchCallback,
      jwt: jwt,
      verificationKeyHash: verificationKeyHash,
    );
  }

  FederatedKeylessAccount._({
    required this.publicKey,
    required this.audless,
    super.address,
    required super.ephemeralKeyPair,
    required super.iss,
    required super.uidKey,
    required super.uidVal,
    required super.aud,
    required super.pepper,
    required super.proof,
    super.proofFetchCallback,
    required super.jwt,
    super.verificationKeyHash,
  }) : super(publicKey: publicKey);

  /// Serializes the account, appending the JWK address after the common
  /// keyless fields.
  @override
  void serialize(Serializer serializer) {
    super.serialize(serializer);
    publicKey.jwkAddress.serialize(serializer);
  }

  /// Deserializes a FederatedKeylessAccount, reading the common keyless fields
  /// followed by the JWK address.
  static FederatedKeylessAccount deserialize(Deserializer deserializer) {
    final components = AbstractKeylessAccount.partialDeserialize(deserializer);
    final jwkAddress = AccountAddress.deserialize(deserializer);
    final claims = getIssAudAndUidVal(
      jwt: components.jwt,
      uidKey: components.uidKey,
    );
    return FederatedKeylessAccount(
      address: components.address,
      proof: components.proof,
      ephemeralKeyPair: components.ephemeralKeyPair,
      iss: claims.iss,
      uidKey: components.uidKey,
      uidVal: claims.uidVal,
      aud: claims.aud,
      pepper: components.pepper,
      jwt: components.jwt,
      verificationKeyHash: components.verificationKeyHash,
      jwkAddress: jwkAddress,
    );
  }

  /// Deserialize bytes using this account's information.
  static FederatedKeylessAccount fromBytes(HexInput bytes) {
    return FederatedKeylessAccount.deserialize(Deserializer.fromHex(bytes));
  }

  /// Creates a FederatedKeylessAccount from the provided parameters. Prefer
  /// this over the constructor: it derives the issuer, audience, and uid value
  /// from the JWT.
  ///
  /// [jwkAddress] is the address which stores the JSON Web Key Set (JWKS)
  /// used to verify the JWT. [uidKey] is an optional key for user
  /// identification, defaults to 'sub'.
  ///
  /// Throws a [StateError] if both [verificationKey] and
  /// [verificationKeyHash] are provided.
  static FederatedKeylessAccount create({
    AccountAddress? address,
    required Object proof,
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    required HexInput pepper,
    required AccountAddressInput jwkAddress,
    String uidKey = 'sub',
    ProofFetchCallback? proofFetchCallback,
    Groth16VerificationKey? verificationKey,
    HexInput? verificationKeyHash,
  }) {
    if (verificationKeyHash != null && verificationKey != null) {
      throw StateError(
        'Cannot provide both verificationKey and verificationKeyHash',
      );
    }

    final claims = getIssAudAndUidVal(jwt: jwt, uidKey: uidKey);
    return FederatedKeylessAccount(
      address: address,
      proof: proof,
      ephemeralKeyPair: ephemeralKeyPair,
      iss: claims.iss,
      uidKey: uidKey,
      uidVal: claims.uidVal,
      aud: claims.aud,
      pepper: pepper,
      jwkAddress: AccountAddress.from(jwkAddress),
      jwt: jwt,
      proofFetchCallback: proofFetchCallback,
      verificationKeyHash: verificationKeyHash ?? verificationKey?.hash(),
    );
  }
}
