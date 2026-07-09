import 'dart:typed_data';

import '../../types/types.dart';
import '../hex.dart';
import 'public_key.dart';
import 'signature.dart';

/// Represents a private key used for signing messages and deriving the
/// associated public key.
///
/// The static members provide the AIP-80 helpers shared by all private key
/// implementations.
abstract class PrivateKey {
  /// The AIP-80 compliant prefixes for each private key type. Append this to
  /// a private key's hex representation to get an AIP-80 compliant string.
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  static const Map<PrivateKeyVariants, String> aip80Prefixes = {
    PrivateKeyVariants.ed25519: 'ed25519-priv-',
    PrivateKeyVariants.secp256k1: 'secp256k1-priv-',
    PrivateKeyVariants.secp256r1: 'secp256r1-priv-',
  };

  /// Format a [HexInput] to an AIP-80 compliant string.
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// [privateKey] is the hex string or bytes format of the private key.
  /// [type] is the private key type.
  static String formatPrivateKey(HexInput privateKey, PrivateKeyVariants type) {
    final aip80Prefix = aip80Prefixes[type]!;

    // Remove the prefix if it exists.
    var formattedPrivateKey = privateKey;
    if (formattedPrivateKey is String &&
        formattedPrivateKey.startsWith(aip80Prefix)) {
      formattedPrivateKey = formattedPrivateKey.split('-')[2];
    }

    return '$aip80Prefix${Hex.fromHexInput(formattedPrivateKey)}';
  }

  /// Parse a [HexInput] that may be a hex string, bytes, or an AIP-80
  /// compliant string to a [Hex] instance.
  ///
  /// [Read about AIP-80](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md)
  ///
  /// [value] is a hex string, bytes, or an AIP-80 compliant string.
  /// [type] is the private key type.
  /// If [strict] is true, the value MUST be compliant with AIP-80.
  static Hex parseHexInput(
    HexInput value,
    PrivateKeyVariants type, [
    bool? strict,
  ]) {
    final Hex data;

    final aip80Prefix = aip80Prefixes[type]!;
    if (value is String) {
      if (strict != true && !value.startsWith(aip80Prefix)) {
        // Hex string input.
        data = Hex.fromHexInput(value);
        // NOTE: no warning is logged here for non-AIP-80 strings when
        // `strict` is unset.
      } else if (value.startsWith(aip80Prefix)) {
        // AIP-80 compliant string input.
        data = Hex.fromHexString(value.split('-')[2]);
      } else {
        if (strict == true) {
          // The value does not start with the AIP-80 prefix, and strict is
          // true.
          throw ArgumentError(
            'Invalid HexString input while parsing private key. Must AIP-80 compliant string.',
          );
        }

        // This condition should never be reached.
        throw ArgumentError('Invalid HexString input while parsing private key.');
      }
    } else {
      // The value is a Uint8List.
      data = Hex.fromHexInput(value);
    }

    return data;
  }

  /// Sign the given message with the private key to create a signature.
  Signature sign(HexInput message);

  /// Derive the public key associated with the private key.
  PublicKey publicKey();

  /// Get the private key in bytes.
  Uint8List toUint8Array();
}
