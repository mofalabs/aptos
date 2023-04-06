
import 'package:freezed_annotation/freezed_annotation.dart';

part 'signature.freezed.dart';
part 'signature.g.dart';

@freezed
class Signature with _$Signature{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Signature({
    required String type,
    required String publicKey,
    required String signature
  }) = _Signature;

  factory Signature.fromJson(Map<String, dynamic> json) => _$SignatureFromJson(json);
}