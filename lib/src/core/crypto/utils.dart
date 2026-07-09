import 'dart:convert';
import 'dart:typed_data';

import '../../types/types.dart';
import '../hex.dart';
import 'any_key_registry.dart';
import 'ed25519.dart';
import 'multi_ed25519.dart';
import 'multi_key.dart';
import 'public_key.dart';
import 'single_key.dart';

/// Normalizes a sign/verify message into a [HexInput] that downstream callers
/// can pass to `Hex.fromHexInput()`.
///
/// Behavior — be aware before passing a string:
/// - `Uint8List` → returned as-is (used as raw bytes).
/// - String that parses as hex via `Hex.isValid()` (with or without a `0x`
///   prefix) → returned as the original hex string, which downstream
///   `Hex.fromHexInput()` decodes to its byte form.
/// - Any other string → returned as the UTF-8 byte encoding of the string.
///
/// AMBIGUITY: a bare even-length string of hex characters is *always*
/// interpreted as hex, even when the caller intended it as text. For example:
///
/// ```dart
/// sign('cafe')   // signs 2 bytes: [0xCA, 0xFE]
/// sign('0xcafe') // signs 2 bytes: [0xCA, 0xFE]   (explicit hex)
/// sign('hello')  // signs 5 bytes: UTF-8 "hello"  (not valid hex)
/// ```
///
/// If you mean *text*, use the `signText`/`verifyText` methods or pass raw
/// bytes. If you mean *hex bytes*, the most explicit form is also a
/// `Uint8List`. The heuristic is preserved as-is for backwards compatibility
/// — changing it would silently re-interpret bytes signed by existing dApps
/// and wallets.
HexInput convertSigningMessage(HexInput message) {
  // If message is of type string, verify it is a valid hex string.
  if (message is String) {
    final isValid = Hex.isValid(message);
    // If message is not a valid hex string, convert it.
    if (!isValid.valid) {
      return Uint8List.fromList(utf8.encode(message));
    }
    // If message is a valid hex string, return it.
    return message;
  }
  // Message is a Uint8List.
  return message;
}

/// Returns the "base" form of an account public key — one of the types that
/// can be used to derive an account's address by appending the signing scheme
/// byte to the public key bytes and hashing (Ed25519PublicKey, AnyPublicKey,
/// MultiEd25519PublicKey or MultiKey).
///
/// Keyless / FederatedKeyless public keys register themselves in the AnyKey
/// variant registry; using the registry lets us wrap them in [AnyPublicKey]
/// here without a compile-time dependency on the keyless module.
///
/// Throws an [ArgumentError] for an unknown account public key type.
AccountPublicKey accountPublicKeyToBaseAccountPublicKey(
  AccountPublicKey publicKey,
) {
  if (publicKey is Ed25519PublicKey ||
      publicKey is AnyPublicKey ||
      publicKey is MultiEd25519PublicKey ||
      publicKey is MultiKey) {
    return publicKey;
  }
  if (detectAnyPublicKeyVariant(publicKey) != null) {
    return AnyPublicKey(publicKey);
  }
  throw ArgumentError('Unknown account public key: $publicKey');
}

/// Returns the [SigningScheme] used when deriving an authentication key from
/// [publicKey].
///
/// Throws an [ArgumentError] for an unknown account public key type.
SigningScheme accountPublicKeyToSigningScheme(AccountPublicKey publicKey) {
  final baseAccountPublicKey = accountPublicKeyToBaseAccountPublicKey(publicKey);
  if (baseAccountPublicKey is Ed25519PublicKey) {
    return SigningScheme.ed25519;
  }
  if (baseAccountPublicKey is AnyPublicKey) {
    return SigningScheme.singleKey;
  }
  if (baseAccountPublicKey is MultiEd25519PublicKey) {
    return SigningScheme.multiEd25519;
  }
  if (baseAccountPublicKey is MultiKey) {
    return SigningScheme.multiKey;
  }
  throw ArgumentError('Unknown signing scheme: $baseAccountPublicKey');
}
