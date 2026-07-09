import '../account/account.dart' as signer;
import '../core/account_address.dart';
import '../internal/fungible_asset.dart' as internal_fungible_asset;
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/indexer.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class for querying and managing fungible asset-related operations on
/// the Aptos blockchain.
class FungibleAsset {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `FungibleAsset` namespace with the
  /// specified configuration.
  const FungibleAsset(this.config);

  /// Queries all fungible asset metadata.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and filtering configuration.
  Future<List<FungibleAssetMetadata>> getFungibleAssetMetadata({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_fungible_asset.getFungibleAssetMetadata(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries the fungible asset metadata for a specific asset type, e.g.
  /// `0x1::aptos_coin::AptosCoin` for Aptos Coin.
  ///
  /// Throws a [StateError] if no metadata is found for the asset type.
  Future<FungibleAssetMetadata> getFungibleAssetMetadataByAssetType({
    required String assetType,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    final data = await internal_fungible_asset.getFungibleAssetMetadata(
      aptosConfig: config,
      options: IndexerQueryArgs(
        where: {
          'asset_type': {'_eq': assetType},
        },
      ),
    );

    return data.first;
  }

  /// Retrieves fungible asset metadata based on the creator address.
  Future<List<FungibleAssetMetadata>> getFungibleAssetMetadataByCreatorAddress({
    required AccountAddressInput creatorAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_fungible_asset.getFungibleAssetMetadata(
      aptosConfig: config,
      options: IndexerQueryArgs(
        where: {
          'creator_address': {
            '_eq': AccountAddress.from(creatorAddress).toStringLong(),
          },
        },
      ),
    );
  }

  /// Queries all fungible asset activities.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and filtering configuration.
  Future<List<FungibleAssetActivity>> getFungibleAssetActivities({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_fungible_asset.getFungibleAssetActivities(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries all current fungible asset balances.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and filtering configuration.
  Future<List<CurrentFungibleAssetBalance>> getCurrentFungibleAssetBalances({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_fungible_asset.getCurrentFungibleAssetBalances(
      aptosConfig: config,
      options: options,
    );
  }

  /// Transfer a specified amount of fungible asset from the sender's primary
  /// store to the recipient's primary store. This method allows you to
  /// transfer any fungible asset, including fungible tokens.
  ///
  /// Returns a [SimpleTransaction] that can be simulated or submitted to the
  /// chain.
  Future<SimpleTransaction> transferFungibleAsset({
    required signer.Account sender,
    required AccountAddressInput fungibleAssetMetadataAddress,
    required AccountAddressInput recipient,
    required AnyNumber amount,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_fungible_asset.transferFungibleAsset(
      aptosConfig: config,
      sender: sender,
      fungibleAssetMetadataAddress: fungibleAssetMetadataAddress,
      recipient: recipient,
      amount: amount,
      options: options,
    );
  }

  /// Transfer a specified amount of fungible asset from the sender's any
  /// (primary or secondary) fungible store to any (primary or secondary)
  /// fungible store.
  ///
  /// Returns a [SimpleTransaction] that can be simulated or submitted to the
  /// chain.
  Future<SimpleTransaction> transferFungibleAssetBetweenStores({
    required signer.Account sender,
    required AccountAddressInput fromStore,
    required AccountAddressInput toStore,
    required AnyNumber amount,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_fungible_asset.transferFungibleAssetBetweenStores(
      aptosConfig: config,
      sender: sender,
      fromStore: fromStore,
      toStore: toStore,
      amount: amount,
      options: options,
    );
  }
}
