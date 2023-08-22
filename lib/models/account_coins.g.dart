// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_coins.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_AccountCoins _$$_AccountCoinsFromJson(Map<String, dynamic> json) =>
    _$_AccountCoins(
      currentCoinBalances: (json['current_coin_balances'] as List<dynamic>)
          .map((e) => CoinBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_AccountCoinsToJson(_$_AccountCoins instance) =>
    <String, dynamic>{
      'current_coin_balances': instance.currentCoinBalances,
    };

_$_CoinBalance _$$_CoinBalanceFromJson(Map<String, dynamic> json) =>
    _$_CoinBalance(
      amount: json['amount'] as int,
      coinType: json['coin_type'] as String,
      coinInfo: json['coin_info'] == null
          ? null
          : CoinInfo.fromJson(json['coin_info'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_CoinBalanceToJson(_$_CoinBalance instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'coin_type': instance.coinType,
      'coin_info': instance.coinInfo,
    };

_$_CoinInfo _$$_CoinInfoFromJson(Map<String, dynamic> json) => _$_CoinInfo(
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      symbol: json['symbol'] as String,
    );

Map<String, dynamic> _$$_CoinInfoToJson(_$_CoinInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'decimals': instance.decimals,
      'symbol': instance.symbol,
    };
