import 'dart:typed_data';

import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import '../hex.dart';
import 'signature.dart';

/// Represents an abstract public key.
///
/// This class provides a common interface for verifying signatures associated
/// with the public key. It allows for the retrieval of the raw public key
/// bytes and the public key in a hexadecimal string format.
abstract class PublicKey extends Serializable {
  /// Verifies that the private key associated with this public key signed the
  /// [message] with the given [signature].
  bool verifySignature({required HexInput message, required Signature signature});

  /// Verifies signature with the public key and makes any network calls
  /// required to get state required to verify the signature.
  ///
  /// The validity of certain types of signatures is dependent on network
  /// state. This is the case for Keyless signatures, which need to look up the
  /// verification key and keyless configuration.
  // TODO: type [aptosConfig] as AptosConfig once the api module is
  // available.
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    return verifySignature(message: message, signature: signature);
  }

  /// Get the raw public key bytes.
  Uint8List toUint8Array() => bcsToBytes();

  /// Get the public key as a hex string without the 0x prefix.
  @override
  String toStringWithoutPrefix() =>
      Hex.fromHexInput(toUint8Array()).toStringWithoutPrefix();

  /// Get the public key as a hex string with a 0x prefix.
  @override
  String toString() => Hex.fromHexInput(toUint8Array()).toString();
}

/// An abstract representation of an account public key.
///
/// Provides a common interface for deriving an authentication key.
abstract class AccountPublicKey extends PublicKey {
  /// Get the authentication key associated with this public key.
  AuthenticationKey authKey();
}
