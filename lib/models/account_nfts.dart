
import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_nfts.freezed.dart';
part 'account_nfts.g.dart';

@freezed
class AccountNFTs with _$AccountNFTs{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AccountNFTs({
    required List<AccountNFT> currentTokenOwnerships
  }) = _AccountNFTs;

  factory AccountNFTs.fromJson(Map<String, dynamic> json) => _$AccountNFTsFromJson(json);
}

@freezed
class AccountNFT with _$AccountNFT{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AccountNFT({
    required int amount,
    required TokenData currentTokenData,
    required CollectionData currentCollectionData,
    required int lastTransactionVersion,
    required int propertyVersion,
  }) = _AccountNFT;

  factory AccountNFT.fromJson(Map<String, dynamic> json) => _$AccountNFTFromJson(json);
}

@freezed
class TokenData with _$TokenData{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory TokenData({
    required String creatorAddress,
    required String collectionName,
    required String description,
    required String metadataUri,
    required String name,
    required String tokenDataIdHash,
    required String collectionDataIdHash,
  }) = _TokenData;

  factory TokenData.fromJson(Map<String, dynamic> json) => _$TokenDataFromJson(json);
}

@freezed
class CollectionData with _$CollectionData{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CollectionData({
    required String metadataUri,
    required int supply,
    required String description,
    required String collectionName,
    required String collectionDataIdHash,
    required String tableHandle,
    required String creatorAddress
  }) = _CollectionData;

  factory CollectionData.fromJson(Map<String, dynamic> json) => _$CollectionDataFromJson(json);
}