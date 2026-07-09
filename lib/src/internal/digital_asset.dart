/// This file contains the underlying implementations for the exposed API
/// surface in `api/digital_asset.dart`.
library;

import 'dart:typed_data';

import '../account/account.dart';
import '../api/aptos_config.dart';
import '../bcs/consts.dart';
import '../bcs/serializable/move_primitives.dart';
import '../bcs/serializable/move_structs.dart';
import '../core/account_address.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/transaction_builder/remote_abi.dart';
import '../transactions/type_tag/parser.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/indexer.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../types/types.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;
import 'transaction_submission.dart';

/// A property type for digital asset property maps, mapping the user input
/// to the Move type Move expects.
enum PropertyType {
  boolean('bool'),
  u8('u8'),
  u16('u16'),
  u32('u32'),
  u64('u64'),
  u128('u128'),
  u256('u256'),
  address('address'),
  string('0x1::string::String'),
  array('vector<u8>');

  const PropertyType(this.value);

  /// The Move type string Move expects for this property type.
  final String value;
}

/// Accepted property value types for user input: `bool`, `int`, `BigInt`,
/// `String`, `AccountAddress`, or `Uint8List`.
///
/// To pass in an array, use the `Uint8List` type, for example
/// `MoveVector([MoveString('hello'), MoveString('world')]).bcsToBytes()`.
typedef PropertyValue = Object;

/// The default digital asset type to use if none is provided.
const String _defaultDigitalAssetType = '0x4::token::Token';

// FETCH QUERIES

/// Retrieves data for a specific digital asset using its address.
Future<TokenData> getDigitalAssetData({
  required AptosConfig aptosConfig,
  required AccountAddressInput digitalAssetAddress,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getTokenData,
      variables: {
        'where_condition': {
          'token_data_id': {
            '_eq': AccountAddress.from(digitalAssetAddress).toStringLong(),
          },
        },
      },
    ),
    originMethod: 'getDigitalAssetData',
  );

  return TokenData.fromJson(
    Map<String, dynamic>.from(
        (data['current_token_datas_v2'] as List).first as Map),
  );
}

/// Retrieves the current ownership details of a specified digital asset.
Future<TokenOwnership> getCurrentDigitalAssetOwnership({
  required AptosConfig aptosConfig,
  required AccountAddressInput digitalAssetAddress,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getCurrentTokenOwnership,
      variables: {
        'where_condition': {
          'token_data_id': {
            '_eq': AccountAddress.from(digitalAssetAddress).toStringLong(),
          },
          'amount': {'_gt': 0},
        },
      },
    ),
    originMethod: 'getCurrentDigitalAssetOwnership',
  );

  return TokenOwnership.fromJson(
    Map<String, dynamic>.from(
        (data['current_token_ownerships_v2'] as List).first as Map),
  );
}

