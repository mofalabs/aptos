// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'current_token_datas.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

CurrentTokenDatas _$CurrentTokenDatasFromJson(Map<String, dynamic> json) {
  return _CurrentTokenDatas.fromJson(json);
}

/// @nodoc
mixin _$CurrentTokenDatas {
  List<CurrentTokenData> get currentTokenDatasV2 =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentTokenDatas implements _CurrentTokenDatas {
  const _$_CurrentTokenDatas(
      {required final List<CurrentTokenData> currentTokenDatasV2})
      : _currentTokenDatasV2 = currentTokenDatasV2;

  factory _$_CurrentTokenDatas.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentTokenDatasFromJson(json);

  final List<CurrentTokenData> _currentTokenDatasV2;
  @override
  List<CurrentTokenData> get currentTokenDatasV2 {
    if (_currentTokenDatasV2 is EqualUnmodifiableListView)
      return _currentTokenDatasV2;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_currentTokenDatasV2);
  }

  @override
  String toString() {
    return 'CurrentTokenDatas(currentTokenDatasV2: $currentTokenDatasV2)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentTokenDatasToJson(
      this,
    );
  }
}

abstract class _CurrentTokenDatas implements CurrentTokenDatas {
  const factory _CurrentTokenDatas(
          {required final List<CurrentTokenData> currentTokenDatasV2}) =
      _$_CurrentTokenDatas;

  factory _CurrentTokenDatas.fromJson(Map<String, dynamic> json) =
      _$_CurrentTokenDatas.fromJson;

  @override
  List<CurrentTokenData> get currentTokenDatasV2;
}

CurrentTokenData _$CurrentTokenDataFromJson(Map<String, dynamic> json) {
  return _CurrentTokenData.fromJson(json);
}

/// @nodoc
mixin _$CurrentTokenData {
  String get tokenDataId => throw _privateConstructorUsedError;
  String get tokenName => throw _privateConstructorUsedError;
  String get tokenUri => throw _privateConstructorUsedError;
  TokenProperties get tokenProperties => throw _privateConstructorUsedError;
  TokenStandard get tokenStandard => throw _privateConstructorUsedError;
  int? get largestPropertyVersionV1 => throw _privateConstructorUsedError;
  int? get maximum => throw _privateConstructorUsedError;
  bool? get isFungibleV2 => throw _privateConstructorUsedError;
  int get supply => throw _privateConstructorUsedError;
  int get lastTransactionVersion => throw _privateConstructorUsedError;
  String get lastTransactionTimestamp => throw _privateConstructorUsedError;
  CurrentCollection? get currentCollection =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentTokenData implements _CurrentTokenData {
  const _$_CurrentTokenData(
      {required this.tokenDataId,
      required this.tokenName,
      required this.tokenUri,
      required this.tokenProperties,
      required this.tokenStandard,
      required this.largestPropertyVersionV1,
      required this.maximum,
      required this.isFungibleV2,
      required this.supply,
      required this.lastTransactionVersion,
      required this.lastTransactionTimestamp,
      required this.currentCollection});

  factory _$_CurrentTokenData.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentTokenDataFromJson(json);

  @override
  final String tokenDataId;
  @override
  final String tokenName;
  @override
  final String tokenUri;
  @override
  final TokenProperties tokenProperties;
  @override
  final TokenStandard tokenStandard;
  @override
  final int? largestPropertyVersionV1;
  @override
  final int? maximum;
  @override
  final bool? isFungibleV2;
  @override
  final int supply;
  @override
  final int lastTransactionVersion;
  @override
  final String lastTransactionTimestamp;
  @override
  final CurrentCollection? currentCollection;

  @override
  String toString() {
    return 'CurrentTokenData(tokenDataId: $tokenDataId, tokenName: $tokenName, tokenUri: $tokenUri, tokenProperties: $tokenProperties, tokenStandard: $tokenStandard, largestPropertyVersionV1: $largestPropertyVersionV1, maximum: $maximum, isFungibleV2: $isFungibleV2, supply: $supply, lastTransactionVersion: $lastTransactionVersion, lastTransactionTimestamp: $lastTransactionTimestamp, currentCollection: $currentCollection)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentTokenDataToJson(
      this,
    );
  }
}

