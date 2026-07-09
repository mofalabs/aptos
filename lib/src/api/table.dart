import '../internal/table.dart' as internal_table;
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class to query all `Table` Aptos related queries.
class Table {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Table` namespace with the specified
  /// configuration.
  const Table(this.config);

  /// Queries for a specific item in a table identified by the handle and the
  /// key for the item.
  ///
  /// [handle] - A pointer to where that table is stored.
  /// [data] - Object that describes the table item, including key and value
  /// types.
  ///
  /// Returns the table item value rendered in JSON.
  Future<T> getTableItem<T>({
    required String handle,
    required TableItemRequest data,
    LedgerVersionArg? options,
  }) {
    return internal_table.getTableItem<T>(
      aptosConfig: config,
      handle: handle,
      data: data,
      options: options,
    );
  }

  /// Queries for table items data with optional filtering and pagination.
  ///
  /// Note: This query calls the indexer server.
  ///
  /// [minimumLedgerVersion] - Optional minimum ledger version to wait for
  /// before querying.
  /// [options] - Optional pagination ([IndexerQueryArgs.offset],
  /// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where]) and
  /// ordering ([IndexerQueryArgs.orderBy]) parameters.
  Future<List<TableItemData>> getTableItemsData({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.defaultProcessor,
    );
    return internal_table.getTableItemsData(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries for the metadata of table items, allowing for filtering and
  /// pagination.
  ///
  /// Note: This query calls the indexer server.
  ///
  /// [minimumLedgerVersion] - Optional minimum ledger version to wait for
  /// before querying.
  /// [options] - Optional pagination ([IndexerQueryArgs.offset],
  /// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where]) and
  /// ordering ([IndexerQueryArgs.orderBy]) parameters.
  Future<List<TableMetadata>> getTableItemsMetadata({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.defaultProcessor,
    );
    return internal_table.getTableItemsMetadata(
      aptosConfig: config,
      options: options,
    );
  }
}
