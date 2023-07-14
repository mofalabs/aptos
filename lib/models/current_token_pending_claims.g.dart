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
      creatorAddress: json['creator_address'] as String,
      collectionName: json['collection_name'] as String,
      name: json['name'] as String,
      propertyVersion: json['property_version'] as int,
    );

Map<String, dynamic> _$$_CurrentTokenPendingToJson(
        _$_CurrentTokenPending instance) =>
    <String, dynamic>{
      'from_address': instance.fromAddress,
      'creator_address': instance.creatorAddress,
      'collection_name': instance.collectionName,
      'name': instance.name,
      'property_version': instance.propertyVersion,
    };
