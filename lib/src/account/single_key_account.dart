import '../core/account_address.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/private_key.dart';
import '../core/crypto/secp256k1.dart';
import '../core/crypto/single_key.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../types/types.dart';
import 'account.dart';
import 'ed25519_account.dart';

/// An interface which defines if an Account utilizes SingleKey signing.
///
/// Such an account will use the [AnyPublicKey] enum to represent its public
/// key when deriving the auth key.
abstract class SingleKeySigner implements Account {
  AnyPublicKey getAnyPublicKey();
}

/// Determines whether the provided object is a [SingleKeySigner].
bool isSingleKeySigner(Object? obj) => obj is SingleKeySigner;

/// A signer that is either a [SingleKeySigner] or a legacy [Ed25519Account].
///
/// Dart has no union types, so this is an alias of [Account]; values of any
/// other type are rejected at runtime by the consuming APIs.
typedef SingleKeySignerOrLegacyEd25519Account = Account;

/// Signer implementation for the SingleKey authentication scheme, backed by a
/// single private key. The supported signature schemes are Ed25519 and
/// Secp256k1.
///
/// Note: Constructing an instance does not create the account on-chain.
class SingleKeyAccount extends Account implements SingleKeySigner {
  /// Private key associated with the account
  /// (an `Ed25519PrivateKey` or `Secp256k1PrivateKey`).
  final PrivateKeyInput privateKey;

  @override
  final AnyPublicKey publicKey;

  @override
  final AccountAddress accountAddress;

  @override
  SigningScheme get signingScheme => SigningScheme.singleKey;

  /// Creates a SingleKey account from a [privateKey].
  ///
  /// [address] is optional; when omitted, the address is derived from the
  /// public key.
  ///
  /// Throws an [ArgumentError] if [privateKey] is not a supported private
  /// key type.
  factory SingleKeyAccount({
    required PrivateKeyInput privateKey,
    AccountAddressInput? address,
  }) {
    if (privateKey is! PrivateKey) {
      throw ArgumentError(
        'privateKey must be a PrivateKey instance, got '
        '${privateKey.runtimeType}',
      );
    }
    final publicKey = AnyPublicKey(privateKey.publicKey());
    final accountAddress = address != null
        ? AccountAddress.from(address)
        : publicKey.authKey().derivedAddress();
    return SingleKeyAccount._(privateKey, publicKey, accountAddress);
  }

  SingleKeyAccount._(this.privateKey, this.publicKey, this.accountAddress);

  @override
  AnyPublicKey getAnyPublicKey() => publicKey;

  /// Generates an account from a random private key for the given [scheme],
  /// which defaults to Ed25519 and may also be Secp256k1Ecdsa.
  ///
  /// Throws an [ArgumentError] if an unsupported signature scheme is
  /// provided.
  static SingleKeyAccount generate({
    SigningSchemeInput scheme = SigningSchemeInput.ed25519,
  }) {
    final PrivateKey privateKey;
    switch (scheme) {
      case SigningSchemeInput.ed25519:
        privateKey = Ed25519PrivateKey.generate();
      case SigningSchemeInput.secp256k1Ecdsa:
        privateKey = Secp256k1PrivateKey.generate();
    }
    return SingleKeyAccount(privateKey: privateKey);
  }

  /// Derives an account from a BIP44 [path] and [mnemonic], using the given
  /// [scheme] (defaulting to Ed25519).
  ///
  /// [scheme] is the signature scheme to derive the private key with;
  /// defaults to Ed25519. [path] is the BIP44 derive hardened path
  /// (e.g. `m/44'/637'/0'/0'/0'`) for Ed25519, or non-hardened path
  /// (e.g. `m/44'/637'/0'/0/0`) for secp256k1.
  /// Detailed description: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
  /// [mnemonic] is the mnemonic seed phrase of the account.
  static SingleKeyAccount fromDerivationPath({
    SigningSchemeInput scheme = SigningSchemeInput.ed25519,
    required String path,
    required String mnemonic,
  }) {
    final PrivateKey privateKey;
    switch (scheme) {
      case SigningSchemeInput.ed25519:
        privateKey = Ed25519PrivateKey.fromDerivationPath(path, mnemonic);
      case SigningSchemeInput.secp256k1Ecdsa:
        privateKey = Secp256k1PrivateKey.fromDerivationPath(path, mnemonic);
    }
    return SingleKeyAccount(privateKey: privateKey);
  }

  /// Signs [message] and returns an authenticator holding the signature and
  /// the account's public key.
  @override
  AccountAuthenticatorSingleKey signWithAuthenticator(HexInput message) {
    return AccountAuthenticatorSingleKey(publicKey, sign(message));
  }

  /// Signs [transaction] and returns an authenticator holding the signature
  /// and the account's public key.
  @override
  AccountAuthenticatorSingleKey signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    return AccountAuthenticatorSingleKey(
      publicKey,
      signTransaction(transaction),
    );
  }

  /// Sign the given message using the account's private key.
  @override
  AnySignature sign(HexInput message) {
    return AnySignature((privateKey as PrivateKey).sign(message));
  }

  /// Signs the signing message derived from [transaction].
  @override
  AnySignature signTransaction(AnyRawTransaction transaction) {
    return sign(generateSigningMessageForTransaction(transaction));
  }

  /// Creates a SingleKeyAccount from a legacy [Ed25519Account], preserving
  /// the account's address.
  static SingleKeyAccount fromEd25519Account(Ed25519Account account) {
    return SingleKeyAccount(
      privateKey: account.privateKey,
      address: account.accountAddress,
    );
  }
}
