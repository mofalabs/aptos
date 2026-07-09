import '../core/account_address.dart';
import '../internal/staking.dart' as internal_staking;
import '../types/indexer.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class to query all `Staking` related queries on Aptos.
class Staking {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Staking` namespace with the
  /// specified configuration.
  const Staking(this.config);

  /// Queries the current number of delegators in a specified pool.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  Future<int> getNumberOfDelegators({
    required AccountAddressInput poolAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.stakeProcessor,
    );
    return internal_staking.getNumberOfDelegators(
      aptosConfig: config,
      poolAddress: poolAddress,
    );
  }

  /// Retrieves the current number of delegators across all pools.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional ordering options for the response.
  Future<List<NumberOfDelegators>> getNumberOfDelegatorsForAllPools({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.stakeProcessor,
    );
    return internal_staking.getNumberOfDelegatorsForAllPools(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries delegated staking activities for a specific delegator and pool.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  Future<List<DelegatedStakingActivity>> getDelegatedStakingActivities({
    required AccountAddressInput delegatorAddress,
    required AccountAddressInput poolAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.stakeProcessor,
    );
    return internal_staking.getDelegatedStakingActivities(
      aptosConfig: config,
      delegatorAddress: delegatorAddress,
      poolAddress: poolAddress,
    );
  }
}
