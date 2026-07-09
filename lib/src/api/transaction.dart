import 'dart:typed_data';

import '../account/account.dart';
import '../core/account_address.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/public_key.dart';
import '../internal/account.dart' as internal_account;
import '../internal/transaction.dart' as internal_transaction;
import '../internal/transaction_submission.dart'
    as internal_transaction_submission;
import '../transactions/authenticator/account.dart';
import '../transactions/instances/multi_agent_transaction.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/transaction_builder/transaction_builder.dart'
    as transaction_builder;
import '../transactions/types.dart';
import '../types/ledger.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../types/types.dart';
import 'aptos_config.dart';
import 'management.dart';

/// Validates the fee payer data when submitting a transaction to ensure that
/// the fee payer authenticator is provided if a fee payer address is
/// specified.
///
/// The validation is skipped if a custom transaction submitter is defined.
void _validateFeePayerDataOnSubmission({
  required AptosConfig config,
  required AnyRawTransaction transaction,
  AccountAuthenticator? feePayerAuthenticator,
  TransactionSubmitter? transactionSubmitter,
}) {
  // Skip validation if a transaction submitter is defined.
  if (config.getTransactionSubmitter() != null ||
      transactionSubmitter != null) {
    return;
  }

  if (transaction.feePayerAddress != null && feePayerAuthenticator == null) {
    throw StateError(
      'You are submitting a Fee Payer transaction but missing the '
      'feePayerAuthenticator',
    );
  }
}

/// A class to handle all `Build` transaction operations.
class TransactionBuild {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  const TransactionBuild(this.config);

  /// Builds a simple transaction with the specified sender and data.
  ///
  /// [sender] - The sender account address.
  /// [data] - The transaction data.
  /// [options] - Optional transaction configurations.
  /// [withFeePayer] - Whether there is a fee payer for the transaction.
  Future<SimpleTransaction> simple({
    required AccountAddressInput sender,
    required InputGenerateTransactionPayloadData data,
    InputGenerateTransactionOptions? options,
    bool withFeePayer = false,
  }) async {
    return await internal_transaction_submission.generateTransaction(
      aptosConfig: config,
      sender: sender,
      data: data,
      options: options,
      withFeePayer: withFeePayer,
    ) as SimpleTransaction;
  }

  /// Builds a multi-agent transaction that allows multiple signers to
  /// authorize a transaction.
  ///
  /// [secondarySignerAddresses] - An array of the secondary signers' account
  /// addresses.
  Future<MultiAgentTransaction> multiAgent({
    required AccountAddressInput sender,
    required InputGenerateTransactionPayloadData data,
    required List<AccountAddressInput> secondarySignerAddresses,
    InputGenerateTransactionOptions? options,
    bool withFeePayer = false,
  }) async {
    return await internal_transaction_submission.generateTransaction(
      aptosConfig: config,
      sender: sender,
      data: data,
      secondarySignerAddresses: secondarySignerAddresses,
      options: options,
      withFeePayer: withFeePayer,
    ) as MultiAgentTransaction;
  }
}

/// A class to handle all `Simulate` transaction operations.
class TransactionSimulate {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  const TransactionSimulate(this.config);

  /// Simulates a transaction based on the provided parameters and returns
  /// the result. This function helps you understand the outcome of a
  /// transaction before executing it on the blockchain.
  Future<List<UserTransactionResponse>> simple({
    required AnyRawTransaction transaction,
    PublicKey? signerPublicKey,
    PublicKey? feePayerPublicKey,
    InputSimulateTransactionOptions? options,
  }) {
    return internal_transaction_submission.simulateTransaction(
      aptosConfig: config,
      transaction: transaction,
      signerPublicKey: signerPublicKey,
      feePayerPublicKey: feePayerPublicKey,
      options: options,
    );
  }

  /// Simulates a multi-agent transaction by generating a signed transaction
  /// and posting it to the Aptos full node.
  ///
  /// [secondarySignersPublicKeys] - An array of public keys for secondary
  /// signers; individual entries may be `null` to skip the corresponding key
  /// check.
  Future<List<UserTransactionResponse>> multiAgent({
    required AnyRawTransaction transaction,
    PublicKey? signerPublicKey,
    List<PublicKey?>? secondarySignersPublicKeys,
    PublicKey? feePayerPublicKey,
    InputSimulateTransactionOptions? options,
  }) {
    return internal_transaction_submission.simulateTransaction(
      aptosConfig: config,
      transaction: transaction,
      signerPublicKey: signerPublicKey,
      secondarySignersPublicKeys: secondarySignersPublicKeys,
      feePayerPublicKey: feePayerPublicKey,
      options: options,
    );
  }
}

/// A class to handle all `Submit` transaction operations.
class TransactionSubmit {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  const TransactionSubmit(this.config);

