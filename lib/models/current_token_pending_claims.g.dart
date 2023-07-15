// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_token_pending_claims.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_CurrentTokenPendingClaims _$$_CurrentTokenPendingClaimsFromJson(
        Map<String, dynamic> json) =>
    _$_CurrentTokenPendingClaims(
      currentTokenPendingClaims: (json['current_token_pending_claims']
              as List<dynamic>)
          .map((e) => CurrentTokenPending.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_CurrentTokenPendingClaimsToJson(
        _$_CurrentTokenPendingClaims instance) =>
    <String, dynamic>{
      'current_token_pending_claims': instance.currentTokenPendingClaims,
    };

_$_CurrentTokenPending _$$_CurrentTokenPendingFromJson(
        Map<String, dynamic> json) =>
    _$_CurrentTokenPending(
      fromAddress: json['from_address'] as String,
      toAddress: json['to_address'] as String,
      creatorAddress: json['creator_address'] as String,
      collectionName: json['collection_name'] as String,
      name: json['name'] as String,
      propertyVersion: json['property_version'] as int,
      amount: json['amount'] as int,
      currentCollectionData: CurrentCollectionData.fromJson(
          json['current_collection_data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_CurrentTokenPendingToJson(
        _$_CurrentTokenPending instance) =>
    <String, dynamic>{
      'from_address': instance.fromAddress,
      'to_address': instance.toAddress,
      'creator_address': instance.creatorAddress,
      'collection_name': instance.collectionName,
      'name': instance.name,
      'property_version': instance.propertyVersion,
      'amount': instance.amount,
      'current_collection_data': instance.currentCollectionData,
    };

_$_CurrentCollectionData _$$_CurrentCollectionDataFromJson(
        Map<String, dynamic> json) =>
    _$_CurrentCollectionData(
      collectionDataIdHash: json['collection_data_id_hash'] as String,
      collectionName: json['collection_name'] as String,
      description: json['description'] as String,
      lastTransactionVersion: json['last_transaction_version'] as int,
      metadataUri: json['metadata_uri'] as String,
      supply: json['supply'] as int,
    );

Map<String, dynamic> _$$_CurrentCollectionDataToJson(
        _$_CurrentCollectionData instance) =>
    <String, dynamic>{
      'collection_data_id_hash': instance.collectionDataIdHash,
      'collection_name': instance.collectionName,
      'description': instance.description,
      'last_transaction_version': instance.lastTransactionVersion,
      'metadata_uri': instance.metadataUri,
      'supply': instance.supply,
    };
