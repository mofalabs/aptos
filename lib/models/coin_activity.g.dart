// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coin_activity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_CoinActivity _$$_CoinActivityFromJson(Map<String, dynamic> json) =>
    _$_CoinActivity(
      transactionTimestamp: json['transaction_timestamp'] as String,
      transactionVersion: json['transaction_version'] as int,
      amount: json['amount'] as int,
      activityType: json['activity_type'] as String,
      coinType: json['coin_type'] as String,
      isGasFee: json['is_gas_fee'] as bool,
      isTransactionSuccess: json['is_transaction_success'] as bool,
      eventAccountAddress: json['event_account_address'] as String,
      eventCreationNumber: json['event_creation_number'] as int,
      eventSequenceNumber: json['event_sequence_number'] as int,
      entryFunctionIdStr: json['entry_function_id_str'] as String?,
      blockHeight: json['block_height'] as int,
    );

Map<String, dynamic> _$$_CoinActivityToJson(_$_CoinActivity instance) =>
    <String, dynamic>{
      'transaction_timestamp': instance.transactionTimestamp,
      'transaction_version': instance.transactionVersion,
      'amount': instance.amount,
      'activity_type': instance.activityType,
      'coin_type': instance.coinType,
      'is_gas_fee': instance.isGasFee,
      'is_transaction_success': instance.isTransactionSuccess,
      'event_account_address': instance.eventAccountAddress,
      'event_creation_number': instance.eventCreationNumber,
      'event_sequence_number': instance.eventSequenceNumber,
      'entry_function_id_str': instance.entryFunctionIdStr,
      'block_height': instance.blockHeight,
    };
