import 'dart:typed_data';

import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/api/account.dart';
import 'package:aptos/src/api/aptos.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/api/coin.dart';
import 'package:aptos/src/api/faucet.dart';
import 'package:aptos/src/api/general.dart';
import 'package:aptos/src/api/table.dart';
import 'package:aptos/src/api/transaction.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/errors/errors.dart';
import 'package:aptos/src/transactions/authenticator/account.dart';
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/type_tag/type_tag.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/types/api_extras.dart';
import 'package:aptos/src/types/ledger.dart';
import 'package:aptos/src/types/move_types.dart';
import 'package:aptos/src/types/pagination.dart';
import 'package:aptos/src/types/transaction_responses.dart';
import 'package:aptos/src/types/types.dart';
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

/// A fake transaction submitter plugin that records invocations.
class FakeTransactionSubmitter implements TransactionSubmitter {
  int calls = 0;

  @override
  Future<PendingTransactionResponse> submitTransaction({
    required AptosConfig aptosConfig,
    required AnyRawTransaction transaction,
    required AccountAuthenticator senderAuthenticator,
    AccountAuthenticator? feePayerAuthenticator,
    List<AccountAuthenticator>? additionalSignersAuthenticators,
    Map<String, Object?>? pluginParams,
  }) async {
    calls += 1;
    return PendingTransactionResponse.fromJson(pendingTxnJson('0xplugin'));
  }
}

const String devnetFullnode = 'https://api.devnet.aptoslabs.com/v1';

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

