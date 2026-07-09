/// Drives batched transaction submission and execution tracking.
///
/// Exposes a broadcast [Stream] of [TransactionWorkerEvent]s, with the event
/// names available as the [TransactionWorkerEventsEnum] enum.
library;

import 'dart:async';

import '../../account/account.dart';
import '../../api/aptos_config.dart';
import '../../internal/transaction.dart';
import '../../internal/transaction_submission.dart';
import '../../types/transaction_responses.dart';
import '../instances/simple_transaction.dart';
import '../types.dart';
import 'account_sequence_number.dart';
import 'async_queue.dart';

/// Maximum number of transactions to keep in the history arrays to prevent
/// unbounded memory growth. When this limit is exceeded, the oldest entries
/// are removed.
const int _maxTransactionHistorySize = 10000;

/// The status string recorded for successfully settled submissions.
const String promiseFulfilledStatus = 'fulfilled';

/// Events emitted by the transaction worker during its operation, allowing
/// the dapp to respond to various transaction states.
enum TransactionWorkerEventsEnum {
  /// Fired after a transaction gets sent to the chain.
  transactionSent('transactionSent'),

  /// Fired if there is an error sending the transaction to the chain.
  transactionSendFailed('transactionSendFailed'),

  /// Fired when a single transaction has executed successfully.
  transactionExecuted('transactionExecuted'),

  /// Fired if a single transaction fails in execution.
  transactionExecutionFailed('transactionExecutionFailed'),

  /// Fired when the worker has finished its job / when the queue has been
  /// emptied.
  executionFinish('executionFinish');

  const TransactionWorkerEventsEnum(this.value);

  /// The event name string.
  final String value;
}

/// The base payload for transaction worker events.
abstract class TransactionWorkerEventData {
  final String message;

  const TransactionWorkerEventData({required this.message});
}

/// The payload for when the worker has finished its job.
class ExecutionFinishEventData extends TransactionWorkerEventData {
  const ExecutionFinishEventData({required super.message});
}

/// The payload for a success event.
class SuccessEventData extends TransactionWorkerEventData {
  final String transactionHash;

  const SuccessEventData({
    required super.message,
    required this.transactionHash,
  });
}

/// The payload for a failure event.
class FailureEventData extends TransactionWorkerEventData {
  final String error;

  const FailureEventData({required super.message, required this.error});
}

/// A single event emitted by the [TransactionWorker]: the event name and its
/// payload ([SuccessEventData], [FailureEventData], or
/// [ExecutionFinishEventData]).
class TransactionWorkerEvent {
  final TransactionWorkerEventsEnum name;
  final TransactionWorkerEventData data;

  const TransactionWorkerEvent(this.name, this.data);
}

/// A history entry for a sent or executed transaction: the transaction hash
/// (or settle status when the submission was rejected), the sequence number
/// it was sent with, and the error (if any).
typedef TransactionHistoryEntry = (String, BigInt, Object?);

/// The outcome of an awaited submission: either fulfilled with a value or
/// rejected with a reason.
class _SettledResult<T> {
  final String status;
  final T? value;
  final Object? reason;

  const _SettledResult.fulfilled(T this.value)
      : status = promiseFulfilledStatus,
        reason = null;

  const _SettledResult.rejected(Object this.reason)
      : status = 'rejected',
        value = null;
}

Future<_SettledResult<T>> _settle<T>(Future<T> future) async {
  try {
    return _SettledResult.fulfilled(await future);
  } catch (error) {
    return _SettledResult.rejected(error);
  }
}

/// TransactionWorker provides a simple framework for receiving payloads to be
/// processed.
///
/// Once one `start()`s the process and pushes a new transaction, the worker
/// acquires the current account's next sequence number (by using the
/// [AccountSequenceNumber] class), generates a signed transaction and pushes
/// an async submission process into the `outstandingTransactions` queue. At
/// the same time, the worker processes transactions by reading the
/// `outstandingTransactions` queue and submits the next transaction to chain,
/// it
/// 1) waits for resolution of the submission process or get pre-execution
///    validation error and
/// 2) waits for the resolution of the execution process or get an execution
///    error.
/// The worker fires events for any submission and/or execution success
/// and/or failure.
class TransactionWorker {
  final AptosConfig aptosConfig;

