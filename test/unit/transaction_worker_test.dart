import 'dart:async';

import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/api/management.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/transactions/management/account_sequence_number.dart';
import 'package:aptos/src/transactions/management/async_queue.dart';
import 'package:aptos/src/transactions/management/transaction_worker.dart';
import 'package:aptos/src/transactions/type_tag/type_tag.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/types/move_types.dart';
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:aptos/src/utils/memoize.dart';
import 'package:test/test.dart';

/// A fake client that returns canned responses and records requests.
/// The last response is repeated once the list is exhausted.
class FakeClient implements Client {
  final List<ClientResponse<dynamic>> responses;
  final List<ClientRequest> requests = [];
  int _index = 0;

  FakeClient(this.responses);

  @override
  Future<ClientResponse<dynamic>> provider(ClientRequest requestOptions) async {
    requests.add(requestOptions);
    final response = responses[_index];
    if (_index < responses.length - 1) _index += 1;
    return response;
  }
}

Map<String, dynamic> accountInfoJson(String sequenceNumber) => {
      'sequence_number': sequenceNumber,
      'authentication_key': '0x0123',
    };

Map<String, dynamic> entryFunctionPayloadJson() => {
      'type': 'entry_function_payload',
      'function': '0x1::aptos_account::transfer',
      'type_arguments': <String>[],
      'arguments': <dynamic>[],
    };

Map<String, dynamic> pendingTxnJson(String hash) => {
      'type': 'pending_transaction',
      'hash': hash,
      'sender': '0x1',
      'sequence_number': '0',
      'max_gas_amount': '2000',
      'gas_unit_price': '100',
      'expiration_timestamp_secs': '999999',
      'payload': entryFunctionPayloadJson(),
    };

Map<String, dynamic> userTxnJson(String hash) => {
      'type': 'user_transaction',
      'version': '42',
      'hash': hash,
      'state_change_hash': '0x1',
      'event_root_hash': '0x1',
      'gas_used': '10',
      'success': true,
      'vm_status': 'Executed successfully',
      'accumulator_root_hash': '0x1',
      'changes': <dynamic>[],
      'sender': '0x1',
      'sequence_number': '0',
      'max_gas_amount': '2000',
      'gas_unit_price': '100',
      'expiration_timestamp_secs': '999999',
      'payload': entryFunctionPayloadJson(),
      'events': <dynamic>[],
      'timestamp': '1719000000000000',
    };

/// The ABI of `0x1::aptos_account::transfer_coins`, provided explicitly so
/// the worker does not need a canned module response for the remote ABI
/// fetch.
final EntryFunctionABI coinTransferAbi = EntryFunctionABI(
  typeParameters: const [MoveFunctionGenericTypeParam(constraints: [])],
  parameters: [TypeTagAddress(), TypeTagU64()],
);

InputEntryFunctionData transferData() => InputEntryFunctionData(
      function: '0x1::aptos_account::transfer_coins',
      typeArguments: ['0x1::aptos_coin::AptosCoin'],
      functionArguments: ['0x2', 100],
      abi: coinTransferAbi,
    );

/// Fully offline generation options (mainnet chain id is known statically);
/// the worker supplies the sequence number itself.
InputGenerateTransactionOptions offlineOptions() =>
    const InputGenerateTransactionOptions(
      maxGasAmount: 2000,
      gasUnitPrice: 100,
      expireTimestamp: 999999,
    );

