

import 'package:freezed_annotation/freezed_annotation.dart';

part 'current_token_pending_claims.freezed.dart';
part 'current_token_pending_claims.g.dart';

@freezed
class CurrentTokenPendingClaims with _$CurrentTokenPendingClaims{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CurrentTokenPendingClaims({
    required List<CurrentTokenPending> currentTokenPendingClaims
  }) = _CurrentTokenPendingClaims;

  factory CurrentTokenPendingClaims.fromJson(Map<String, dynamic> json) => _$CurrentTokenPendingClaimsFromJson(json);
}

@freezed
class CurrentTokenPending with _$CurrentTokenPending{
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CurrentTokenPending({
    required String fromAddress,
    required String creatorAddress,
    required String collectionName,
    required String name,
    required int propertyVersion
  }) = _CurrentTokenPending;

  factory CurrentTokenPending.fromJson(Map<String, dynamic> json) => _$CurrentTokenPendingFromJson(json);
}