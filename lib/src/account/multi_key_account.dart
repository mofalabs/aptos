import 'dart:typed_data';

import '../core/account_address.dart';
import '../core/crypto/multi_key.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/signature.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../types/types.dart';
import 'account.dart';
import 'ed25519_account.dart';
import 'keyless_signer.dart';
import 'single_key_account.dart';

/// Signer implementation for the MultiKey authentication scheme.
///
/// This account utilizes an M of N signing scheme, where M and N are
/// specified in the [MultiKey]. It signs messages using an array of M
/// accounts, each corresponding to a public key in the [MultiKey].
///
/// Note: Generating a signer instance does not create the account on-chain.
class MultiKeyAccount extends Account implements KeylessSigner {
  /// Public key associated with the account.
  @override
  final MultiKey publicKey;

  /// Account address associated with the account.
  @override
  final AccountAddress accountAddress;

  /// Signing scheme used to sign transactions.
  @override
  SigningScheme get signingScheme => SigningScheme.multiKey;

  /// The signers used to sign messages. These signers should correspond to
  /// public keys in the MultiKeyAccount's public key. The number of signers
  /// should be equal to `publicKey.signaturesRequired`.
  final List<Account> signers;

  /// An array of indices where for `signer[i]`, `signerIndicies[i]` is the
  /// index of the corresponding public key in `publicKey.publicKeys`. Used to
  /// derive the right public key to use for verification.
  // TODO: Rename Indicies to Indices.
  final List<int> signerIndicies;

  /// The bitmap representing which public keys from the MultiKey are being
  /// used.
  final Uint8List signaturesBitmap;

  /// Constructs a MultiKeyAccount instance, which requires multiple
  /// signatures for transactions.
  ///
  /// [multiKey] is the multikey of the account consisting of N public keys
  /// and a number M representing the required signatures. [signers] is an
  /// array of M signers that will be used to sign the transaction; each must
  /// be a [SingleKeySigner] or a legacy [Ed25519Account]. [address] is an
  /// optional account address input; if not provided, the derived address
  /// from the public key will be used.
  ///
  /// Throws a [StateError] if the number of signers does not exactly match
  /// the multikey's required signatures, and an [ArgumentError] if a signer
  /// is not a [SingleKeySigner] or [Ed25519Account].
  factory MultiKeyAccount({
    required MultiKey multiKey,
    required List<SingleKeySignerOrLegacyEd25519Account> signers,
    AccountAddressInput? address,
  }) {
    final normalizedSigners = signers.map((signer) {
      if (signer is Ed25519Account) {
        return SingleKeyAccount.fromEd25519Account(signer);
      }
      if (signer is SingleKeySigner) {
        return signer;
      }
      throw ArgumentError(
        'MultiKeyAccount signers must be SingleKeySigner or Ed25519Account '
        'instances, got ${signer.runtimeType}',
      );
    }).toList();

    if (multiKey.signaturesRequired > normalizedSigners.length) {
      throw StateError(
        'Not enough signers provided to satisfy the required signatures. '
        'Need ${multiKey.signaturesRequired} signers, but only '
        '${normalizedSigners.length} provided',
      );
    } else if (multiKey.signaturesRequired < normalizedSigners.length) {
      throw StateError(
        'More signers provided than required. Need '
        '${multiKey.signaturesRequired} signers, but '
        '${normalizedSigners.length} provided',
      );
    }

    final accountAddress = address != null
        ? AccountAddress.from(address)
        : multiKey.authKey().derivedAddress();

    // For each signer, find its corresponding position in the MultiKey's
    // public keys array.
    final bitPositions = <int>[];
    for (final signer in normalizedSigners) {
      bitPositions.add(multiKey.getIndex(signer.getAnyPublicKey()));
    }

    // Create pairs of [signer, position] and sort them by position.
    // This sorting is critical because:
    // 1. The on-chain verification expects signatures to be in ascending
    //    order by bit position.
    // 2. The bitmap must match the order of signatures when verifying.
    final signersAndBitPosition = <(Account, int)>[
      for (var i = 0; i < normalizedSigners.length; i += 1)
        (normalizedSigners[i], bitPositions[i])
    ]..sort((a, b) => a.$2 - b.$2);

    // Create a bitmap representing which public keys from the MultiKey are
    // being used. This bitmap is used during signature verification to
    // identify which public keys should be used to verify each signature.
    final signaturesBitmap = multiKey.createBitmap(bits: bitPositions);

    return MultiKeyAccount._(
      multiKey,
      accountAddress,
      // Extract the sorted signers and their positions into separate arrays.
      signersAndBitPosition.map((value) => value.$1).toList(),
      signersAndBitPosition.map((value) => value.$2).toList(),
      signaturesBitmap,
    );
  }

