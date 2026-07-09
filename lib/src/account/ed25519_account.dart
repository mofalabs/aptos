import '../core/account_address.dart';
import '../core/crypto/ed25519.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../types/types.dart';
import 'account.dart';

/// An account backed by an Ed25519 key pair, providing message and
/// transaction signing.
///
/// Note: Constructing an instance does not create the account on-chain.
class Ed25519Account extends Account {
  /// Private key associated with the account.
  final Ed25519PrivateKey privateKey;

  @override
  final Ed25519PublicKey publicKey;

  @override
  final AccountAddress accountAddress;

  @override
  SigningScheme get signingScheme => SigningScheme.ed25519;

  // region Constructors

  /// Creates an Ed25519 account from a [privateKey].
  ///
  /// [address] is optional; when omitted, the address is derived from the
  /// public key.
  factory Ed25519Account({
    required Ed25519PrivateKey privateKey,
    AccountAddressInput? address,
  }) {
    final publicKey = privateKey.publicKey();
    final accountAddress = address != null
        ? AccountAddress.from(address)
        : publicKey.authKey().derivedAddress();
    return Ed25519Account._(privateKey, publicKey, accountAddress);
  }

  Ed25519Account._(this.privateKey, this.publicKey, this.accountAddress);

  /// Generates a new Ed25519 account from a randomly generated private key.
  static Ed25519Account generate() {
    final privateKey = Ed25519PrivateKey.generate();
    return Ed25519Account(privateKey: privateKey);
  }

  /// Derives an Ed25519 account using a specified BIP44 path and mnemonic
  /// seed phrase.
  ///
  /// [path] is the BIP44 derive hardened path, e.g. `m/44'/637'/0'/0'/0'`.
  /// Detailed description: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
  /// [mnemonic] is the mnemonic seed phrase of the account.
  static Ed25519Account fromDerivationPath({
    required String path,
    required String mnemonic,
  }) {
    final privateKey = Ed25519PrivateKey.fromDerivationPath(path, mnemonic);
    return Ed25519Account(privateKey: privateKey);
  }

  // endregion

  // region Account

  /// Signs [message] and returns an authenticator holding the Ed25519
  /// signature and the account's public key.
  @override
  AccountAuthenticatorEd25519 signWithAuthenticator(HexInput message) {
    return AccountAuthenticatorEd25519(publicKey, privateKey.sign(message));
  }

  /// Signs [transaction] and returns an authenticator holding the Ed25519
  /// signature and the account's public key.
  @override
  AccountAuthenticatorEd25519 signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    return AccountAuthenticatorEd25519(
      publicKey,
      signTransaction(transaction),
    );
  }

  /// Sign the given message using the account's Ed25519 private key.
  @override
  Ed25519Signature sign(HexInput message) {
    return privateKey.sign(message);
  }

  /// Signs the signing message derived from [transaction].
  @override
  Ed25519Signature signTransaction(AnyRawTransaction transaction) {
    return sign(generateSigningMessageForTransaction(transaction));
  }

  // endregion
}