  final Account account;

  /// Current account sequence number manager.
  final AccountSequenceNumber accountSequenceNumber;

  final AsyncQueue<Future<void> Function()> taskQueue =
      AsyncQueue<Future<void> Function()>();

  /// Whether the process has started.
  bool started;

  /// Transaction payloads waiting to be generated and signed.
  final AsyncQueue<
          (
            InputGenerateTransactionPayloadData,
            InputGenerateTransactionOptions?
          )> transactionsQueue =
      AsyncQueue<
          (
            InputGenerateTransactionPayloadData,
            InputGenerateTransactionOptions?
          )>();

  /// Signed transactions waiting to be submitted.
  final AsyncQueue<(Future<PendingTransactionResponse>, BigInt)>
      outstandingTransactions =
      AsyncQueue<(Future<PendingTransactionResponse>, BigInt)>();

  /// Transactions that have been submitted to chain. Limited to
  /// [_maxTransactionHistorySize] entries to prevent unbounded memory growth.
  final List<TransactionHistoryEntry> sentTransactions = [];

  /// Transactions that have been committed to chain. Limited to
  /// [_maxTransactionHistorySize] entries to prevent unbounded memory growth.
  final List<TransactionHistoryEntry> executedTransactions = [];

  final StreamController<TransactionWorkerEvent> _eventsController =
      StreamController<TransactionWorkerEvent>.broadcast();

  /// A broadcast stream of the events fired by this worker.
  Stream<TransactionWorkerEvent> get events => _eventsController.stream;

  /// A broadcast stream filtered to a single event [name].
  Stream<TransactionWorkerEvent> on(TransactionWorkerEventsEnum name) =>
      events.where((event) => event.name == name);

  /// Initializes a new instance of the class, providing a framework for
  /// receiving payloads to be processed.
  ///
  /// [aptosConfig] - A configuration object for Aptos.
  /// [account] - The account that will be used for sending transactions.
  /// [maxWaitTime] - The maximum wait time to wait before re-syncing the
  /// sequence number to the current on-chain state, default is 30 seconds.
  /// [maximumInFlight] - The maximum number of transactions that can be
  /// submitted per account, default is 100.
  /// [sleepTime] - The time to wait before re-evaluating if the maximum
  /// number of transactions are in flight, default is 10.
  TransactionWorker(
    this.aptosConfig,
    this.account, [
    int maxWaitTime = 30,
    int maximumInFlight = 100,
    int sleepTime = 10,
  ])  : started = false,
        accountSequenceNumber = AccountSequenceNumber(
          aptosConfig,
          account,
          maxWaitTime,
          maximumInFlight,
          sleepTime,
        );

  /// Adds a transaction to the history array while enforcing the maximum
  /// size limit. Removes the oldest entries when the limit is exceeded.
  void _addToTransactionHistory(
    List<TransactionHistoryEntry> history,
    TransactionHistoryEntry entry,
  ) {
    history.add(entry);
    // Remove oldest entries if we exceed the limit (remove ~10% when
    // triggered).
    if (history.length > _maxTransactionHistorySize) {
      final removeCount = (_maxTransactionHistorySize * 0.1).ceil();
      history.removeRange(0, removeCount);
    }
  }

  void _emit(
    TransactionWorkerEventsEnum name,
    TransactionWorkerEventData data,
  ) {
    if (!_eventsController.isClosed) {
      _eventsController.add(TransactionWorkerEvent(name, data));
    }
  }

