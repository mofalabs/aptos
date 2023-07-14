// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'current_token_pending_claims.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

CurrentTokenPendingClaims _$CurrentTokenPendingClaimsFromJson(
    Map<String, dynamic> json) {
  return _CurrentTokenPendingClaims.fromJson(json);
}

/// @nodoc
mixin _$CurrentTokenPendingClaims {
  List<CurrentTokenPending> get currentTokenPendingClaims =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentTokenPendingClaims implements _CurrentTokenPendingClaims {
  const _$_CurrentTokenPendingClaims(
      {required final List<CurrentTokenPending> currentTokenPendingClaims})
      : _currentTokenPendingClaims = currentTokenPendingClaims;

  factory _$_CurrentTokenPendingClaims.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentTokenPendingClaimsFromJson(json);

  final List<CurrentTokenPending> _currentTokenPendingClaims;
  @override
  List<CurrentTokenPending> get currentTokenPendingClaims {
    if (_currentTokenPendingClaims is EqualUnmodifiableListView)
      return _currentTokenPendingClaims;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_currentTokenPendingClaims);
  }

  @override
  String toString() {
    return 'CurrentTokenPendingClaims(currentTokenPendingClaims: $currentTokenPendingClaims)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentTokenPendingClaimsToJson(
      this,
    );
  }
}

abstract class _CurrentTokenPendingClaims implements CurrentTokenPendingClaims {
  const factory _CurrentTokenPendingClaims(
      {required final List<CurrentTokenPending>
          currentTokenPendingClaims}) = _$_CurrentTokenPendingClaims;

  factory _CurrentTokenPendingClaims.fromJson(Map<String, dynamic> json) =
      _$_CurrentTokenPendingClaims.fromJson;

  @override
  List<CurrentTokenPending> get currentTokenPendingClaims;
}

CurrentTokenPending _$CurrentTokenPendingFromJson(Map<String, dynamic> json) {
  return _CurrentTokenPending.fromJson(json);
}

/// @nodoc
mixin _$CurrentTokenPending {
  String get fromAddress => throw _privateConstructorUsedError;
  String get creatorAddress => throw _privateConstructorUsedError;
  String get collectionName => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get propertyVersion => throw _privateConstructorUsedError;
  CurrentCollectionData get currentCollectionData =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentTokenPending implements _CurrentTokenPending {
  const _$_CurrentTokenPending(
      {required this.fromAddress,
      required this.creatorAddress,
      required this.collectionName,
      required this.name,
      required this.propertyVersion,
      required this.currentCollectionData});

  factory _$_CurrentTokenPending.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentTokenPendingFromJson(json);

  @override
  final String fromAddress;
  @override
  final String creatorAddress;
  @override
  final String collectionName;
  @override
  final String name;
  @override
  final int propertyVersion;
  @override
  final CurrentCollectionData currentCollectionData;

  @override
  String toString() {
    return 'CurrentTokenPending(fromAddress: $fromAddress, creatorAddress: $creatorAddress, collectionName: $collectionName, name: $name, propertyVersion: $propertyVersion, currentCollectionData: $currentCollectionData)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentTokenPendingToJson(
      this,
    );
  }
}

abstract class _CurrentTokenPending implements CurrentTokenPending {
  const factory _CurrentTokenPending(
          {required final String fromAddress,
          required final String creatorAddress,
          required final String collectionName,
          required final String name,
          required final int propertyVersion,
          required final CurrentCollectionData currentCollectionData}) =
      _$_CurrentTokenPending;

  factory _CurrentTokenPending.fromJson(Map<String, dynamic> json) =
      _$_CurrentTokenPending.fromJson;

  @override
  String get fromAddress;
  @override
  String get creatorAddress;
  @override
  String get collectionName;
  @override
  String get name;
  @override
  int get propertyVersion;
  @override
  CurrentCollectionData get currentCollectionData;
}

CurrentCollectionData _$CurrentCollectionDataFromJson(
    Map<String, dynamic> json) {
  return _CurrentCollectionData.fromJson(json);
}

/// @nodoc
mixin _$CurrentCollectionData {
  String get collectionDataIdHash => throw _privateConstructorUsedError;
  String get collectionName => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get lastTransactionVersion => throw _privateConstructorUsedError;
  String get metadataUri => throw _privateConstructorUsedError;
  int get supply => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_CurrentCollectionData implements _CurrentCollectionData {
  const _$_CurrentCollectionData(
      {required this.collectionDataIdHash,
      required this.collectionName,
      required this.description,
      required this.lastTransactionVersion,
      required this.metadataUri,
      required this.supply});

  factory _$_CurrentCollectionData.fromJson(Map<String, dynamic> json) =>
      _$$_CurrentCollectionDataFromJson(json);

  @override
  final String collectionDataIdHash;
  @override
  final String collectionName;
  @override
  final String description;
  @override
  final int lastTransactionVersion;
  @override
  final String metadataUri;
  @override
  final int supply;

  @override
  String toString() {
    return 'CurrentCollectionData(collectionDataIdHash: $collectionDataIdHash, collectionName: $collectionName, description: $description, lastTransactionVersion: $lastTransactionVersion, metadataUri: $metadataUri, supply: $supply)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CurrentCollectionDataToJson(
      this,
    );
  }
}

abstract class _CurrentCollectionData implements CurrentCollectionData {
  const factory _CurrentCollectionData(
      {required final String collectionDataIdHash,
      required final String collectionName,
      required final String description,
      required final int lastTransactionVersion,
      required final String metadataUri,
      required final int supply}) = _$_CurrentCollectionData;

  factory _CurrentCollectionData.fromJson(Map<String, dynamic> json) =
      _$_CurrentCollectionData.fromJson;

  @override
  String get collectionDataIdHash;
  @override
  String get collectionName;
  @override
  String get description;
  @override
  int get lastTransactionVersion;
  @override
  String get metadataUri;
  @override
  int get supply;
}
