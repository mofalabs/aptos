// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_token_datas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_CurrentTokenDatas _$$_CurrentTokenDatasFromJson(Map<String, dynamic> json) =>
    _$_CurrentTokenDatas(
      currentTokenDatasV2: (json['current_token_datas_v2'] as List<dynamic>)
          .map((e) => CurrentTokenData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_CurrentTokenDatasToJson(
        _$_CurrentTokenDatas instance) =>
    <String, dynamic>{
      'current_token_datas_v2': instance.currentTokenDatasV2,
    };

_$_CurrentTokenData _$$_CurrentTokenDataFromJson(Map<String, dynamic> json) =>
    _$_CurrentTokenData(
      tokenDataId: json['token_data_id'] as String,
      tokenName: json['token_name'] as String,
      tokenUri: json['token_uri'] as String,
      tokenProperties: TokenProperties.fromJson(
          json['token_properties'] as Map<String, dynamic>),
      tokenStandard:
          $enumDecode(_$TokenStandardEnumMap, json['token_standard']),
      largestPropertyVersionV1: json['largest_property_version_v1'] as int?,
      maximum: json['maximum'] as int?,
      isFungibleV2: json['is_fungible_v2'] as bool?,
      supply: json['supply'] as int,
      lastTransactionVersion: json['last_transaction_version'] as int,
      lastTransactionTimestamp: json['last_transaction_timestamp'] as String,
      currentCollection: json['current_collection'] == null
          ? null
          : CurrentCollection.fromJson(
              json['current_collection'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_CurrentTokenDataToJson(_$_CurrentTokenData instance) =>
    <String, dynamic>{
      'token_data_id': instance.tokenDataId,
      'token_name': instance.tokenName,
      'token_uri': instance.tokenUri,
      'token_properties': instance.tokenProperties,
      'token_standard': _$TokenStandardEnumMap[instance.tokenStandard]!,
      'largest_property_version_v1': instance.largestPropertyVersionV1,
      'maximum': instance.maximum,
      'is_fungible_v2': instance.isFungibleV2,
      'supply': instance.supply,
      'last_transaction_version': instance.lastTransactionVersion,
      'last_transaction_timestamp': instance.lastTransactionTimestamp,
      'current_collection': instance.currentCollection,
    };

const _$TokenStandardEnumMap = {
  TokenStandard.v1: 'v1',
  TokenStandard.v2: 'v2',
};

_$_TokenProperties _$$_TokenPropertiesFromJson(Map<String, dynamic> json) =>
    _$_TokenProperties(
      tokenBurnableByOwner: json['TOKEN_BURNABLE_BY_OWNER'] as String?,
      tokenPropertyMutatble: json['TOKEN_PROPERTY_MUTATBLE'] as String?,
    );

Map<String, dynamic> _$$_TokenPropertiesToJson(_$_TokenProperties instance) =>
    <String, dynamic>{
      'TOKEN_BURNABLE_BY_OWNER': instance.tokenBurnableByOwner,
      'TOKEN_PROPERTY_MUTATBLE': instance.tokenPropertyMutatble,
    };

_$_CurrentCollection _$$_CurrentCollectionFromJson(Map<String, dynamic> json) =>
    _$_CurrentCollection(
      collectionId: json['collection_id'] as String,
      collectionName: json['collection_name'] as String,
      creatorAddress: json['creator_address'] as String,
      uri: json['uri'] as String,
      currentSupply: json['current_supply'] as int,
    );

Map<String, dynamic> _$$_CurrentCollectionToJson(
        _$_CurrentCollection instance) =>
    <String, dynamic>{
      'collection_id': instance.collectionId,
      'collection_name': instance.collectionName,
      'creator_address': instance.creatorAddress,
      'uri': instance.uri,
      'current_supply': instance.currentSupply,
    };
