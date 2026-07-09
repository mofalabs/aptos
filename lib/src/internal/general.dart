/// This file contains the underlying implementations for the exposed API
/// surface in `api/general.dart` (fullnode- and indexer-backed functions),
/// plus `getGasPriceEstimation`, `getBlockByVersion` and `getBlockByHeight`
/// (kept here because the transaction building pipeline already depends on
/// this file).
library;

import '../api/aptos_config.dart';
import '../client/get.dart';
import '../client/post.dart';
import '../client/types.dart';
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../utils/const.dart';
import '../utils/memoize.dart';
import 'queries.dart' as queries;
import 'transaction.dart' show getTransactions;

/// Cache TTL for ledger info (10 seconds). Ledger info changes frequently
/// but we can cache briefly to reduce redundant calls when building multiple
/// transactions in quick succession.
const Duration _ledgerInfoCacheTtl = Duration(seconds: 10);

/// Retrieves information about the current ledger.
///
/// Results are cached for 10 seconds to reduce redundant network calls
/// during rapid transaction building.
Future<LedgerInfo> getLedgerInfo({required AptosConfig aptosConfig}) {
  final cacheKey = 'ledger-info-${aptosConfig.network.value}';

  return memoizeAsync(
    () async {
      final response = await getAptosFullNode(
        aptosConfig: aptosConfig,
        originMethod: 'getLedgerInfo',
        path: '',
      );
      return LedgerInfo.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    },
    cacheKey,
    ttl: _ledgerInfoCacheTtl,
  )();
}

/// Executes a GraphQL query against the Aptos indexer and returns the
/// resulting `data` payload (the GraphQL `data` envelope is unwrapped by the
/// client layer, see `aptosRequest`).
Future<Map<String, dynamic>> queryIndexer({
  required AptosConfig aptosConfig,
  required GraphqlQuery query,
  String? originMethod,
}) async {
  final response = await postAptosIndexer(
    aptosConfig: aptosConfig,
    originMethod: originMethod ?? 'queryIndexer',
    path: '',
    body: query.toJson(),
    overrides: const AptosRequestOverrides(withCredentials: false),
  );
  return Map<String, dynamic>.from(response.data as Map);
}

