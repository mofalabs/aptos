import 'dart:async';
import 'dart:typed_data';

import '../api/aptos_config.dart';
import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../core/account_address.dart';
import '../core/crypto/federated_keyless.dart';
import '../core/crypto/keyless.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/signature.dart';
import '../core/crypto/single_key.dart';
import '../core/hex.dart';
import '../internal/keyless.dart' as internal_keyless;
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../types/types.dart';
import '../utils/helpers.dart';
import 'ephemeral_key_pair.dart';
import 'keyless_signer.dart';
import 'single_key_account.dart';

// Re-exported here so the keyless signer types remain accessible from this
// module.
export 'keyless_signer.dart' show KeylessSigner, isKeylessSigner;

/// The result of a proof fetch: either `Success` or `Failed` (with an error
/// message).
class ProofFetchStatus {
  /// Either `Success` or `Failed`.
  final String status;

  /// The error message; only set when [status] is `Failed`.
  final String? error;

  const ProofFetchStatus.success()
      : status = 'Success',
        error = null;

  const ProofFetchStatus.failed(String this.error) : status = 'Failed';
}

/// A callback invoked when an asynchronous proof fetch finishes.
typedef ProofFetchCallback = Future<void> Function(ProofFetchStatus status);

/// Account implementation for the Keyless authentication scheme. This
/// abstract class is used for standard Keyless Accounts and Federated
/// Keyless Accounts.
abstract class AbstractKeylessAccount extends Serializable
    implements KeylessSigner, SingleKeySigner {
  static const int pepperLength = 31;

  /// The KeylessPublicKey associated with the account
  /// (a [KeylessPublicKey] or [FederatedKeylessPublicKey]).
  @override
  AccountPublicKey get publicKey;

  /// The EphemeralKeyPair used to generate sign.
  final EphemeralKeyPair ephemeralKeyPair;

  /// The claim on the JWT to identify a user. This is typically 'sub' or
  /// 'email'.
  final String uidKey;

  /// The value of the uidKey claim on the JWT. This is intended to be a
  /// stable user identifier.
  final String uidVal;

  /// The value of the 'aud' claim on the JWT, also known as client ID. This
  /// is the identifier for the dApp's OIDC registration with the identity
  /// provider.
  final String aud;

  /// A value which contains 31 bytes of entropy that preserves privacy of
  /// the account. Typically fetched from a pepper provider.
  final Uint8List pepper;

  /// Account address associated with the account.
  @override
  final AccountAddress accountAddress;

  /// The zero knowledge signature (if ready) which contains the proof used
  /// to validate the EphemeralKeyPair.
  ZeroKnowledgeSig? proof;

  /// The proof of the EphemeralKeyPair or a `Future<ZeroKnowledgeSig>` that
  /// provides the proof. This is used to allow for awaiting on fetching the
  /// proof.
  final Object proofOrPromise;

  /// Signing scheme used to sign transactions.
  @override
  SigningScheme get signingScheme => SigningScheme.singleKey;

  /// The JWT token used to derive the account.
  final String jwt;

  /// The hash of the verification key used to verify the proof. This is
  /// optional and can be used to check verifying key rotations which may
  /// invalidate the proof.
  final Uint8List? verificationKeyHash;

  /// Use the static generator `create(...)` on the concrete subclasses
  /// instead. Creates an instance of the KeylessAccount with an optional
  /// proof.
  ///
  /// [address] is the optional account address associated with the
  /// KeylessAccount. [publicKey] is a [KeylessPublicKey] or
  /// [FederatedKeylessPublicKey]. [ephemeralKeyPair] is the ephemeral key
  /// pair used in the account creation. [iss] is a JWT issuer. [uidKey] is
  /// the claim on the JWT to identify a user (typically 'sub' or 'email').
  /// [uidVal] is the unique id for this user, intended to be a stable user
  /// identifier. [aud] is the value of the 'aud' claim on the JWT (client
  /// ID). [pepper] is a hexadecimal input used for additional security.
  /// [proof] is a [ZeroKnowledgeSig] or a `Future<ZeroKnowledgeSig>`.
  /// [proofFetchCallback] is an optional callback function for fetching
  /// proof. [jwt] is a JSON Web Token used for authentication.
  /// [verificationKeyHash] is an optional 32-byte verification key hash as
  /// hex input used to check proof validity.
  AbstractKeylessAccount({
    AccountAddress? address,
    required AccountPublicKey publicKey,
    required this.ephemeralKeyPair,
    // ignore: avoid_unused_constructor_parameters
    required String iss,
    required this.uidKey,
    required this.uidVal,
    required this.aud,
    required HexInput pepper,
    required Object proof,
    ProofFetchCallback? proofFetchCallback,
    required this.jwt,
    HexInput? verificationKeyHash,
  })  : accountAddress = address != null
            ? AccountAddress.from(address)
            : publicKey.authKey().derivedAddress(),
        proofOrPromise = proof,
        pepper = _validatePepper(pepper),
        verificationKeyHash = verificationKeyHash != null
            ? _validateVerificationKeyHash(verificationKeyHash)
            : null {
    if (proof is ZeroKnowledgeSig) {
      this.proof = proof;
    } else if (proof is Future<ZeroKnowledgeSig>) {
      if (proofFetchCallback == null) {
        throw StateError('Must provide callback for async proof fetch');
      }
      // Note, this is purposely not awaited to be non-blocking. The caller
      // should await on the proofFetchCallback.
      unawaited(init(proof, proofFetchCallback));
    } else {
      throw ArgumentError(
        'proof must be a ZeroKnowledgeSig or a Future<ZeroKnowledgeSig>, '
        'got ${proof.runtimeType}',
      );
    }
  }

  static Uint8List _validatePepper(HexInput pepper) {
    final pepperBytes = Hex.fromHexInput(pepper).toUint8List();
    if (pepperBytes.length != AbstractKeylessAccount.pepperLength) {
      throw ArgumentError(
        'Pepper length in bytes should be '
        '${AbstractKeylessAccount.pepperLength}',
      );
    }
    return pepperBytes;
  }

  static Uint8List _validateVerificationKeyHash(
    HexInput verificationKeyHash,
  ) {
    final bytes = Hex.hexInputToUint8List(verificationKeyHash);
    if (bytes.length != 32) {
      throw ArgumentError('verificationKeyHash must be 32 bytes');
    }
    return bytes;
  }

  @override
  AnyPublicKey getAnyPublicKey() => AnyPublicKey(publicKey);

  /// This initializes the asynchronous proof fetch.
  ///
  /// Reports whether the proof fetch succeeded or failed via
  /// [proofFetchCallback], but has no return value.
  Future<void> init(
    Future<ZeroKnowledgeSig> promise,
    ProofFetchCallback proofFetchCallback,
  ) async {
    try {
      proof = await promise;
      await proofFetchCallback(const ProofFetchStatus.success());
    } catch (error) {
      await proofFetchCallback(ProofFetchStatus.failed(error.toString()));
    }
  }

  /// Serializes the account, including the JWT data and the proof.
  ///
  /// Throws a [StateError] if the proof is not yet defined.
  @override
  void serialize(Serializer serializer) {
    accountAddress.serialize(serializer);
    serializer.serializeStr(jwt);
    serializer.serializeStr(uidKey);
    serializer.serializeFixedBytes(pepper);
    ephemeralKeyPair.serialize(serializer);
    final proof = this.proof;
    if (proof == null) {
      throw StateError('Cannot serialize - proof undefined');
    }
    proof.serialize(serializer);
    serializer.serializeOptionFixedBytes(verificationKeyHash);
  }

  /// Deserializes the common fields of a keyless account (everything except
  /// the trailing subclass-specific data).
  static ({
    AccountAddress address,
    String jwt,
    String uidKey,
    Uint8List pepper,
    EphemeralKeyPair ephemeralKeyPair,
    ZeroKnowledgeSig proof,
    Uint8List? verificationKeyHash,
  }) partialDeserialize(Deserializer deserializer) {
    final address = AccountAddress.deserialize(deserializer);
    final jwt = deserializer.deserializeStr();
    final uidKey = deserializer.deserializeStr();
    final pepper = deserializer.deserializeFixedBytes(31);
    final ephemeralKeyPair = EphemeralKeyPair.deserialize(deserializer);
    final proof = ZeroKnowledgeSig.deserialize(deserializer);
    final verificationKeyHash = deserializer.deserializeOptionFixedBytes(32);

    return (
      address: address,
      jwt: jwt,
      uidKey: uidKey,
      pepper: pepper,
      ephemeralKeyPair: ephemeralKeyPair,
      proof: proof,
      verificationKeyHash: verificationKeyHash,
    );
  }

  /// Checks if the proof is expired. If so the account must be re-derived
  /// with a new EphemeralKeyPair and JWT token.
  bool isExpired() {
    return ephemeralKeyPair.isExpired();
  }

  /// Sign a message using Keyless.
  ///
  /// Returns the AccountAuthenticator containing the signature, together
  /// with the account's public key.
  @override
  AccountAuthenticatorSingleKey signWithAuthenticator(HexInput message) {
    final signature = AnySignature(sign(message));
    final publicKey = AnyPublicKey(this.publicKey);
    return AccountAuthenticatorSingleKey(publicKey, signature);
  }

  /// Sign a transaction using Keyless.
  ///
  /// Returns the AccountAuthenticator containing the signature of the
  /// transaction, together with the account's public key.
  @override
  AccountAuthenticatorSingleKey signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    final signature = AnySignature(signTransaction(transaction));
    final publicKey = AnyPublicKey(this.publicKey);
    return AccountAuthenticatorSingleKey(publicKey, signature);
  }

  /// Waits for asynchronous proof fetching to finish.
  @override
  Future<void> waitForProofFetch() async {
    final proofOrPromise = this.proofOrPromise;
    if (proofOrPromise is Future<ZeroKnowledgeSig>) {
      try {
        await proofOrPromise;
      } catch (_) {
        // Failures are reported through the proof fetch callback, so awaiting
        // the (already handled) future here must not rethrow to the caller of
        // waitForProofFetch.
      }
    }
  }

  /// Validates that the Keyless Account can be used to sign transactions.
  ///
  /// Performs the local validity checks (expiry, proof availability, JWT
  /// header shape), then uses the network to check the verification key
  /// against the on-chain configuration and to verify that a JWK matching
  /// the JWT's `kid` exists.
  @override
  Future<void> checkKeylessAccountValidity(
    covariant AptosConfig aptosConfig,
  ) async {
    if (isExpired()) {
      throw StateError('The ephemeral keypair has expired.');
    }
    await waitForProofFetch();
    if (proof == null) {
      throw StateError('The asynchronous proof fetch failed.');
    }
    // SECURITY: the JWT signature is NOT verified here; we only read the
    // `kid` header to compare against the verification key hash. JWT
    // signature verification is performed on-chain by the keyless verifier.
    // Throws if the header is malformed or is missing 'kid'.
    final header = parseJwtHeader(base64UrlDecode(jwt.split('.')[0]));
    final verificationKeyHash = this.verificationKeyHash;
    if (verificationKeyHash != null) {
      final keylessConfig =
          await internal_keyless.getKeylessConfig(aptosConfig: aptosConfig);
      final onChainHash = keylessConfig.verificationKey.hash();
      if (Hex.fromHexInput(onChainHash).toString() !=
          Hex.fromHexInput(verificationKeyHash).toString()) {
        throw StateError(
          'The verification key hash does not match the on-chain '
          'verification key; the key may have rotated, invalidating the '
          'proof. Re-derive the account to fetch a new proof.',
        );
      }
    } else {
      warnIfDevelopment(
        '[Aptos SDK] The verification key hash was not set. Proof may be '
        'invalid if the verification key has rotated.',
      );
    }
    await AbstractKeylessAccount.fetchJWK(
      aptosConfig: aptosConfig,
      publicKey: publicKey,
      kid: header.kid,
    );
  }

  /// Sign the given message using Keyless.
  ///
  /// Throws a [StateError] if the ephemeral key pair is expired or the proof
  /// is not yet fetched.
  @override
  KeylessSignature sign(HexInput message) {
    final expiryDateSecs = ephemeralKeyPair.expiryDateSecs;
    if (isExpired()) {
      throw StateError('The ephemeral keypair has expired.');
    }
    final proof = this.proof;
    if (proof == null) {
      throw StateError(
        'Proof not found - make sure to call '
        '`await account.checkKeylessAccountValidity()` before signing.',
      );
    }
    final ephemeralPublicKey = ephemeralKeyPair.getPublicKey();
    final ephemeralSignature = ephemeralKeyPair.sign(message);

    return KeylessSignature(
      jwtHeader: base64UrlDecode(jwt.split('.')[0]),
      ephemeralCertificate:
          EphemeralCertificate(proof, EphemeralCertificateVariant.zkProof),
      expiryDateSecs: expiryDateSecs,
      ephemeralPublicKey: ephemeralPublicKey,
      ephemeralSignature: ephemeralSignature,
    );
  }

  /// Sign the given transaction with Keyless.
  /// Signs the transaction and proof to guard against proof malleability.
  @override
  KeylessSignature signTransaction(AnyRawTransaction transaction) {
    final proof = this.proof;
    if (proof == null) {
      throw StateError(
        'Proof not found - make sure to call '
        '`await account.checkKeylessAccountValidity()` before signing.',
      );
    }
    final raw = deriveTransactionType(transaction);
    final txnAndProof = TransactionAndProof(raw, proof.proof);
    final signMess = txnAndProof.hash();
    return sign(signMess);
  }

  /// Returns the message to be signed for the given transaction (the hash of
  /// the transaction and proof).
  Uint8List getSigningMessage(AnyRawTransaction transaction) {
    final proof = this.proof;
    if (proof == null) {
      throw StateError(
        'Proof not found - make sure to call '
        '`await account.checkKeylessAccountValidity()` before signing.',
      );
    }
    final raw = deriveTransactionType(transaction);
    final txnAndProof = TransactionAndProof(raw, proof.proof);
    return txnAndProof.hash();
  }

  /// Note - This function is currently incomplete and should only be used to
  /// verify ownership of the KeylessAccount.
  ///
  /// Verifies a signature given the message.
  ///
  /// [jwk] and [keylessConfig] are required for keyless verification; they
  /// are optional named parameters only to satisfy the base [Account]
  /// interface.
  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
    MoveJWK? jwk,
    KeylessConfiguration? keylessConfig,
  }) {
    final publicKey = this.publicKey;
    if (publicKey is KeylessPublicKey) {
      return publicKey.verifySignature(
        message: message,
        signature: signature,
        jwk: jwk,
        keylessConfig: keylessConfig,
      );
    }
    if (publicKey is FederatedKeylessPublicKey) {
      return publicKey.verifySignature(
        message: message,
        signature: signature,
        jwk: jwk,
        keylessConfig: keylessConfig,
      );
    }
    return publicKey.verifySignature(message: message, signature: signature);
  }

  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    return publicKey.verifySignatureAsync(
      aptosConfig: aptosConfig,
      message: message,
      signature: signature,
      options: options,
    );
  }

  /// Fetches the JWK from the on-chain JWK sets for the issuer of
  /// [publicKey] (a [KeylessPublicKey] or [FederatedKeylessPublicKey]),
  /// matching the given [kid].
  static Future<MoveJWK> fetchJWK({
    required AptosConfig aptosConfig,
    required AccountPublicKey publicKey,
    required String kid,
  }) {
    return internal_keyless.fetchJWK(
      aptosConfig: aptosConfig,
      publicKey: publicKey,
      kid: kid,
    );
  }
}

/// A container class to hold a transaction and a proof. It implements
/// CryptoHashable which is used to create the signing message for Keyless
/// transactions. We sign over the proof to ensure non-malleability.
class TransactionAndProof extends Serializable {
  /// The transaction to sign (a BCS-serializable raw transaction instance —
  /// `RawTransaction`, `MultiAgentRawTransaction`, or
  /// `FeePayerRawTransaction`).
  final Serializable transaction;

  /// The zero knowledge proof used in signing the transaction.
  final ZkProof? proof;

  /// The domain separator prefix used when hashing.
  final String domainSeparator = 'APTOS::TransactionAndProof';

  TransactionAndProof(this.transaction, [this.proof]);

  /// Serializes the transaction bytes followed by the optional proof.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(transaction.bcsToBytes());
    serializer.serializeOption(proof);
  }

  /// Hashes the bcs serialized form of the class. This is the Dart corollary
  /// to the BCSCryptoHash macro in aptos-core.
  Uint8List hash() {
    return generateSigningMessage(bcsToBytes(), domainSeparator);
  }
}
