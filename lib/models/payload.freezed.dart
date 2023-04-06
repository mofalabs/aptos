// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Payload _$PayloadFromJson(Map<String, dynamic> json) {
  return _Payload.fromJson(json);
}

/// @nodoc
mixin _$Payload {
  String get type => throw _privateConstructorUsedError;
  String get function => throw _privateConstructorUsedError;
  List<String> get typeArguments => throw _privateConstructorUsedError;
  List<dynamic> get arguments => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$_Payload implements _Payload {
  const _$_Payload(
      {required this.type,
      required this.function,
      required final List<String> typeArguments,
      required final List<dynamic> arguments})
      : _typeArguments = typeArguments,
        _arguments = arguments;

  factory _$_Payload.fromJson(Map<String, dynamic> json) =>
      _$$_PayloadFromJson(json);

  @override
  final String type;
  @override
  final String function;
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
    return 'Payload(type: $type, function: $function, typeArguments: $typeArguments, arguments: $arguments)';
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_PayloadToJson(
      this,
    );
  }
}

abstract class _Payload implements Payload {
  const factory _Payload(
      {required final String type,
      required final String function,
      required final List<String> typeArguments,
      required final List<dynamic> arguments}) = _$_Payload;

  factory _Payload.fromJson(Map<String, dynamic> json) = _$_Payload.fromJson;

  @override
  String get type;
  @override
  String get function;
  @override
  List<String> get typeArguments;
  @override
  List<dynamic> get arguments;
}