/// Retrieves the top user transactions for the chain, ordered by descending
/// version.
///
/// [limit] - The maximum number of transactions to retrieve.
Future<List<ChainTopUserTransaction>> getChainTopUserTransactions({
  required AptosConfig aptosConfig,
  required int limit,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getChainTopUserTransactions,
      variables: {'limit': limit},
    ),
    originMethod: 'getChainTopUserTransactions',
  );

  return (data['user_transactions'] as List)
      .map((e) => ChainTopUserTransaction.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the current statuses of all indexer processors.
Future<List<ProcessorStatus>> getProcessorStatuses({
  required AptosConfig aptosConfig,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: const GraphqlQuery(query: queries.getProcessorStatus),
    originMethod: 'getProcessorStatuses',
  );

  return (data['processor_status'] as List)
      .map((e) =>
          ProcessorStatus.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the last success version from the indexer.
Future<BigInt> getIndexerLastSuccessVersion({
  required AptosConfig aptosConfig,
}) async {
  final response = await getProcessorStatuses(aptosConfig: aptosConfig);
  return BigInt.parse(response[0].lastSuccessVersion.toString());
}

/// Retrieves the status of a specified processor in the Aptos network.
/// This function allows you to check the current operational status of a
/// processor, which can be useful for monitoring and troubleshooting.
Future<ProcessorStatus> getProcessorStatus({
  required AptosConfig aptosConfig,
  required ProcessorType processorType,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getProcessorStatus,
      variables: {
        'where_condition': {
          'processor': {'_eq': processorType.value},
        },
      },
    ),
    originMethod: 'getProcessorStatus',
  );

  return ProcessorStatus.fromJson(
    Map<String, dynamic>.from((data['processor_status'] as List).first as Map),
  );
}

/// Retrieves the estimated gas price for transactions on the Aptos network.
///
/// Results are cached for 5 minutes.
Future<GasEstimation> getGasPriceEstimation({
  required AptosConfig aptosConfig,
}) {
  return memoizeAsync(
    () async {
      final response = await getAptosFullNode(
        aptosConfig: aptosConfig,
        originMethod: 'getGasPriceEstimation',
        path: 'estimate_gas_price',
      );
      return GasEstimation.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    },
    'gas-price-${aptosConfig.network.value}',
    ttl: const Duration(minutes: 5),
  )();
}

/// Retrieves a block from the Aptos blockchain by its ledger version.
/// This function allows you to obtain detailed information about a specific
/// block, including its transactions if requested via [withTransactions].
Future<Block> getBlockByVersion({
  required AptosConfig aptosConfig,
  required AnyNumber ledgerVersion,
  bool? withTransactions,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getBlockByVersion',
    path: 'blocks/by_version/$ledgerVersion',
    params: {
      if (withTransactions != null) 'with_transactions': withTransactions,
    },
  );
  final block =
      Block.fromJson(Map<String, dynamic>.from(response.data as Map));

  return _fillBlockTransactions(
    aptosConfig: aptosConfig,
    block: block,
    withTransactions: withTransactions,
  );
}

/// Retrieves a block from the Aptos blockchain by its height, potentially
/// including its transactions when [withTransactions] is set.
Future<Block> getBlockByHeight({
  required AptosConfig aptosConfig,
  required AnyNumber blockHeight,
  bool? withTransactions,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getBlockByHeight',
    path: 'blocks/by_height/$blockHeight',
    params: {
      if (withTransactions != null) 'with_transactions': withTransactions,
    },
  );
  final block =
      Block.fromJson(Map<String, dynamic>.from(response.data as Map));

  return _fillBlockTransactions(
    aptosConfig: aptosConfig,
    block: block,
    withTransactions: withTransactions,
  );
}

/// Fills in the block with transactions if not enough were returned. This
/// function ensures that the block contains all relevant transactions by
/// fetching any missing ones based on the specified options.
Future<Block> _fillBlockTransactions({
  required AptosConfig aptosConfig,
  required Block block,
  bool? withTransactions,
}) async {
  if (withTransactions != true) {
    return block;
  }

  // Transactions should be filled, but this ensures it.
  final transactions = [...?block.transactions];

  final firstVersion = BigInt.parse(block.firstVersion);
  final lastVersion = BigInt.parse(block.lastVersion);

  // Convert the transaction to the type. When the block has no transactions
  // yet, there is no current version to continue from, so we start at the
  // beginning of the block.
  String? curVersion;
  if (transactions.isNotEmpty) {
    final lastTxn = transactions.last;
    if (lastTxn is CommittedTransactionResponse) {
      curVersion = lastTxn.version;
    }
  }

  // This time, if we don't have any transactions, we will try once with the
  // start of the block.
  final latestVersion =
      curVersion == null ? firstVersion - BigInt.one : BigInt.parse(curVersion);

  // If we have all the transactions in the block, we can skip out, otherwise
  // we need to fill the transactions.
  if (latestVersion == lastVersion) {
    return block;
  }

  // For now, we will grab all the transactions in groups of 100, but we can
  // make this more efficient by trying larger amounts.
  const pageSize = 100;
  final fetchFutures = <Future<List<TransactionResponse>>>[];
  for (var i = latestVersion + BigInt.one;
      i < lastVersion;
      i += BigInt.from(pageSize)) {
    final remaining = (lastVersion - i + BigInt.one).toInt();
    fetchFutures.add(getTransactions(
      aptosConfig: aptosConfig,
      options: PaginationArgs(
        offset: i,
        limit: pageSize < remaining ? pageSize : remaining,
      ),
    ));
  }

  // Combine all the futures.
  final responses = await Future.wait(fetchFutures);
  for (final txns in responses) {
    transactions.addAll(txns);
  }

  return Block(
    blockHeight: block.blockHeight,
    blockHash: block.blockHash,
    blockTimestamp: block.blockTimestamp,
    firstVersion: block.firstVersion,
    lastVersion: block.lastVersion,
    transactions: transactions,
  );
}
