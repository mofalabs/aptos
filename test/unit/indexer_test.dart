import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/api/ans.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/api/fungible_asset.dart';
import 'package:aptos/src/api/utils.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/errors/errors.dart';
import 'package:aptos/src/internal/account.dart' as internal_account;
import 'package:aptos/src/internal/ans.dart' as internal_ans;
import 'package:aptos/src/internal/general.dart' as internal_general;
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/types/ans.dart';
import 'package:aptos/src/types/indexer.dart';
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:aptos/src/utils/const.dart';
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

const String devnetIndexer = 'https://api.devnet.aptoslabs.com/v1/graphql';

ClientResponse<dynamic> graphqlResponse(Map<String, dynamic> data) =>
    ClientResponse(status: 200, data: {'data': data});

ClientResponse<dynamic> processorStatusResponse(Object lastSuccessVersion) =>
    graphqlResponse({
      'processor_status': [
        {
          'last_success_version': lastSuccessVersion,
          'processor': 'default_processor',
          'last_updated': '2026-01-01T00:00:00',
        },
      ],
    });

Map<String, dynamic> tokenOwnershipJson() => {
      'token_standard': 'v2',
      'token_properties_mutated_v1': null,
      'token_data_id': '0xtoken',
      'table_type_v1': null,
      'storage_id': '0xstorage',
      'property_version_v1': 0,
      'owner_address': '0x1',
      'last_transaction_version': 42,
      'last_transaction_timestamp': '2026-01-01T00:00:00',
      'is_soulbound_v2': false,
      'is_fungible_v2': false,
      'amount': 1,
      'current_token_data': {
        'collection_id': '0xcollection',
        'description': 'a token',
        'is_fungible_v2': false,
        'largest_property_version_v1': null,
        'last_transaction_timestamp': '2026-01-01T00:00:00',
        'last_transaction_version': 42,
        'maximum': null,
        'supply': '1',
        'token_data_id': '0xtoken',
        'token_name': 'Token #1',
        'token_properties': <String, dynamic>{},
        'token_standard': 'v2',
        'token_uri': 'https://example.com/1.png',
        'decimals': 0,
        'current_collection': {
          'collection_id': '0xcollection',
          'collection_name': 'My Collection',
          'creator_address': '0xcafe',
          'current_supply': 10,
          'description': 'a collection',
          'last_transaction_timestamp': '2026-01-01T00:00:00',
          'last_transaction_version': 42,
          'max_supply': 100,
          'mutable_description': true,
          'mutable_uri': true,
          'table_handle_v1': null,
          'token_standard': 'v2',
          'total_minted_v2': 10,
          'uri': 'https://example.com',
        },
      },
    };