/// Retrieves the digital assets owned by a specified account address.
///
/// [options] - Optional pagination and ordering parameters.
Future<List<TokenOwnership>> getOwnedDigitalAssets({
  required AptosConfig aptosConfig,
  required AccountAddressInput ownerAddress,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getCurrentTokenOwnership,
      variables: {
        'where_condition': {
          'owner_address': {
            '_eq': AccountAddress.from(ownerAddress).toStringLong(),
          },
          'amount': {'_gt': 0},
        },
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getOwnedDigitalAssets',
  );

  return (data['current_token_ownerships_v2'] as List)
      .map((e) => TokenOwnership.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the activity associated with a specific digital asset.
///
/// [options] - Optional pagination and ordering parameters.
Future<List<TokenActivity>> getDigitalAssetActivity({
  required AptosConfig aptosConfig,
  required AccountAddressInput digitalAssetAddress,
  IndexerQueryArgs? options,
}) async {
  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getTokenActivity,
      variables: {
        'where_condition': {
          'token_data_id': {
            '_eq': AccountAddress.from(digitalAssetAddress).toStringLong(),
          },
        },
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getDigitalAssetActivity',
  );

  return (data['token_activities_v2'] as List)
      .map((e) => TokenActivity.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves data for the current collections based on the specified
/// options, returning the first matching collection.
///
/// [options] - Optional filtering ([IndexerQueryArgs.where], a
/// `current_collections_v2_bool_exp`), token standard and pagination
/// parameters.
///
/// Throws a [StateError] if no collection matches.
Future<CollectionData> getCollectionData({
  required AptosConfig aptosConfig,
  IndexerQueryArgs? options,
}) async {
  final whereCondition = <String, dynamic>{...?options?.where};

  if (options?.tokenStandard != null) {
    whereCondition['token_standard'] = {'_eq': options!.tokenStandard!.value};
  }

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getCollectionData,
      variables: {
        'where_condition': whereCondition,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
      },
    ),
    originMethod: 'getCollectionData',
  );

  return CollectionData.fromJson(
    Map<String, dynamic>.from(
        (data['current_collections_v2'] as List).first as Map),
  );
}

/// Retrieves collection data based on the creator's address and the
/// collection name.
Future<CollectionData> getCollectionDataByCreatorAddressAndCollectionName({
  required AptosConfig aptosConfig,
  required AccountAddressInput creatorAddress,
  required String collectionName,
  IndexerQueryArgs? options,
}) {
  final address = AccountAddress.from(creatorAddress);

  return getCollectionData(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      tokenStandard: options?.tokenStandard,
      where: {
        'collection_name': {'_eq': collectionName},
        'creator_address': {'_eq': address.toStringLong()},
      },
    ),
  );
}

/// Retrieves collection data associated with a specific creator's address.
Future<CollectionData> getCollectionDataByCreatorAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput creatorAddress,
  IndexerQueryArgs? options,
}) {
  final address = AccountAddress.from(creatorAddress);

  return getCollectionData(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      tokenStandard: options?.tokenStandard,
      where: {
        'creator_address': {'_eq': address.toStringLong()},
      },
    ),
  );
}

/// Retrieves data for a specific collection using its unique identifier (the
/// collection object address).
Future<CollectionData> getCollectionDataByCollectionId({
  required AptosConfig aptosConfig,
  required AccountAddressInput collectionId,
  IndexerQueryArgs? options,
}) {
  final address = AccountAddress.from(collectionId);

  return getCollectionData(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      offset: options?.offset,
      limit: options?.limit,
      tokenStandard: options?.tokenStandard,
      where: {
        'collection_id': {'_eq': address.toStringLong()},
      },
    ),
  );
}

/// Retrieves the collection ID based on the creator's address and the
/// collection name.
Future<String> getCollectionId({
  required AptosConfig aptosConfig,
  required AccountAddressInput creatorAddress,
  required String collectionName,
  TokenStandard? tokenStandard,
}) async {
  final address = AccountAddress.from(creatorAddress);

  final data = await getCollectionData(
    aptosConfig: aptosConfig,
    options: IndexerQueryArgs(
      tokenStandard: tokenStandard,
      where: {
        'collection_name': {'_eq': collectionName},
        'creator_address': {'_eq': address.toStringLong()},
      },
    ),
  );
  return data.collectionId;
}

// TRANSACTIONS

// Lazy-initialized ABIs to avoid rebuilding them on every call.
EntryFunctionABI? _createCollectionAbi;
EntryFunctionABI _getCreateCollectionAbi() {
  return _createCollectionAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [
      TypeTagStruct(stringStructTag()),
      TypeTagU64(),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagBool(),
      TypeTagU64(),
      TypeTagU64(),
    ],
  );
}

