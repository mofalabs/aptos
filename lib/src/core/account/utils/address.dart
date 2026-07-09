import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../../../types/types.dart';
import '../../account_address.dart';

Uint8List _sha3Hash(List<int> input) {
  final digest = SHA3Digest(256);
  return digest.process(Uint8List.fromList(input));
}

Uint8List _seedBytes(Object seed) {
  if (seed is Uint8List) return seed;
  if (seed is String) return Uint8List.fromList(utf8.encode(seed));
  throw ArgumentError('Seed must be a String or Uint8List');
}

/// Creates an object address from creator address and seed.
///
/// [seed] is either a [Uint8List] or a [String].
AccountAddress createObjectAddress(AccountAddress creatorAddress, Object seed) {
  final bytes = <int>[
    ...creatorAddress.bcsToBytes(),
    ..._seedBytes(seed),
    DeriveScheme.deriveObjectAddressFromSeed.value,
  ];
  return AccountAddress(_sha3Hash(bytes));
}

/// Creates a resource address from creator address and seed.
///
/// [seed] is either a [Uint8List] or a [String].
AccountAddress createResourceAddress(
  AccountAddress creatorAddress,
  Object seed,
) {
  final bytes = <int>[
    ...creatorAddress.bcsToBytes(),
    ..._seedBytes(seed),
    DeriveScheme.deriveResourceAccountAddress.value,
  ];
  return AccountAddress(_sha3Hash(bytes));
}

/// Creates a user derived object address from source address and derive_from
/// address.
AccountAddress createUserDerivedObjectAddress(
  AccountAddress sourceAddress,
  AccountAddress deriveFromAddress,
) {
  final bytes = <int>[
    ...sourceAddress.bcsToBytes(),
    ...deriveFromAddress.bcsToBytes(),
    DeriveScheme.deriveObjectAddressFromObject.value,
  ];
  return AccountAddress(_sha3Hash(bytes));
}

/// Creates a token object address from creator address, collection name and
/// token name.
AccountAddress createTokenAddress(
  AccountAddress creatorAddress,
  String collectionName,
  String tokenName,
) {
  final seed = '$collectionName::$tokenName';
  return createObjectAddress(creatorAddress, seed);
}