  /// Submits a transaction to the Aptos blockchain using the provided
  /// transaction details and authenticators.
  Future<PendingTransactionResponse> simple({
    required AnyRawTransaction transaction,
    required AccountAuthenticator senderAuthenticator,
    AccountAuthenticator? feePayerAuthenticator,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) {
    _validateFeePayerDataOnSubmission(
      config: config,
      transaction: transaction,
      feePayerAuthenticator: feePayerAuthenticator,
      transactionSubmitter: transactionSubmitter,
    );
    return internal_transaction_submission.submitTransaction(
      aptosConfig: config,
      data: InputSubmitTransactionData(
        transaction: transaction,
        senderAuthenticator: senderAuthenticator,
        feePayerAuthenticator: feePayerAuthenticator,
        pluginParams: pluginParams,
        transactionSubmitter: transactionSubmitter,
      ),
    );
  }

  /// Submits a multi-agent transaction to the Aptos network, allowing
  /// multiple signers to authorize the transaction.
  Future<PendingTransactionResponse> multiAgent({
    required AnyRawTransaction transaction,
    required AccountAuthenticator senderAuthenticator,
    required List<AccountAuthenticator> additionalSignersAuthenticators,
    AccountAuthenticator? feePayerAuthenticator,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) {
    _validateFeePayerDataOnSubmission(
      config: config,
      transaction: transaction,
      feePayerAuthenticator: feePayerAuthenticator,
      transactionSubmitter: transactionSubmitter,
    );
    return internal_transaction_submission.submitTransaction(
      aptosConfig: config,
      data: InputSubmitTransactionData(
        transaction: transaction,
        senderAuthenticator: senderAuthenticator,
        additionalSignersAuthenticators: additionalSignersAuthenticators,
        feePayerAuthenticator: feePayerAuthenticator,
        pluginParams: pluginParams,
        transactionSubmitter: transactionSubmitter,
      ),
    );
  }
}

/// Represents a transaction in the Aptos blockchain, providing methods to
/// build, simulate, submit, and manage transactions. This class encapsulates
/// functionalities for querying transaction details, estimating gas prices,
/// signing transactions, and handling transaction states.
class Transaction {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// All `Build` transaction operations (`simple`, `multiAgent`).
  final TransactionBuild build;

  /// All `Simulate` transaction operations (`simple`, `multiAgent`).
  final TransactionSimulate simulate;

  /// All `Submit` transaction operations (`simple`, `multiAgent`).
  final TransactionSubmit submit;

  /// All transaction batching operations (worker-based batch submission for
  /// a single account).
  final TransactionManagement batch;

  /// Creates an instance of the `Transaction` namespace with the specified
  /// configuration.
  Transaction(this.config)
      : build = TransactionBuild(config),
        simulate = TransactionSimulate(config),
        submit = TransactionSubmit(config),
        batch = TransactionManagement(config);

  /// Queries on-chain transactions, excluding pending transactions. Use this
  /// function to retrieve historical transactions from the blockchain.
  Future<List<TransactionResponse>> getTransactions({
    PaginationArgs? options,
  }) {
    return internal_transaction.getTransactions(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries on-chain transaction by version. This function will not return
  /// pending transactions.
  Future<TransactionResponse> getTransactionByVersion({
    required AnyNumber ledgerVersion,
  }) {
    return internal_transaction.getTransactionByVersion(
      aptosConfig: config,
      ledgerVersion: ledgerVersion,
    );
  }

  /// Queries on-chain transactions by their transaction hash, returning both
  /// pending and committed transactions.
  Future<TransactionResponse> getTransactionByHash({
    required HexInput transactionHash,
  }) {
    return internal_transaction.getTransactionByHash(
      aptosConfig: config,
      transactionHash: transactionHash,
    );
  }

  /// Defines if the specified transaction is currently in a pending state.
  Future<bool> isPendingTransaction({required HexInput transactionHash}) {
    return internal_transaction.isTransactionPending(
      aptosConfig: config,
      transactionHash: transactionHash,
    );
  }

  /// Waits for a transaction to move past the pending state and provides the
  /// transaction response. There are 4 cases:
  ///
  /// 1. The transaction is processed and committed to the chain: resolves
  ///    with the transaction response.
  /// 2. The transaction is rejected: throws an `AptosApiError`.
  /// 3. The transaction is committed but execution failed: throws a
  ///    `FailedTransactionError` if `checkSuccess` is true (the default),
  ///    otherwise resolves with the failed transaction response.
  /// 4. The transaction stays pending beyond `timeoutSecs` (default 20
  ///    seconds): throws a `WaitForTransactionError`.
  Future<CommittedTransactionResponse> waitForTransaction({
    required HexInput transactionHash,
    WaitForTransactionOptions? options,
  }) {
    return internal_transaction.waitForTransaction(
      aptosConfig: config,
      transactionHash: transactionHash,
      options: options,
    );
  }

  /// Estimates the gas unit price required to process a transaction on the
  /// Aptos blockchain in a timely manner.
  Future<GasEstimation> getGasPriceEstimation() {
    return internal_transaction.getGasPriceEstimation(aptosConfig: config);
  }

  /// Returns a signing message for a transaction, allowing a user to sign it
  /// using their preferred method before submission to the network.
  Uint8List getSigningMessage({required AnyRawTransaction transaction}) {
    return internal_transaction_submission.getSigningMessage(
      transaction: transaction,
    );
  }

  /// Generates a transaction to publish a Move package to the blockchain.
  ///
  /// To get the [metadataBytes] and [moduleBytecode], can compile using the
  /// Aptos CLI with the command `aptos move compile --save-metadata ...`.
  Future<SimpleTransaction> publishPackageTransaction({
    required AccountAddressInput account,
    required HexInput metadataBytes,
    required List<HexInput> moduleBytecode,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_transaction_submission.publicPackageTransaction(
      aptosConfig: config,
      account: account,
      metadataBytes: metadataBytes,
      moduleBytecode: moduleBytecode,
      options: options,
    );
  }

  /// Rotates the authentication key for a given account. Once an account is
  /// rotated, only the new private key can be used to sign transactions for
  /// the account.
  ///
  /// Provide either [toAccount] (an `Ed25519Account` or
  /// `MultiEd25519Account`) or [toNewPrivateKey].
  Future<SimpleTransaction> rotateAuthKey({
    required Account fromAccount,
    Account? toAccount,
    Ed25519PrivateKey? toNewPrivateKey,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_account.rotateAuthKey(
      aptosConfig: config,
      fromAccount: fromAccount,
      toAccount: toAccount,
      toNewPrivateKey: toNewPrivateKey,
      options: options,
    );
  }

  /// Rotates the authentication key for a given account without verifying
  /// the new key (no proof of ownership of the new key).
  Future<SimpleTransaction> rotateAuthKeyUnverified({
    required Account fromAccount,
    required AccountPublicKey toNewPublicKey,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_account.rotateAuthKeyUnverified(
      aptosConfig: config,
      fromAccount: fromAccount,
      toNewPublicKey: toNewPublicKey,
      options: options,
    );
  }

  /// Signs a transaction that can later be submitted to the chain.
  ///
  /// Returns the [AccountAuthenticator] for the signed transaction.
  AccountAuthenticator sign({
    required Account signer,
    required AnyRawTransaction transaction,
  }) {
    return internal_transaction_submission.signTransaction(
      signer: signer,
      transaction: transaction,
    );
  }

  /// Signs a transaction as a fee payer that can later be submitted to the
  /// chain. The transaction must include a `feePayerAddress`; it is updated
  /// to the signer's address.
  AccountAuthenticator signAsFeePayer({
    required Account signer,
    required AnyRawTransaction transaction,
  }) {
    return internal_transaction_submission.signAsFeePayer(
      signer: signer,
      transaction: transaction,
    );
  }

  /// Generates the user transaction hash that the transaction will have once
  /// submitted, from the transaction and its authenticators.
  String generateUserTransactionHash(InputSubmitTransactionData args) {
    return transaction_builder.generateUserTransactionHash(args);
  }

  // TRANSACTION SUBMISSION //

  /// Signs and submits a single signer transaction to the blockchain.
  ///
  /// For a fee payer (sponsored) transaction, provide either [feePayer] (the
  /// fee payer account, which signs as fee payer) or [feePayerAuthenticator]
  /// (an authenticator already produced by the fee payer), but not both.
  Future<PendingTransactionResponse> signAndSubmitTransaction({
    required Account signer,
    required AnyRawTransaction transaction,
    Account? feePayer,
    AccountAuthenticator? feePayerAuthenticator,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) {
    return internal_transaction_submission.signAndSubmitTransaction(
      aptosConfig: config,
      signer: signer,
      transaction: transaction,
      feePayer: feePayer,
      feePayerAuthenticator: feePayerAuthenticator,
      pluginParams: pluginParams,
      transactionSubmitter: transactionSubmitter,
    );
  }

  /// Signs and submits a single signer transaction as the fee payer to the
  /// chain, given an authenticator by the sender of the transaction.
  Future<PendingTransactionResponse> signAndSubmitAsFeePayer({
    required Account feePayer,
    required AccountAuthenticator senderAuthenticator,
    required AnyRawTransaction transaction,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) {
    return internal_transaction_submission.signAndSubmitAsFeePayer(
      aptosConfig: config,
      feePayer: feePayer,
      senderAuthenticator: senderAuthenticator,
      transaction: transaction,
      pluginParams: pluginParams,
      transactionSubmitter: transactionSubmitter,
    );
  }
}
