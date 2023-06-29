import 'package:aptos/hex_string.dart';
import 'package:aptos/models/account_coins.dart';
import 'package:aptos/models/account_nfts.dart';
import 'package:aptos/models/coin_activities.dart';
import 'package:aptos/models/current_token_datas.dart';
import 'package:graphql/client.dart';

import 'indexer/queries.dart';

enum TokenStandard {
  v1,
  v2
}

/// Provides methods for retrieving data from Aptos Indexer.
/// For more detailed Queries specification see
/// https://cloud.hasura.io/public/graphiql?endpoint=https://indexer.mainnet.aptoslabs.com/v1/graphql
class IndexerClient {
  final String endpoint;
  late final GraphQLClient client;

  IndexerClient(this.endpoint, { GraphQLCache? cache }) {
    final _httpLink = HttpLink(endpoint);
    client = GraphQLClient(link: _httpLink, cache: cache ?? GraphQLCache());
  }

  /// Indexer only accepts address in the long format,
  /// i.e a 66 chars long -> 0x<64 chars>
  static void validateAddress(String address) {
    if (address.length < 66) {
      throw ArgumentError("Address needs to be 66 chars long.");
    }
  }

  Future queryIndexer({
      required dynamic document, 
      Map<String, dynamic> variables = const {}
  }) async {
    if (document is String) {
      document = gql(document);
    }
    final options = QueryOptions(document: document, variables: variables);
    final resp = await client.query(options);
    if(resp.hasException) {
      throw ArgumentError("Indexer data error ${resp.exception}");
    }
    return resp.data;
  }

  Future<dynamic> getIndexerLedgerInfo() async {
    final data = queryIndexer(document: GetIndexerLedgerInfo);
    return data;
  }

  Future<List<AccountNFT>> getAccountNFTs({
    required String ownerAddress, 
    int? offset, 
    int? limit
  }) async {
    final address = HexString.ensure(ownerAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "address": address,
      "offset": offset,
      "limit": limit
    };
    final data = await queryIndexer(document: GetAccountCurrentTokens, variables: variables);
    return AccountNFTs.fromJson(data).currentTokenOwnerships;
  }

  Future<dynamic> getTokenActivities({
    required String idHash, 
    int? offset, 
    int? limit
  }) async {
    final variables = {
      "idHash": idHash,
      "offset": offset,
      "limit": limit
    };
    return queryIndexer(document: GetTokenActivities, variables: variables);
  }

  Future<List<CoinBalance>> getAccountCoinsData({
    required String ownerAddress, 
    int? offset, 
    int? limit
  }) async {
    final address = HexString.ensure(ownerAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "owner_address": address,
      "offset": offset,
      "limit": limit
    };
    final data = await queryIndexer(document: GetAccountCoinsData, variables: variables);
    return AccountCoins.fromJson(data).currentCoinBalances;
  }

  /// Gets the count of tokens owned by an account
  Future<dynamic> getAccountTokensCount(String ownerAddress) async {
    final address = HexString.ensure(ownerAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "owner_address": address
    };
    return queryIndexer(document: GetAccountTokensCount, variables: variables);
  }

  /// Gets the count of transactions submitted by an account
  Future<dynamic> getAccountTransactionsCount(String accountAddress) async {
    final address = HexString.ensure(accountAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "address": address
    };
    return queryIndexer(document: GetAccountTransactionsCount, variables: variables);
  }

  /// Queries an account transactions data
  Future<dynamic> getAccountTransactionsData({
    required String accountAddress, 
    int? offset, 
    int? limit
  }) async {
    final address = HexString.ensure(accountAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "address": address,
      "offset": offset,
      "limit": limit
    };
    return queryIndexer(document: GetAccountTransactionsData, variables: variables);
  }

  /// Queries delegated staking activities
  Future<dynamic> getDelegatedStakingActivities({
    required String delegatorAddress,
    required String poolAddress
  }) async {
    final delegator = HexString.ensure(delegatorAddress).hex();
    final pool = HexString.ensure(poolAddress).hex();
    IndexerClient.validateAddress(delegator);
    IndexerClient.validateAddress(pool);

    final variables = {
      "delegatorAddress": delegator,
      "poolAddress": pool
    };
    return queryIndexer(document: GetDelegatedStakingActivities, variables: variables);
  }

