// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Signature _$$_SignatureFromJson(Map<String, dynamic> json) => _$_Signature(
      type: json['type'] as String,
      publicKey: json['public_key'] as String,
      signature: json['signature'] as String,
    );

Map<String, dynamic> _$$_SignatureToJson(_$_Signature instance) =>
    <String, dynamic>{
      'type': instance.type,
      'public_key': instance.publicKey,
      'signature': instance.signature,
    };