/// Creates a new collection transaction on the Aptos blockchain, allowing
/// you to define the properties of the collection, including its name,
/// description and URI.
///
/// The optional named parameters configure the collection's supply, royalty
/// and mutability settings.
Future<SimpleTransaction> createCollectionTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String description,
  required String name,
  required String uri,
  AnyNumber? maxSupply,
  bool? mutableDescription,
  bool? mutableRoyalty,
  bool? mutableURI,
  bool? mutableTokenDescription,
  bool? mutableTokenName,
  bool? mutableTokenProperties,
  bool? mutableTokenURI,
  bool? tokensBurnableByCreator,
  bool? tokensFreezableByCreator,
  int? royaltyNumerator,
  int? royaltyDenominator,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::create_collection',
      functionArguments: [
        // Do not change the order.
        MoveString(description),
        U64(_toBigInt(maxSupply ?? maxU64BigInt)),
        MoveString(name),
        MoveString(uri),
        Bool(mutableDescription ?? true),
        Bool(mutableRoyalty ?? true),
        Bool(mutableURI ?? true),
        Bool(mutableTokenDescription ?? true),
        Bool(mutableTokenName ?? true),
        Bool(mutableTokenProperties ?? true),
        Bool(mutableTokenURI ?? true),
        Bool(tokensBurnableByCreator ?? true),
        Bool(tokensFreezableByCreator ?? true),
        U64(BigInt.from(royaltyNumerator ?? 0)),
        U64(BigInt.from(royaltyDenominator ?? 1)),
      ],
      abi: _getCreateCollectionAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _mintDigitalAssetAbi;
EntryFunctionABI _getMintDigitalAssetAbi() {
  return _mintDigitalAssetAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagVector(TypeTagStruct(stringStructTag())),
      TypeTagVector(TypeTagStruct(stringStructTag())),
      TypeTagVector(TypeTagVector.u8()),
    ],
  );
}

/// Creates a transaction to mint a digital asset into a collection.
Future<SimpleTransaction> mintDigitalAssetTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String collection,
  required String description,
  required String name,
  required String uri,
  List<String>? propertyKeys,
  List<PropertyType>? propertyTypes,
  List<PropertyValue>? propertyValues,
  InputGenerateTransactionOptions? options,
}) async {
  final convertedPropertyType =
      propertyTypes?.map((type) => type.value).toList();
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::mint',
      functionArguments: [
        MoveString(collection),
        MoveString(description),
        MoveString(name),
        MoveString(uri),
        MoveVector.string(propertyKeys ?? []),
        MoveVector.string(convertedPropertyType ?? []),
        _getPropertyValueRaw(propertyValues ?? [], convertedPropertyType ?? []),
      ],
      abi: _getMintDigitalAssetAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _transferDigitalAssetAbi;
EntryFunctionABI _getTransferDigitalAssetAbi() {
  return _transferDigitalAssetAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagAddress(),
    ],
  );
}

/// Initiates a transaction to transfer a digital asset from one account to
/// another.
Future<SimpleTransaction> transferDigitalAssetTransaction({
  required AptosConfig aptosConfig,
  required Account sender,
  required AccountAddressInput digitalAssetAddress,
  required AccountAddressInput recipient,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::object::transfer',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        AccountAddress.from(recipient),
      ],
      abi: _getTransferDigitalAssetAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _mintSoulBoundAbi;
EntryFunctionABI _getMintSoulBoundAbi() {
  return _mintSoulBoundAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagVector(TypeTagStruct(stringStructTag())),
      TypeTagVector(TypeTagStruct(stringStructTag())),
      TypeTagVector(TypeTagVector.u8()),
      TypeTagAddress(),
    ],
  );
}

/// Creates a transaction to mint a soul-bound token into a recipient's
/// account.
///
/// Throws an [ArgumentError] if the counts of property keys, property types
/// and property values do not match.
Future<SimpleTransaction> mintSoulBoundTransaction({
  required AptosConfig aptosConfig,
  required Account account,
  required String collection,
  required String description,
  required String name,
  required String uri,
  required AccountAddressInput recipient,
  List<String>? propertyKeys,
  List<PropertyType>? propertyTypes,
  List<PropertyValue>? propertyValues,
  InputGenerateTransactionOptions? options,
}) async {
  if (propertyKeys?.length != propertyValues?.length) {
    throw ArgumentError('Property keys and property values counts do not match');
  }
  if (propertyTypes?.length != propertyValues?.length) {
    throw ArgumentError('Property types and property values counts do not match');
  }
  final convertedPropertyType =
      propertyTypes?.map((type) => type.value).toList();
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: account.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::mint_soul_bound',
      functionArguments: [
        collection,
        description,
        name,
        uri,
        MoveVector.string(propertyKeys ?? []),
        MoveVector.string(convertedPropertyType ?? []),
        _getPropertyValueRaw(propertyValues ?? [], convertedPropertyType ?? []),
        recipient,
      ],
      abi: _getMintSoulBoundAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _burnDigitalAssetAbi;
EntryFunctionABI _getBurnDigitalAssetAbi() {
  return _burnDigitalAssetAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [TypeTagStruct(objectStructTag(TypeTagGeneric(0)))],
  );
}

