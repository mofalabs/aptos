/// Response and argument types for the Aptos indexer (GraphQL) API.
///
/// Only the response shapes actually consumed by the indexer-backed functions
/// are modeled here.
///
/// The GraphQL `bigint`/`numeric`/`timestamp` scalars are typed `dynamic`,
/// since the indexer may return them as JSON numbers or strings depending on
/// the scalar.
library;

import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/public_key.dart';
import 'pagination.dart';

/// The GraphQL query to pass into the `queryIndexer` function.
class GraphqlQuery {
  /// The GraphQL document.
  final String query;

  /// The GraphQL variables.
  final Map<String, dynamic>? variables;

  const GraphqlQuery({required this.query, this.variables});

  Map<String, dynamic> toJson() => {
        'query': query,
        if (variables != null) 'variables': variables,
      };
}

/// Specifies the order direction for sorting, including options for handling
/// null values.
enum OrderByValue {
  asc('asc'),
  ascNullsFirst('asc_nulls_first'),
  ascNullsLast('asc_nulls_last'),
  desc('desc'),
  descNullsFirst('desc_nulls_first'),
  descNullsLast('desc_nulls_last');

  const OrderByValue(this.value);

  final String value;
}

/// A generic order-by argument: a list of `{column: OrderByValue}` maps
/// (values may also be nested maps for ordering by nested relations).
typedef OrderBy = List<Map<String, Object>>;

/// Converts an [OrderBy] argument into a JSON-encodable structure
/// ([OrderByValue] entries are replaced by their wire string).
Object? orderByToJson(OrderBy? orderBy) =>
    orderBy?.map(_orderByEntryToJson).toList();

Object _orderByEntryToJson(Object value) {
  if (value is OrderByValue) return value.value;
  if (value is Map) {
    return value.map(
      (key, nested) => MapEntry(key, _orderByEntryToJson(nested as Object)),
    );
  }
  return value;
}

/// The token standard to query for, which can be either version `v1` or `v2`.
enum TokenStandard {
  v1('v1'),
  v2('v2');

  const TokenStandard(this.value);

  final String value;
}

/// Combined optional arguments for indexer GraphQL queries: pagination,
/// filtering (`where`), ordering (`order_by`) and token standard.
///
/// Each query only honors the fields it accepts (e.g. queries without an
/// `order_by` GraphQL variable ignore [orderBy]).
class IndexerQueryArgs {
  /// The number of records to skip before collecting the result set.
  final AnyNumber? offset;

  /// The maximum number of records to return.
  final int? limit;

  /// A Hasura `*_bool_exp` where-condition to filter the results.
  final Map<String, dynamic>? where;

  /// The criteria to sort the results by.
  final OrderBy? orderBy;

  /// The token standard to filter by (token/collection queries only).
  final TokenStandard? tokenStandard;

  const IndexerQueryArgs({
    this.offset,
    this.limit,
    this.where,
    this.orderBy,
    this.tokenStandard,
  });
}

/// A user transaction row of the `GetChainTopUserTransactions` query.
class ChainTopUserTransaction {
  /// The transaction version (GraphQL `bigint`).
  final dynamic version;

  const ChainTopUserTransaction({this.version});

  factory ChainTopUserTransaction.fromJson(Map<String, dynamic> json) =>
      ChainTopUserTransaction(version: json['version']);
}

/// A processor status row of the `GetProcessorStatus` query.
class ProcessorStatus {
  /// The last ledger version processed successfully (GraphQL `bigint`).
  final dynamic lastSuccessVersion;

  /// The processor name.
  final String processor;

  /// When the processor was last updated (GraphQL `timestamp`).
  final dynamic lastUpdated;

  const ProcessorStatus({
    required this.lastSuccessVersion,
    required this.processor,
    this.lastUpdated,
  });

  factory ProcessorStatus.fromJson(Map<String, dynamic> json) =>
      ProcessorStatus(
        lastSuccessVersion: json['last_success_version'],
        processor: json['processor'] as String,
        lastUpdated: json['last_updated'],
      );
}