  /// Gets the count of token's activities
  Future<dynamic> getTokenActivitiesCount(String tokenId) async {
    final variables = {
      "token_id": tokenId
    };
    return queryIndexer(document: GetTokenActivitiesCount, variables: variables);
  }

  /// Queries token data
  // Future<dynamic> getTokenData(String tokenId) async {
  //   final variables = {
  //     "token_id": tokenId
  //   };
  //   return queryIndexer(document: GetTokenData, variables: variables);
  // }

  /// Queries token data by [tokenId]
  Future<List<CurrentTokenData>> getTokenData(
    String tokenId,
    {TokenStandard? tokenStandard}
  ) async {
    final tokenAddress = HexString.ensure(tokenId).hex();
    IndexerClient.validateAddress(tokenAddress);

    final whereCondition = {
      "token_data_id": { "_eq": tokenAddress },
    };

    if (tokenStandard != null) {
      whereCondition["token_standard"] = { "_eq": tokenStandard.toString() };
    }

    final variables = { "where_condition": whereCondition };
    final data = await queryIndexer(document: GetTokenData, variables: variables);
    return CurrentTokenDatas.fromJson(data).currentTokenDatasV2;
  }

  /// Queries token owners data
  Future<dynamic> getTokenOwnersData(String tokenId, int propertyVersion) async {
    final variables = {
      "token_id": tokenId,
      "property_version": propertyVersion
    };
    return queryIndexer(document: GetTokenOwnersData, variables: variables);
  }

  /// Queries top user transactions
  Future<dynamic> getTopUserTransactions(int limit) async {
    final variables = {
      "limit": limit
    };
    return queryIndexer(document: GetTopUserTransactions, variables: variables);
  }

  /// Queries user transactions
  Future<dynamic> getUserTransactions({
    int? startVersion, 
    int? offset, 
    int? limit
  }) async {
    final variables = {
      "start_version": startVersion,
      "offset": offset,
      "limit": limit
    };
    return queryIndexer(document: GetUserTransactions, variables: variables);
  }

  /// Queries current delegator balances count
  Future<dynamic> getCurrentDelegatorBalancesCount(String poolAddress) async {
    final address = HexString.ensure(poolAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "poolAddress": address
    };
    return queryIndexer(document: GetCurrentDelegatorBalancesCount, variables: variables);
  }

  /// Queries an account coin activity
  Future<List<CoinActivity>> getAccountCoinActivity({
    required String accountAddress, 
    int? offset, 
    int? limit
  }) async {
    final address = HexString.ensure(accountAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "address": address,
      "offset": offset,
      "limit": limit
    };
    final data = await queryIndexer(document: GetAccountCoinActivity, variables: variables);
    return CoinActivities.fromJson(data).coinActivities;
  }

  /// Queries an account specified coin activity
  Future<List<CoinActivity>> getAccountSpecifiedCoinActivity({
    required String coinType,
    required String accountAddress,
    int? offset,
    int? limit
  }) async {
    final address = HexString.ensure(accountAddress).hex();
    IndexerClient.validateAddress(address);
    final variables = {
      "coin": coinType,
      "address": address,
      "offset": offset,
      "limit": limit
    };
    final data = await queryIndexer(document: GetAccountSpecifiedCoinActivity, variables: variables);
    return CoinActivities.fromJson(data).coinActivities;
  }

  Future<CoinInfo> getCoinInfo({
    required String coinType,
  }) async {
    final variables = {"coin": coinType};
    final data = await queryIndexer(
        document: GetCoinInfo, variables: variables);
    var infos = data['coin_infos'] as List;
    if(infos.isEmpty) {
      return const CoinInfo(name: '',symbol: '',decimals: 8);
    }
    return CoinInfo.fromJson(infos.first);
  }
}