/// Creates a transaction to burn a specified digital asset, permanently
/// removing it from the account.
Future<SimpleTransaction> burnDigitalAssetTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::burn',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [AccountAddress.from(digitalAssetAddress)],
      abi: _getBurnDigitalAssetAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _freezeDigitalAssetAbi;
EntryFunctionABI _getFreezeDigitalAssetAbi() {
  return _freezeDigitalAssetAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [TypeTagStruct(objectStructTag(TypeTagGeneric(0)))],
  );
}

/// Creates a transaction to freeze the transfer of a digital asset.
Future<SimpleTransaction> freezeDigitalAssetTransferTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::freeze_transfer',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [digitalAssetAddress],
      abi: _getFreezeDigitalAssetAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _unfreezeDigitalAssetAbi;
EntryFunctionABI _getUnfreezeDigitalAssetAbi() {
  return _unfreezeDigitalAssetAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [TypeTagStruct(objectStructTag(TypeTagGeneric(0)))],
  );
}

/// Unfreezes the transfer of a digital asset, allowing it to be transferred
/// again.
Future<SimpleTransaction> unfreezeDigitalAssetTransferTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::unfreeze_transfer',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [digitalAssetAddress],
      abi: _getUnfreezeDigitalAssetAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _setDigitalAssetDescriptionAbi;
EntryFunctionABI _getSetDigitalAssetDescriptionAbi() {
  return _setDigitalAssetDescriptionAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
    ],
  );
}

/// Sets the description for a digital asset.
Future<SimpleTransaction> setDigitalAssetDescriptionTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String description,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::set_description',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(description),
      ],
      abi: _getSetDigitalAssetDescriptionAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _setDigitalAssetNameAbi;
EntryFunctionABI _getSetDigitalAssetNameAbi() {
  return _setDigitalAssetNameAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
    ],
  );
}

/// Sets the name of a digital asset on the Aptos blockchain.
Future<SimpleTransaction> setDigitalAssetNameTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String name,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::set_name',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(name),
      ],
      abi: _getSetDigitalAssetNameAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _setDigitalAssetURIAbi;
EntryFunctionABI _getSetDigitalAssetURIAbi() {
  return _setDigitalAssetURIAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
    ],
  );
}

/// Sets the URI for a digital asset, allowing you to update the metadata
/// associated with it.
Future<SimpleTransaction> setDigitalAssetURITransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String uri,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::set_uri',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(uri),
      ],
      abi: _getSetDigitalAssetURIAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _addDigitalAssetPropertyAbi;
EntryFunctionABI _getAddDigitalAssetPropertyAbi() {
  return _addDigitalAssetPropertyAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagVector.u8(),
    ],
  );
}

/// Creates a transaction to add a property to a digital asset.
Future<SimpleTransaction> addDigitalAssetPropertyTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String propertyKey,
  required PropertyType propertyType,
  required PropertyValue propertyValue,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::add_property',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(propertyKey),
        MoveString(propertyType.value),
        MoveVector.u8(
            _getSinglePropertyValueRaw(propertyValue, propertyType.value)),
      ],
      abi: _getAddDigitalAssetPropertyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _removeDigitalAssetPropertyAbi;
EntryFunctionABI _getRemoveDigitalAssetPropertyAbi() {
  return _removeDigitalAssetPropertyAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
    ],
  );
}

