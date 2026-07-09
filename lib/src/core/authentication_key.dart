import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../types/types.dart';
import 'account_address.dart';
import 'crypto/public_key.dart';
import 'hex.dart';

/// The scheme used when deriving an authentication key. This can be a
/// [SigningScheme] or a [DeriveScheme].
///
/// Dart has no union types, so this is an alias of [Object]; values of any
/// other type are rejected at runtime.
typedef AuthenticationKeyScheme = Object;

int _schemeValue(AuthenticationKeyScheme scheme) {
  if (scheme is SigningScheme) return scheme.value;
  if (scheme is DeriveScheme) return scheme.value;
  throw ArgumentError(
    'AuthenticationKeyScheme must be a SigningScheme or DeriveScheme, '
    'got ${scheme.runtimeType}',
  );
}

/// Represents an authentication key used for account management. Each account
/// stores an authentication key that enables account owners to rotate their
/// private key(s) without changing the address that hosts their account. The
/// authentication key is a SHA3-256 hash of data and is always 32 bytes in
/// length.
///
/// See https://aptos.dev/concepts/accounts | Account Basics
///
/// Account addresses can be derived from the AuthenticationKey.
class AuthenticationKey extends Serializable {
  /// An authentication key is always a SHA3-256 hash of data, and is always
  /// 32 bytes.
  ///
  /// The data to hash depends on the underlying public key type and the
  /// derivation scheme.
  static const int length = 32;

  /// The raw bytes of the authentication key.
  final Hex data;

  /// Creates an instance of the AuthenticationKey using the provided hex
  /// input. This ensures that the hex input is valid and conforms to the
  /// required length for an Authentication Key.
  ///
  /// Throws an [ArgumentError] if the length of the provided hex input is not
  /// equal to the required Authentication Key length.
  AuthenticationKey({required HexInput data})
      : data = Hex.fromHexInput(data) {
    if (this.data.toUint8List().length != AuthenticationKey.length) {
      throw ArgumentError(
        'Authentication Key length should be ${AuthenticationKey.length}',
      );
    }
  }

  /// Serializes the authentication key as length-prefixed bytes (BCS
  /// `serde_bytes` encoding).
  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(data.toUint8List());
  }

  /// Deserialize an AuthenticationKey from the byte buffer in a
  /// [Deserializer] instance.
  static AuthenticationKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    if (bytes.length != AuthenticationKey.length) {
      throw ArgumentError(
        'AuthenticationKey BCS must be ${AuthenticationKey.length} bytes, got ${bytes.length}',
      );
    }
    return AuthenticationKey(data: bytes);
  }

  /// Override `Serializable.toString` (which would return the length-prefixed
  /// BCS hex) so the public representation stays the underlying 32-byte hex
  /// address — what callers compare against (REST `authentication_key`,
  /// indexer GraphQL filters, on-chain account address derivation).
  @override
  String toString() => data.toString();

  /// Convert the internal data representation to a [Uint8List].
  Uint8List toUint8Array() => data.toUint8List();

  /// Generates an AuthenticationKey from the specified scheme and input
  /// bytes. This function is essential for creating a valid authentication
  /// key based on a given scheme.
  static AuthenticationKey fromSchemeAndBytes({
    required AuthenticationKeyScheme scheme,
    required HexInput input,
  }) {
    final inputBytes = Hex.fromHexInput(input).toUint8List();
    final hashInput = Uint8List(inputBytes.length + 1);
    hashInput.setRange(0, inputBytes.length, inputBytes);
    hashInput[inputBytes.length] = _schemeValue(scheme);
    final hashDigest = SHA3Digest(256).process(hashInput);
    return AuthenticationKey(data: hashDigest);
  }

  /// Derives an AuthenticationKey from the provided public key using a
  /// specified derivation scheme.
  ///
  /// Deprecated: use [fromPublicKey] instead.
  static AuthenticationKey fromPublicKeyAndScheme({
    required AccountPublicKey publicKey,
    required AuthenticationKeyScheme scheme,
  }) {
    return publicKey.authKey();
  }

  /// Converts a PublicKey to an AuthenticationKey using the derivation scheme
  /// inferred from the provided PublicKey instance.
  static AuthenticationKey fromPublicKey({
    required AccountPublicKey publicKey,
  }) {
    return publicKey.authKey();
  }

  /// Derives an account address from an AuthenticationKey by translating the
  /// AuthenticationKey bytes directly to an AccountAddress.
  AccountAddress derivedAddress() => AccountAddress(data.toUint8List());
}
