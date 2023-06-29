
import 'package:aptos/indexer_client.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'current_token_datas.freezed.dart';
part 'current_token_datas.g.dart';

@freezed
class CurrentTokenDatas with _$CurrentTokenDatas{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CurrentTokenDatas({
    required List<CurrentTokenData> currentTokenDatasV2
  }) = _CurrentTokenDatas;

  factory CurrentTokenDatas.fromJson(Map<String, dynamic> json) => _$CurrentTokenDatasFromJson(json);
}

@freezed
class CurrentTokenData with _$CurrentTokenData{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CurrentTokenData({
    required String tokenDataId,
    required String tokenName,
    required String tokenUri,
    required TokenProperties tokenProperties,
    required TokenStandard tokenStandard,
    required int? largestPropertyVersionV1,
    required int? maximum,
    required bool? isFungibleV2,
    required int supply,
    required int lastTransactionVersion,
    required String lastTransactionTimestamp,
    required CurrentCollection? currentCollection
  }) = _CurrentTokenData;

  factory CurrentTokenData.fromJson(Map<String, dynamic> json) => _$CurrentTokenDataFromJson(json);
}

@freezed
class TokenProperties with _$TokenProperties{
  @JsonSerializable(fieldRename: FieldRename.screamingSnake)
  const factory TokenProperties({
    required String? tokenBurnableByOwner,
    required String? tokenPropertyMutatble,
  }) = _TokenProperties;

  factory TokenProperties.fromJson(Map<String, dynamic> json) => _$TokenPropertiesFromJson(json);
}

@freezed
class CurrentCollection with _$CurrentCollection{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CurrentCollection({
    required String collectionId,
    required String collectionName,
    required String creatorAddress,
    required String uri,
    required int currentSupply,
  }) = _CurrentCollection;

  factory CurrentCollection.fromJson(Map<String, dynamic> json) => _$CurrentCollectionFromJson(json);
}