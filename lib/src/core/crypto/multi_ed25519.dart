import 'dart:typed_data';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import 'ed25519.dart';
import 'multi_key.dart';
import 'signature.dart';

/// Represents the public key of a K-of-N Ed25519 multi-sig transaction.
///
/// A K-of-N multi-sig transaction requires at least K out of N authorized
/// signers to sign the transaction for it to be executed. This class
/// encapsulates the logic for managing the public keys and the threshold for
/// valid signatures.
///
/// See https://aptos.dev/integration/creating-a-signed-transaction/
class MultiEd25519PublicKey extends AbstractMultiKey {
  /// Maximum number of public keys supported.
  static const int maxKeys = 32;

  /// Minimum number of public keys needed.
  static const int minKeys = 2;

  /// Minimum threshold for the number of valid signatures required.
  static const int minThreshold = 1;

  /// List of Ed25519 public keys for this LegacyMultiEd25519PublicKey.
  @override
  final List<Ed25519PublicKey> publicKeys;

  /// The minimum number of valid signatures required, for the number of
  /// public keys specified.
  final int threshold;

  /// Public key for a K-of-N multi-sig transaction. A K-of-N multi-sig
  /// transaction means that for such a transaction to be executed, at least K
  /// out of the N authorized signers have signed the transaction and passed
  /// the check conducted by the chain.
  ///
  /// [publicKeys] is the list of public keys; at least [threshold] signatures
  /// must be valid.
  ///
  /// Throws an [ArgumentError] if the number of public keys or the threshold
  /// is out of range.
  MultiEd25519PublicKey({
    required this.publicKeys,
    required this.threshold,
  }) {
    // Validate number of public keys.
    if (publicKeys.length > MultiEd25519PublicKey.maxKeys ||
        publicKeys.length < MultiEd25519PublicKey.minKeys) {
      throw ArgumentError(
        'Must have between ${MultiEd25519PublicKey.minKeys} and '
        '${MultiEd25519PublicKey.maxKeys} public keys, inclusive',
      );
    }

    // Validate threshold: must be between 1 and the number of public keys,
    // inclusive.
    if (threshold < MultiEd25519PublicKey.minThreshold ||
        threshold > publicKeys.length) {
      throw ArgumentError(
        'Threshold must be between ${MultiEd25519PublicKey.minThreshold} and '
        '${publicKeys.length}, inclusive',
      );
    }
  }

  @override
  int getSignaturesRequired() => threshold;

  // region AccountPublicKey

  /// Verifies a multi-signature against a given message.
  /// This function ensures that the provided signatures meet the required
  /// threshold and are valid for the given message.
  ///
  /// Returns false if [signature] is not a [MultiEd25519Signature].
  ///
  /// Throws a [StateError] if the bitmap and signatures length mismatch or if
  /// there are not enough valid signatures.
  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
  }) {
    if (signature is! MultiEd25519Signature) {
      return false;
    }

    final indices = <int>[];
    for (var i = 0; i < 4; i += 1) {
      for (var j = 0; j < 8; j += 1) {
        final bitIsSet = (signature.bitmap[i] & (1 << (7 - j))) != 0;
        if (bitIsSet) {
          final index = i * 8 + j;
          indices.add(index);
        }
      }
    }

    if (indices.length != signature.signatures.length) {
      throw StateError('Bitmap and signatures length mismatch');
    }

    if (indices.length < threshold) {
      throw StateError('Not enough signatures');
    }

    for (var i = 0; i < indices.length; i += 1) {
      final publicKey = publicKeys[indices[i]];
      if (!publicKey.verifySignature(
        message: message,
        signature: signature.signatures[i],
      )) {
        return false;
      }
    }
    return true;
  }

  /// Generates an authentication key based on the current instance's byte
  /// representation using the MultiEd25519 scheme.
  @override
  AuthenticationKey authKey() {
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.multiEd25519,
      input: toUint8Array(),
    );
  }

  /// Converts a PublicKeys into Uint8Array (bytes) with:
  /// `bytes = p1_bytes | ... | pn_bytes | threshold`
  @override
  Uint8List toUint8Array() {
    final bytes = Uint8List(publicKeys.length * Ed25519PublicKey.length + 1);
    for (var i = 0; i < publicKeys.length; i += 1) {
      bytes.setRange(
        i * Ed25519PublicKey.length,
        (i + 1) * Ed25519PublicKey.length,
        publicKeys[i].toUint8Array(),
      );
    }

    bytes[publicKeys.length * Ed25519PublicKey.length] = threshold;

    return bytes;
  }

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toUint8Array());
  }

  /// Deserializes a MultiEd25519PublicKey from the provided deserializer
  /// (length-prefixed bytes).
  static MultiEd25519PublicKey deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    return _fromConcatenatedBytes(bytes);
  }

  /// Deserializes a MultiEd25519PublicKey from the remaining bytes of the
  /// provided deserializer (no length prefix).
  static MultiEd25519PublicKey deserializeWithoutLength(
    Deserializer deserializer,
  ) {
    final length = deserializer.remaining();
    final bytes = deserializer.deserializeFixedBytes(length);
    return _fromConcatenatedBytes(bytes);
  }

  static MultiEd25519PublicKey _fromConcatenatedBytes(Uint8List bytes) {
    final threshold = bytes[bytes.length - 1];

    final keys = <Ed25519PublicKey>[];

    for (var i = 0; i < bytes.length - 1; i += Ed25519PublicKey.length) {
      keys.add(Ed25519PublicKey(bytes.sublist(i, i + Ed25519PublicKey.length)));
    }
    return MultiEd25519PublicKey(publicKeys: keys, threshold: threshold);
  }

  // endregion
}

