
import 'dart:typed_data';

import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/multi_ed25519.dart';
import 'package:aptos/hex_string.dart';
import 'package:pointycastle/digests/sha3.dart';

/// Each account stores an authentication key. Authentication key enables account owners to rotate
/// their private key(s) associated with the account without changing the address that hosts their account.
/// https://aptos.dev/basics/basics-accounts | Account Basics
///
/// Account addresses can be derived from AuthenticationKey
class AuthenticationKey {
  static const LENGTH = 32;

  static const MULTI_ED25519_SCHEME = 1;

  static const ED25519_SCHEME = 0;

  static const DERIVE_RESOURCE_ACCOUNT_SCHEME = 255;

  final Uint8List bytes;

  AuthenticationKey(this.bytes) {
    if (bytes.length != AuthenticationKey.LENGTH) {
      throw ArgumentError("Expected a byte array of length 32");
    }
  }

  /// Converts a K-of-N MultiEd25519PublicKey to AuthenticationKey with:
  /// `auth_key = sha3-256(p_1 | … | p_n | K | 0x01)`. `K` represents the K-of-N required for
  /// authenticating the transaction. `0x01` is the 1-byte scheme for multisig.
  static AuthenticationKey fromMultiEd25519PublicKey(MultiEd25519PublicKey publicKey) {
    Uint8List pubKeyBytes = publicKey.toBytes();

    final bytes = Uint8List(pubKeyBytes.length + 1);
    bytes.setAll(0, pubKeyBytes);
    bytes.setAll(pubKeyBytes.length, [AuthenticationKey.MULTI_ED25519_SCHEME]);

    final sha3Hash = SHA3Digest(256);
    return AuthenticationKey(sha3Hash.process(bytes));
  }

  static AuthenticationKey fromEd25519PublicKey(Ed25519PublicKey publicKey) {
    final pubKeyBytes = publicKey.value;

    final bytes = Uint8List(pubKeyBytes.length + 1);
    bytes.setAll(0, pubKeyBytes);
    bytes.setAll(pubKeyBytes.length, [AuthenticationKey.ED25519_SCHEME]);

    final sha3Hash = SHA3Digest(256);
    return AuthenticationKey(sha3Hash.process(bytes));
  }

  /// Derives an account address from AuthenticationKey. Since current AccountAddress is 32 bytes,
  /// AuthenticationKey bytes are directly translated to AccountAddress.
  HexString derivedAddress() {
    return HexString.fromUint8Array(bytes);
  }
}
