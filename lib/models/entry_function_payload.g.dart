// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_function_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_EntryFunctionPayload _$$_EntryFunctionPayloadFromJson(
        Map<String, dynamic> json) =>
    _$_EntryFunctionPayload(
      functionId: json['functionId'] as String,
      typeArguments: (json['typeArguments'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      arguments: json['arguments'] as List<dynamic>,
    );

Map<String, dynamic> _$$_EntryFunctionPayloadToJson(
        _$_EntryFunctionPayload instance) =>
    <String, dynamic>{
      'functionId': instance.functionId,
      'typeArguments': instance.typeArguments,
      'arguments': instance.arguments,
    };
