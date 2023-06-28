// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_nfts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_AccountNFTs _$$_AccountNFTsFromJson(Map<String, dynamic> json) =>
    _$_AccountNFTs(
      currentTokenOwnerships:
          (json['current_token_ownerships'] as List<dynamic>)
              .map((e) => AccountNFT.fromJson(e as Map<String, dynamic>))
              .toList(),
    );

Map<String, dynamic> _$$_AccountNFTsToJson(_$_AccountNFTs instance) =>
    <String, dynamic>{
      'current_token_ownerships': instance.currentTokenOwnerships,
    };

_$_AccountNFT _$$_AccountNFTFromJson(Map<String, dynamic> json) =>
    _$_AccountNFT(
      amount: json['amount'] as int,
      currentTokenData: TokenData.fromJson(
          json['current_token_data'] as Map<String, dynamic>),
      currentCollectionData: CollectionData.fromJson(
          json['current_collection_data'] as Map<String, dynamic>),
      lastTransactionVersion: json['last_transaction_version'] as int,
      propertyVersion: json['property_version'] as int,
    );

Map<String, dynamic> _$$_AccountNFTToJson(_$_AccountNFT instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'current_token_data': instance.currentTokenData,
      'current_collection_data': instance.currentCollectionData,
      'last_transaction_version': instance.lastTransactionVersion,
      'property_version': instance.propertyVersion,
    };

_$_TokenData _$$_TokenDataFromJson(Map<String, dynamic> json) => _$_TokenData(
      creatorAddress: json['creator_address'] as String,
      collectionName: json['collection_name'] as String,
      description: json['description'] as String,
      metadataUri: json['metadata_uri'] as String,
      name: json['name'] as String,
      tokenDataIdHash: json['token_data_id_hash'] as String,
      collectionDataIdHash: json['collection_data_id_hash'] as String,
    );

Map<String, dynamic> _$$_TokenDataToJson(_$_TokenData instance) =>
    <String, dynamic>{
      'creator_address': instance.creatorAddress,
      'collection_name': instance.collectionName,
      'description': instance.description,
      'metadata_uri': instance.metadataUri,
      'name': instance.name,
      'token_data_id_hash': instance.tokenDataIdHash,
      'collection_data_id_hash': instance.collectionDataIdHash,
    };

_$_CollectionData _$$_CollectionDataFromJson(Map<String, dynamic> json) =>
    _$_CollectionData(
      metadataUri: json['metadata_uri'] as String,
      supply: json['supply'] as int,
      description: json['description'] as String,
      collectionName: json['collection_name'] as String,
      collectionDataIdHash: json['collection_data_id_hash'] as String,
      tableHandle: json['table_handle'] as String,
      creatorAddress: json['creator_address'] as String,
    );

Map<String, dynamic> _$$_CollectionDataToJson(_$_CollectionData instance) =>
    <String, dynamic>{
      'metadata_uri': instance.metadataUri,
      'supply': instance.supply,
      'description': instance.description,
      'collection_name': instance.collectionName,
      'collection_data_id_hash': instance.collectionDataIdHash,
      'table_handle': instance.tableHandle,
      'creator_address': instance.creatorAddress,
    };
