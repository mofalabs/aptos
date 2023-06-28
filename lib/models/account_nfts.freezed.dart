// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_nfts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

AccountNFTs _$AccountNFTsFromJson(Map<String, dynamic> json) {
  return _AccountNFTs.fromJson(json);
}

/// @nodoc
mixin _$AccountNFTs {
  List<AccountNFT> get currentTokenOwnerships =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_AccountNFTs implements _AccountNFTs {
  const _$_AccountNFTs({required final List<AccountNFT> currentTokenOwnerships})
      : _currentTokenOwnerships = currentTokenOwnerships;

  factory _$_AccountNFTs.fromJson(Map<String, dynamic> json) =>
      _$$_AccountNFTsFromJson(json);

  final List<AccountNFT> _currentTokenOwnerships;
  @override
  List<AccountNFT> get currentTokenOwnerships {
    if (_currentTokenOwnerships is EqualUnmodifiableListView)
      return _currentTokenOwnerships;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_currentTokenOwnerships);
  }

  @override
  String toString() {
    return 'AccountNFTs(currentTokenOwnerships: $currentTokenOwnerships)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_AccountNFTsToJson(
      this,
    );
  }
}

abstract class _AccountNFTs implements AccountNFTs {
  const factory _AccountNFTs(
          {required final List<AccountNFT> currentTokenOwnerships}) =
      _$_AccountNFTs;

  factory _AccountNFTs.fromJson(Map<String, dynamic> json) =
      _$_AccountNFTs.fromJson;

  @override
  List<AccountNFT> get currentTokenOwnerships;
}

AccountNFT _$AccountNFTFromJson(Map<String, dynamic> json) {
  return _AccountNFT.fromJson(json);
}

/// @nodoc
mixin _$AccountNFT {
  int get amount => throw _privateConstructorUsedError;
  TokenData get currentTokenData => throw _privateConstructorUsedError;
  CollectionData get currentCollectionData =>
      throw _privateConstructorUsedError;
  int get lastTransactionVersion => throw _privateConstructorUsedError;
  int get propertyVersion => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_AccountNFT implements _AccountNFT {
  const _$_AccountNFT(
      {required this.amount,
      required this.currentTokenData,
      required this.currentCollectionData,
      required this.lastTransactionVersion,
      required this.propertyVersion});

  factory _$_AccountNFT.fromJson(Map<String, dynamic> json) =>
      _$$_AccountNFTFromJson(json);

  @override
  final int amount;
  @override
  final TokenData currentTokenData;
  @override
  final CollectionData currentCollectionData;
  @override
  final int lastTransactionVersion;
  @override
  final int propertyVersion;

  @override
  String toString() {
    return 'AccountNFT(amount: $amount, currentTokenData: $currentTokenData, currentCollectionData: $currentCollectionData, lastTransactionVersion: $lastTransactionVersion, propertyVersion: $propertyVersion)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_AccountNFTToJson(
      this,
    );
  }
}

abstract class _AccountNFT implements AccountNFT {
  const factory _AccountNFT(
      {required final int amount,
      required final TokenData currentTokenData,
      required final CollectionData currentCollectionData,
      required final int lastTransactionVersion,
      required final int propertyVersion}) = _$_AccountNFT;

  factory _AccountNFT.fromJson(Map<String, dynamic> json) =
      _$_AccountNFT.fromJson;

  @override
  int get amount;
  @override
  TokenData get currentTokenData;
  @override
  CollectionData get currentCollectionData;
  @override
  int get lastTransactionVersion;
  @override
  int get propertyVersion;
}

TokenData _$TokenDataFromJson(Map<String, dynamic> json) {
  return _TokenData.fromJson(json);
}

/// @nodoc
mixin _$TokenData {
  String get creatorAddress => throw _privateConstructorUsedError;
  String get collectionName => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get metadataUri => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get tokenDataIdHash => throw _privateConstructorUsedError;
  String get collectionDataIdHash => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_TokenData implements _TokenData {
  const _$_TokenData(
      {required this.creatorAddress,
      required this.collectionName,
      required this.description,
      required this.metadataUri,
      required this.name,
      required this.tokenDataIdHash,
      required this.collectionDataIdHash});

  factory _$_TokenData.fromJson(Map<String, dynamic> json) =>
      _$$_TokenDataFromJson(json);

  @override
  final String creatorAddress;
  @override
  final String collectionName;
  @override
  final String description;
  @override
  final String metadataUri;
  @override
  final String name;
  @override
  final String tokenDataIdHash;
  @override
  final String collectionDataIdHash;

  @override
  String toString() {
    return 'TokenData(creatorAddress: $creatorAddress, collectionName: $collectionName, description: $description, metadataUri: $metadataUri, name: $name, tokenDataIdHash: $tokenDataIdHash, collectionDataIdHash: $collectionDataIdHash)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_TokenDataToJson(
      this,
    );
  }
}

abstract class _TokenData implements TokenData {
  const factory _TokenData(
      {required final String creatorAddress,
      required final String collectionName,
      required final String description,
      required final String metadataUri,
      required final String name,
      required final String tokenDataIdHash,
      required final String collectionDataIdHash}) = _$_TokenData;

  factory _TokenData.fromJson(Map<String, dynamic> json) =
      _$_TokenData.fromJson;

  @override
  String get creatorAddress;
  @override
  String get collectionName;
  @override
  String get description;
  @override
  String get metadataUri;
  @override
  String get name;
  @override
  String get tokenDataIdHash;
  @override
  String get collectionDataIdHash;
}

CollectionData _$CollectionDataFromJson(Map<String, dynamic> json) {
  return _CollectionData.fromJson(json);
}

/// @nodoc
mixin _$CollectionData {
  String get metadataUri => throw _privateConstructorUsedError;
  int get supply => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get collectionName => throw _privateConstructorUsedError;
  String get collectionDataIdHash => throw _privateConstructorUsedError;
  String get tableHandle => throw _privateConstructorUsedError;
  String get creatorAddress => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CollectionData implements _CollectionData {
  const _$_CollectionData(
      {required this.metadataUri,
      required this.supply,
      required this.description,
      required this.collectionName,
      required this.collectionDataIdHash,
      required this.tableHandle,
      required this.creatorAddress});

  factory _$_CollectionData.fromJson(Map<String, dynamic> json) =>
      _$$_CollectionDataFromJson(json);

  @override
  final String metadataUri;
  @override
  final int supply;
  @override
  final String description;
  @override
  final String collectionName;
  @override
  final String collectionDataIdHash;
  @override
  final String tableHandle;
  @override
  final String creatorAddress;

  @override
  String toString() {
    return 'CollectionData(metadataUri: $metadataUri, supply: $supply, description: $description, collectionName: $collectionName, collectionDataIdHash: $collectionDataIdHash, tableHandle: $tableHandle, creatorAddress: $creatorAddress)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CollectionDataToJson(
      this,
    );
  }
}

abstract class _CollectionData implements CollectionData {
  const factory _CollectionData(
      {required final String metadataUri,
      required final int supply,
      required final String description,
      required final String collectionName,
      required final String collectionDataIdHash,
      required final String tableHandle,
      required final String creatorAddress}) = _$_CollectionData;

  factory _CollectionData.fromJson(Map<String, dynamic> json) =
      _$_CollectionData.fromJson;

  @override
  String get metadataUri;
  @override
  int get supply;
  @override
  String get description;
  @override
  String get collectionName;
  @override
  String get collectionDataIdHash;
  @override
  String get tableHandle;
  @override
  String get creatorAddress;
}
