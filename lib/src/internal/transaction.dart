/// This file contains the underlying implementations for the exposed API
/// surface in `api/transaction.dart`. By moving the methods out into a
/// separate file, other namespaces and processes can access these methods
/// without depending on the entire transaction namespace and without having a
/// dependency cycle error.
///
/// NOTE: `waitForIndexer` and the block query helpers are split across files.
/// `waitForIndexer` is indexer-backed and deferred to the indexer task, while
/// `getBlockByVersion`/`getBlockByHeight` live in `internal/general.dart` (see
/// that file). `getGasPriceEstimation` is implemented in
/// `internal/general.dart` (where the transaction building pipeline already
/// depends on it) and re-exported here.
library;

import '../api/aptos_config.dart';
import '../client/get.dart';
import '../errors/errors.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../types/types.dart';
import '../utils/const.dart';
import '../utils/helpers.dart';

export '../errors/errors.dart'
    show WaitForTransactionError, FailedTransactionError;
export 'general.dart' show getGasPriceEstimation;

/// Retrieve a list of transactions based on the specified options.
Future<List<TransactionResponse>> getTransactions({
  required AptosConfig aptosConfig,
  PaginationArgs? options,
}) async {
  final data = await paginateWithCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getTransactions',
    path: 'transactions',
    params: {
      if (options?.offset != null) 'start': options!.offset,
      if (options?.limit != null) 'limit': options!.limit,
    },
  );
  return data
      .map((e) =>
          TransactionResponse.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the transaction details associated with a specific ledger
/// version.
Future<TransactionResponse> getTransactionByVersion({
  required AptosConfig aptosConfig,
  required AnyNumber ledgerVersion,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getTransactionByVersion',
    path: 'transactions/by_version/$ledgerVersion',
  );
  return TransactionResponse.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
}

/// Retrieves transaction details using the specified transaction hash.
Future<TransactionResponse> getTransactionByHash({
  required AptosConfig aptosConfig,
  required HexInput transactionHash,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    path: 'transactions/by_hash/$transactionHash',
    originMethod: 'getTransactionByHash',
  );
  return TransactionResponse.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
}

/// Checks if a transaction is currently pending based on its hash.
///
/// Throws an error if the transaction cannot be retrieved due to reasons
/// other than a 404 status.
Future<bool> isTransactionPending({
  required AptosConfig aptosConfig,
  required HexInput transactionHash,
}) async {
  try {
    final transaction = await getTransactionByHash(
      aptosConfig: aptosConfig,
      transactionHash: transactionHash,
    );
    return transaction.type == TransactionResponseType.pending;
  } on AptosApiError catch (e) {
    if (e.status == 404) {
      return true;
    }
    rethrow;
  }
}

/// Waits for a transaction to be confirmed by its hash, using the fullnode's
/// long-poll endpoint. This function allows you to monitor the status of a
/// transaction until it is finalized.
Future<TransactionResponse> longWaitForTransaction({
  required AptosConfig aptosConfig,
  required HexInput transactionHash,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    path: 'transactions/wait_by_hash/$transactionHash',
    originMethod: 'longWaitForTransaction',
  );
  return TransactionResponse.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
}

/// Waits for a transaction to be confirmed on the blockchain and handles
/// potential errors during the process. This function allows you to monitor
/// the status of a transaction until it is either confirmed or fails.
///
/// [options] - Optional settings for waiting, including `timeoutSecs` (the
/// maximum time to wait for the transaction in seconds, defaults to 20) and
/// `checkSuccess` (whether to check the success status of the transaction,
/// defaults to true).
///
/// Throws a [WaitForTransactionError] if the transaction times out or remains
/// pending, and a [FailedTransactionError] if the transaction fails.
Future<CommittedTransactionResponse> waitForTransaction({
  required AptosConfig aptosConfig,
  required HexInput transactionHash,
  WaitForTransactionOptions? options,
}) async {
  final timeoutSecs = options?.timeoutSecs ?? defaultTxnTimeoutSec;
  final checkSuccess = options?.checkSuccess ?? true;

  var isPending = true;
  var timeElapsed = 0.0;
  TransactionResponse? lastTxn;
  AptosApiError? lastError;
  var backoffIntervalMs = 200.0;
  const backoffMultiplier = 1.5;

  // A response is "settled" when the fullnode has populated the execution
  // result.
  //
  // NOTE: a committed-shaped response whose `success` field has not been
  // filled in yet could also be considered unsettled. The DTOs require
  // `success` on committed responses, so such a partial response fails to
  // parse instead; that window cannot be represented here.
  bool isUnsettled(TransactionResponse? txn) {
    if (txn == null) return true;
    return txn.type == TransactionResponseType.pending;
  }

  // Handles API errors by rethrowing request errors (4xx other than 404) and
  // recording retryable errors (404 and 5xx) as the last error seen.
  void handleAPIError(Object e) {
    // In short, this means we will retry if it was an AptosApiError and the
    // code was 404 or 5xx.
    if (e is! AptosApiError) {
      throw e; // This would be unexpected.
    }
    lastError = e;
    final isRequestError = e.status != 404 && e.status >= 400 && e.status < 500;
    if (isRequestError) {
      throw e;
    }
  }

  // Check to see if the txn is already on the blockchain.
  try {
    lastTxn = await getTransactionByHash(
      aptosConfig: aptosConfig,
      transactionHash: transactionHash,
    );
    isPending = isUnsettled(lastTxn);
  } catch (e) {
    handleAPIError(e);
  }

  // If the transaction is pending, we do a long wait once to avoid polling.
  if (isPending) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      lastTxn = await longWaitForTransaction(
        aptosConfig: aptosConfig,
        transactionHash: transactionHash,
      );
      isPending = isUnsettled(lastTxn);
    } catch (e) {
      handleAPIError(e);
    }
    timeElapsed =
        (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
  }

  // Now we do polling to see if the transaction is still pending.
  while (isPending) {
    if (timeElapsed >= timeoutSecs) {
      break;
    }
    try {
      lastTxn = await getTransactionByHash(
        aptosConfig: aptosConfig,
        transactionHash: transactionHash,
      );

      isPending = isUnsettled(lastTxn);

      if (!isPending) {
        break;
      }
    } catch (e) {
      handleAPIError(e);
    }

    await sleep(backoffIntervalMs.round());
    timeElapsed += backoffIntervalMs / 1000; // Convert to seconds.
    backoffIntervalMs *= backoffMultiplier;
  }

  // There is a chance that lastTxn is still null. Let's throw the last error
  // otherwise a WaitForTransactionError.
  if (lastTxn == null) {
    if (lastError != null) {
      throw lastError!;
    }
    throw WaitForTransactionError(
      'Fetching transaction $transactionHash failed and timed out after '
      '$timeoutSecs seconds',
      lastTxn,
    );
  }

  if (lastTxn.type == TransactionResponseType.pending) {
    throw WaitForTransactionError(
      'Transaction $transactionHash timed out in pending state after '
      '$timeoutSecs seconds',
      lastTxn,
    );
  }
  final committedTxn = lastTxn as CommittedTransactionResponse;
  if (!checkSuccess) {
    return committedTxn;
  }
  if (!committedTxn.success) {
    throw FailedTransactionError(
      'Transaction $transactionHash failed with an error: '
      '${committedTxn.vmStatus}',
      committedTxn,
    );
  }

  return committedTxn;
}

// NOTE: `waitForIndexer` is indexer-backed (it relies on
// `getProcessorStatus`/`getIndexerLastSuccessVersion`) and is deferred to the
// indexer task.
