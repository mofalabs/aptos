import '../bcs/deserializer.dart';
import '../core/account_address.dart';
import '../types/types.dart';

/// Deserializes the signing scheme variant and account address that prefix
/// every serialized `Account`.
///
/// Throws a [StateError] if the signing scheme variant is invalid.
({AccountAddress address, SigningScheme signingScheme})
    deserializeSchemeAndAddress(Deserializer deserializer) {
  final signingSchemeIndex = deserializer.deserializeUleb128AsU32();
  // Validate that signingScheme is a valid SigningScheme value.
  final signingScheme = SigningScheme.values
      .where((scheme) => scheme.value == signingSchemeIndex)
      .firstOrNull;
  if (signingScheme == null) {
    throw StateError(
      'Deserialization of Account failed: SigningScheme variant '
      '$signingSchemeIndex is invalid',
    );
  }
  final address = AccountAddress.deserialize(deserializer);
  return (address: address, signingScheme: signingScheme);
}
