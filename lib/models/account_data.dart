import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_data.freezed.dart';
part 'account_data.g.dart';

@freezed
class AccountData with _$AccountData{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AccountData({
    required String sequenceNumber,
    required String authenticationKey
  }) = _AccountData;

  factory AccountData.fromJson(Map<String, dynamic> json) => _$AccountDataFromJson(json);
}