/// Metadata for a fungible asset.
///
/// Also used for the nested `metadata` object of the account coins data
/// query (which omits `supply_v2`/`maximum_v2`).
class FungibleAssetMetadata {
  final String? iconUri;
  final String? projectUri;
  final String? supplyAggregatorTableHandleV1;
  final String? supplyAggregatorTableKeyV1;
  final String creatorAddress;
  final String assetType;
  final int decimals;
  final dynamic lastTransactionTimestamp;
  final dynamic lastTransactionVersion;
  final String name;
  final String symbol;
  final String tokenStandard;
  final dynamic supplyV2;
  final dynamic maximumV2;

  const FungibleAssetMetadata({
    this.iconUri,
    this.projectUri,
    this.supplyAggregatorTableHandleV1,
    this.supplyAggregatorTableKeyV1,
    required this.creatorAddress,
    required this.assetType,
    required this.decimals,
    this.lastTransactionTimestamp,
    this.lastTransactionVersion,
    required this.name,
    required this.symbol,
    required this.tokenStandard,
    this.supplyV2,
    this.maximumV2,
  });

  factory FungibleAssetMetadata.fromJson(Map<String, dynamic> json) =>
      FungibleAssetMetadata(
        iconUri: json['icon_uri'] as String?,
        projectUri: json['project_uri'] as String?,
        supplyAggregatorTableHandleV1:
            json['supply_aggregator_table_handle_v1'] as String?,
        supplyAggregatorTableKeyV1:
            json['supply_aggregator_table_key_v1'] as String?,
        creatorAddress: json['creator_address'] as String,
        assetType: json['asset_type'] as String,
        decimals: json['decimals'] as int,
        lastTransactionTimestamp: json['last_transaction_timestamp'],
        lastTransactionVersion: json['last_transaction_version'],
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        tokenStandard: json['token_standard'] as String,
        supplyV2: json['supply_v2'],
        maximumV2: json['maximum_v2'],
      );
}

/// An activity associated with a fungible asset.
class FungibleAssetActivity {
  final dynamic amount;
  final String? assetType;
  final dynamic blockHeight;
  final String? entryFunctionIdStr;
  final dynamic eventIndex;
  final String? gasFeePayerAddress;
  final bool? isFrozen;
  final bool isGasFee;
  final bool isTransactionSuccess;
  final String? ownerAddress;
  final String storageId;
  final dynamic storageRefundAmount;
  final String tokenStandard;
  final dynamic transactionTimestamp;
  final dynamic transactionVersion;
  final String type;

  const FungibleAssetActivity({
    this.amount,
    this.assetType,
    this.blockHeight,
    this.entryFunctionIdStr,
    this.eventIndex,
    this.gasFeePayerAddress,
    this.isFrozen,
    required this.isGasFee,
    required this.isTransactionSuccess,
    this.ownerAddress,
    required this.storageId,
    this.storageRefundAmount,
    required this.tokenStandard,
    this.transactionTimestamp,
    this.transactionVersion,
    required this.type,
  });

  factory FungibleAssetActivity.fromJson(Map<String, dynamic> json) =>
      FungibleAssetActivity(
        amount: json['amount'],
        assetType: json['asset_type'] as String?,
        blockHeight: json['block_height'],
        entryFunctionIdStr: json['entry_function_id_str'] as String?,
        eventIndex: json['event_index'],
        gasFeePayerAddress: json['gas_fee_payer_address'] as String?,
        isFrozen: json['is_frozen'] as bool?,
        isGasFee: json['is_gas_fee'] as bool,
        isTransactionSuccess: json['is_transaction_success'] as bool,
        ownerAddress: json['owner_address'] as String?,
        storageId: json['storage_id'] as String,
        storageRefundAmount: json['storage_refund_amount'],
        tokenStandard: json['token_standard'] as String,
        transactionTimestamp: json['transaction_timestamp'],
        transactionVersion: json['transaction_version'],
        type: json['type'] as String,
      );
}

/// A current fungible asset balance of an owner address.
///
/// The `metadata` field is only populated by the account coins data query
/// (`GetAccountCoinsData`); the plain balances query does not request it.
class CurrentFungibleAssetBalance {
  final dynamic amount;
  final String assetType;
  final bool isFrozen;
  final bool isPrimary;
  final dynamic lastTransactionTimestamp;
  final dynamic lastTransactionVersion;
  final String ownerAddress;
  final String storageId;
  final String tokenStandard;
  final FungibleAssetMetadata? metadata;

