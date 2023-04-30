// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coin_activity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

CoinActivity _$CoinActivityFromJson(Map<String, dynamic> json) {
  return _CoinActivity.fromJson(json);
}

/// @nodoc
mixin _$CoinActivity {
  String get transactionTimestamp => throw _privateConstructorUsedError;
  int get transactionVersion => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String get activityType => throw _privateConstructorUsedError;
  String get coinType => throw _privateConstructorUsedError;
  bool get isGasFee => throw _privateConstructorUsedError;
  bool get isTransactionSuccess => throw _privateConstructorUsedError;
  String get eventAccountAddress => throw _privateConstructorUsedError;
  int get eventCreationNumber => throw _privateConstructorUsedError;
  int get eventSequenceNumber => throw _privateConstructorUsedError;
  String? get entryFunctionIdStr => throw _privateConstructorUsedError;
  int get blockHeight => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CoinActivity implements _CoinActivity {
  const _$_CoinActivity(
      {required this.transactionTimestamp,
      required this.transactionVersion,
      required this.amount,
      required this.activityType,
      required this.coinType,
      required this.isGasFee,
      required this.isTransactionSuccess,
      required this.eventAccountAddress,
      required this.eventCreationNumber,
      required this.eventSequenceNumber,
      this.entryFunctionIdStr,
      required this.blockHeight});

  factory _$_CoinActivity.fromJson(Map<String, dynamic> json) =>
      _$$_CoinActivityFromJson(json);

  @override
  final String transactionTimestamp;
  @override
  final int transactionVersion;
  @override
  final int amount;
  @override
  final String activityType;
  @override
  final String coinType;
  @override
  final bool isGasFee;
  @override
  final bool isTransactionSuccess;
  @override
  final String eventAccountAddress;
  @override
  final int eventCreationNumber;
  @override
  final int eventSequenceNumber;
  @override
  final String? entryFunctionIdStr;
  @override
  final int blockHeight;

  @override
  String toString() {
    return 'CoinActivity(transactionTimestamp: $transactionTimestamp, transactionVersion: $transactionVersion, amount: $amount, activityType: $activityType, coinType: $coinType, isGasFee: $isGasFee, isTransactionSuccess: $isTransactionSuccess, eventAccountAddress: $eventAccountAddress, eventCreationNumber: $eventCreationNumber, eventSequenceNumber: $eventSequenceNumber, entryFunctionIdStr: $entryFunctionIdStr, blockHeight: $blockHeight)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CoinActivityToJson(
      this,
    );
  }
}

abstract class _CoinActivity implements CoinActivity {
  const factory _CoinActivity(
      {required final String transactionTimestamp,
      required final int transactionVersion,
      required final int amount,
      required final String activityType,
      required final String coinType,
      required final bool isGasFee,
      required final bool isTransactionSuccess,
      required final String eventAccountAddress,
      required final int eventCreationNumber,
      required final int eventSequenceNumber,
      final String? entryFunctionIdStr,
      required final int blockHeight}) = _$_CoinActivity;

  factory _CoinActivity.fromJson(Map<String, dynamic> json) =
      _$_CoinActivity.fromJson;

  @override
  String get transactionTimestamp;
  @override
  int get transactionVersion;
  @override
  int get amount;
  @override
  String get activityType;
  @override
  String get coinType;
  @override
  bool get isGasFee;
  @override
  bool get isTransactionSuccess;
  @override
  String get eventAccountAddress;
  @override
  int get eventCreationNumber;
  @override
  int get eventSequenceNumber;
  @override
  String? get entryFunctionIdStr;
  @override
  int get blockHeight;
}
