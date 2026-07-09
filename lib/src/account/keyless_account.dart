import '../bcs/deserializer.dart';
import '../core/account_address.dart';
import '../core/crypto/keyless.dart';
import '../core/hex.dart';
import '../types/types.dart';
import 'abstract_keyless_account.dart';
import 'ephemeral_key_pair.dart';

/// Account implementation for the Keyless authentication scheme.
///
/// Used to represent a Keyless based account and sign transactions with it.
///
/// Use `KeylessAccount.create()` to instantiate a KeylessAccount with a JWT,
/// proof and EphemeralKeyPair.
///
/// When the proof expires or the JWT becomes invalid, the KeylessAccount must
/// be instantiated again with a new JWT, EphemeralKeyPair, and corresponding
/// proof.
class KeylessAccount extends AbstractKeylessAccount {
  /// The KeylessPublicKey associated with the account.
  @override
  final KeylessPublicKey publicKey;

  // Use the static constructor 'create' instead.

  /// Use the static generator `create(...)` instead.
  /// Creates an instance of the KeylessAccount with an optional proof.
  ///
  /// [address] is the optional account address associated with the
  /// KeylessAccount. [ephemeralKeyPair] is the ephemeral key pair used in
  /// the account creation. [iss] is a JWT issuer. [uidKey] is the claim on
  /// the JWT to identify a user (typically 'sub' or 'email'). [uidVal] is
  /// the unique id for this user, intended to be a stable user identifier.
  /// [aud] is the value of the 'aud' claim on the JWT (client ID). [pepper]
  /// is a hexadecimal input used for additional security. [proof] is a
  /// [ZeroKnowledgeSig] or a `Future<ZeroKnowledgeSig>`.
  /// [proofFetchCallback] is an optional callback function for fetching
  /// proof. [jwt] is a JSON Web Token used for authentication.
  factory KeylessAccount({
    AccountAddress? address,
    required EphemeralKeyPair ephemeralKeyPair,
    required String iss,
    required String uidKey,
    required String uidVal,
    required String aud,
    required HexInput pepper,
    required Object proof,
    ProofFetchCallback? proofFetchCallback,
    required String jwt,
    HexInput? verificationKeyHash,
  }) {
    final publicKey = KeylessPublicKey.create(
      iss: iss,
      uidKey: uidKey,
      uidVal: uidVal,
      aud: aud,
      pepper: pepper,
    );
    return KeylessAccount._(
      publicKey: publicKey,
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

  KeylessAccount._({
    required this.publicKey,
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

  /// Deserializes a KeylessAccount, reading the JWT, uid key, pepper,
  /// ephemeral key pair, and proof from the deserializer.
  static KeylessAccount deserialize(Deserializer deserializer) {
    final components = AbstractKeylessAccount.partialDeserialize(deserializer);
    final claims = getIssAudAndUidVal(
      jwt: components.jwt,
      uidKey: components.uidKey,
    );
    return KeylessAccount(
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
    );
  }

  /// Deserialize bytes using this account's information.
  static KeylessAccount fromBytes(HexInput bytes) {
    return KeylessAccount.deserialize(
      Deserializer(Hex.hexInputToUint8List(bytes)),
    );
  }

  /// Creates a KeylessAccount from the provided parameters. Prefer this over
  /// the constructor: it derives the issuer, audience, and uid value from the
  /// JWT.
  ///
  /// [address] is the optional account address associated with the
  /// KeylessAccount. [proof] is a [ZeroKnowledgeSig] or a
  /// `Future<ZeroKnowledgeSig>`. [jwt] is a JSON Web Token used for
  /// authentication. [ephemeralKeyPair] is the ephemeral key pair used in
  /// the account creation. [pepper] is a hexadecimal input used for
  /// additional security. [uidKey] is an optional key for user
  /// identification, defaults to 'sub'. [proofFetchCallback] is an optional
  /// callback function for fetching proof.
  ///
  /// Throws a [StateError] if both [verificationKey] and
  /// [verificationKeyHash] are provided.
  static KeylessAccount create({
    AccountAddress? address,
    required Object proof,
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    required HexInput pepper,
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
    return KeylessAccount(
      address: address,
      proof: proof,
      ephemeralKeyPair: ephemeralKeyPair,
      iss: claims.iss,
      uidKey: uidKey,
      uidVal: claims.uidVal,
      aud: claims.aud,
      pepper: pepper,
      jwt: jwt,
      proofFetchCallback: proofFetchCallback,
      verificationKeyHash: verificationKeyHash ?? verificationKey?.hash(),
    );
  }
}