/// Removes a property from a digital asset on the Aptos blockchain.
Future<SimpleTransaction> removeDigitalAssetPropertyTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String propertyKey,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::remove_property',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(propertyKey),
      ],
      abi: _getRemoveDigitalAssetPropertyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _updateDigitalAssetPropertyAbi;
EntryFunctionABI _getUpdateDigitalAssetPropertyAbi() {
  return _updateDigitalAssetPropertyAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
      TypeTagStruct(stringStructTag()),
      TypeTagVector.u8(),
    ],
  );
}

/// Updates a property of a digital asset.
Future<SimpleTransaction> updateDigitalAssetPropertyTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String propertyKey,
  required PropertyType propertyType,
  required PropertyValue propertyValue,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::update_property',
      typeArguments: [digitalAssetType ?? _defaultDigitalAssetType],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(propertyKey),
        MoveString(propertyType.value),
        _getSinglePropertyValueRaw(propertyValue, propertyType.value),
      ],
      abi: _getUpdateDigitalAssetPropertyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _addDigitalAssetTypedPropertyAbi;
EntryFunctionABI _getAddDigitalAssetTypedPropertyAbi() {
  return _addDigitalAssetTypedPropertyAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
      MoveFunctionGenericTypeParam(constraints: []),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
      TypeTagGeneric(1),
    ],
  );
}

/// Creates a transaction to add a typed property to a digital asset.
Future<SimpleTransaction> addDigitalAssetTypedPropertyTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String propertyKey,
  required PropertyType propertyType,
  required PropertyValue propertyValue,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::add_typed_property',
      typeArguments: [
        digitalAssetType ?? _defaultDigitalAssetType,
        propertyType.value,
      ],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(propertyKey),
        propertyValue,
      ],
      abi: _getAddDigitalAssetTypedPropertyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

EntryFunctionABI? _updateDigitalAssetTypedPropertyAbi;
EntryFunctionABI _getUpdateDigitalAssetTypedPropertyAbi() {
  return _updateDigitalAssetTypedPropertyAbi ??= EntryFunctionABI(
    typeParameters: const [
      MoveFunctionGenericTypeParam(constraints: [MoveAbility.key]),
      MoveFunctionGenericTypeParam(constraints: []),
    ],
    parameters: [
      TypeTagStruct(objectStructTag(TypeTagGeneric(0))),
      TypeTagStruct(stringStructTag()),
      TypeTagGeneric(1),
    ],
  );
}

/// Updates a typed property of a digital asset.
Future<SimpleTransaction> updateDigitalAssetTypedPropertyTransaction({
  required AptosConfig aptosConfig,
  required Account creator,
  required String propertyKey,
  required PropertyType propertyType,
  required PropertyValue propertyValue,
  required AccountAddressInput digitalAssetAddress,
  MoveStructId? digitalAssetType,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: creator.accountAddress,
    data: InputEntryFunctionData(
      function: '0x4::aptos_token::update_typed_property',
      typeArguments: [
        digitalAssetType ?? _defaultDigitalAssetType,
        propertyType.value,
      ],
      functionArguments: [
        AccountAddress.from(digitalAssetAddress),
        MoveString(propertyKey),
        propertyValue,
      ],
      abi: _getUpdateDigitalAssetTypedPropertyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

BigInt _toBigInt(AnyNumber value) =>
    value is BigInt ? value : BigInt.from(value as int);

/// Retrieves the raw values of the specified properties based on their Move
/// types.
List<Uint8List> _getPropertyValueRaw(
  List<PropertyValue> propertyValues,
  List<String> propertyTypes,
) {
  final results = <Uint8List>[];
  for (var index = 0; index < propertyTypes.length; index += 1) {
    results.add(
      _getSinglePropertyValueRaw(propertyValues[index], propertyTypes[index]),
    );
  }
  return results;
}

/// Retrieves the raw byte representation of a single property value based on
/// its Move type.
Uint8List _getSinglePropertyValueRaw(
  PropertyValue propertyValue,
  String propertyType,
) {
  final typeTag = parseTypeTag(propertyType);
  final res = checkOrConvertArgument(propertyValue, typeTag, 0, []);
  return res.bcsToBytes();
}