  const CurrentFungibleAssetBalance({
    this.amount,
    required this.assetType,
    required this.isFrozen,
    required this.isPrimary,
    this.lastTransactionTimestamp,
    this.lastTransactionVersion,
    required this.ownerAddress,
    required this.storageId,
    required this.tokenStandard,
    this.metadata,
  });

  factory CurrentFungibleAssetBalance.fromJson(Map<String, dynamic> json) =>
      CurrentFungibleAssetBalance(
        amount: json['amount'],
        assetType: json['asset_type'] as String,
        isFrozen: json['is_frozen'] as bool,
        isPrimary: json['is_primary'] as bool,
        lastTransactionTimestamp: json['last_transaction_timestamp'],
        lastTransactionVersion: json['last_transaction_version'],
        ownerAddress: json['owner_address'] as String,
        storageId: json['storage_id'] as String,
        tokenStandard: json['token_standard'] as String,
        metadata: json['metadata'] == null
            ? null
            : FungibleAssetMetadata.fromJson(
                Map<String, dynamic>.from(json['metadata'] as Map),
              ),
      );
}

/// Data for a collection (a `current_collections_v2` row; also the nested
/// `current_collection` object of token data).
class CollectionData {
  final String uri;
  final dynamic totalMintedV2;
  final String tokenStandard;
  final String? tableHandleV1;
  final bool? mutableUri;
  final bool? mutableDescription;
  final dynamic maxSupply;
  final String collectionId;
  final String collectionName;
  final String creatorAddress;
  final dynamic currentSupply;
  final String description;
  final dynamic lastTransactionTimestamp;
  final dynamic lastTransactionVersion;

  const CollectionData({
    required this.uri,
    this.totalMintedV2,
    required this.tokenStandard,
    this.tableHandleV1,
    this.mutableUri,
    this.mutableDescription,
    this.maxSupply,
    required this.collectionId,
    required this.collectionName,
    required this.creatorAddress,
    this.currentSupply,
    required this.description,
    this.lastTransactionTimestamp,
    this.lastTransactionVersion,
  });

  factory CollectionData.fromJson(Map<String, dynamic> json) => CollectionData(
        uri: json['uri'] as String,
        totalMintedV2: json['total_minted_v2'],
        tokenStandard: json['token_standard'] as String,
        tableHandleV1: json['table_handle_v1'] as String?,
        mutableUri: json['mutable_uri'] as bool?,
        mutableDescription: json['mutable_description'] as bool?,
        maxSupply: json['max_supply'],
        collectionId: json['collection_id'] as String,
        collectionName: json['collection_name'] as String,
        creatorAddress: json['creator_address'] as String,
        currentSupply: json['current_supply'],
        description: json['description'] as String,
        lastTransactionTimestamp: json['last_transaction_timestamp'],
        lastTransactionVersion: json['last_transaction_version'],
      );
}

/// Data for a token/digital asset (a `current_token_datas_v2` row; also the
/// nested `current_token_data` object of token ownerships).
class TokenData {
  final String collectionId;
  final String description;
  final bool? isFungibleV2;
  final dynamic largestPropertyVersionV1;
  final dynamic lastTransactionTimestamp;
  final dynamic lastTransactionVersion;
  final dynamic maximum;
  final dynamic supply;
  final String tokenDataId;
  final String tokenName;
  final dynamic tokenProperties;
  final String tokenStandard;
  final String tokenUri;
  final dynamic decimals;
  final CollectionData? currentCollection;

  const TokenData({
    required this.collectionId,
    required this.description,
    this.isFungibleV2,
    this.largestPropertyVersionV1,
    this.lastTransactionTimestamp,
    this.lastTransactionVersion,
    this.maximum,
    this.supply,
    required this.tokenDataId,
    required this.tokenName,
    this.tokenProperties,
    required this.tokenStandard,
    required this.tokenUri,
    this.decimals,
    this.currentCollection,
  });