/// Represents the signature of a K-of-N Ed25519 multi-sig transaction.
///
/// See https://aptos.dev/integration/creating-a-signed-transaction/#multisignature-transactions
class MultiEd25519Signature extends Signature {
  /// Maximum number of Ed25519 signatures supported.
  static const int maxSignaturesSupported = 32;

  /// Number of bytes in the bitmap representing who signed the transaction
  /// (32-bits).
  static const int bitmapLen = 4;

  /// The list of underlying Ed25519 signatures.
  final List<Ed25519Signature> signatures;

  /// 32-bit Bitmap representing who signed the transaction.
  ///
  /// This is represented where each public key can be masked to determine
  /// whether the message was signed by that key.
  final Uint8List bitmap;

  /// Signature for a K-of-N multi-sig transaction.
  ///
  /// [bitmap] is either a 4-byte [Uint8List] (at most 32 signatures are
  /// supported; if the Nth bit is `1`, the Nth signature should be provided
  /// in [signatures]; bits are read from left to right) or a plain
  /// `List<int>` of bitmap positions — valid positions range between 0 and
  /// 31; see [createBitmap].
  ///
  /// Throws an [ArgumentError] if the number of signatures exceeds the
  /// maximum supported or if the bitmap length is incorrect.
  MultiEd25519Signature({
    required this.signatures,
    required List<int> bitmap,
  }) : bitmap = _normalizeBitmap(bitmap) {
    if (signatures.length > MultiEd25519Signature.maxSignaturesSupported) {
      throw ArgumentError(
        'The number of signatures cannot be greater than '
        '${MultiEd25519Signature.maxSignaturesSupported}',
      );
    }
  }

  static Uint8List _normalizeBitmap(List<int> bitmap) {
    if (bitmap is! Uint8List) {
      return MultiEd25519Signature.createBitmap(bits: bitmap);
    }
    if (bitmap.length != MultiEd25519Signature.bitmapLen) {
      throw ArgumentError(
        '"bitmap" length should be ${MultiEd25519Signature.bitmapLen}',
      );
    }
    return bitmap;
  }

  // region Signature

  /// Converts a MultiSignature into Uint8Array (bytes) with
  /// `bytes = s1_bytes | ... | sn_bytes | bitmap`
  @override
  Uint8List toUint8Array() {
    final bytes = Uint8List(
      signatures.length * Ed25519Signature.length +
          MultiEd25519Signature.bitmapLen,
    );
    for (var i = 0; i < signatures.length; i += 1) {
      bytes.setRange(
        i * Ed25519Signature.length,
        (i + 1) * Ed25519Signature.length,
        signatures[i].toUint8Array(),
      );
    }

    bytes.setRange(
      signatures.length * Ed25519Signature.length,
      bytes.length,
      bitmap,
    );

    return bytes;
  }

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toUint8Array());
  }

  static MultiEd25519Signature deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeBytes();
    final bitmap = bytes.sublist(bytes.length - 4);

    final signatures = <Ed25519Signature>[];

    for (var i = 0;
        i < bytes.length - bitmap.length;
        i += Ed25519Signature.length) {
      signatures.add(
        Ed25519Signature(bytes.sublist(i, i + Ed25519Signature.length)),
      );
    }
    return MultiEd25519Signature(signatures: signatures, bitmap: bitmap);
  }

  // endregion

  /// Helper method to create a bitmap out of the specified bit positions.
  /// This function allows you to set specific bits in a 32-bit long bitmap
  /// based on the provided positions.
  ///
  /// [bits] are the bitmap positions that should be set. A position starts
  /// at index 0. Valid positions should range between 0 and 31, and must be
  /// sorted in ascending order.
  ///
  /// For example, `[0, 2, 31]` means the 1st, 3rd and 32nd bits should be
  /// set in the bitmap. The resulting bitmap is
  /// `0b10100000000000000000000000000001`.
  ///
  /// Returns a bitmap that is 32 bits long.
  static Uint8List createBitmap({required List<int> bits}) {
    // Bits are read from left to right. e.g. 0b10000000 represents the first
    // bit is set in one byte. The decimal value of 0b10000000 is 128.
    const firstBitInByte = 128;
    final bitmap = Uint8List(4);

    // Check if duplicates exist in bits.
    final dupCheckSet = <int>{};

    for (var index = 0; index < bits.length; index += 1) {
      final bit = bits[index];
      if (bit >= MultiEd25519Signature.maxSignaturesSupported) {
        throw ArgumentError(
          'Cannot have a signature larger than '
          '${MultiEd25519Signature.maxSignaturesSupported - 1}.',
        );
      }

      if (dupCheckSet.contains(bit)) {
        throw ArgumentError('Duplicate bits detected.');
      }

      if (index > 0 && bit <= bits[index - 1]) {
        throw ArgumentError('The bits need to be sorted in ascending order.');
      }

      dupCheckSet.add(bit);

      final byteOffset = bit ~/ 8;

      bitmap[byteOffset] |= firstBitInByte >> (bit % 8);
    }

    return bitmap;
  }
}
