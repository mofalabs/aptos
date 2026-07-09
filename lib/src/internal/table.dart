/// Internal helpers for reading table items from the fullnode.
library;

import '../api/aptos_config.dart';
import '../client/post.dart';
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/pagination.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;

/// Retrieves a specific item from a table in the Aptos blockchain.
///
/// [handle] - The identifier for the table from which to retrieve the item.
/// [data] - The request data for the table item.
/// [options] - Optional parameters for the request, including ledger version.
Future<T> getTableItem<T>({
  required AptosConfig aptosConfig,
  required String handle,
  required TableItemRequest data,
  LedgerVersionArg? options,
}) async {
  final response = await postAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getTableItem',
    path: 'tables/$handle/item',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
    body: data.toJson(),
  );
  return response.data as T;
}

/// Retrieves table items data from the indexer based on the specified
/// conditions and pagination options.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where], a
/// `table_items_bool_exp`) and ordering ([IndexerQueryArgs.orderBy])
/// parameters.
Future<List<TableItemData>> getTableItemsData({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getTableItemsData,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getTableItemsData',
  );

  return (data['table_items'] as List)
      .map((e) => TableItemData.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves metadata for table items from the indexer based on the
/// specified options.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where], a
/// `table_metadatas_bool_exp`) and ordering ([IndexerQueryArgs.orderBy])
/// parameters.
Future<List<TableMetadata>> getTableItemsMetadata({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getTableItemsMetadata,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getTableItemsMetadata',
  );

  return (data['table_metadatas'] as List)
      .map((e) => TableMetadata.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
