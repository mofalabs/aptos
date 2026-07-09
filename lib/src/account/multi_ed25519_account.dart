import 'dart:typed_data';

import '../core/account_address.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/multi_ed25519.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/raw_transaction.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../types/types.dart';
import 'account.dart';

/// Signer implementation for the Multi-Ed25519 authentication scheme.
///
/// Note: This authentication scheme is a legacy authentication scheme.
/// Prefer using MultiKeyAccounts as a MultiKeyAccount can support any type of
/// signer, not just Ed25519. Generating a signer instance does not create the
/// account on-chain.
class MultiEd25519Account extends Account {
  @override
  final MultiEd25519PublicKey publicKey;

  @override
  final AccountAddress accountAddress;

  @override
  SigningScheme get signingScheme => SigningScheme.multiEd25519;

  /// The signers used to sign messages. These signers should correspond to
  /// public keys in the MultiEd25519Account. The number of signers should be
  /// equal to `publicKey.threshold`.
  final List<Ed25519PrivateKey> signers;

  /// An array of indices where for `signer[i]`, `signerIndices[i]` is the
  /// index of the corresponding public key in `publicKey.publicKeys`. Used to
  /// derive the right public key to use for verification.
  final List<int> signerIndices;

  /// The bitmap representing which public keys from the
  /// MultiEd25519PublicKey are being used.
  final Uint8List signaturesBitmap;

  // region Constructors

  /// Throws a [StateError] if the number of signers does not exactly match
  /// the public key's threshold.
  factory MultiEd25519Account({
    required MultiEd25519PublicKey publicKey,
    required List<Ed25519PrivateKey> signers,
    AccountAddressInput? address,
  }) {
    final accountAddress = address != null
        ? AccountAddress.from(address)
        : publicKey.authKey().derivedAddress();

    if (publicKey.threshold > signers.length) {
      throw StateError(
        'Not enough signers provided to satisfy the required signatures. '
        'Need ${publicKey.threshold} signers, but only ${signers.length} '
        'provided',
      );
    } else if (publicKey.threshold < signers.length) {
      throw StateError(
        'More signers provided than required. Need ${publicKey.threshold} '
        'signers, but ${signers.length} provided',
      );
    }

    // For each signer, find its corresponding position in the public keys
    // array.
    final bitPositions = <int>[];
    for (final signer in signers) {
      bitPositions.add(publicKey.getIndex(signer.publicKey()));
    }

    // Create pairs of [signer, position] and sort them by position.
    // This sorting is critical because:
    // 1. The on-chain verification expects signatures to be in ascending
    //    order by bit position.
    // 2. The bitmap must match the order of signatures when verifying.
    final signersAndBitPosition = <(Ed25519PrivateKey, int)>[
      for (var i = 0; i < signers.length; i += 1) (signers[i], bitPositions[i])
    ]..sort((a, b) => a.$2 - b.$2);

    // Create a bitmap representing which public keys from the
    // MultiEd25519PublicKey are being used. This bitmap is used during
    // signature verification to identify which public keys should be used to
    // verify each signature.
    final signaturesBitmap = publicKey.createBitmap(bits: bitPositions);

    return MultiEd25519Account._(
      publicKey,
      accountAddress,
      // Extract the sorted signers and their positions into separate arrays.
      signersAndBitPosition.map((value) => value.$1).toList(),
      signersAndBitPosition.map((value) => value.$2).toList(),
      signaturesBitmap,
    );
  }

  MultiEd25519Account._(
    this.publicKey,
    this.accountAddress,
    this.signers,
    this.signerIndices,
    this.signaturesBitmap,
  );

  // endregion

  // region Account

  /// Sign a message using the account's Ed25519 private keys, returning the
  /// AccountAuthenticator containing the signature together with the
  /// account's public key.
  @override
  AccountAuthenticatorMultiEd25519 signWithAuthenticator(HexInput message) {
    return AccountAuthenticatorMultiEd25519(publicKey, sign(message));
  }

  /// Sign a transaction using the account's Ed25519 private keys.
  @override
  AccountAuthenticatorMultiEd25519 signTransactionWithAuthenticator(
    AnyRawTransaction transaction,
  ) {
    return AccountAuthenticatorMultiEd25519(
      publicKey,
      signTransaction(transaction),
    );
  }

  /// Sign the given message using the account's Ed25519 private keys.
  @override
  MultiEd25519Signature sign(HexInput message) {
    final signatures = <Ed25519Signature>[];
    for (final signer in signers) {
      signatures.add(signer.sign(message));
    }
    return MultiEd25519Signature(
      signatures: signatures,
      bitmap: signaturesBitmap,
    );
  }

  /// Sign the given transaction using the available signing capabilities.
  @override
  MultiEd25519Signature signTransaction(AnyRawTransaction transaction) {
    return sign(generateSigningMessageForTransaction(transaction));
  }

  // endregion
}