  /// Submits the next transaction for the account by generating it with the
  /// current sequence number and adding it to the outstanding transaction
  /// queue for processing. This function continues to submit transactions
  /// until there are no more to process.
  ///
  /// Throws a [StateError] if the transaction submission fails.
  Future<void> submitNextTransaction() async {
    try {
      while (true) {
        final sequenceNumber = await accountSequenceNumber.nextSequenceNumber();
        if (sequenceNumber == null) return;
        final transaction = await generateNextTransaction(
          account,
          sequenceNumber,
        );
        if (transaction == null) return;
        final pendingTransaction = signAndSubmitTransaction(
          aptosConfig: aptosConfig,
          transaction: transaction,
          signer: account,
        );
        // The future is settled later by `processTransactions`; ignore()
        // prevents an early submission failure from being reported as an
        // unhandled asynchronous error in the meantime.
        pendingTransaction.ignore();
        outstandingTransactions.enqueue((pendingTransaction, sequenceNumber));
      }
    } on AsyncQueueCancelledError {
      return;
    } catch (error) {
      throw StateError(
        'Submit transaction failed for ${account.accountAddress} with error '
        '$error',
      );
    }
  }

  /// Reads the outstanding transaction queue and submits the transactions to
  /// the chain. This function processes each transaction, checking their
  /// status and emitting events based on whether they were successfully sent
  /// or failed.
  ///
  /// Throws a [StateError] if the process execution fails.
  Future<void> processTransactions() async {
    try {
      while (true) {
        final awaitingTransactions = <Future<PendingTransactionResponse>>[];
        final sequenceNumbers = <BigInt>[];
        var (pendingTransaction, sequenceNumber) =
            await outstandingTransactions.dequeue();

        awaitingTransactions.add(pendingTransaction);
        sequenceNumbers.add(sequenceNumber);

        while (!outstandingTransactions.isEmpty()) {
          (pendingTransaction, sequenceNumber) =
              await outstandingTransactions.dequeue();

          awaitingTransactions.add(pendingTransaction);
          sequenceNumbers.add(sequenceNumber);
        }
        // Send awaiting transactions to chain, collecting each outcome
        // regardless of whether it succeeded or failed.
        final settledTransactions = await Future.wait(
          awaitingTransactions.map(_settle),
        );
        for (var i = 0;
            i < settledTransactions.length && i < sequenceNumbers.length;
            i += 1) {
          // Check sent transaction status.
          final sentTransaction = settledTransactions[i];
          sequenceNumber = sequenceNumbers[i];
          if (sentTransaction.status == promiseFulfilledStatus) {
            // Transaction sent to chain.
            final value = sentTransaction.value!;
            _addToTransactionHistory(
              sentTransactions,
              (value.hash, sequenceNumber, null),
            );
            // Check sent transaction execution.
            _emit(
              TransactionWorkerEventsEnum.transactionSent,
              SuccessEventData(
                message: 'transaction hash ${value.hash} has been committed to '
                    'chain',
                transactionHash: value.hash,
              ),
            );
            await checkTransaction(value, sequenceNumber);
          } else {
            // Send transaction failed.
            _addToTransactionHistory(
              sentTransactions,
              (sentTransaction.status, sequenceNumber, sentTransaction.reason),
            );
            _emit(
              TransactionWorkerEventsEnum.transactionSendFailed,
              FailureEventData(
                message:
                    'failed to commit transaction ${sentTransactions.length} '
                    'with error ${sentTransaction.reason}',
                error: '${sentTransaction.reason}',
              ),
            );
          }
        }
        _emit(
          TransactionWorkerEventsEnum.executionFinish,
          ExecutionFinishEventData(
            message:
                'execute ${settledTransactions.length} transactions finished',
          ),
        );
      }
    } on AsyncQueueCancelledError {
      return;
    } catch (error) {
      throw StateError(
        'Process execution failed for ${account.accountAddress} with error '
        '$error',
      );
    }
  }

