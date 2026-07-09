import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/signature.dart';
import '../core/hex.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../types/move_types.dart';
import '../types/types.dart';
import '../utils/const.dart';
import '../utils/helpers.dart';
import 'account.dart';
import 'ed25519_account.dart';

// NOTE: `AbstractSignature` and `AbstractPublicKey` are defined here next to
// their only consumers. They may be moved to a dedicated
// `lib/src/core/crypto/abstraction.dart` once the crypto module grows one.

/// An opaque signature wrapper produced by an Account Abstraction signer
/// function.
class AbstractSignature extends Signature {
  /// The raw `authenticator` bytes returned by the signer function.
  final Uint8List value;

  AbstractSignature(HexInput value)
      : value = Hex.fromHexInput(value).toUint8List();

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(value);
  }

  static AbstractSignature deserialize(Deserializer deserializer) {
    return AbstractSignature(deserializer.deserializeBytes());
  }
}

/// A placeholder public key for Account Abstraction accounts; it simply
/// wraps the account address (AA accounts have no real public key).
class AbstractPublicKey extends AccountPublicKey {
  /// The address of the abstracted account.
  final AccountAddress accountAddress;

  AbstractPublicKey(this.accountAddress);

  @override
  AuthenticationKey authKey() {
    return AuthenticationKey(data: accountAddress.toUint8List());
  }

  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
  }) {
    throw UnsupportedError(
      'This function is not implemented for AbstractPublicKey.',
    );
  }

  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    throw UnsupportedError(
      'This function is not implemented for AbstractPublicKey.',
    );
  }

  @override
  void serialize(Serializer serializer) {
    throw UnsupportedError(
      'This function is not implemented for AbstractPublicKey.',
    );
  }
}

/// Signer implementation for the Account Abstraction (AA) authentication
/// scheme, where transactions are authenticated by an on-chain Move function
/// instead of a cryptographic key pair.
class AbstractedAccount extends Account {
  @override
  final AbstractPublicKey publicKey;

  @override
  final AccountAddress accountAddress;

  /// The authentication function that will be used to verify the signature,
  /// in the form `moduleAddress::moduleName::functionName`.
  ///
  /// Example: `'0x1::permissioned_delegation::authenticate'`.
  final MoveFunctionId authenticationFunction;

  @override
  SigningScheme get signingScheme => SigningScheme.singleKey;

  /// The signer function; signs transaction digests and returns the
  /// `authenticator` bytes in the `AbstractionAuthData`, wrapped in an
  /// [AbstractSignature].
  AbstractSignature Function(HexInput digest) _signer;

  /// Creates an AbstractedAccount.
  ///
  /// [accountAddress] is the account address of the account. [signer] is the
  /// function that signs the SHA3-256 digest of the transaction signing
  /// message and returns the `authenticator` bytes used in the
  /// `AbstractionAuthData`. [authenticationFunction] is the Move function
  /// used to verify the signature.
  ///
  /// Throws a [StateError] if [authenticationFunction] is not a valid
  /// fully-qualified Move function name.
  AbstractedAccount({
    required this.accountAddress,
    required Uint8List Function(HexInput digest) signer,
    required this.authenticationFunction,
  })  : publicKey = AbstractPublicKey(accountAddress),
        _signer = ((digest) => AbstractSignature(signer(digest))) {
    if (!isValidFunctionInfo(authenticationFunction)) {
      throw StateError(
        'Invalid authentication function $authenticationFunction passed into '
        'AbstractedAccount',
      );
    }
  }

  /// Creates an `AbstractedAccount` from an [Ed25519Account] that has a
  /// permissioned signer function and using the
  /// `0x1::permissioned_delegation::authenticate` function to verify the
  /// signature.
  ///
  /// [signer] is the [Ed25519Account] that can be used to sign permissioned
  /// transactions.
  static AbstractedAccount fromPermissionedSigner({
    required Ed25519Account signer,
    AccountAddress? accountAddress,
  }) {
    return AbstractedAccount(
      signer: (digest) {
        final serializer = Serializer();
        signer.publicKey.serialize(serializer);
        signer.sign(digest).serialize(serializer);
        return serializer.toUint8List();
      },
      accountAddress: accountAddress ?? signer.accountAddress,
      authenticationFunction: '0x1::permissioned_delegation::authenticate',
    );
  }

  /// Generates the account abstraction signing message: the domain-separated
  /// hash prefix followed by the BCS bytes of the
  /// [AccountAbstractionMessage].
  static Uint8List generateAccountAbstractionMessage(
    HexInput message,
    String functionInfo,
  ) {
    final accountAbstractionMessage =
        AccountAbstractionMessage(message, functionInfo);
    return generateSigningMessage(
      accountAbstractionMessage.bcsToBytes(),
      accountAbstractionSigningDataSalt,
    );
  }

  @override
  AccountAuthenticatorAbstraction signWithAuthenticator(HexInput message) {
    final messageBytes = Hex.fromHexInput(message).toUint8List();
    final digest = SHA3Digest(256).process(messageBytes);
    return AccountAuthenticatorAbstraction(
      authenticationFunction,
      digest,
      sign(digest).toUint8Array(),
    );
  }

  @override
  AccountAuthenticatorAbstraction signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    final message = AbstractedAccount.generateAccountAbstractionMessage(
      generateSigningMessageForTransaction(transaction),
      authenticationFunction,
    );
    return signWithAuthenticator(message);
  }

  @override
  AbstractSignature sign(HexInput message) => _signer(message);

  @override
  AbstractSignature signTransaction(AnyRawTransaction transaction) {
    return sign(generateSigningMessageForTransaction(transaction));
  }

  /// Update the signer function for the account. This can be done after
  /// asynchronous operations are complete to update the context of the
  /// signer function.
  ///
  /// [signer] is the new signer function to use for the account.
  void setSigner(HexInput Function(HexInput digest) signer) {
    _signer = (digest) => AbstractSignature(signer(digest));
  }
}
