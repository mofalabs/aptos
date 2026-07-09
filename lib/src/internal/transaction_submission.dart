/// This file contains the underlying implementations for the exposed
/// submission API surface in `api/transaction.dart`. By moving the methods
/// out into a separate file, other namespaces and processes can access these
/// methods without depending on the entire transaction namespace and without
/// having a dependency cycle error.
library;

import 'dart:typed_data';

import '../account/account.dart';
import '../account/keyless_signer.dart';
import '../api/aptos_config.dart';
import '../bcs/serializable/move_structs.dart';
import '../client/post.dart';
import '../core/account_address.dart';
import '../core/crypto/public_key.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/instances/transaction_payload.dart';
import '../transactions/transaction_builder/signing_message.dart';
import '../transactions/transaction_builder/transaction_builder.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/transaction_responses.dart';
import '../types/types.dart';

/// Generates any transaction by passing in the required arguments.
///
/// Returns a [SimpleTransaction] when [secondarySignerAddresses] is `null`,
/// and a `MultiAgentTransaction` otherwise.
///
/// [sender] - The transaction sender's account address.
/// [data] - The payload input: entry function, script, or multisig data.
/// [withFeePayer] - Whether this is a fee payer (aka sponsored) transaction.
/// [secondarySignerAddresses] - For multi-agent transactions.
/// [options] - Optional transaction generation options.
Future<AnyRawTransaction> generateTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required InputGenerateTransactionPayloadData data,
  InputGenerateTransactionOptions? options,
  bool withFeePayer = false,
  List<AccountAddressInput>? secondarySignerAddresses,
}) async {
  final payload = await buildTransactionPayload(
    aptosConfig: aptosConfig,
    data: data,
  );
  return buildRawTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    options: options,
    withFeePayer: withFeePayer,
    secondarySignerAddresses: secondarySignerAddresses,
    payload: payload,
  );
}

/// Builds a transaction payload based on the provided configuration and
/// input data. This function is essential for preparing transaction data for
/// execution on the Aptos blockchain.
Future<AnyTransactionPayloadInstance> buildTransactionPayload({
  required AptosConfig aptosConfig,
  required InputGenerateTransactionPayloadData data,
}) {
  // `generateTransactionPayload` dispatches by payload kind: script data
  // needs no remote ABI, while entry function and multisig data merge in the
  // aptosConfig for the remote ABI fetch.
  return generateTransactionPayload(data, aptosConfig);
}

/// Builds a raw transaction from the provided payload. This function helps
/// in creating a transaction that can be sent to the Aptos blockchain.
Future<AnyRawTransaction> buildRawTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required AnyTransactionPayloadInstance payload,
  InputGenerateTransactionOptions? options,
  bool withFeePayer = false,
  List<AccountAddressInput>? secondarySignerAddresses,
}) {
  AccountAddressInput? feePayerAddress;
  if (withFeePayer) {
    feePayerAddress = AccountAddress.zero.toString();
  }

  return buildTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    payload: payload,
    options: options,
    secondarySignerAddresses: secondarySignerAddresses,
    feePayerAddress: feePayerAddress,
  );
}

/// Builds a signing message that can be signed by external signers.
///
/// Note: Please prefer using `signTransaction` unless signing outside the
/// SDK.
Uint8List getSigningMessage({required AnyRawTransaction transaction}) {
  return generateSigningMessageForTransaction(transaction);
}

/// Signs a transaction that can later be submitted to the chain.
///
/// Returns the signer [AccountAuthenticator].
AccountAuthenticator signTransaction({
  required Account signer,
  required AnyRawTransaction transaction,
}) {
  return signer.signTransactionWithAuthenticator(transaction);
}

/// Signs a fee payer transaction as the fee payer: sets the transaction's
/// fee payer address to the signer's address, then signs the transaction.
AccountAuthenticator signAsFeePayer({
  required Account signer,
  required AnyRawTransaction transaction,
}) {
  // If the transaction doesn't hold a "feePayerAddress" it means this is not
  // a fee payer transaction.
  if (transaction.feePayerAddress == null) {
    throw StateError('Transaction $transaction is not a Fee Payer transaction');
  }

  // Set the feePayerAddress to the signer account address.
  transaction.feePayerAddress = signer.accountAddress;

  return signTransaction(signer: signer, transaction: transaction);
}

