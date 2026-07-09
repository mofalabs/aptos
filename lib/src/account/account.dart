import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/signature.dart';
import '../core/crypto/single_key.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../types/types.dart';
import 'ed25519_account.dart';
import 'single_key_account.dart';

/// Base type for all Aptos accounts.
///
/// Acts as the common entry point for account creation via [Account.generate]
/// or [Account.fromDerivationPath]. Though declared abstract, it is meant to
/// be used as an interface (via `implements`).
///
/// Note: Constructing an account instance does not create the account
/// on-chain.
abstract class Account {
  /// Public key associated with the account.
  AccountPublicKey get publicKey;

  /// Account address associated with the account.
  AccountAddress get accountAddress;

  /// Signing scheme used to sign transactions.
  SigningScheme get signingScheme;

  /// Generates a new account for the given signing [scheme].
  ///
  /// [scheme] defaults to Ed25519. [legacy] defaults to true and selects the
  /// legacy account representation.
  ///
  /// Returns an [Ed25519Account] when [scheme] is Ed25519 and [legacy] is
  /// true, otherwise a [SingleKeyAccount].
  static Account generate({
    SigningSchemeInput scheme = SigningSchemeInput.ed25519,
    bool legacy = true,
  }) {
    if (scheme == SigningSchemeInput.ed25519 && legacy) {
      return Ed25519Account.generate();
    }
    return SingleKeyAccount.generate(scheme: scheme);
  }

  /// Creates an account from a [privateKey] and optional [address].
  ///
  /// [privateKey] is an `Ed25519PrivateKey` or `Secp256k1PrivateKey`.
  /// [legacy] defaults to true and selects the legacy account representation.
  ///
  /// Returns an [Ed25519Account] for a legacy Ed25519 key, otherwise a
  /// [SingleKeyAccount].
  static Account fromPrivateKey({
    required PrivateKeyInput privateKey,
    AccountAddressInput? address,
    bool legacy = true,
  }) {
    if (privateKey is Ed25519PrivateKey && legacy) {
      return Ed25519Account(privateKey: privateKey, address: address);
    }
    return SingleKeyAccount(privateKey: privateKey, address: address);
  }

  /// Instantiates an account using a private key and a specified account
  /// address. This is primarily used to instantiate an [Account] that has had
  /// its authentication key rotated.
  @Deprecated('use fromPrivateKey instead.')
  static Account fromPrivateKeyAndAddress({
    required PrivateKeyInput privateKey,
    AccountAddressInput? address,
    bool legacy = true,
  }) {
    return Account.fromPrivateKey(
      privateKey: privateKey,
      address: address,
      legacy: legacy,
    );
  }

  /// Derives an account from a [mnemonic] and derivation [path].
  ///
  /// [scheme] is the signing scheme to derive with; defaults to Ed25519.
  /// [legacy] defaults to true and selects the legacy account representation.
  static Account fromDerivationPath({
    SigningSchemeInput scheme = SigningSchemeInput.ed25519,
    required String path,
    required String mnemonic,
    bool legacy = true,
  }) {
    if (scheme == SigningSchemeInput.ed25519 && legacy) {
      return Ed25519Account.fromDerivationPath(path: path, mnemonic: mnemonic);
    }
    return SingleKeyAccount.fromDerivationPath(
      scheme: scheme,
      path: path,
      mnemonic: mnemonic,
    );
  }

  /// Returns the authentication key derived from [publicKey]. The auth key can
  /// be rotated to change an account's keys without changing its address.
  /// See: https://aptos.dev/concepts/accounts#single-signer-authentication
  static AuthenticationKey authKey({required AccountPublicKey publicKey}) {
    return publicKey.authKey();
  }

  /// Sign a message using the available signing capabilities.
  ///
  /// [message] is the signing message, as binary input. Returns the
  /// [AccountAuthenticator] containing the signature, together with the
  /// account's public key.
  AccountAuthenticator signWithAuthenticator(HexInput message);

  /// Sign a transaction using the available signing capabilities.
  ///
  /// [transaction] is the raw transaction. Returns the [AccountAuthenticator]
  /// containing the signature of the transaction, together with the account's
  /// public key.
  AccountAuthenticator signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  );

  /// Sign the given message using the available signing capabilities.
  ///
  /// [message] is in [HexInput] format.
  Signature sign(HexInput message);

  /// Sign the given transaction using the available signing capabilities.
  Signature signTransaction(AnyRawTransaction transaction);

  /// Verifies [signature] against [message] using the account's public key.
  bool verifySignature({
    required HexInput message,
    required Signature signature,
  }) {
    return publicKey.verifySignature(message: message, signature: signature);
  }

  /// Verify the given message and signature with the public key. It fetches
  /// any on-chain state if needed for verification.
  // TODO: type [aptosConfig] as AptosConfig once the api module is available.
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
}