  factory TokenData.fromJson(Map<String, dynamic> json) => TokenData(
        collectionId: json['collection_id'] as String,
        description: json['description'] as String,
        isFungibleV2: json['is_fungible_v2'] as bool?,
        largestPropertyVersionV1: json['largest_property_version_v1'],
        lastTransactionTimestamp: json['last_transaction_timestamp'],
        lastTransactionVersion: json['last_transaction_version'],
        maximum: json['maximum'],
        supply: json['supply'],
        tokenDataId: json['token_data_id'] as String,
        tokenName: json['token_name'] as String,
        tokenProperties: json['token_properties'],
        tokenStandard: json['token_standard'] as String,
        tokenUri: json['token_uri'] as String,
        decimals: json['decimals'],
        currentCollection: json['current_collection'] == null
            ? null
            : CollectionData.fromJson(
                Map<String, dynamic>.from(json['current_collection'] as Map),
              ),
      );
}

/// A current token ownership row (the `CurrentTokenOwnershipFields`
/// fragment of `current_token_ownerships_v2`).
class TokenOwnership {
  final String tokenStandard;
  final dynamic tokenPropertiesMutatedV1;
  final String tokenDataId;
  final String? tableTypeV1;
  final String storageId;
  final dynamic propertyVersionV1;
  final String ownerAddress;
  final dynamic lastTransactionVersion;
  final dynamic lastTransactionTimestamp;
  final bool? isSoulboundV2;
  final bool? isFungibleV2;
  final dynamic amount;
  final TokenData? currentTokenData;

  const TokenOwnership({
    required this.tokenStandard,
    this.tokenPropertiesMutatedV1,
    required this.tokenDataId,
    this.tableTypeV1,
    required this.storageId,
    this.propertyVersionV1,
    required this.ownerAddress,
    this.lastTransactionVersion,
    this.lastTransactionTimestamp,
    this.isSoulboundV2,
    this.isFungibleV2,
    this.amount,
    this.currentTokenData,
  });

  factory TokenOwnership.fromJson(Map<String, dynamic> json) => TokenOwnership(
        tokenStandard: json['token_standard'] as String,
        tokenPropertiesMutatedV1: json['token_properties_mutated_v1'],
        tokenDataId: json['token_data_id'] as String,
        tableTypeV1: json['table_type_v1'] as String?,
        storageId: json['storage_id'] as String,
        propertyVersionV1: json['property_version_v1'],
        ownerAddress: json['owner_address'] as String,
        lastTransactionVersion: json['last_transaction_version'],
        lastTransactionTimestamp: json['last_transaction_timestamp'],
        isSoulboundV2: json['is_soulbound_v2'] as bool?,
        isFungibleV2: json['is_fungible_v2'] as bool?,
        amount: json['amount'],
        currentTokenData: json['current_token_data'] == null
            ? null
            : TokenData.fromJson(
                Map<String, dynamic>.from(json['current_token_data'] as Map),
              ),
      );
}

/// A token activity row (the `TokenActivitiesFields` fragment of
/// `token_activities_v2`).
class TokenActivity {
  final String? afterValue;
  final String? beforeValue;
  final String? entryFunctionIdStr;
  final String eventAccountAddress;
  final dynamic eventIndex;
  final String? fromAddress;
  final bool? isFungibleV2;
  final dynamic propertyVersionV1;
  final String? toAddress;
  final dynamic tokenAmount;
  final String tokenDataId;
  final String tokenStandard;
  final dynamic transactionTimestamp;
  final dynamic transactionVersion;
  final String type;

  const TokenActivity({
    this.afterValue,
    this.beforeValue,
    this.entryFunctionIdStr,
    required this.eventAccountAddress,
    this.eventIndex,
    this.fromAddress,
    this.isFungibleV2,
    this.propertyVersionV1,
    this.toAddress,
    this.tokenAmount,
    required this.tokenDataId,
    required this.tokenStandard,
    this.transactionTimestamp,
    this.transactionVersion,
    required this.type,
  });