abstract class _CurrentTokenData implements CurrentTokenData {
  const factory _CurrentTokenData(
          {required final String tokenDataId,
          required final String tokenName,
          required final String tokenUri,
          required final TokenProperties tokenProperties,
          required final TokenStandard tokenStandard,
          required final int? largestPropertyVersionV1,
          required final int? maximum,
          required final bool? isFungibleV2,
          required final int supply,
          required final int lastTransactionVersion,
          required final String lastTransactionTimestamp,
          required final CurrentCollection? currentCollection}) =
      _$_CurrentTokenData;

  factory _CurrentTokenData.fromJson(Map<String, dynamic> json) =
      _$_CurrentTokenData.fromJson;

  @override
  String get tokenDataId;
  @override
  String get tokenName;
  @override
  String get tokenUri;
  @override
  TokenProperties get tokenProperties;
  @override
  TokenStandard get tokenStandard;
  @override
  int? get largestPropertyVersionV1;
  @override
  int? get maximum;
  @override
  bool? get isFungibleV2;
  @override
  int get supply;
  @override
  int get lastTransactionVersion;
  @override
  String get lastTransactionTimestamp;
  @override
  CurrentCollection? get currentCollection;
}

TokenProperties _$TokenPropertiesFromJson(Map<String, dynamic> json) {
  return _TokenProperties.fromJson(json);
}

/// @nodoc
mixin _$TokenProperties {
  String? get tokenBurnableByOwner => throw _privateConstructorUsedError;
  String? get tokenPropertyMutatble => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.screamingSnake)
class _$_TokenProperties implements _TokenProperties {
  const _$_TokenProperties(
      {required this.tokenBurnableByOwner,
      required this.tokenPropertyMutatble});

  factory _$_TokenProperties.fromJson(Map<String, dynamic> json) =>
      _$$_TokenPropertiesFromJson(json);

  @override
  final String? tokenBurnableByOwner;
  @override
  final String? tokenPropertyMutatble;

  @override
  String toString() {
    return 'TokenProperties(tokenBurnableByOwner: $tokenBurnableByOwner, tokenPropertyMutatble: $tokenPropertyMutatble)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_TokenPropertiesToJson(
      this,
    );
  }
}

abstract class _TokenProperties implements TokenProperties {
  const factory _TokenProperties(
      {required final String? tokenBurnableByOwner,
      required final String? tokenPropertyMutatble}) = _$_TokenProperties;

  factory _TokenProperties.fromJson(Map<String, dynamic> json) =
      _$_TokenProperties.fromJson;

  @override
  String? get tokenBurnableByOwner;
  @override
  String? get tokenPropertyMutatble;
}

CurrentCollection _$CurrentCollectionFromJson(Map<String, dynamic> json) {
  return _CurrentCollection.fromJson(json);
}

/// @nodoc
mixin _$CurrentCollection {
  String get collectionId => throw _privateConstructorUsedError;
  String get collectionName => throw _privateConstructorUsedError;
  String get creatorAddress => throw _privateConstructorUsedError;
  String get uri => throw _privateConstructorUsedError;
  int get currentSupply => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentCollection implements _CurrentCollection {
  const _$_CurrentCollection(
      {required this.collectionId,
      required this.collectionName,
      required this.creatorAddress,
      required this.uri,
      required this.currentSupply});

  factory _$_CurrentCollection.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentCollectionFromJson(json);

  @override
  final String collectionId;
  @override
  final String collectionName;
  @override
  final String creatorAddress;
  @override
  final String uri;
  @override
  final int currentSupply;

  @override
  String toString() {
    return 'CurrentCollection(collectionId: $collectionId, collectionName: $collectionName, creatorAddress: $creatorAddress, uri: $uri, currentSupply: $currentSupply)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentCollectionToJson(
      this,
    );
  }
}

abstract class _CurrentCollection implements CurrentCollection {
  const factory _CurrentCollection(
      {required final String collectionId,
      required final String collectionName,
      required final String creatorAddress,
      required final String uri,
      required final int currentSupply}) = _$_CurrentCollection;

  factory _CurrentCollection.fromJson(Map<String, dynamic> json) =
      _$_CurrentCollection.fromJson;

  @override
  String get collectionId;
  @override
  String get collectionName;
  @override
  String get creatorAddress;
  @override
  String get uri;
  @override
  int get currentSupply;
}
