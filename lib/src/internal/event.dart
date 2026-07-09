/// This file contains the underlying implementations for the exposed API
/// surface in `api/event.dart`.
///
/// NOTE: the Indexer API events (v1) table is deprecated; these queries are
/// retained here for completeness.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../types/indexer.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;

const int _maxEventTypeLength = 300;

void _checkEventTypeLength(Object? eventType) {
  if (eventType is String && eventType.length > _maxEventTypeLength) {
    throw ArgumentError(
      'Event type length exceeds the maximum length of $_maxEventTypeLength',
    );
  }
}

/// Retrieves events associated with a specific module event type.
/// This function allows you to filter events based on the event type and
/// pagination options.
Future<List<IndexerEvent>> getModuleEventsByEventType({
  required AptosConfig aptosConfig,
  required MoveStructId eventType,
  IndexerQueryArgs? options,
}) {
  final whereCondition = <String, dynamic>{
    '_or': [
      // EventHandle events.
      {
        'account_address': {'_eq': eventType.split('::')[0]},
      },
      // Module events.
      {
        'account_address': {
          '_eq':
              '0x0000000000000000000000000000000000000000000000000000000000000000',
        },
        'sequence_number': {'_eq': 0},
        'creation_number': {'_eq': 0},
      },
    ],
    'indexed_type': {'_eq': eventType},
  };

  return getEvents(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      orderBy: options?.orderBy,
      where: whereCondition,
    ),
  );
}

/// Retrieves events associated with a specific account and creation number.
Future<List<IndexerEvent>> getAccountEventsByCreationNumber({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required AnyNumber creationNumber,
  IndexerQueryArgs? options,
}) {
  final address = AccountAddress.from(accountAddress);

  final whereCondition = <String, dynamic>{
    'account_address': {'_eq': address.toStringLong()},
    'creation_number': {
      '_eq': creationNumber is BigInt
          ? creationNumber.toString()
          : creationNumber,
    },
  };

  return getEvents(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      orderBy: options?.orderBy,
      where: whereCondition,
    ),
  );
}

/// Retrieves events associated with a specific account and event type.
Future<List<IndexerEvent>> getAccountEventsByEventType({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required MoveStructId eventType,
  IndexerQueryArgs? options,
}) {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final whereCondition = <String, dynamic>{
    'account_address': {'_eq': address},
    'indexed_type': {'_eq': eventType},
  };

  return getEvents(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      orderBy: options?.orderBy,
      where: whereCondition,
    ),
  );
}

/// Retrieves a list of events based on the specified filtering and
/// pagination options.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]), filtering ([IndexerQueryArgs.where], an
/// `events_bool_exp`) and ordering ([IndexerQueryArgs.orderBy]) parameters.
Future<List<IndexerEvent>> getEvents({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final indexedType = options?.where?['indexed_type'];
  _checkEventTypeLength(indexedType is Map ? indexedType['_eq'] : null);

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getEvents,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getEvents',
  );

  return (data['events'] as List)
      .map((e) => IndexerEvent.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
