import 'dart:typed_data';

import '../../bcs/serializer.dart';
import '../hex.dart';

/// An abstract representation of a crypto signature,
/// associated with a specific signature scheme, e.g., Ed25519 or Secp256k1.
///
/// This class represents the product of signing a message directly from a
/// PrivateKey and can be verified against a CryptoPublicKey.
abstract class Signature extends Serializable {
  /// Get the raw signature bytes.
  Uint8List toUint8Array() => bcsToBytes();

  /// Get the signature as a hex string without the 0x prefix.
  @override
  String toStringWithoutPrefix() =>
      Hex.fromHexInput(toUint8Array()).toStringWithoutPrefix();

  /// Get the signature as a hex string with a 0x prefix e.g. 0x123456...
  @override
  String toString() => Hex.fromHexInput(toUint8Array()).toString();
}
