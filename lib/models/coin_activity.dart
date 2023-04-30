
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coin_activity.freezed.dart';
part 'coin_activity.g.dart';

@freezed
class CoinActivity with _$CoinActivity{
@JsonSerializable(fieldRename: FieldRename.snake)
  const factory CoinActivity({
    required String transactionTimestamp,
    required int transactionVersion,
    required int amount,
    required String activityType,
    required String coinType,
    required bool isGasFee,
    required bool isTransactionSuccess,
    required String eventAccountAddress,
    required int eventCreationNumber,
    required int eventSequenceNumber,
    required String entryFunctionIdStr,
    required int blockHeight
  }) = _CoinActivity;

  factory CoinActivity.fromJson(Map<String, dynamic> json) => _$CoinActivityFromJson(json);
}