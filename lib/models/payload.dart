import 'package:freezed_annotation/freezed_annotation.dart';

part 'payload.freezed.dart';
part 'payload.g.dart';

@freezed
class Payload with _$Payload{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Payload({
    required String type,
    required String function,
    required List<String> typeArguments,
    required List<dynamic> arguments
  }) = _Payload;

  factory Payload.fromJson(Map<String, dynamic> json) => _$PayloadFromJson(json);
}