void main() {
  setUp(() {
    clearMemoizeCache();
    internal_ans.clearANSGracePeriodCache();
  });

  group('queryIndexer', () {
    test('posts {query, variables} to the indexer URL and unwraps data',
        () async {
      final client = FakeClient([
        graphqlResponse({'foo': 'bar'}),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final data = await internal_general.queryIndexer(
        aptosConfig: config,
        query: const GraphqlQuery(
          query: 'query { foo }',
          variables: {'a': 1},
        ),
        originMethod: 'testQuery',
      );

      // The GraphQL `data` envelope is unwrapped.
      expect(data, equals({'foo': 'bar'}));

      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(request.method, equals('POST'));
      expect(request.url, equals(devnetIndexer));
      expect(
        request.body,
        equals({
          'query': 'query { foo }',
          'variables': {'a': 1},
        }),
      );
      // withCredentials is false for indexer queries.
      expect(request.overrides?.withCredentials, isFalse);
      expect(request.headers?['x-aptos-dart-sdk-origin-method'],
          equals('testQuery'));
    });

    test('omits the variables key when no variables are provided', () async {
      final client = FakeClient([
        graphqlResponse({'processor_status': <dynamic>[]}),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      await internal_general.getProcessorStatuses(aptosConfig: config);

      final body = client.requests.single.body as Map;
      expect(body.containsKey('variables'), isFalse);
      expect(body['query'], contains('query getProcessorStatus'));
    });

    test('throws AptosApiError on GraphQL errors', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'errors': [
            {'message': 'field not found'},
          ],
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      await expectLater(
        internal_general.queryIndexer(
          aptosConfig: config,
          query: const GraphqlQuery(query: 'query { nope }'),
        ),
        throwsA(isA<AptosApiError>()),
      );
    });

    test('getChainTopUserTransactions builds the limit variable', () async {
      final client = FakeClient([
        graphqlResponse({
          'user_transactions': [
            {'version': 200},
            {'version': 100},
          ],
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final transactions = await internal_general.getChainTopUserTransactions(
        aptosConfig: config,
        limit: 2,
      );

      expect(transactions, hasLength(2));
      expect(transactions.first.version, equals(200));
      final body = client.requests.single.body as Map;
      expect(body['variables'], equals({'limit': 2}));
      expect(body['query'], contains('query getChainTopUserTransactions'));
    });
  });

  group('fungible asset', () {
    test('getFungibleAssetMetadata builds variables and parses the response',
        () async {
      final client = FakeClient([
        graphqlResponse({
          'fungible_asset_metadata': [
            {
              'icon_uri': null,
              'project_uri': null,
              'supply_aggregator_table_handle_v1': null,
              'supply_aggregator_table_key_v1': null,
              'creator_address': '0x1',
              'asset_type': '0x1::aptos_coin::AptosCoin',
              'decimals': 8,
              'last_transaction_timestamp': '2026-01-01T00:00:00',
              'last_transaction_version': 7,
              'name': 'Aptos Coin',
              'symbol': 'APT',
              'token_standard': 'v1',
              'supply_v2': null,
              'maximum_v2': null,
            },
          ],
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);
      final fungibleAsset = FungibleAsset(config);

      final metadata = await fungibleAsset.getFungibleAssetMetadata(
        options: const IndexerQueryArgs(
          limit: 10,
          offset: 5,
          where: {
            'asset_type': {'_eq': '0x1::aptos_coin::AptosCoin'},
          },
        ),
      );

      expect(metadata, hasLength(1));
      expect(metadata.first.symbol, equals('APT'));
      expect(metadata.first.decimals, equals(8));
      expect(metadata.first.assetType, equals('0x1::aptos_coin::AptosCoin'));

      // No minimumLedgerVersion: only the GraphQL request was made.
      expect(client.requests, hasLength(1));
      final body = client.requests.single.body as Map;
      expect(body['query'], contains('query getFungibleAssetMetadata'));
      expect(
        body['variables'],
        equals({
          'where_condition': {
            'asset_type': {'_eq': '0x1::aptos_coin::AptosCoin'},
          },
          'limit': 10,
          'offset': 5,
        }),
      );
    });

    test('transferFungibleAsset builds the primary_fungible_store payload',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {}),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);
      final sender = Account.generate();

      final transaction = await FungibleAsset(config).transferFungibleAsset(
        sender: sender,
        fungibleAssetMetadataAddress: '0xa',
        recipient: '0x2',
        amount: 100,
        options: InputGenerateTransactionOptions(
          maxGasAmount: 2000,
          gasUnitPrice: 100,
          expireTimestamp: 999999,
          accountSequenceNumber: BigInt.zero,
        ),
      );

      // The ABI is provided internally and everything else is explicit: the
      // transaction is built fully offline.
      expect(client.requests, isEmpty);
      expect(transaction, isA<SimpleTransaction>());

      final payload =
          transaction.rawTransaction.payload as TransactionPayloadEntryFunction;
      final entryFunction = payload.entryFunction;
      expect(entryFunction.moduleName.address.toString(), equals('0x1'));
      expect(entryFunction.moduleName.name.identifier,
          equals('primary_fungible_store'));
      expect(entryFunction.functionName.identifier, equals('transfer'));
      expect(entryFunction.typeArgs, hasLength(1));
      expect(entryFunction.typeArgs.single.toString(),
          equals('0x1::fungible_asset::Metadata'));
      expect(entryFunction.args, hasLength(3));
    });
  });

  group('account indexer queries', () {
    test(
        'getAccountOwnedTokens builds the where/pagination variables and '
        'parses ownerships', () async {
      final client = FakeClient([
        graphqlResponse({
          'current_token_ownerships_v2': [tokenOwnershipJson()],
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final tokens = await internal_account.getAccountOwnedTokens(
        aptosConfig: config,
        accountAddress: '0x1',
        options: const IndexerQueryArgs(
          tokenStandard: TokenStandard.v2,
          offset: 5,
          limit: 10,
          orderBy: [
            {'last_transaction_version': OrderByValue.desc},
          ],
        ),
      );

      final body = client.requests.single.body as Map;
      expect(body['query'], contains('query getAccountOwnedTokens'));
      expect(body['query'], contains('fragment CurrentTokenOwnershipFields'));
      expect(
        body['variables'],
        equals({
          'where_condition': {
            'owner_address': {
              '_eq':
                  '0x0000000000000000000000000000000000000000000000000000000000000001',
            },
            'amount': {'_gt': 0},
            'token_standard': {'_eq': 'v2'},
          },
          'offset': 5,
          'limit': 10,
          'order_by': [
            {'last_transaction_version': 'desc'},
          ],
        }),
      );

      expect(tokens, hasLength(1));
      final ownership = tokens.single;
      expect(ownership.tokenDataId, equals('0xtoken'));
      expect(ownership.amount, equals(1));
      expect(ownership.currentTokenData?.tokenName, equals('Token #1'));
      expect(ownership.currentTokenData?.currentCollection?.collectionName,
          equals('My Collection'));
    });

    test('getAccountCoinsCount reads the aggregate count', () async {
      final client = FakeClient([
        graphqlResponse({
          'current_fungible_asset_balances_aggregate': {
            'aggregate': {'count': 3},
          },
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final count = await internal_account.getAccountCoinsCount(
        aptosConfig: config,
        accountAddress: '0x1',
      );

      expect(count, equals(3));
      final body = client.requests.single.body as Map;
      expect(
        body['variables'],
        equals({
          'address':
              '0x0000000000000000000000000000000000000000000000000000000000000001',
        }),
      );
    });
  });

  group('ANS', () {
    const testnetRouter =
        '0x5f8fd2347449685cf41d4db97926ec3a096eaf381332be4f1318ad4d16a8497c';

    test('isValidANSName splits domains and subdomains and validates them', () {
      expect(internal_ans.isValidANSName('test.apt'),
          equals((domainName: 'test', subdomainName: null)));
      expect(internal_ans.isValidANSName('sub.test.apt'),
          equals((domainName: 'test', subdomainName: 'sub')));
      expect(internal_ans.isValidANSName('sub.test'),
          equals((domainName: 'test', subdomainName: 'sub')));
      expect(
          () => internal_ans.isValidANSName('a.b.c.apt'), throwsArgumentError);
      expect(() => internal_ans.isValidANSName('ab'), throwsArgumentError);
      expect(() => internal_ans.isValidANSName('-bad-'), throwsArgumentError);
    });

    test('SubdomainExpirationPolicy parses numeric indexer values', () {
      expect(SubdomainExpirationPolicy.fromValue(0),
          equals(SubdomainExpirationPolicy.independent));
      expect(SubdomainExpirationPolicy.fromValue(1),
          equals(SubdomainExpirationPolicy.followsDomain));
      expect(SubdomainExpirationPolicy.fromValue('1'),
          equals(SubdomainExpirationPolicy.followsDomain));
      expect(SubdomainExpirationPolicy.fromValue(null), isNull);
    });

    test('getName fetches grace period + names and sanitizes the result',
        () async {
      final client = FakeClient([
        // 1. The remote ABI fetch for the grace period view function.
        ClientResponse(status: 200, data: {
          'bytecode': '0x',
          'abi': {
            'address': testnetRouter,
            'name': 'config',
            'friends': <String>[],
            'exposed_functions': [
              {
                'name': 'reregistration_grace_sec',
                'visibility': 'public',
                'is_entry': false,
                'is_view': true,
                'generic_type_params': <dynamic>[],
                'params': <String>[],
                'return': ['u64'],
              },
            ],
            'structs': <dynamic>[],
          },
        }),
        // 2. The view call returning the grace period in seconds.
        const ClientResponse(status: 200, data: ['2592000']),
        // 3. The indexer names query.
        graphqlResponse({
          'current_aptos_names': [
            {
              'domain': 'aptos',
              'expiration_timestamp': '2030-01-01T00:00:00',
              'registered_address': '0x456',
              'subdomain': 'test',
              'token_standard': 'v2',
              'is_primary': true,
              'owner_address': '0x123',
              'subdomain_expiration_policy': 1,
              'domain_expiration_timestamp': '2031-01-01T00:00:00',
            },
          ],
          'current_aptos_names_aggregate': {
            'aggregate': {'count': 1},
          },
        }),
      ]);
      final config = AptosConfig(network: Network.testnet, client: client);

      final name = await Ans(config).getName(name: 'test.aptos.apt');

      expect(client.requests, hasLength(3));
      // The ABI fetch hits the router's config module.
      expect(client.requests[0].url,
          contains('/accounts/$testnetRouter/module/config'));
      // The view call.
      expect(client.requests[1].url, endsWith('/view'));
      // The names GraphQL query.
      expect(client.requests[2].url,
          equals('https://api.testnet.aptoslabs.com/v1/graphql'));
      final body = client.requests[2].body as Map;
      expect(body['query'], contains('query getNames'));
      expect(body['query'], contains('fragment AnsTokenFragment'));
      expect(
        body['variables'],
        equals({
          'where_condition': {
            'domain': {'_eq': 'aptos'},
            'subdomain': {'_eq': 'test'},
          },
          'limit': 1,
        }),
      );

      expect(name, isNotNull);
      expect(name!.domain, equals('aptos'));
      expect(name.subdomain, equals('test'));
      expect(name.ownerAddress, equals('0x123'));
      expect(name.registeredAddress, equals('0x456'));
      expect(name.isPrimary, isTrue);
      expect(name.tokenStandard, equals('v2'));
      expect(name.subdomainExpirationPolicy,
          equals(SubdomainExpirationPolicy.followsDomain));
      // Timestamps are normalized to UTC ISO strings.
      expect(name.expirationTimestamp, equals('2030-01-01T00:00:00Z'));
      expect(name.domainExpirationTimestamp, equals('2031-01-01T00:00:00Z'));
      // The subdomain follows the domain, so the derived expiration is the
      // domain's expiration.
      expect(name.expiration.toUtc().year, equals(2031));
      expect(name.expirationStatus, equals(ExpirationStatus.active));
    });

    test('getName returns null when the indexer has no matching row', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: {
          'bytecode': '0x',
          'abi': {
            'address': testnetRouter,
            'name': 'config',
            'friends': <String>[],
            'exposed_functions': [
              {
                'name': 'reregistration_grace_sec',
                'visibility': 'public',
                'is_entry': false,
                'is_view': true,
                'generic_type_params': <dynamic>[],
                'params': <String>[],
                'return': ['u64'],
              },
            ],
            'structs': <dynamic>[],
          },
        }),
        const ClientResponse(status: 200, data: ['2592000']),
        graphqlResponse({
          'current_aptos_names': <dynamic>[],
          'current_aptos_names_aggregate': {
            'aggregate': {'count': 0},
          },
        }),
      ]);
      final config = AptosConfig(network: Network.testnet, client: client);

      final name = await Ans(config).getName(name: 'missing.apt');
      expect(name, isNull);
    });

    test('the ANS contract is not deployed on devnet', () {
      final config = AptosConfig(network: Network.devnet);
      expect(
        () => internal_ans.getRouterAddress(config),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('The ANS contract is not deployed to devnet'),
        )),
      );
    });
  });

  group('waitForIndexerOnVersion', () {
    test('does nothing when minimumLedgerVersion is null', () async {
      final client = FakeClient([
        processorStatusResponse(0),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      await waitForIndexerOnVersion(
        config: config,
        minimumLedgerVersion: null,
        processorType: ProcessorType.defaultProcessor,
      );

      expect(client.requests, isEmpty);
    });

    test('polls the processor status until the version is reached', () async {
      final client = FakeClient([
        processorStatusResponse('5'),
        processorStatusResponse('10'),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      await waitForIndexerOnVersion(
        config: config,
        minimumLedgerVersion: 10,
        processorType: ProcessorType.defaultProcessor,
      );

      expect(client.requests, hasLength(2));
      for (final request in client.requests) {
        expect(request.url, equals(devnetIndexer));
        final body = request.body as Map;
        expect(body['query'], contains('query getProcessorStatus'));
        expect(
          body['variables'],
          equals({
            'where_condition': {
              'processor': {'_eq': 'default_processor'},
            },
          }),
        );
      }
    });

    test(
        'waits on the aggregate last success version when no processor '
        'type is given', () async {
      final client = FakeClient([
        processorStatusResponse('99'),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      await waitForIndexer(
        aptosConfig: config,
        minimumLedgerVersion: BigInt.from(50),
      );

      expect(client.requests, hasLength(1));
      final body = client.requests.single.body as Map;
      // getProcessorStatuses sends no variables at all.
      expect(body.containsKey('variables'), isFalse);
    });
  });
}
