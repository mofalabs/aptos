// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_coins.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

AccountCoins _$AccountCoinsFromJson(Map<String, dynamic> json) {
  return _AccountCoins.fromJson(json);
}

/// @nodoc
mixin _$AccountCoins {
  List<CoinBalance> get currentCoinBalances =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_AccountCoins implements _AccountCoins {
  const _$_AccountCoins({required final List<CoinBalance> currentCoinBalances})
      : _currentCoinBalances = currentCoinBalances;

  factory _$_AccountCoins.fromJson(Map<String, dynamic> json) =>
      _$$_AccountCoinsFromJson(json);

  final List<CoinBalance> _currentCoinBalances;
  @override
  List<CoinBalance> get currentCoinBalances {
    if (_currentCoinBalances is EqualUnmodifiableListView)
      return _currentCoinBalances;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_currentCoinBalances);
  }

  @override
  String toString() {
    return 'AccountCoins(currentCoinBalances: $currentCoinBalances)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_AccountCoinsToJson(
      this,
    );
  }
}

abstract class _AccountCoins implements AccountCoins {
  const factory _AccountCoins(
      {required final List<CoinBalance> currentCoinBalances}) = _$_AccountCoins;

  factory _AccountCoins.fromJson(Map<String, dynamic> json) =
      _$_AccountCoins.fromJson;

  @override
  List<CoinBalance> get currentCoinBalances;
}

CoinBalance _$CoinBalanceFromJson(Map<String, dynamic> json) {
  return _CoinBalance.fromJson(json);
}

/// @nodoc
mixin _$CoinBalance {
  int get amount => throw _privateConstructorUsedError;
  String get coinType => throw _privateConstructorUsedError;
  CoinInfo? get coinInfo => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CoinBalance implements _CoinBalance {
  const _$_CoinBalance(
      {required this.amount, required this.coinType, this.coinInfo});

  factory _$_CoinBalance.fromJson(Map<String, dynamic> json) =>
      _$$_CoinBalanceFromJson(json);

  @override
  final int amount;
  @override
  final String coinType;
  @override
  final CoinInfo? coinInfo;

  @override
  String toString() {
    return 'CoinBalance(amount: $amount, coinType: $coinType, coinInfo: $coinInfo)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CoinBalanceToJson(
      this,
    );
  }
}

abstract class _CoinBalance implements CoinBalance {
  const factory _CoinBalance(
      {required final int amount,
      required final String coinType,
      final CoinInfo? coinInfo}) = _$_CoinBalance;

  factory _CoinBalance.fromJson(Map<String, dynamic> json) =
      _$_CoinBalance.fromJson;

  @override
  int get amount;
  @override
  String get coinType;
  @override
  CoinInfo? get coinInfo;
}

CoinInfo _$CoinInfoFromJson(Map<String, dynamic> json) {
  return _CoinInfo.fromJson(json);
}

/// @nodoc
mixin _$CoinInfo {
  String get name => throw _privateConstructorUsedError;
  int get decimals => throw _privateConstructorUsedError;
  String get symbol => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CoinInfo implements _CoinInfo {
  const _$_CoinInfo(
      {required this.name, required this.decimals, required this.symbol});

  factory _$_CoinInfo.fromJson(Map<String, dynamic> json) =>
      _$$_CoinInfoFromJson(json);

  @override
  final String name;
  @override
  final int decimals;
  @override
  final String symbol;

  @override
  String toString() {
    return 'CoinInfo(name: $name, decimals: $decimals, symbol: $symbol)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CoinInfoToJson(
      this,
    );
  }
}

abstract class _CoinInfo implements CoinInfo {
  const factory _CoinInfo(
      {required final String name,
      required final int decimals,
      required final String symbol}) = _$_CoinInfo;

  factory _CoinInfo.fromJson(Map<String, dynamic> json) = _$_CoinInfo.fromJson;

  @override
  String get name;
  @override
  int get decimals;
  @override
  String get symbol;
}