/// Error message thrown when `simulateTransaction` is called with an
/// encrypted payload. Simulation is not supported for encrypted transactions;
/// build the same entry function without encryption, simulate that
/// transaction, then build with encryption for submit.
const String encryptedTransactionSimulationNotSupportedMessage =
    'Transaction simulation is not supported for encrypted payloads. Build a '
    'plaintext transaction with the same entry function and simulate it, then '
    'build with options.encrypted true for submission.';

/// Throws if the transaction cannot be simulated because its payload is
/// encrypted.
void assertSimulatableTransaction(AnyRawTransaction transaction) {
  if (transaction.rawTransaction.payload
      is TransactionPayloadEncryptedPayload) {
    throw StateError(encryptedTransactionSimulationNotSupportedMessage);
  }
}

/// Simulates a transaction before signing it to evaluate its potential
/// outcome.
///
/// [signerPublicKey] - Optional. The signer public key; when `null` the
/// public/auth key check is skipped during simulation.
/// [secondarySignersPublicKeys] - Optional. For when the transaction involves
/// multiple signers.
/// [feePayerPublicKey] - Optional. For when the transaction is sponsored by a
/// fee payer.
/// [options] - Optional simulation options (gas estimation flags).
Future<List<UserTransactionResponse>> simulateTransaction({
  required AptosConfig aptosConfig,
  required AnyRawTransaction transaction,
  PublicKey? signerPublicKey,
  List<PublicKey?>? secondarySignersPublicKeys,
  PublicKey? feePayerPublicKey,
  InputSimulateTransactionOptions? options,
}) async {
  assertSimulatableTransaction(transaction);

  final signedTransaction = await generateSignedTransactionForSimulation(
    InputSimulateTransactionData(
      transaction: transaction,
      signerPublicKey: signerPublicKey,
      secondarySignersPublicKeys: secondarySignersPublicKeys,
      feePayerPublicKey: feePayerPublicKey,
      options: options,
    ),
  );

  Future<List<UserTransactionResponse>> post({
    required bool estimateMaxGasAmount,
  }) async {
    final response = await postAptosFullNode(
      aptosConfig: aptosConfig,
      body: signedTransaction,
      path: 'transactions/simulate',
      params: {
        'estimate_gas_unit_price': options?.estimateGasUnitPrice ?? false,
        'estimate_max_gas_amount': estimateMaxGasAmount,
        'estimate_prioritized_gas_unit_price':
            options?.estimatePrioritizedGasUnitPrice ?? false,
      },
      originMethod: 'simulateTransaction',
      contentType: MimeType.bcsSignedTransaction,
    );
    return (response.data as List)
        .map((e) => UserTransactionResponse.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  final data = await post(
    estimateMaxGasAmount: options?.estimateMaxGasAmount ?? false,
  );

  // If the server's gas estimation produced a value below the network
  // minimum, retry without estimation so the transaction's original
  // max_gas_amount is used.
  if ((options?.estimateMaxGasAmount ?? false) &&
      data.isNotEmpty &&
      data.first.vmStatus ==
          'MAX_GAS_UNITS_BELOW_MIN_TRANSACTION_GAS_UNITS') {
    return post(estimateMaxGasAmount: false);
  }

  return data;
}

/// Submits a transaction to the Aptos blockchain.
///
/// When a `transactionSubmitter` is provided on [data] it is used; otherwise
/// the transaction submitter configured via
/// `AptosConfig.pluginSettings` is used (unless ignored via
/// `setIgnoreTransactionSubmitter`); otherwise the transaction is submitted
/// directly to the fullnode.
///
/// Returns a [PendingTransactionResponse] containing the status of the
/// submitted transaction.
Future<PendingTransactionResponse> submitTransaction({
  required AptosConfig aptosConfig,
  required InputSubmitTransactionData data,
}) async {
  final maybeTransactionSubmitter =
      data.transactionSubmitter ?? aptosConfig.getTransactionSubmitter();
  if (maybeTransactionSubmitter != null) {
    return maybeTransactionSubmitter.submitTransaction(
      aptosConfig: aptosConfig,
      transaction: data.transaction,
      senderAuthenticator: data.senderAuthenticator,
      feePayerAuthenticator: data.feePayerAuthenticator,
      additionalSignersAuthenticators: data.additionalSignersAuthenticators,
      pluginParams: data.pluginParams,
    );
  }
  final signedTransaction = generateSignedTransaction(data);
  // NOTE: a best-effort keyless JWK refresh diagnostic could be attempted
  // when submission fails for a keyless sender, but it is not done here; the
  // original submission error is always thrown.
  final response = await postAptosFullNode(
    aptosConfig: aptosConfig,
    body: signedTransaction,
    path: 'transactions',
    originMethod: 'submitTransaction',
    contentType: MimeType.bcsSignedTransaction,
  );
  return PendingTransactionResponse.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
}

/// Signs and submits a single signer transaction to the blockchain.
///
/// Exactly one of [feePayer] or [feePayerAuthenticator] may be provided for a
/// fee payer transaction.
Future<PendingTransactionResponse> signAndSubmitTransaction({
  required AptosConfig aptosConfig,
  required Account signer,
  required AnyRawTransaction transaction,
  Account? feePayer,
  AccountAuthenticator? feePayerAuthenticator,
  Map<String, Object?>? pluginParams,
  TransactionSubmitter? transactionSubmitter,
}) async {
  if (feePayer != null && feePayerAuthenticator != null) {
    throw ArgumentError(
      'Cannot provide both feePayer and feePayerAuthenticator',
    );
  }
  // If the signer contains a KeylessAccount, await proof fetching in case the
  // proof was fetched asynchronously.
  if (isKeylessSigner(signer)) {
    await (signer as KeylessSigner).checkKeylessAccountValidity(aptosConfig);
  }
  if (isKeylessSigner(feePayer)) {
    await (feePayer as KeylessSigner).checkKeylessAccountValidity(aptosConfig);
  }
  if (transaction.rawTransaction.payload
          is TransactionPayloadEncryptedPayload &&
      (isKeylessSigner(signer) || isKeylessSigner(feePayer))) {
    throw StateError(
      'Encrypted transactions are not supported with keyless or federated '
      'keyless signers (signature mutability breaks payload binding).',
    );
  }
  final resolvedFeePayerAuthenticator = feePayerAuthenticator ??
      (feePayer != null
          ? signAsFeePayer(signer: feePayer, transaction: transaction)
          : null);

  final senderAuthenticator =
      signTransaction(signer: signer, transaction: transaction);
  return submitTransaction(
    aptosConfig: aptosConfig,
    data: InputSubmitTransactionData(
      transaction: transaction,
      senderAuthenticator: senderAuthenticator,
      feePayerAuthenticator: resolvedFeePayerAuthenticator,
      pluginParams: pluginParams,
      transactionSubmitter: transactionSubmitter,
    ),
  );
}

/// Signs a fee payer transaction as the fee payer and submits it to the
/// chain, given an authenticator produced by the sender of the transaction.
Future<PendingTransactionResponse> signAndSubmitAsFeePayer({
  required AptosConfig aptosConfig,
  required Account feePayer,
  required AccountAuthenticator senderAuthenticator,
  required AnyRawTransaction transaction,
  Map<String, Object?>? pluginParams,
  TransactionSubmitter? transactionSubmitter,
}) async {
  if (isKeylessSigner(feePayer)) {
    await (feePayer as KeylessSigner).checkKeylessAccountValidity(aptosConfig);
  }

  final feePayerAuthenticator =
      signAsFeePayer(signer: feePayer, transaction: transaction);

  return submitTransaction(
    aptosConfig: aptosConfig,
    data: InputSubmitTransactionData(
      transaction: transaction,
      senderAuthenticator: senderAuthenticator,
      feePayerAuthenticator: feePayerAuthenticator,
      pluginParams: pluginParams,
      transactionSubmitter: transactionSubmitter,
    ),
  );
}

// Lazy-initialized to avoid circular dependency issues at module load time.
EntryFunctionABI? _packagePublishAbi;
EntryFunctionABI _getPackagePublishAbi() {
  return _packagePublishAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [TypeTagVector.u8(), TypeTagVector(TypeTagVector.u8())],
  );
}

/// Publishes a package transaction to the Aptos blockchain. This function
/// allows you to create and send a transaction that publishes a package with
/// the specified metadata and bytecode.
///
/// [account] - The address of the account sending the transaction.
/// [metadataBytes] - The metadata associated with the package, as hex input.
/// [moduleBytecode] - An array of module bytecode, each as hex input.
Future<SimpleTransaction> publicPackageTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput account,
  required HexInput metadataBytes,
  required List<HexInput> moduleBytecode,
  InputGenerateTransactionOptions? options,
}) async {
  final totalByteCode =
      moduleBytecode.map((bytecode) => MoveVector.u8(bytecode)).toList();

  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(account),
    data: InputEntryFunctionData(
      function: '0x1::code::publish_package_txn',
      functionArguments: [
        MoveVector.u8(metadataBytes),
        MoveVector(totalByteCode),
      ],
      abi: _getPackagePublishAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}
