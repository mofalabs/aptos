
import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_coins.freezed.dart';
part 'account_coins.g.dart';

@freezed
class AccountCoins with _$AccountCoins{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AccountCoins({
    required List<CoinBalance> currentCoinBalances
  }) = _AccountCoins;

  factory AccountCoins.fromJson(Map<String, dynamic> json) => _$AccountCoinsFromJson(json);
}

@freezed
class CoinBalance with _$CoinBalance{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CoinBalance({
    required int amount,
    required String coinType,
    CoinInfo? coinInfo
  }) = _CoinBalance;

  factory CoinBalance.fromJson(Map<String, dynamic> json) => _$CoinBalanceFromJson(json);
}

@freezed
class CoinInfo with _$CoinInfo{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CoinInfo({
    required String name,
    required int decimals,
    required String symbol
  }) = _CoinInfo;

  factory CoinInfo.fromJson(Map<String, dynamic> json) => _$CoinInfoFromJson(json);
}