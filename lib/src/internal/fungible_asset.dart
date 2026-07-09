/// This file contains the underlying implementations for the exposed API
/// surface in `api/fungible_asset.dart`.
library;

import '../account/account.dart';
import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/type_tag/parser.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/indexer.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;
import 'transaction_submission.dart';

/// Retrieves metadata for fungible assets based on specified criteria.
/// This function allows you to filter and paginate through fungible asset
/// metadata.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]) and filtering ([IndexerQueryArgs.where], a
/// `fungible_asset_metadata_bool_exp`) parameters.
Future<List<FungibleAssetMetadata>> getFungibleAssetMetadata({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getFungibleAssetMetadata,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
      },
    ),
    originMethod: 'getFungibleAssetMetadata',
  );

  return (data['fungible_asset_metadata'] as List)
      .map((e) =>
          FungibleAssetMetadata.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the activities associated with fungible assets.
/// This function allows you to filter and paginate through the activities
/// based on specified conditions.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]) and filtering ([IndexerQueryArgs.where], a
/// `fungible_asset_activities_bool_exp`) parameters.
Future<List<FungibleAssetActivity>> getFungibleAssetActivities({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getFungibleAssetActivities,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
      },
    ),
    originMethod: 'getFungibleAssetActivities',
  );

  return (data['fungible_asset_activities'] as List)
      .map((e) =>
          FungibleAssetActivity.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the current balances of fungible assets.
///
/// [options] - Optional pagination ([IndexerQueryArgs.offset],
/// [IndexerQueryArgs.limit]) and filtering ([IndexerQueryArgs.where], a
/// `current_fungible_asset_balances_bool_exp`) parameters.
Future<List<CurrentFungibleAssetBalance>> getCurrentFungibleAssetBalances({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getCurrentFungibleAssetBalances,
      variables: {
        if (options?.where != null) 'where_condition': options!.where,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
      },
    ),
    originMethod: 'getCurrentFungibleAssetBalances',
  );

  return (data['current_fungible_asset_balances'] as List)
      .map((e) => CurrentFungibleAssetBalance.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
}

// Lazy-initialized to avoid circular dependency issues at module load time.
EntryFunctionABI? _faTransferAbi;
EntryFunctionABI _getFaTransferAbi() {
  return _faTransferAbi ??= EntryFunctionABI(
    typeParameters: const [MoveFunctionGenericTypeParam(constraints: [])],
    parameters: [
      parseTypeTag('0x1::object::Object'),
      TypeTagAddress(),
      TypeTagU64(),
    ],
  );
}

/// Transfers a specified amount of a fungible asset from the sender's
/// primary store to the recipient's primary store.
///
/// [sender] - The account initiating the transfer.
/// [fungibleAssetMetadataAddress] - The address of the fungible asset's
/// metadata.
/// [recipient] - The address of the account receiving the asset.
/// [amount] - The amount of the fungible asset to transfer.
Future<SimpleTransaction> transferFungibleAsset({
  required AptosConfig aptosConfig,
  required Account sender,
  required AccountAddressInput fungibleAssetMetadataAddress,
  required AccountAddressInput recipient,
  required AnyNumber amount,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::primary_fungible_store::transfer',
      typeArguments: const ['0x1::fungible_asset::Metadata'],
      functionArguments: [fungibleAssetMetadataAddress, recipient, amount],
      abi: _getFaTransferAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

/// Transfers a specified amount of a fungible asset from any (primary or
/// secondary) fungible store to any (primary or secondary) fungible store.
///
/// [sender] - The account initiating the transfer.
/// [fromStore] - The address of the fungible store initiating the transfer.
/// [toStore] - The address of the fungible store receiving the asset.
/// [amount] - The amount of the fungible asset to transfer.
Future<SimpleTransaction> transferFungibleAssetBetweenStores({
  required AptosConfig aptosConfig,
  required Account sender,
  required AccountAddressInput fromStore,
  required AccountAddressInput toStore,
  required AnyNumber amount,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::dispatchable_fungible_asset::transfer',
      typeArguments: const ['0x1::fungible_asset::FungibleStore'],
      functionArguments: [fromStore, toStore, amount],
      abi: _getFaTransferAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}
