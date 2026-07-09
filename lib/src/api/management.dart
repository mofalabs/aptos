import 'dart:async';

import '../account/account.dart';
import '../transactions/management/transaction_worker.dart';
import '../transactions/types.dart';
import 'aptos_config.dart';

/// A class for managing batch transaction submission for a single account
/// via a background [TransactionWorker].
///
/// The worker's events are re-exposed as a broadcast [Stream] of
/// [TransactionWorkerEvent]s.
class TransactionManagement {
  /// The account the worker is currently sending transactions for. Set by
  /// [forSingleAccount].
  late Account account;

  /// The transaction worker doing the batching. Set by [forSingleAccount].
  late TransactionWorker transactionWorker;

  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  final StreamController<TransactionWorkerEvent> _eventsController =
      StreamController<TransactionWorkerEvent>.broadcast();

  /// Initializes a new instance of the `TransactionManagement` namespace
  /// with the provided configuration.
  TransactionManagement(this.config);

  /// A broadcast stream of the events fired by the underlying transaction
  /// worker.
  Stream<TransactionWorkerEvent> get events => _eventsController.stream;

  /// A broadcast stream filtered to a single event [name].
  Stream<TransactionWorkerEvent> on(TransactionWorkerEventsEnum name) =>
      events.where((event) => event.name == name);

  /// Initializes the transaction worker using the provided sender account
  /// and begins listening for events. This function is essential for setting
  /// up the transaction processing environment.
  ///
  /// [sender] - The sender account to sign and submit the transactions.
  void _start({required Account sender}) {
    account = sender;
    transactionWorker = TransactionWorker(config, sender);

    transactionWorker.start();
    _registerToEvents();
  }

  /// Pushes transaction data to the transaction worker for processing.
  ///
  /// [data] - An array of transaction payloads to be processed.
  /// [options] - Optional transaction generation configurations (excluding
  /// `accountSequenceNumber`, which the worker manages).
  void _push({
    required List<InputGenerateTransactionPayloadData> data,
    InputGenerateTransactionOptions? options,
  }) {
    for (final d in data) {
      unawaited(transactionWorker.push(d, options));
    }
  }

  /// Starts listening to transaction worker events, re-emitting them on this
  /// class's [events] stream, allowing the application to respond to
  /// transaction status changes.
  void _registerToEvents() {
    transactionWorker.events.listen((event) {
      if (!_eventsController.isClosed) {
        _eventsController.add(event);
      }
    });
  }

  /// Send batch transactions for a single account.
  ///
  /// This function uses a transaction worker that receives payloads to be
  /// processed and submitted to chain. Note that this process is best for
  /// submitting multiple transactions that don't rely on each other, i.e.
  /// batch funds, batch token mints, etc.
  ///
  /// If any worker failure, the function throws an error.
  ///
  /// [sender] - The sender account to sign and submit the transaction.
  /// [data] - An array of transaction payloads.
  /// [options] - Optional transaction generation configurations (excluding
  /// `accountSequenceNumber`).
  void forSingleAccount({
    required Account sender,
    required List<InputGenerateTransactionPayloadData> data,
    InputGenerateTransactionOptions? options,
  }) {
    try {
      _start(sender: sender);

      _push(data: data, options: options);
    } catch (error) {
      throw StateError('failed to submit transactions with error: $error');
    }
  }
}
