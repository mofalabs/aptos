import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/api/abstraction.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/types/abstraction.dart';
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
  Future<ClientResponse<dynamic>> provider(
      ClientRequest requestOptions) async {
    requests.add(requestOptions);
    final response = responses[_index];
    if (_index < responses.length - 1) _index += 1;
    return response;
  }
}

const authenticationFunction = '0x1::any_authenticator::authenticate';

/// Offline transaction options (mainnet chain id is known statically, no
/// sequence number fetch needed).
InputGenerateTransactionOptions offlineOptions() =>
    InputGenerateTransactionOptions(
      maxGasAmount: 2000,
      gasUnitPrice: 100,
      expireTimestamp: 999999,
      accountSequenceNumber: BigInt.zero,
    );

(AccountAbstraction, FakeClient) makeAbstraction(
    List<ClientResponse<dynamic>> responses) {
  final client = FakeClient(responses);
  final config = AptosConfig(network: Network.mainnet, client: client);
  return (AccountAbstraction(config), client);
}

/// Extracts `moduleAddress::moduleName::functionName` from an entry function
/// transaction payload.
String payloadFunctionId(SimpleTransaction transaction) {
  final payload =
      transaction.rawTransaction.payload as TransactionPayloadEntryFunction;
  final entryFunction = payload.entryFunction;
  return '${entryFunction.moduleName.address}::'
      '${entryFunction.moduleName.name.identifier}::'
      '${entryFunction.functionName.identifier}';
}

void main() {
  setUp(clearMemoizeCache);

  group('AA enum variants (types/abstraction.dart)', () {
    test('mirror the expected values', () {
      expect(AbstractAuthenticationDataVariant.v1.value, 0);
      expect(AbstractAuthenticationDataVariant.derivableV1.value, 1);
      expect(AASigningDataVariant.v1.value, 0);
    });
  });

  group('enable/disable account abstraction transactions', () {
    test('enableAccountAbstractionTransaction builds add_authentication_'
        'function with the function parts as arguments', () async {
      final (abstraction, client) = makeAbstraction([
        const ClientResponse(status: 200, data: {}),
      ]);
      final sender = Account.generate();

      final transaction = await abstraction.enableAccountAbstractionTransaction(
        accountAddress: sender.accountAddress,
        authenticationFunction: authenticationFunction,
        options: offlineOptions(),
      );

      // The ABI is provided internally: fully offline build.
      expect(client.requests, isEmpty);
      expect(
        payloadFunctionId(transaction),
        '0x1::account_abstraction::add_authentication_function',
      );
      final payload = transaction.rawTransaction.payload
          as TransactionPayloadEntryFunction;
      // moduleAddress, moduleName, functionName.
      expect(payload.entryFunction.args, hasLength(3));
      expect(
        transaction.rawTransaction.sender.equals(sender.accountAddress),
        isTrue,
      );
    });

    test(
        'disableAccountAbstractionTransaction with an authentication '
        'function builds remove_authentication_function', () async {
      final (abstraction, client) = makeAbstraction([
        const ClientResponse(status: 200, data: {}),
      ]);
      final sender = Account.generate();

      final transaction =
          await abstraction.disableAccountAbstractionTransaction(
        accountAddress: sender.accountAddress,
        authenticationFunction: authenticationFunction,
        options: offlineOptions(),
      );

      expect(client.requests, isEmpty);
      expect(
        payloadFunctionId(transaction),
        '0x1::account_abstraction::remove_authentication_function',
      );
    });

    test(
        'disableAccountAbstractionTransaction without an authentication '
        'function builds remove_authenticator', () async {
      final (abstraction, client) = makeAbstraction([
        const ClientResponse(status: 200, data: {}),
      ]);
      final sender = Account.generate();

      final transaction =
          await abstraction.disableAccountAbstractionTransaction(
        accountAddress: sender.accountAddress,
        options: offlineOptions(),
      );

      expect(client.requests, isEmpty);
      expect(
        payloadFunctionId(transaction),
        '0x1::account_abstraction::remove_authenticator',
      );
      final payload = transaction.rawTransaction.payload
          as TransactionPayloadEntryFunction;
      expect(payload.entryFunction.args, isEmpty);
    });
  });

  group('isAccountAbstractionEnabled', () {
    test('parses the view response and matches the authentication function',
        () async {
      final (abstraction, client) = makeAbstraction([
        const ClientResponse(status: 200, data: [
          {
            'vec': [
              [
                {
                  'module_address': '0x1',
                  'module_name': 'any_authenticator',
                  'function_name': 'authenticate',
                },
              ],
            ],
          },
        ]),
      ]);

      final enabled = await abstraction.isAccountAbstractionEnabled(
        accountAddress: '0x1',
        authenticationFunction: authenticationFunction,
      );

      expect(enabled, isTrue);
      final request = client.requests.single;
      expect(request.method, 'POST');
      expect(request.url, endsWith('/view'));
    });

    test('returns false when a different function is registered', () async {
      final (abstraction, _) = makeAbstraction([
        const ClientResponse(status: 200, data: [
          {
            'vec': [
              [
                {
                  'module_address': '0x1',
                  'module_name': 'other_authenticator',
                  'function_name': 'authenticate',
                },
              ],
            ],
          },
        ]),
      ]);

      final enabled = await abstraction.isAccountAbstractionEnabled(
        accountAddress: '0x1',
        authenticationFunction: authenticationFunction,
      );

      expect(enabled, isFalse);
    });

    test('returns false when the account has no dispatchable authenticator',
        () async {
      final (abstraction, _) = makeAbstraction([
        const ClientResponse(status: 200, data: [
          {'vec': <dynamic>[]},
        ]),
      ]);

      final enabled = await abstraction.isAccountAbstractionEnabled(
        accountAddress: '0x1',
        authenticationFunction: authenticationFunction,
      );

      expect(enabled, isFalse);
    });

    test('getAuthenticationFunction returns null for the empty option',
        () async {
      final (abstraction, _) = makeAbstraction([
        const ClientResponse(status: 200, data: [
          {'vec': <dynamic>[]},
        ]),
      ]);

      final functionInfos = await abstraction.getAuthenticationFunction(
        accountAddress: '0x1',
      );

      expect(functionInfos, isNull);
    });
  });
}