Map<String, dynamic> userTxnJson({
  String hash = '0xabc',
  bool success = true,
  String vmStatus = 'Executed successfully',
}) =>
    {
      'type': 'user_transaction',
      'version': '42',
      'hash': hash,
      'state_change_hash': '0x1',
      'event_root_hash': '0x1',
      'gas_used': '10',
      'success': success,
      'vm_status': vmStatus,
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

Map<String, dynamic> ledgerInfoJson({int chainId = 4}) => {
      'chain_id': chainId,
      'epoch': '5',
      'ledger_version': '100',
      'oldest_ledger_version': '0',
      'ledger_timestamp': '1719000000000000',
      'node_role': 'full_node',
      'oldest_block_height': '0',
      'block_height': '50',
    };

/// The ABI of `0x1::aptos_account::transfer_coins`, provided explicitly so
/// tests do not need a canned module response for the remote ABI fetch.
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

/// Builds a mainnet transaction fully offline (chain id is known statically,
/// all options are explicit, and the ABI is provided).
Future<SimpleTransaction> buildOfflineTransaction(Aptos aptos,
    {required Account sender}) {
  return aptos.transaction.build.simple(
    sender: sender.accountAddress,
    data: transferData(),
    options: InputGenerateTransactionOptions(
      maxGasAmount: 2000,
      gasUnitPrice: 100,
      expireTimestamp: 999999,
      accountSequenceNumber: BigInt.zero,
    ),
  );
}

void main() {
  setUp(clearMemoizeCache);

  group('Aptos facade', () {
    test('constructs with a default config and exposes namespaces', () {
      final aptos = Aptos();
      expect(aptos.config.network, equals(Network.devnet));

      expect(aptos.account, isA<AccountApi>());
      expect(aptos.coin, isA<Coin>());
      expect(aptos.general, isA<General>());
      expect(aptos.faucet, isA<Faucet>());
      expect(aptos.table, isA<Table>());
      expect(aptos.transaction, isA<Transaction>());

      // Namespace instances are cached and share the facade config.
      expect(identical(aptos.transaction, aptos.transaction), isTrue);
      expect(identical(aptos.account.config, aptos.config), isTrue);

      // build/simulate/submit live only under aptos.transaction.
      expect(aptos.transaction.build, isA<TransactionBuild>());
      expect(aptos.transaction.simulate, isA<TransactionSimulate>());
      expect(aptos.transaction.submit, isA<TransactionSubmit>());
    });
  });

  group('account + general queries', () {
    test('getAccountInfo hits accounts/{address} and parses the response',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'sequence_number': '7',
          'authentication_key': '0x0123',
        }),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final info = await aptos.getAccountInfo(accountAddress: '0x1');

      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(request.method, equals('GET'));
      // Special addresses are rendered in short form.
      expect(request.url, equals('$devnetFullnode/accounts/0x1'));
      expect(info.sequenceNumber, equals('7'));
      expect(info.authenticationKey, equals('0x0123'));
    });

    test('getLedgerInfo hits the fullnode root and parses the response',
        () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: ledgerInfoJson(chainId: 4)),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final ledgerInfo = await aptos.getLedgerInfo();

      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(request.method, equals('GET'));
      expect(request.url, equals(devnetFullnode));
      expect(ledgerInfo.chainId, equals(4));
      expect(ledgerInfo.blockHeight, equals('50'));

      // getChainId reuses the (memoized) ledger info.
      expect(await aptos.getChainId(), equals(4));
      expect(client.requests, hasLength(1));
    });

    test('view posts a BCS view function payload to /view', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: ['100']),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final data = await aptos.view(
        payload: InputViewFunctionData(
          function: '0x1::chain_status::is_operating',
          functionArguments: const [],
          abi: const ViewFunctionABI(
            typeParameters: [],
            parameters: [],
            returnTypes: [],
          ),
        ),
      );

      expect(data, equals(['100']));
      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(request.method, equals('POST'));
      expect(request.url, equals('$devnetFullnode/view'));
      expect(request.contentType, equals(MimeType.bcsViewFunction.value));
      expect(request.headers?['content-type'],
          equals(MimeType.bcsViewFunction.value));
      expect(request.body, isA<Uint8List>());
    });

    test('viewJson posts the JSON view payload to /view', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: ['42']),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final data = await aptos.viewJson(
        payload: const InputViewFunctionJsonData(
          function: '0x1::coin::balance',
          typeArguments: ['0x1::aptos_coin::AptosCoin'],
          functionArguments: ['0x1'],
        ),
        options: const LedgerVersionArg(ledgerVersion: 33),
      );

      expect(data, equals(['42']));
      final request = client.requests.single;
      expect(request.url, equals('$devnetFullnode/view'));
      expect(request.params?['ledger_version'], equals(33));
      expect(
        request.body,
        equals({
          'function': '0x1::coin::balance',
          'type_arguments': ['0x1::aptos_coin::AptosCoin'],
          'arguments': ['0x1'],
        }),
      );
    });

    test('getTableItem posts to tables/{handle}/item', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: '42'),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final value = await aptos.getTableItem<String>(
        handle: '0xhandle',
        data: const TableItemRequest(
          keyType: 'address',
          valueType: 'u128',
          key: '0x1',
        ),
      );

      expect(value, equals('42'));
      final request = client.requests.single;
      expect(request.method, equals('POST'));
      expect(request.url, equals('$devnetFullnode/tables/0xhandle/item'));
      expect(
        request.body,
        equals({'key_type': 'address', 'value_type': 'u128', 'key': '0x1'}),
      );
    });
  });

  group('transaction build', () {
    test(
        'build.simple with explicit options builds offline on mainnet '
        '(canned chain id)', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {}),
      ]);
      final aptos =
          Aptos(AptosConfig(network: Network.mainnet, client: client));
      final sender = Account.generate();

      final transaction = await aptos.transaction.build.simple(
        sender: sender.accountAddress,
        data: transferData(),
        options: InputGenerateTransactionOptions(
          maxGasAmount: 2000,
          gasUnitPrice: 100,
          expireTimestamp: 999999,
          accountSequenceNumber: BigInt.from(5),
        ),
      );

      // Everything was provided explicitly: no network requests were made.
      expect(client.requests, isEmpty);

      expect(transaction, isA<SimpleTransaction>());
      final rawTxn = transaction.rawTransaction;
      expect(rawTxn.sender.equals(sender.accountAddress), isTrue);
      expect(rawTxn.sequenceNumber, equals(BigInt.from(5)));
      expect(rawTxn.maxGasAmount, equals(BigInt.from(2000)));
      expect(rawTxn.gasUnitPrice, equals(BigInt.from(100)));
      expect(rawTxn.expirationTimestampSecs, equals(BigInt.from(999999)));
      // Mainnet chain id is known statically.
      expect(rawTxn.chainId.chainId, equals(1));
      expect(transaction.feePayerAddress, isNull);
      expect(transaction.secondarySignerAddresses, isNull);
    });

    test('build.simple fetches the sequence number when not provided',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'sequence_number': '11',
          'authentication_key': '0x0123',
        }),
      ]);
      final aptos =
          Aptos(AptosConfig(network: Network.mainnet, client: client));
      final sender = Account.generate();

      final transaction = await aptos.transaction.build.simple(
        sender: sender.accountAddress,
        data: transferData(),
        options: const InputGenerateTransactionOptions(
          maxGasAmount: 2000,
          gasUnitPrice: 100,
          expireTimestamp: 999999,
        ),
      );

      expect(client.requests, hasLength(1));
      expect(client.requests.single.url, contains('/accounts/'));
      expect(
          transaction.rawTransaction.sequenceNumber, equals(BigInt.from(11)));
    });
  });

  group('sign and submit', () {
    test('sign + submit.simple posts BCS signed transaction', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: pendingTxnJson('0xdead')),
      ]);
      final aptos =
          Aptos(AptosConfig(network: Network.mainnet, client: client));
      final sender = Account.generate();

      final transaction = await buildOfflineTransaction(aptos, sender: sender);
      final senderAuthenticator =
          aptos.transaction.sign(signer: sender, transaction: transaction);
      expect(senderAuthenticator, isA<AccountAuthenticatorEd25519>());

      final pending = await aptos.transaction.submit.simple(
        transaction: transaction,
        senderAuthenticator: senderAuthenticator,
      );

      expect(pending, isA<PendingTransactionResponse>());
      expect(pending.hash, equals('0xdead'));

      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(request.method, equals('POST'));
      expect(request.url,
          equals('https://api.mainnet.aptoslabs.com/v1/transactions'));
      expect(request.contentType, equals(MimeType.bcsSignedTransaction.value));
      expect(request.headers?['content-type'],
          equals(MimeType.bcsSignedTransaction.value));
      expect(request.body, isA<Uint8List>());
      expect((request.body as Uint8List), isNotEmpty);
    });

    test('signAndSubmitTransaction signs and posts in one call', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: pendingTxnJson('0xbeef')),
      ]);
      final aptos =
          Aptos(AptosConfig(network: Network.mainnet, client: client));
      final sender = Account.generate();

      final transaction = await buildOfflineTransaction(aptos, sender: sender);
      final pending = await aptos.signAndSubmitTransaction(
        signer: sender,
        transaction: transaction,
      );

      expect(pending.hash, equals('0xbeef'));
      final request = client.requests.single;
      expect(request.url, endsWith('/transactions'));
      expect(request.contentType, equals(MimeType.bcsSignedTransaction.value));
    });

    test('submit.simple requires feePayerAuthenticator for fee payer txns',
        () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: pendingTxnJson('0x1')),
      ]);
      final aptos =
          Aptos(AptosConfig(network: Network.mainnet, client: client));
      final sender = Account.generate();

      final transaction = await aptos.transaction.build.simple(
        sender: sender.accountAddress,
        data: transferData(),
        options: InputGenerateTransactionOptions(
          maxGasAmount: 2000,
          gasUnitPrice: 100,
          expireTimestamp: 999999,
          accountSequenceNumber: BigInt.zero,
        ),
        withFeePayer: true,
      );
      final senderAuthenticator =
          aptos.transaction.sign(signer: sender, transaction: transaction);

      expect(
        () => aptos.transaction.submit.simple(
          transaction: transaction,
          senderAuthenticator: senderAuthenticator,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('missing the feePayerAuthenticator'))),
      );
    });
  });

  group('waitForTransaction', () {
    test('returns the committed transaction on success', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: userTxnJson(hash: '0xabc')),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final response = await aptos.waitForTransaction(transactionHash: '0xabc');

      expect(response, isA<UserTransactionResponse>());
      expect(response.success, isTrue);
      expect(response.hash, equals('0xabc'));
      expect(client.requests.single.url,
          equals('$devnetFullnode/transactions/by_hash/0xabc'));
    });

    test('throws FailedTransactionError when execution failed (checkSuccess)',
        () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: userTxnJson(hash: '0xabc', success: false, vmStatus: 'OOG'),
        ),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      await expectLater(
        aptos.waitForTransaction(transactionHash: '0xabc'),
        throwsA(isA<FailedTransactionError>()
            .having((e) => e.message, 'message', contains('OOG'))
            .having((e) => (e.transaction as UserTransactionResponse).success,
                'transaction.success', isFalse)),
      );
    });

    test('returns the failed transaction when checkSuccess is false', () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: userTxnJson(hash: '0xabc', success: false, vmStatus: 'OOG'),
        ),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final response = await aptos.waitForTransaction(
        transactionHash: '0xabc',
        options: const WaitForTransactionOptions(checkSuccess: false),
      );

      expect(response.success, isFalse);
      expect(response.vmStatus, equals('OOG'));
    });

    test('throws WaitForTransactionError when stuck pending past the timeout',
        () async {
      // Every poll (including the long-poll) keeps returning the pending
      // transaction; the FakeClient repeats the last response forever.
      final client = FakeClient([
        ClientResponse(status: 200, data: pendingTxnJson('0xabc')),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      await expectLater(
        aptos.waitForTransaction(
          transactionHash: '0xabc',
          options: const WaitForTransactionOptions(timeoutSecs: 1),
        ),
        throwsA(isA<WaitForTransactionError>()
            .having((e) => e.message, 'message',
                contains('timed out in pending state'))
            .having(
                (e) => e.lastSubmittedTransaction?.type,
                'lastSubmittedTransaction.type',
                equals(TransactionResponseType.pending))),
      );

      // The first request was getTransactionByHash, the second the long wait,
      // then polling.
      expect(client.requests.length, greaterThanOrEqualTo(2));
      expect(client.requests[0].url,
          equals('$devnetFullnode/transactions/by_hash/0xabc'));
      expect(client.requests[1].url,
          equals('$devnetFullnode/transactions/wait_by_hash/0xabc'));
    });
  });

  group('faucet', () {
    test('fundAccount posts to the faucet and waits for the transaction',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'txn_hashes': ['0xfund'],
        }),
        ClientResponse(status: 200, data: userTxnJson(hash: '0xfund')),
      ]);
      final aptos = Aptos(AptosConfig(network: Network.devnet, client: client));

      final txn = await aptos.fundAccount(
        accountAddress: '0x1',
        amount: 100000000,
      );

      expect(txn, isA<UserTransactionResponse>());
      expect(txn.hash, equals('0xfund'));

      expect(client.requests, hasLength(2));
      final fundRequest = client.requests[0];
      expect(fundRequest.method, equals('POST'));
      expect(
          fundRequest.url, equals('https://faucet.devnet.aptoslabs.com/fund'));
      expect(
        fundRequest.body,
        equals({'address': '0x1', 'amount': 100000000}),
      );
      expect(client.requests[1].url,
          equals('$devnetFullnode/transactions/by_hash/0xfund'));
    });
  });

  group('TransactionSubmitter plugin', () {
    test(
        'is used when configured and bypassed after '
        'setIgnoreTransactionSubmitter(true)', () async {
      final submitter = FakeTransactionSubmitter();
      final client = FakeClient([
        ClientResponse(status: 200, data: pendingTxnJson('0xnode')),
      ]);
      final aptos = Aptos(AptosConfig(
        network: Network.mainnet,
        client: client,
        pluginSettings: PluginSettings(transactionSubmitter: submitter),
      ));
      final sender = Account.generate();

      final transaction = await buildOfflineTransaction(aptos, sender: sender);

      // With the plugin configured, submission goes through the plugin and
      // never hits the node.
      final viaPlugin = await aptos.signAndSubmitTransaction(
        signer: sender,
        transaction: transaction,
      );
      expect(viaPlugin.hash, equals('0xplugin'));
      expect(submitter.calls, equals(1));
      expect(client.requests, isEmpty);

      // After ignoring the submitter, submission goes to the fullnode.
      aptos.setIgnoreTransactionSubmitter(true);
      final viaNode = await aptos.signAndSubmitTransaction(
        signer: sender,
        transaction: transaction,
      );
      expect(viaNode.hash, equals('0xnode'));
      expect(submitter.calls, equals(1));
      expect(client.requests, hasLength(1));
      expect(client.requests.single.url, endsWith('/transactions'));
      expect(client.requests.single.contentType,
          equals(MimeType.bcsSignedTransaction.value));

      // And it can be re-enabled.
      aptos.setIgnoreTransactionSubmitter(false);
      final viaPluginAgain = await aptos.signAndSubmitTransaction(
        signer: sender,
        transaction: transaction,
      );
      expect(viaPluginAgain.hash, equals('0xplugin'));
      expect(submitter.calls, equals(2));
      expect(client.requests, hasLength(1));
    });
  });
}