  /// Once a transaction has been sent to the chain, this function checks for
  /// its execution status.
  ///
  /// [sentTransaction] - The transaction that was sent to the chain and is
  /// now waiting to be executed.
  /// [sequenceNumber] - The account's sequence number that was sent with the
  /// transaction.
  Future<void> checkTransaction(
    PendingTransactionResponse sentTransaction,
    BigInt sequenceNumber,
  ) async {
    try {
      final waitFor = <Future<TransactionResponse>>[
        waitForTransaction(
          aptosConfig: aptosConfig,
          transactionHash: sentTransaction.hash,
        ),
      ];
      final settledTransactions = await Future.wait(waitFor.map(_settle));

      for (final executedTransaction in settledTransactions) {
        if (executedTransaction.status == promiseFulfilledStatus) {
          // Transaction executed on chain.
          final value = executedTransaction.value!;
          _addToTransactionHistory(
            executedTransactions,
            (value.hash, sequenceNumber, null),
          );
          _emit(
            TransactionWorkerEventsEnum.transactionExecuted,
            SuccessEventData(
              message:
                  'transaction hash ${value.hash} has been executed on chain',
              transactionHash: sentTransaction.hash,
            ),
          );
        } else {
          // Transaction execution failed.
          _addToTransactionHistory(
            executedTransactions,
            (
              executedTransaction.status,
              sequenceNumber,
              executedTransaction.reason,
            ),
          );
          _emit(
            TransactionWorkerEventsEnum.transactionExecutionFailed,
            FailureEventData(
              message:
                  'failed to execute transaction ${executedTransactions.length}'
                  ' with error ${executedTransaction.reason}',
              error: '${executedTransaction.reason}',
            ),
          );
        }
      }
    } catch (error) {
      throw StateError(
        'Check transaction failed for ${account.accountAddress} with error '
        '$error',
      );
    }
  }

  /// Pushes a transaction to the transactions queue for processing.
  ///
  /// [transactionData] - The transaction payload containing necessary
  /// details; for entry function payloads, provide the ABI to skip remote
  /// ABI lookups.
  /// [options] - Optional parameters for transaction configuration.
  Future<void> push(
    InputGenerateTransactionPayloadData transactionData, [
    InputGenerateTransactionOptions? options,
  ]) async {
    transactionsQueue.enqueue((transactionData, options));
  }

  /// Generates a transaction that can be signed and submitted to the chain.
  ///
  /// [account] - An Aptos account used as the sender of the transaction.
  /// [sequenceNumber] - A sequence number the transaction will be generated
  /// with.
  ///
  /// Returns the transaction, or `null` if the transaction queue is empty.
  Future<SimpleTransaction?> generateNextTransaction(
    Account account,
    BigInt sequenceNumber,
  ) async {
    if (transactionsQueue.isEmpty()) return null;
    final (transactionData, options) = await transactionsQueue.dequeue();
    return await generateTransaction(
      aptosConfig: aptosConfig,
      sender: account.accountAddress,
      data: transactionData,
      options: InputGenerateTransactionOptions(
        maxGasAmount: options?.maxGasAmount,
        gasUnitPrice: options?.gasUnitPrice,
        expireTimestamp: options?.expireTimestamp,
        accountSequenceNumber: sequenceNumber,
      ),
    ) as SimpleTransaction;
  }

  /// Starts transaction submission and processing by executing tasks from
  /// the queue until it is cancelled.
  ///
  /// Throws a [StateError] if unable to start transaction batching.
  Future<void> run() async {
    try {
      while (!taskQueue.isCancelled()) {
        final task = await taskQueue.dequeue();
        await task();
      }
    } on AsyncQueueCancelledError {
      // Cancellation ends the run loop gracefully rather than surfacing as an
      // unhandled asynchronous error.
      return;
    } catch (error) {
      throw StateError('Unable to start transaction batching: $error');
    }
  }

  /// Starts the transaction management process.
  ///
  /// Throws a [StateError] if the worker has already started.
  void start() {
    if (started) {
      throw StateError('worker has already started');
    }
    started = true;
    taskQueue.enqueue(() => submitNextTransaction());
    taskQueue.enqueue(() => processTransactions());
    unawaited(run());
  }

  /// Stops the transaction management process.
  ///
  /// Throws a [StateError] if the worker has already stopped.
  void stop() {
    if (taskQueue.isCancelled()) {
      throw StateError('worker has already stopped');
    }
    started = false;
    taskQueue.cancel();
  }
}