  factory TokenActivity.fromJson(Map<String, dynamic> json) => TokenActivity(
        afterValue: json['after_value'] as String?,
        beforeValue: json['before_value'] as String?,
        entryFunctionIdStr: json['entry_function_id_str'] as String?,
        eventAccountAddress: json['event_account_address'] as String,
        eventIndex: json['event_index'],
        fromAddress: json['from_address'] as String?,
        isFungibleV2: json['is_fungible_v2'] as bool?,
        propertyVersionV1: json['property_version_v1'],
        toAddress: json['to_address'] as String?,
        tokenAmount: json['token_amount'],
        tokenDataId: json['token_data_id'] as String,
        tokenStandard: json['token_standard'] as String,
        transactionTimestamp: json['transaction_timestamp'],
        transactionVersion: json['transaction_version'],
        type: json['type'] as String,
      );
}

/// A collection ownership row of the `GetAccountCollectionsWithOwnedTokens`
/// query (`current_collection_ownership_v2_view`).
class AccountCollectionWithOwnedTokens {
  final String? collectionId;
  final String? collectionName;
  final String? collectionUri;
  final String? creatorAddress;
  final dynamic distinctTokens;
  final dynamic lastTransactionVersion;
  final String? ownerAddress;
  final String? singleTokenUri;
  final CollectionData? currentCollection;

  const AccountCollectionWithOwnedTokens({
    this.collectionId,
    this.collectionName,
    this.collectionUri,
    this.creatorAddress,
    this.distinctTokens,
    this.lastTransactionVersion,
    this.ownerAddress,
    this.singleTokenUri,
    this.currentCollection,
  });

  factory AccountCollectionWithOwnedTokens.fromJson(
          Map<String, dynamic> json) =>
      AccountCollectionWithOwnedTokens(
        collectionId: json['collection_id'] as String?,
        collectionName: json['collection_name'] as String?,
        collectionUri: json['collection_uri'] as String?,
        creatorAddress: json['creator_address'] as String?,
        distinctTokens: json['distinct_tokens'],
        lastTransactionVersion: json['last_transaction_version'],
        ownerAddress: json['owner_address'] as String?,
        singleTokenUri: json['single_token_uri'] as String?,
        currentCollection: json['current_collection'] == null
            ? null
            : CollectionData.fromJson(
                Map<String, dynamic>.from(json['current_collection'] as Map),
              ),
      );
}

/// An object row of the `GetObjectData` query (`current_objects`).
class ObjectData {
  final bool allowUngatedTransfer;
  final String stateKeyHash;
  final String ownerAddress;
  final String objectAddress;
  final dynamic lastTransactionVersion;
  final dynamic lastGuidCreationNum;
  final bool isDeleted;

  const ObjectData({
    required this.allowUngatedTransfer,
    required this.stateKeyHash,
    required this.ownerAddress,
    required this.objectAddress,
    this.lastTransactionVersion,
    this.lastGuidCreationNum,
    required this.isDeleted,
  });

  factory ObjectData.fromJson(Map<String, dynamic> json) => ObjectData(
        allowUngatedTransfer: json['allow_ungated_transfer'] as bool,
        stateKeyHash: json['state_key_hash'] as String,
        ownerAddress: json['owner_address'] as String,
        objectAddress: json['object_address'] as String,
        lastTransactionVersion: json['last_transaction_version'],
        lastGuidCreationNum: json['last_guid_creation_num'],
        isDeleted: json['is_deleted'] as bool,
      );
}

/// The number of active delegators for a pool.
class NumberOfDelegators {
  final dynamic numActiveDelegator;
  final String? poolAddress;

  const NumberOfDelegators({this.numActiveDelegator, this.poolAddress});

  factory NumberOfDelegators.fromJson(Map<String, dynamic> json) =>
      NumberOfDelegators(
        numActiveDelegator: json['num_active_delegator'],
        poolAddress: json['pool_address'] as String?,
      );
}

/// A delegated staking activity row.
class DelegatedStakingActivity {
  final dynamic amount;
  final String delegatorAddress;
  final dynamic eventIndex;
  final String eventType;
  final String poolAddress;
  final dynamic transactionVersion;

  const DelegatedStakingActivity({
    this.amount,
    required this.delegatorAddress,
    this.eventIndex,
    required this.eventType,
    required this.poolAddress,
    this.transactionVersion,
  });