  MultiKeyAccount._(
    this.publicKey,
    this.accountAddress,
    this.signers,
    this.signerIndicies,
    this.signaturesBitmap,
  );

  /// Static constructor to create a MultiKeyAccount using the provided public
  /// keys and signers.
  ///
  /// [publicKeys] are the N public keys of the MultiKeyAccount.
  /// [signaturesRequired] is the number of signatures required to authorize a
  /// transaction. [signers] is an array of M signers that will be used to
  /// sign the transaction.
  static MultiKeyAccount fromPublicKeysAndSigners({
    AccountAddressInput? address,
    required List<PublicKey> publicKeys,
    required int signaturesRequired,
    required List<SingleKeySignerOrLegacyEd25519Account> signers,
  }) {
    final multiKey = MultiKey(
      publicKeys: publicKeys,
      signaturesRequired: signaturesRequired,
    );
    return MultiKeyAccount(
      multiKey: multiKey,
      signers: signers,
      address: address,
    );
  }

  /// Determines if the provided account is a multi-key account.
  static bool isMultiKeySigner(Account account) => account is MultiKeyAccount;

  /// Signs [message] and returns an authenticator holding the aggregated
  /// signature and the account's public key.
  @override
  AccountAuthenticatorMultiKey signWithAuthenticator(HexInput message) {
    return AccountAuthenticatorMultiKey(publicKey, sign(message));
  }

  /// Signs [transaction] and returns an authenticator holding the aggregated
  /// signature and the account's public key.
  @override
  AccountAuthenticatorMultiKey signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    return AccountAuthenticatorMultiKey(
      publicKey,
      signTransaction(transaction),
    );
  }

  /// Waits for any proofs on KeylessAccount signers to be fetched. This
  /// ensures that signing with the KeylessAccount does not fail due to
  /// missing proofs.
  @override
  Future<void> waitForProofFetch() async {
    final keylessSigners = signers.whereType<KeylessSigner>();
    await Future.wait(
      keylessSigners.map((signer) => signer.waitForProofFetch()),
    );
  }

  /// Validates that the Keyless Account can be used to sign transactions.
  @override
  Future<void> checkKeylessAccountValidity(Object? aptosConfig) async {
    final keylessSigners = signers.whereType<KeylessSigner>();
    await Future.wait(
      keylessSigners
          .map((signer) => signer.checkKeylessAccountValidity(aptosConfig)),
    );
  }

  /// Sign the given message using the MultiKeyAccount's signers.
  @override
  MultiKeySignature sign(HexInput data) {
    final signatures = <Signature>[];
    for (final signer in signers) {
      signatures.add(signer.sign(data));
    }
    return MultiKeySignature(
      signatures: signatures,
      bitmap: signaturesBitmap,
    );
  }

  /// Signs [transaction] with each of the account's signers and aggregates
  /// the results into a single [MultiKeySignature].
  @override
  MultiKeySignature signTransaction(AnyRawTransaction transaction) {
    final signatures = <Signature>[];
    for (final signer in signers) {
      signatures.add(signer.signTransaction(transaction));
    }
    return MultiKeySignature(
      signatures: signatures,
      bitmap: signaturesBitmap,
    );
  }

  /// Verifies [signature] against [message] using the account's public keys.
  ///
  /// Note: for KeylessAccount signers, use `verifySignatureAsync` instead.
  @override
  bool verifySignature({
    required HexInput message,
    required covariant MultiKeySignature signature,
  }) {
    return publicKey.verifySignature(message: message, signature: signature);
  }

  /// Verifies [signature] against [message] using the account's public keys,
  /// fetching any on-chain state required for verification.
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
}
