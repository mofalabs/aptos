// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Payload _$$_PayloadFromJson(Map<String, dynamic> json) => _$_Payload(
      type: json['type'] as String,
      function: json['function'] as String,
      typeArguments: (json['type_arguments'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      arguments: json['arguments'] as List<dynamic>,
    );

Map<String, dynamic> _$$_PayloadToJson(_$_Payload instance) =>
    <String, dynamic>{
      'type': instance.type,
      'function': instance.function,
      'type_arguments': instance.typeArguments,
      'arguments': instance.arguments,
    };
