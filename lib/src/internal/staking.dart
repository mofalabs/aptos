/// This file contains the underlying implementations for the exposed API
/// surface in `api/staking.dart`.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../types/indexer.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;

/// Retrieves the number of active delegators for a specified pool address.
Future<int> getNumberOfDelegators({
  required AptosConfig aptosConfig,
  required AccountAddressInput poolAddress,
}) async {
  final address = AccountAddress.from(poolAddress).toStringLong();
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getNumberOfDelegators,
      variables: {
        'where_condition': {
          'pool_address': {'_eq': address},
        },
      },
    ),
  );

  final rows = data['num_active_delegator_per_pool'] as List;
  if (rows.isEmpty) return 0;
  final row =
      NumberOfDelegators.fromJson(Map<String, dynamic>.from(rows.first as Map));
  return row.numActiveDelegator == null
      ? 0
      : int.parse(row.numActiveDelegator.toString());
}

/// Retrieves the number of active delegators for all pools.
///
/// [options] - Optional ordering ([IndexerQueryArgs.orderBy]) parameters.
Future<List<NumberOfDelegators>> getNumberOfDelegatorsForAllPools({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getNumberOfDelegators,
      variables: {
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
  );

  return (data['num_active_delegator_per_pool'] as List)
      .map((e) =>
          NumberOfDelegators.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the delegated staking activities for a specified delegator and
/// pool.
Future<List<DelegatedStakingActivity>> getDelegatedStakingActivities({
  required AptosConfig aptosConfig,
  required AccountAddressInput delegatorAddress,
  required AccountAddressInput poolAddress,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getDelegatedStakingActivities,
      variables: {
        'delegatorAddress':
            AccountAddress.from(delegatorAddress).toStringLong(),
        'poolAddress': AccountAddress.from(poolAddress).toStringLong(),
      },
    ),
  );

  return (data['delegated_staking_activities'] as List)
      .map((e) => DelegatedStakingActivity.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
}
