/// This file contains the underlying implementations for the exposed API
/// surface in `api/object.dart`.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../types/indexer.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;

/// Retrieves the current objects based on the specified filtering and
/// pagination options.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where], a
/// `current_objects_bool_exp`) and ordering ([IndexerQueryArgs.orderBy])
/// parameters.
Future<List<ObjectData>> getObjectData({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getObjectData,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getObjectData',
  );

  return (data['current_objects'] as List)
      .map((e) => ObjectData.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the object data associated with a specific object address.
///
/// Throws a [StateError] if the object is not found in the indexer.
Future<ObjectData> getObjectDataByObjectAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput objectAddress,
  IndexerQueryArgs? options,
}) async {
  final address = AccountAddress.from(objectAddress).toStringLong();

  final data = await getObjectData(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      orderBy: options?.orderBy,
      where: {
        'object_address': {'_eq': address},
      },
    ),
  );
  return data.first;
}
