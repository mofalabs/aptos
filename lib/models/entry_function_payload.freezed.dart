// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_function_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

EntryFunctionPayload _$EntryFunctionPayloadFromJson(Map<String, dynamic> json) {
  return _EntryFunctionPayload.fromJson(json);
}

/// @nodoc
mixin _$EntryFunctionPayload {
  String get functionId => throw _privateConstructorUsedError;
  List<String> get typeArguments => throw _privateConstructorUsedError;
  List<dynamic> get arguments => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
@JsonSerializable()
class _$_EntryFunctionPayload implements _EntryFunctionPayload {
  const _$_EntryFunctionPayload(
      {required this.functionId,
      required final List<String> typeArguments,
      required final List<dynamic> arguments})
      : _typeArguments = typeArguments,
        _arguments = arguments;

  factory _$_EntryFunctionPayload.fromJson(Map<String, dynamic> json) =>
      _$$_EntryFunctionPayloadFromJson(json);

  @override
  final String functionId;
  final List<String> _typeArguments;
  @override
  List<String> get typeArguments {
    if (_typeArguments is EqualUnmodifiableListView) return _typeArguments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_typeArguments);
  }

  final List<dynamic> _arguments;
  @override
  List<dynamic> get arguments {
    if (_arguments is EqualUnmodifiableListView) return _arguments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_arguments);
  }

  @override
  String toString() {
    return 'EntryFunctionPayload(functionId: $functionId, typeArguments: $typeArguments, arguments: $arguments)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_EntryFunctionPayloadToJson(
      this,
    );
  }
}

abstract class _EntryFunctionPayload implements EntryFunctionPayload {
  const factory _EntryFunctionPayload(
      {required final String functionId,
      required final List<String> typeArguments,
      required final List<dynamic> arguments}) = _$_EntryFunctionPayload;

  factory _EntryFunctionPayload.fromJson(Map<String, dynamic> json) =
      _$_EntryFunctionPayload.fromJson;

  @override
  String get functionId;
  @override
  List<String> get typeArguments;
  @override
  List<dynamic> get arguments;
}
