// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'signature.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Signature _$SignatureFromJson(Map<String, dynamic> json) {
  return _Signature.fromJson(json);
}

/// @nodoc
mixin _$Signature {
  String get type => throw _privateConstructorUsedError;
  String get publicKey => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_Signature implements _Signature {
  const _$_Signature(
      {required this.type, required this.publicKey, required this.signature});

  factory _$_Signature.fromJson(Map<String, dynamic> json) =>
      _$$_SignatureFromJson(json);

  @override
  final String type;
  @override
  final String publicKey;
  @override
  final String signature;

  @override
  String toString() {
    return 'Signature(type: $type, publicKey: $publicKey, signature: $signature)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_SignatureToJson(
      this,
    );
  }
}

abstract class _Signature implements Signature {
  const factory _Signature(
      {required final String type,
      required final String publicKey,
      required final String signature}) = _$_Signature;

  factory _Signature.fromJson(Map<String, dynamic> json) =
      _$_Signature.fromJson;

  @override
  String get type;
  @override
  String get publicKey;
  @override
  String get signature;
}