void main() {
  setUp(clearMemoizeCache);

  group('AsyncQueue', () {
    test('enqueues and dequeues in FIFO order', () async {
      final queue = AsyncQueue<int>();
      expect(queue.isEmpty(), isTrue);

      queue.enqueue(1);
      queue.enqueue(2);
      queue.enqueue(3);
      expect(queue.isEmpty(), isFalse);

      expect(await queue.dequeue(), 1);
      expect(await queue.dequeue(), 2);
      expect(await queue.dequeue(), 3);
      expect(queue.isEmpty(), isTrue);
    });

    test('dequeue awaits a future enqueue', () async {
      final queue = AsyncQueue<String>();
      final pending = queue.dequeue();
      expect(queue.pendingDequeueLength(), 1);

      queue.enqueue('hello');
      expect(await pending, 'hello');
      expect(queue.pendingDequeueLength(), 0);
      // The item went straight to the awaiting consumer, not the queue.
      expect(queue.isEmpty(), isTrue);
    });

    test('cancel rejects pending dequeues with AsyncQueueCancelledError',
        () async {
      final queue = AsyncQueue<int>();
      final pending1 = queue.dequeue();
      final pending2 = queue.dequeue();
      queue.enqueue(42); // resolves pending1
      expect(await pending1, 42);

      queue.cancel();
      expect(queue.isCancelled(), isTrue);
      expect(queue.pendingDequeueLength(), 0);
      await expectLater(
        pending2,
        throwsA(isA<AsyncQueueCancelledError>()),
      );

      // Enqueueing again resets the cancelled state and clears the error.
      queue.enqueue(7);
      expect(queue.isCancelled(), isFalse);
      expect(await queue.dequeue(), 7);
    });

    test('cancel empties the backlog', () {
      final queue = AsyncQueue<int>();
      queue.enqueue(1);
      queue.enqueue(2);
      queue.cancel();
      expect(queue.isEmpty(), isTrue);
      expect(queue.isCancelled(), isTrue);
    });
  });

  group('AccountSequenceNumber', () {
    test('initializes from the on-chain state and hands out sequence numbers',
        () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: accountInfoJson('5')),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final account = Account.generate();
      final accountSequenceNumber =
          AccountSequenceNumber(config, account, 30, 100, 10);

      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(5));
      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(6));
      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(7));

      // Only the initialize fetch hit the network.
      expect(client.requests, hasLength(1));
      expect(client.requests.single.url, contains('/accounts/'));
      expect(
        accountSequenceNumber.lastUncommittedNumber,
        BigInt.from(5),
      );
      expect(accountSequenceNumber.currentNumber, BigInt.from(8));
    });

    test(
        'blocks at maximumInFlight and resumes once the on-chain sequence '
        'number advances', () async {
      final client = FakeClient([
        // initialize()
        ClientResponse(status: 200, data: accountInfoJson('5')),
        // update() — still no progress on chain.
        ClientResponse(status: 200, data: accountInfoJson('5')),
        // update() — two transactions committed, the window reopens.
        ClientResponse(status: 200, data: accountInfoJson('7')),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final account = Account.generate();
      final accountSequenceNumber =
          AccountSequenceNumber(config, account, 30, 2, 10);

      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(5));
      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(6));
      // The window (maximumInFlight = 2) is now exhausted: 7 - 5 >= 2. The
      // third call polls the chain until the committed number advances.
      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(7));

      expect(client.requests, hasLength(3));
      expect(
        accountSequenceNumber.lastUncommittedNumber,
        BigInt.from(7),
      );
      expect(accountSequenceNumber.currentNumber, BigInt.from(8));
    });

    test('synchronize polls until the on-chain number catches up', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: accountInfoJson('5')),
        ClientResponse(status: 200, data: accountInfoJson('6')),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final account = Account.generate();
      final accountSequenceNumber =
          AccountSequenceNumber(config, account, 30, 100, 10);

      expect(await accountSequenceNumber.nextSequenceNumber(), BigInt.from(5));
      // current = 6, lastUncommitted = 5 → synchronize must poll once.
      await accountSequenceNumber.synchronize();

      expect(
        accountSequenceNumber.lastUncommittedNumber,
        BigInt.from(6),
      );
      expect(accountSequenceNumber.currentNumber, BigInt.from(6));
    });
  });

  group('TransactionWorker', () {
    test('processes pushed transactions end-to-end and emits events in order',
        () async {
      final client = FakeClient([
        // AccountSequenceNumber.initialize()
        ClientResponse(status: 200, data: accountInfoJson('0')),
        // submit transaction #1 and #2
        ClientResponse(status: 200, data: pendingTxnJson('0xaaa')),
        ClientResponse(status: 200, data: pendingTxnJson('0xbbb')),
        // waitForTransaction #1 and #2
        ClientResponse(status: 200, data: userTxnJson('0xaaa')),
        ClientResponse(status: 200, data: userTxnJson('0xbbb')),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final sender = Account.generate();
      final worker = TransactionWorker(config, sender);

      final events = <TransactionWorkerEvent>[];
      final finished = Completer<void>();
      final subscription = worker.events.listen((event) {
        events.add(event);
        if (event.name == TransactionWorkerEventsEnum.executionFinish &&
            !finished.isCompleted) {
          finished.complete();
        }
      });

      // Queue the payloads, then start the worker.
      await worker.push(transferData(), offlineOptions());
      await worker.push(transferData(), offlineOptions());
      worker.start();
      expect(worker.started, isTrue);
      expect(() => worker.start(), throwsStateError);

      await finished.future.timeout(const Duration(seconds: 10));

      expect(events.map((e) => e.name).toList(), [
        TransactionWorkerEventsEnum.transactionSent,
        TransactionWorkerEventsEnum.transactionExecuted,
        TransactionWorkerEventsEnum.transactionSent,
        TransactionWorkerEventsEnum.transactionExecuted,
        TransactionWorkerEventsEnum.executionFinish,
      ]);
      expect(
        (events[0].data as SuccessEventData).transactionHash,
        '0xaaa',
      );
      expect(
        (events[2].data as SuccessEventData).transactionHash,
        '0xbbb',
      );
      expect(
        (events[4].data as ExecutionFinishEventData).message,
        contains('execute 2 transactions finished'),
      );

      // The histories recorded both transactions with their sequence numbers.
      expect(worker.sentTransactions, hasLength(2));
      expect(worker.sentTransactions[0].$1, '0xaaa');
      expect(worker.sentTransactions[0].$2, BigInt.zero);
      expect(worker.sentTransactions[1].$1, '0xbbb');
      expect(worker.sentTransactions[1].$2, BigInt.one);
      expect(worker.executedTransactions, hasLength(2));
      expect(worker.executedTransactions[0].$1, '0xaaa');
      expect(worker.executedTransactions[1].$1, '0xbbb');

      // The submissions posted BCS bytes to /transactions.
      final submitRequests = client.requests
          .where((r) => r.url.endsWith('/transactions'))
          .toList();
      expect(submitRequests, hasLength(2));

      worker.stop();
      expect(worker.started, isFalse);
      expect(() => worker.stop(), throwsStateError);
      await subscription.cancel();
    });

    test('emits transactionSendFailed when the submission is rejected',
        () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: accountInfoJson('0')),
        // The submission fails with a VM validation error.
        const ClientResponse(
          status: 400,
          statusText: 'Bad Request',
          data: {'message': 'invalid transaction'},
        ),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final sender = Account.generate();
      final worker = TransactionWorker(config, sender);

      final events = <TransactionWorkerEvent>[];
      final finished = Completer<void>();
      final subscription = worker.events.listen((event) {
        events.add(event);
        if (event.name == TransactionWorkerEventsEnum.executionFinish &&
            !finished.isCompleted) {
          finished.complete();
        }
      });

      await worker.push(transferData(), offlineOptions());
      worker.start();
      await finished.future.timeout(const Duration(seconds: 10));

      expect(events.map((e) => e.name).toList(), [
        TransactionWorkerEventsEnum.transactionSendFailed,
        TransactionWorkerEventsEnum.executionFinish,
      ]);
      expect(
        (events[0].data as FailureEventData).error,
        contains('invalid transaction'),
      );
      expect(worker.sentTransactions, hasLength(1));
      expect(worker.sentTransactions.single.$1, 'rejected');
      expect(worker.executedTransactions, isEmpty);

      worker.stop();
      await subscription.cancel();
    });
  });

  group('TransactionManagement (aptos.transaction.batch)', () {
    test('forSingleAccount batches transactions and re-emits worker events',
        () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: accountInfoJson('0')),
        ClientResponse(status: 200, data: pendingTxnJson('0xaaa')),
        ClientResponse(status: 200, data: pendingTxnJson('0xbbb')),
        ClientResponse(status: 200, data: userTxnJson('0xaaa')),
        ClientResponse(status: 200, data: userTxnJson('0xbbb')),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final sender = Account.generate();
      final management = TransactionManagement(config);

      final events = <TransactionWorkerEvent>[];
      final finished = Completer<void>();
      management.events.listen((event) {
        events.add(event);
        if (event.name == TransactionWorkerEventsEnum.executionFinish &&
            !finished.isCompleted) {
          finished.complete();
        }
      });
      final executedHashes = <String>[];
      management
          .on(TransactionWorkerEventsEnum.transactionExecuted)
          .listen((event) {
        executedHashes.add((event.data as SuccessEventData).transactionHash);
      });

      management.forSingleAccount(
        sender: sender,
        data: [transferData(), transferData()],
        options: offlineOptions(),
      );

      await finished.future.timeout(const Duration(seconds: 10));

      expect(identical(management.account, sender), isTrue);
      expect(events.map((e) => e.name).toList(), [
        TransactionWorkerEventsEnum.transactionSent,
        TransactionWorkerEventsEnum.transactionExecuted,
        TransactionWorkerEventsEnum.transactionSent,
        TransactionWorkerEventsEnum.transactionExecuted,
        TransactionWorkerEventsEnum.executionFinish,
      ]);
      expect(executedHashes, ['0xaaa', '0xbbb']);

      management.transactionWorker.stop();
    });
  });
}
