import '../internal/general.dart' as internal_general;
import '../internal/view.dart' as internal_view;
import '../transactions/types.dart';
import '../types/api_extras.dart';
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';

/// A class to query various Aptos-related information and perform operations
/// on the Aptos blockchain.
class General {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `General` namespace with the specified
  /// configuration.
  const General(this.config);

  /// Queries for the Aptos ledger information.
  ///
  /// Returns the Aptos ledger info, which includes details such as chain ID,
  /// epoch, and ledger version.
  Future<LedgerInfo> getLedgerInfo() {
    return internal_general.getLedgerInfo(aptosConfig: config);
  }

  /// Retrieves the chain ID of the Aptos blockchain.
  Future<int> getChainId() async {
    final result = await getLedgerInfo();
    return result.chainId;
  }

  /// Retrieves block information by the specified ledger version.
  ///
  /// [withTransactions] - If set to true, include all transactions in the
  /// block.
  Future<Block> getBlockByVersion({
    required AnyNumber ledgerVersion,
    bool? withTransactions,
  }) {
    return internal_general.getBlockByVersion(
      aptosConfig: config,
      ledgerVersion: ledgerVersion,
      withTransactions: withTransactions,
    );
  }

  /// Retrieves a block by its height, allowing for the inclusion of
  /// transactions if specified.
  ///
  /// [withTransactions] - If set to true, include all transactions in the
  /// block.
  Future<Block> getBlockByHeight({
    required AnyNumber blockHeight,
    bool? withTransactions,
  }) {
    return internal_general.getBlockByHeight(
      aptosConfig: config,
      blockHeight: blockHeight,
      withTransactions: withTransactions,
    );
  }

  /// Queries for a Move view function.
  ///
  /// ```dart
  /// final data = await aptos.view(
  ///   payload: InputViewFunctionData(
  ///     function: '0x1::coin::balance',
  ///     typeArguments: ['0x1::aptos_coin::AptosCoin'],
  ///     functionArguments: [accountAddress],
  ///   ),
  /// );
  /// ```
  ///
  /// Returns an array of Move values.
  Future<List<MoveValue>> view({
    required InputViewFunctionData payload,
    LedgerVersionArg? options,
  }) {
    return internal_view.view(
      aptosConfig: config,
      payload: payload,
      options: options,
    );
  }

  /// Queries for a Move view function with JSON, this provides compatibility
  /// with the old `aptos` package.
  ///
  /// Returns an array of Move values.
  Future<List<MoveValue>> viewJson({
    required InputViewFunctionJsonData payload,
    LedgerVersionArg? options,
  }) {
    return internal_view.viewJson(
      aptosConfig: config,
      payload: payload,
      options: options,
    );
  }

  /// Queries the top user transactions based on the specified limit.
  ///
  /// [limit] - The number of transactions to return.
  Future<List<ChainTopUserTransaction>> getChainTopUserTransactions({
    required int limit,
  }) {
    return internal_general.getChainTopUserTransactions(
      aptosConfig: config,
      limit: limit,
    );
  }

  /// Retrieves data from the Aptos Indexer using a GraphQL query.
  /// This function allows you to execute complex queries to fetch specific
  /// data from the Aptos blockchain.
  ///
  /// [query] - A [GraphqlQuery] with the GraphQL query string and optional
  /// variables.
  ///
  /// Returns the GraphQL `data` payload.
  Future<Map<String, dynamic>> queryIndexer({required GraphqlQuery query}) {
    return internal_general.queryIndexer(aptosConfig: config, query: query);
  }

  /// Retrieves the current statuses of all indexer processors.
  Future<List<ProcessorStatus>> getProcessorStatuses() {
    return internal_general.getProcessorStatuses(aptosConfig: config);
  }

  /// Query the processor status for a specific processor type.
  ///
  /// [processorType] - The processor type to query.
  Future<ProcessorStatus> getProcessorStatus({
    required ProcessorType processorType,
  }) {
    return internal_general.getProcessorStatus(
      aptosConfig: config,
      processorType: processorType,
    );
  }

  /// Queries for the last successful indexer version, providing insight into
  /// the ledger version the indexer is updated to, which may lag behind the
  /// full nodes.
  Future<BigInt> getIndexerLastSuccessVersion() {
    return internal_general.getIndexerLastSuccessVersion(aptosConfig: config);
  }
}
