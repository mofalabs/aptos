import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/client/core.dart';
import 'package:aptos/src/client/get.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/errors/errors.dart';
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:aptos/src/utils/const.dart';
import 'package:test/test.dart';

/// A fake client that returns canned responses and records requests.
class FakeClient implements Client {
  final List<ClientRequest> requests = [];
  final List<ClientResponse<dynamic>> responses;
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

AptosConfig configWith(FakeClient client) =>
    AptosConfig(network: Network.devnet, client: client);

void main() {
  group('AptosConfig', () {
    test('defaults to devnet and resolves URLs by network', () {
      final config = AptosConfig();
      expect(config.network, equals(Network.devnet));
      expect(
        config.getRequestUrl(AptosApiType.fullnode),
        equals('https://api.devnet.aptoslabs.com/v1'),
      );
      expect(
        config.getRequestUrl(AptosApiType.indexer),
        equals('https://api.devnet.aptoslabs.com/v1/graphql'),
      );
      expect(
        config.getRequestUrl(AptosApiType.faucet),
        equals('https://faucet.devnet.aptoslabs.com'),
      );
    });

    test('custom endpoint overrides win', () {
      final config = AptosConfig(
        network: Network.custom,
        fullnode: 'http://localhost:8080/v1',
      );
      expect(config.getRequestUrl(AptosApiType.fullnode),
          equals('http://localhost:8080/v1'));
      expect(() => config.getRequestUrl(AptosApiType.indexer),
          throwsStateError);
    });

    test('testnet/mainnet have no programmatic faucet', () {
      expect(
        () => AptosConfig(network: Network.testnet)
            .getRequestUrl(AptosApiType.faucet),
        throwsStateError,
      );
      expect(
        () => AptosConfig(network: Network.mainnet)
            .getRequestUrl(AptosApiType.faucet),
        throwsStateError,
      );
    });

    test('default gas and expiry values', () {
      final config = AptosConfig();
      expect(config.getDefaultMaxGasAmount(), equals(defaultMaxGasAmount));
      expect(config.getDefaultTxnExpirySecFromNow(),
          equals(defaultTxnExpSecFromNow));

      final custom = AptosConfig(
        transactionGenerationConfig: const TransactionGenerationConfig(
          defaultMaxGasAmountOverride: 12345,
          defaultTxnExpirySecFromNowOverride: 60,
        ),
      );
      expect(custom.getDefaultMaxGasAmount(), equals(12345));
      expect(custom.getDefaultTxnExpirySecFromNow(), equals(60));
    });
  });

  group('aptosRequest', () {
    test('returns response on 2xx and joins url with path', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {'ok': true}),
      ]);
      final response = await aptosRequest(
        const AptosRequest(
            url: 'https://example.com/v1', method: 'GET', path: 'accounts/0x1'),
        configWith(client),
        AptosApiType.fullnode,
      );
      expect(response.status, equals(200));
      expect(response.url, equals('https://example.com/v1/accounts/0x1'));
      expect((response.data as Map)['ok'], isTrue);
      expect(client.requests.single.headers?['x-aptos-client'],
          startsWith('aptos-dart-sdk/'));
    });

    test('throws AptosApiError on non-2xx', () async {
      final client = FakeClient([
        const ClientResponse(
          status: 404,
          statusText: 'Not Found',
          data: {'message': 'account not found', 'error_code': 'not_found'},
        ),
      ]);
      expect(
        () => aptosRequest(
          const AptosRequest(url: 'https://example.com/v1', method: 'GET'),
          configWith(client),
          AptosApiType.fullnode,
        ),
        throwsA(isA<AptosApiError>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.message, 'message',
                contains('account not found'))),
      );
    });

    test('throws AptosApiError on 401 unauthorized', () async {
      final client = FakeClient([
        const ClientResponse(status: 401, data: 'unauthorized'),
      ]);
      expect(
        () => aptosRequest(
          const AptosRequest(url: 'https://example.com/v1', method: 'GET'),
          configWith(client),
          AptosApiType.fullnode,
        ),
        throwsA(isA<AptosApiError>()),
      );
    });

    test('unwraps indexer data and throws on graphql errors', () async {
      final okClient = FakeClient([
        const ClientResponse(
          status: 200,
          data: {
            'data': {'ledger_infos': []},
          },
        ),
      ]);
      final response = await aptosRequest(
        const AptosRequest(url: 'https://example.com/graphql', method: 'POST'),
        configWith(okClient),
        AptosApiType.indexer,
      );
      expect((response.data as Map).containsKey('ledger_infos'), isTrue);

      final errClient = FakeClient([
        const ClientResponse(
          status: 200,
          data: {
            'errors': [
              {'message': 'field not found'},
            ],
          },
        ),
      ]);
      expect(
        () => aptosRequest(
          const AptosRequest(
              url: 'https://example.com/graphql', method: 'POST'),
          configWith(errClient),
          AptosApiType.indexer,
        ),
        throwsA(isA<AptosApiError>().having(
            (e) => e.message, 'message', contains('field not found'))),
      );
    });

    test('pepper/prover errors have redacted bodies', () async {
      final client = FakeClient([
        const ClientResponse(
          status: 400,
          statusText: 'Bad Request',
          data: {'secret': 'jwt-material'},
        ),
      ]);
      expect(
        () => aptosRequest(
          const AptosRequest(url: 'https://example.com/pepper', method: 'POST'),
          configWith(client),
          AptosApiType.pepper,
        ),
        throwsA(isA<AptosApiError>()
            .having((e) => e.message, 'message', contains('redacted'))
            .having(
                (e) => e.message, 'message', isNot(contains('jwt-material')))),
      );
    });
  });

  group('pagination', () {
    test('paginateWithCursor follows the x-aptos-cursor header', () async {
      final client = FakeClient([
        const ClientResponse(
          status: 200,
          data: [1, 2],
          headers: {'x-aptos-cursor': 'abc'},
        ),
        const ClientResponse(status: 200, data: [3], headers: {}),
      ]);
      final result = await paginateWithCursor(
        aptosConfig: configWith(client),
        originMethod: 'test',
        path: 'accounts/0x1/transactions',
      );
      expect(result, equals([1, 2, 3]));
      expect(client.requests, hasLength(2));
      expect(client.requests[1].params?['start'], equals('abc'));
    });

    test('paginateWithObfuscatedCursor respects total limit', () async {
      final client = FakeClient([
        const ClientResponse(
          status: 200,
          data: [1, 2],
          headers: {'x-aptos-cursor': 'abc'},
        ),
        const ClientResponse(
          status: 200,
          data: [3, 4],
          headers: {'x-aptos-cursor': 'def'},
        ),
      ]);
      final result = await paginateWithObfuscatedCursor(
        aptosConfig: configWith(client),
        originMethod: 'test',
        path: 'objects',
        params: {'limit': 4},
      );
      expect(result, equals([1, 2, 3, 4]));
      expect(client.requests, hasLength(2));
    });
  });
}