  factory DelegatedStakingActivity.fromJson(Map<String, dynamic> json) =>
      DelegatedStakingActivity(
        amount: json['amount'],
        delegatorAddress: json['delegator_address'] as String,
        eventIndex: json['event_index'],
        eventType: json['event_type'] as String,
        poolAddress: json['pool_address'] as String,
        transactionVersion: json['transaction_version'],
      );
}

/// A table item row of the `GetTableItemsData` query.
class TableItemData {
  final dynamic decodedKey;
  final dynamic decodedValue;
  final String key;
  final String tableHandle;
  final dynamic transactionVersion;
  final dynamic writeSetChangeIndex;

  const TableItemData({
    this.decodedKey,
    this.decodedValue,
    required this.key,
    required this.tableHandle,
    this.transactionVersion,
    this.writeSetChangeIndex,
  });

  factory TableItemData.fromJson(Map<String, dynamic> json) => TableItemData(
        decodedKey: json['decoded_key'],
        decodedValue: json['decoded_value'],
        key: json['key'] as String,
        tableHandle: json['table_handle'] as String,
        transactionVersion: json['transaction_version'],
        writeSetChangeIndex: json['write_set_change_index'],
      );
}

/// A table metadata row of the `GetTableItemsMetadata` query.
class TableMetadata {
  final String handle;
  final String keyType;
  final String valueType;

  const TableMetadata({
    required this.handle,
    required this.keyType,
    required this.valueType,
  });

  factory TableMetadata.fromJson(Map<String, dynamic> json) => TableMetadata(
        handle: json['handle'] as String,
        keyType: json['key_type'] as String,
        valueType: json['value_type'] as String,
      );
}

/// An auth-key/account-address association row of the
/// `GetAccountAddressesForAuthKey` query.
class AuthKeyAccountAddress {
  final String authKey;
  final String accountAddress;
  final dynamic lastTransactionVersion;
  final bool isAuthKeyUsed;

  const AuthKeyAccountAddress({
    required this.authKey,
    required this.accountAddress,
    this.lastTransactionVersion,
    required this.isAuthKeyUsed,
  });

  factory AuthKeyAccountAddress.fromJson(Map<String, dynamic> json) =>
      AuthKeyAccountAddress(
        authKey: json['auth_key'] as String,
        accountAddress: json['account_address'] as String,
        lastTransactionVersion: json['last_transaction_version'],
        isAuthKeyUsed: json['is_auth_key_used'] as bool,
      );
}

/// A public-key/auth-key association row of the `GetAuthKeysForPublicKey`
/// query.
class PublicKeyAuthKey {
  final String publicKey;
  final String publicKeyType;
  final String authKey;
  final String? accountPublicKey;
  final dynamic lastTransactionVersion;
  final bool isPublicKeyUsed;
  final String signatureType;

  const PublicKeyAuthKey({
    required this.publicKey,
    required this.publicKeyType,
    required this.authKey,
    this.accountPublicKey,
    this.lastTransactionVersion,
    required this.isPublicKeyUsed,
    required this.signatureType,
  });

  factory PublicKeyAuthKey.fromJson(Map<String, dynamic> json) =>
      PublicKeyAuthKey(
        publicKey: json['public_key'] as String,
        publicKeyType: json['public_key_type'] as String,
        authKey: json['auth_key'] as String,
        accountPublicKey: json['account_public_key'] as String?,
        lastTransactionVersion: json['last_transaction_version'],
        isPublicKeyUsed: json['is_public_key_used'] as bool,
        signatureType: json['signature_type'] as String,
      );
}

/// Information about an account associated with a public key, as returned by
/// `getAccountsForPublicKey`.
class AccountInfo {
  final AccountAddress accountAddress;
  final AccountPublicKey publicKey;
  final int lastTransactionVersion;

  const AccountInfo({
    required this.accountAddress,
    required this.publicKey,
    required this.lastTransactionVersion,
  });
}

/// An auth-key/account-address pair resolved from the indexer, used
/// internally when deriving accounts.
class AuthKeyAddressPair {
  final AuthenticationKey authKey;
  final AccountAddress accountAddress;
  final int lastTransactionVersion;

  const AuthKeyAddressPair({
    required this.authKey,
    required this.accountAddress,
    required this.lastTransactionVersion,
  });
}
