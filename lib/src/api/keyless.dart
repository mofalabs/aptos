import 'dart:typed_data';

import '../account/abstract_keyless_account.dart';
import '../account/account.dart';
import '../account/ephemeral_key_pair.dart';
import '../core/account_address.dart';
import '../core/crypto/keyless.dart';
import '../internal/keyless.dart' as internal_keyless;
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/types.dart';
import 'aptos_config.dart';

/// A class to query all `Keyless` related queries on Aptos.
///
/// More documentation on how to integrate Keyless Accounts see the
/// [Aptos Keyless Integration Guide](https://aptos.dev/guides/keyless-accounts/#aptos-keyless-integration-guide).
class Keyless {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Keyless` namespace with the provided
  /// configuration.
  const Keyless(this.config);

  /// Fetches the pepper from the Aptos pepper service API.
  ///
  /// [jwt] - JWT token.
  /// [ephemeralKeyPair] - The EphemeralKeyPair used to generate the nonce in
  /// the JWT token.
  /// [uidKey] - An optional key in the JWT token to use to set the uidVal in
  /// the IdCommitment.
  /// [derivationPath] - A derivation path used for creating multiple accounts
  /// per user via the BIP-44 standard. Defaults to "m/44'/637'/0'/0'/0".
  ///
  /// Returns the pepper which is a [Uint8List] of length 31.
  Future<Uint8List> getPepper({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    String uidKey = 'sub',
    String? derivationPath,
  }) {
    return internal_keyless.getPepper(
      aptosConfig: config,
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
      derivationPath: derivationPath,
    );
  }

  /// Fetches the `pepper_base` from the Aptos pepper service API.
  ///
  /// The `pepper_base` is the VUF signature from which the final pepper is
  /// derived — a 48-byte compressed BLS12-381 G1 point. It is deterministic
  /// for a given OIDC identity and independent of the ephemeral key and
  /// derivation path, making it a stable seed for deriving a
  /// confidential-asset decryption key. Deriving the key from `pepper_base`
  /// (rather than the final pepper, which is a one-way hash of it) ensures a
  /// leaked pepper does not compromise confidentiality.
  ///
  /// [jwt] - JWT token.
  /// [ephemeralKeyPair] - The EphemeralKeyPair used to generate the nonce in
  /// the JWT token.
  /// [uidKey] - An optional key in the JWT token to use to set the uidVal in
  /// the IdCommitment.
  /// [derivationPath] - A derivation path used for creating multiple accounts
  /// per user via the BIP-44 standard. Note: `pepper_base` itself does not
  /// depend on the derivation path.
  ///
  /// Returns the `pepper_base` as a [Uint8List] of length 48.
  Future<Uint8List> getPepperBase({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    String uidKey = 'sub',
    String? derivationPath,
  }) {
    return internal_keyless.getPepperBase(
      aptosConfig: config,
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
      derivationPath: derivationPath,
    );
  }

  /// Fetches a proof from the Aptos prover service API.
  ///
  /// [jwt] - JWT token.
  /// [ephemeralKeyPair] - The EphemeralKeyPair used to generate the nonce in
  /// the JWT token.
  /// [pepper] - The pepper used for the account. If not provided, it will be
  /// fetched from the Aptos pepper service.
  /// [uidKey] - A key in the JWT token to use to set the uidVal in the
  /// IdCommitment.
  ///
  /// Returns the proof which is represented by a [ZeroKnowledgeSig].
  Future<ZeroKnowledgeSig> getProof({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    HexInput? pepper,
    String uidKey = 'sub',
  }) {
    return internal_keyless.getProof(
      aptosConfig: config,
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      pepper: pepper,
      uidKey: uidKey,
    );
  }

  /// Derives a Keyless Account from the provided JWT token and corresponding
  /// EphemeralKeyPair. This function computes the proof via the proving
  /// service and can fetch the pepper from the pepper service if not
  /// explicitly provided.
  ///
  /// [jwt] - The JWT token used for deriving the account.
  /// [ephemeralKeyPair] - The EphemeralKeyPair used to generate the nonce in
  /// the JWT token.
  /// [jwkAddress] - The address where the JWKs used to verify signatures are
  /// found. Setting the value derives a `FederatedKeylessAccount`.
  /// [uidKey] - An optional key in the JWT token to set the uidVal in the
  /// IdCommitment.
  /// [pepper] - An optional pepper value.
  /// [proofFetchCallback] - An optional callback function for fetching the
  /// proof in the background, allowing for a more responsive user experience.
  ///
  /// Returns a `KeylessAccount` (or `FederatedKeylessAccount` when
  /// [jwkAddress] is set) that can be used to sign transactions.
  Future<AbstractKeylessAccount> deriveKeylessAccount({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    AccountAddressInput? jwkAddress,
    String uidKey = 'sub',
    HexInput? pepper,
    ProofFetchCallback? proofFetchCallback,
  }) {
    return internal_keyless.deriveKeylessAccount(
      aptosConfig: config,
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      jwkAddress: jwkAddress,
      uidKey: uidKey,
      pepper: pepper,
      proofFetchCallback: proofFetchCallback,
    );
  }

  /// This installs a set of FederatedJWKs at an address for a given iss.
  ///
  /// It will fetch the JSON Web Key Set (JWKS) from the well-known endpoint
  /// and update the FederatedJWKs at the sender's address to reflect it.
  ///
  /// [sender] - The account that will install the JWKs.
  /// [iss] - The iss claim of the federated OIDC provider.
  /// [jwksUrl] - The URL to find the corresponding JWKs. For supported IDP
  /// providers this parameter is not necessary.
  ///
  /// Returns the transaction to update the JWKs, ready for submission.
  Future<SimpleTransaction> updateFederatedKeylessJwkSetTransaction({
    required Account sender,
    required String iss,
    String? jwksUrl,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_keyless.updateFederatedKeylessJwkSetTransaction(
      aptosConfig: config,
      sender: sender,
      iss: iss,
      jwksUrl: jwksUrl,
      options: options,
    );
  }
}
