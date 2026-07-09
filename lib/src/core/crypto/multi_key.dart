import 'dart:typed_data';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../types/types.dart';
import '../authentication_key.dart';
import 'public_key.dart';
import 'signature.dart';
import 'single_key.dart';

/// Counts the number of set bits (1s) in a byte.
int _bitCount(int byte) {
  var n = byte;
  n -= (n >> 1) & 0x55555555;
  n = (n & 0x33333333) + ((n >> 2) & 0x33333333);
  return (((n + (n >> 4)) & 0x0f0f0f0f) * 0x01010101) >> 24;
}

const int _maxNumKeylessPublicForMultiKey = 3;

/// An abstract base for multi-key public keys (`MultiKey` and the legacy
/// `MultiEd25519PublicKey`).
abstract class AbstractMultiKey extends AccountPublicKey {
  /// The public keys of the individual signers.
  List<PublicKey> get publicKeys;

  /// Create a bitmap that holds the mapping from the original public keys to
  /// the signatures passed in.
  ///
  /// [bits] is an array of the index mapping to the matching public keys.
  ///
  /// Returns a 4-byte bitmap.
  Uint8List createBitmap({required List<int> bits}) {
    // Bits are read from left to right. e.g. 0b10000000 represents the first
    // bit is set in one byte. The decimal value of 0b10000000 is 128.
    const firstBitInByte = 128;
    final bitmap = Uint8List(4);

    // Check if duplicates exist in bits.
    final dupCheckSet = <int>{};

    for (var idx = 0; idx < bits.length; idx += 1) {
      final bit = bits[idx];
      if (idx + 1 > publicKeys.length) {
        throw ArgumentError(
          'Signature index ${idx + 1} is out of public keys range, '
          '${publicKeys.length}.',
        );
      }

      if (!dupCheckSet.add(bit)) {
        throw ArgumentError('Duplicate bit $bit detected.');
      }

      final byteOffset = bit ~/ 8;

      bitmap[byteOffset] |= firstBitInByte >> (bit % 8);
    }

    return bitmap;
  }

  /// Get the index of the provided public key.
  ///
  /// This function retrieves the index of a specified public key within the
  /// MultiKey. Throws an [ArgumentError] if the public key is not found.
  int getIndex(PublicKey publicKey) {
    final index =
        publicKeys.indexWhere((pk) => pk.toString() == publicKey.toString());

    if (index != -1) {
      return index;
    }
    throw ArgumentError(
      'Public key $publicKey not found in multi key set $publicKeys',
    );
  }

  /// The minimum number of valid signatures required.
  int getSignaturesRequired();
}

/// Represents a multi-key authentication scheme for accounts, allowing
/// multiple public keys to be associated with a single account. This class
/// enforces a minimum number of valid signatures required to authorize
/// actions, ensuring enhanced security for multi-agent accounts.
///
/// The public keys of each individual agent can be any type of public key
/// supported by Aptos. Since
/// [AIP-55](https://github.com/aptos-foundation/AIPs/pull/263), Aptos supports
/// `Legacy` and `Unified` authentication keys.
class MultiKey extends AbstractMultiKey {
  /// List of any public keys.
  @override
  final List<AnyPublicKey> publicKeys;

  /// The minimum number of valid signatures required, for the number of
  /// public keys specified.
  final int signaturesRequired;

  // region Constructors

  /// Public key for a K-of-N multi-key account.
  ///
  /// [publicKeys] may contain any mix of raw public keys and [AnyPublicKey]
  /// wrappers; all keys are normalized to the SingleKey authentication
  /// scheme.
  ///
  /// Throws an [ArgumentError] if [signaturesRequired] is less than 1, if
  /// fewer public keys than required signatures are provided, or if more
  /// than 3 keyless public keys are used with more than 3 required
  /// signatures.
  MultiKey({
    required List<PublicKey> publicKeys,
    required this.signaturesRequired,
  }) : publicKeys = _validateAndNormalize(publicKeys, signaturesRequired);

  static List<AnyPublicKey> _validateAndNormalize(
    List<PublicKey> publicKeys,
    int signaturesRequired,
  ) {
    // Validate the number of required signatures is greater than zero.
    if (signaturesRequired < 1) {
      throw ArgumentError(
        'The number of required signatures needs to be greater than 0',
      );
    }

    // Validate number of public keys is greater than signatures required.
    if (publicKeys.length < signaturesRequired) {
      throw ArgumentError(
        'Provided ${publicKeys.length} public keys is smaller than the '
        '$signaturesRequired required signatures',
      );
    }

    // Make sure that all keys are normalized to the SingleKey authentication
    // scheme.
    final normalized = publicKeys
        .map((publicKey) =>
            publicKey is AnyPublicKey ? publicKey : AnyPublicKey(publicKey))
        .toList();
    if (signaturesRequired > _maxNumKeylessPublicForMultiKey) {
      final keylessCount = normalized
          .where((pk) =>
              pk.variant == AnyPublicKeyVariant.keyless ||
              pk.variant == AnyPublicKeyVariant.federatedKeyless)
          .length;
      if (keylessCount > _maxNumKeylessPublicForMultiKey) {
        throw ArgumentError(
          'Construction of MultiKey with more than '
          '$_maxNumKeylessPublicForMultiKey keyless public keys is not '
          'allowed when signaturesRequired is greater than '
          '$_maxNumKeylessPublicForMultiKey. This is because a maximum of 3 '
          'keyless signatures are supported for a K-of-N MultiKey '
          'transaction.',
        );
      }
    }
    return normalized;
  }

  @override
  int getSignaturesRequired() => signaturesRequired;

  // endregion

  // region AccountPublicKey

  /// Verifies the provided signature against the given message.
  ///
  /// Note: This function will fail if a keyless signature is used. Use
  /// `verifySignatureAsync` instead.
  ///
  /// Throws a [StateError] if the number of signatures does not match the
  /// number of required signatures.
  @override
  bool verifySignature({
    required HexInput message,
    required covariant MultiKeySignature signature,
  }) {
    if (signature.signatures.length != signaturesRequired) {
      throw StateError(
        'The number of signatures does not match the number of required '
        'signatures',
      );
    }
    final signerIndices = signature.bitMapToSignerIndices();
    for (var i = 0; i < signature.signatures.length; i += 1) {
      final singleSignature = signature.signatures[i];
      final publicKey = publicKeys[signerIndices[i]];
      if (!publicKey.verifySignature(
        message: message,
        signature: singleSignature,
      )) {
        return false;
      }
    }
    return true;
  }

  /// Verifies the provided signature against the given message, making any
  /// network calls required to verify keyless signatures.
  ///
  /// [options] may be a [VerifySignatureAsyncOptions]; when
  /// `throwErrorWithReason` is set, failures throw instead of returning
  /// false.
  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) async {
    try {
      if (signature is! MultiKeySignature) {
        throw ArgumentError('Signature is not a MultiKeySignature');
      }
      if (signature.signatures.length != signaturesRequired) {
        throw StateError(
          'The number of signatures does not match the number of required '
          'signatures',
        );
      }
      final signerIndices = signature.bitMapToSignerIndices();
      for (var i = 0; i < signature.signatures.length; i += 1) {
        final singleSignature = signature.signatures[i];
        final publicKey = publicKeys[signerIndices[i]];
        if (!await publicKey.verifySignatureAsync(
          aptosConfig: aptosConfig,
          message: message,
          signature: singleSignature,
          options: options,
        )) {
          return false;
        }
      }
      return true;
    } catch (error) {
      if (options is VerifySignatureAsyncOptions &&
          options.throwErrorWithReason) {
        rethrow;
      }
      return false;
    }
  }

  /// Generates an authentication key based on the current instance's byte
  /// representation using the MultiKey scheme.
  @override
  AuthenticationKey authKey() {
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.multiKey,
      input: toUint8Array(),
    );
  }

  // endregion

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    serializer.serializeVector(publicKeys);
    serializer.serializeU8(signaturesRequired);
  }

  static MultiKey deserialize(Deserializer deserializer) {
    final keys = deserializer.deserializeVector(AnyPublicKey.deserialize);
    final signaturesRequired = deserializer.deserializeU8();

    return MultiKey(publicKeys: keys, signaturesRequired: signaturesRequired);
  }

  // endregion

  /// Get the index of the provided public key.
  ///
  /// The key is normalized to an [AnyPublicKey] before the lookup so both
  /// raw and wrapped keys are found. Throws an [ArgumentError] if the public
  /// key is not found.
  @override
  int getIndex(PublicKey publicKey) {
    final anyPublicKey =
        publicKey is AnyPublicKey ? publicKey : AnyPublicKey(publicKey);
    return super.getIndex(anyPublicKey);
  }

  /// Determines if the provided public key is a MultiKey instance.
  static bool isInstance(PublicKey value) => value is MultiKey;
}

/// Represents a multi-signature transaction using multiple signature types.
/// This class allows for the creation and management of a K-of-N
/// multi-signature scheme, where a specified number of signatures are
/// required to authorize a transaction.
///
/// It includes functionality to validate the number of signatures against a
/// bitmap, which indicates which public keys have signed the transaction.
class MultiKeySignature extends Signature {
  /// Number of bytes in the bitmap representing who signed the transaction
  /// (32-bits).
  static const int bitmapLen = 4;

  /// Maximum number of signatures supported.
  static const int maxSignaturesSupported = bitmapLen * 8;

  /// The list of underlying signatures.
  final List<AnySignature> signatures;

  /// 32-bit Bitmap representing who signed the transaction.
  ///
  /// This is represented where each public key can be masked to determine
  /// whether the message was signed by that key.
  final Uint8List bitmap;

  /// Signature for a K-of-N multi-sig transaction.
  ///
  /// [signatures] may contain any mix of raw signatures and [AnySignature]
  /// wrappers; all are normalized to the SingleKey authentication scheme.
  ///
  /// [bitmap] is either a 4-byte [Uint8List] (at most 32 signatures are
  /// supported; if the Nth bit is `1`, the Nth signature should be provided
  /// in [signatures]; bits are read from left to right) or a plain
  /// `List<int>` of bit positions passed to [createBitmap].
  ///
  /// Throws an [ArgumentError] if the number of signatures exceeds the
  /// maximum supported, if the bitmap length is incorrect, or if the number
  /// of signatures does not match the bitmap.
  MultiKeySignature({
    required List<Signature> signatures,
    required List<int> bitmap,
  })  : signatures = _normalizeSignatures(signatures),
        bitmap = _normalizeBitmap(bitmap) {
    final nSignatures =
        this.bitmap.fold<int>(0, (acc, byte) => acc + _bitCount(byte));
    if (nSignatures != this.signatures.length) {
      throw ArgumentError(
        'Expecting $nSignatures signatures from the bitmap, but got '
        '${this.signatures.length}',
      );
    }
  }

  static List<AnySignature> _normalizeSignatures(List<Signature> signatures) {
    if (signatures.length > MultiKeySignature.maxSignaturesSupported) {
      throw ArgumentError(
        'The number of signatures cannot be greater than '
        '${MultiKeySignature.maxSignaturesSupported}',
      );
    }

    // Make sure that all signatures are normalized to the SingleKey
    // authentication scheme.
    return signatures
        .map((signature) =>
            signature is AnySignature ? signature : AnySignature(signature))
        .toList();
  }

  static Uint8List _normalizeBitmap(List<int> bitmap) {
    if (bitmap is! Uint8List) {
      return MultiKeySignature.createBitmap(bits: bitmap);
    }
    if (bitmap.length != MultiKeySignature.bitmapLen) {
      throw ArgumentError(
        '"bitmap" length should be ${MultiKeySignature.bitmapLen}',
      );
    }
    return bitmap;
  }

  /// Helper method to create a bitmap out of the specified bit positions.
  ///
  /// [bits] are the bitmap positions that should be set. A position starts
  /// at index 0. Valid positions should range between 0 and 31.
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

    for (final bit in bits) {
      if (bit >= MultiKeySignature.maxSignaturesSupported) {
        throw ArgumentError(
          'Cannot have a signature larger than '
          '${MultiKeySignature.maxSignaturesSupported - 1}.',
        );
      }

      if (!dupCheckSet.add(bit)) {
        throw ArgumentError('Duplicate bits detected.');
      }

      final byteOffset = bit ~/ 8;

      bitmap[byteOffset] |= firstBitInByte >> (bit % 8);
    }

    return bitmap;
  }

  /// Converts the bitmap to an array of signer indices.
  ///
  /// Example:
  ///
  /// bitmap: `[0b10001000, 0b01000000, 0b00000000, 0b00000000]`
  /// signerIndices: `[0, 4, 9]`
  List<int> bitMapToSignerIndices() {
    final signerIndices = <int>[];
    for (var i = 0; i < bitmap.length; i += 1) {
      final byte = bitmap[i];
      for (var bit = 0; bit < 8; bit += 1) {
        if ((byte & (128 >> bit)) != 0) {
          signerIndices.add(i * 8 + bit);
        }
      }
    }
    return signerIndices;
  }

  // region Serializable

  @override
  void serialize(Serializer serializer) {
    // Note: we should not need to serialize the vector length, as it can be
    // derived from the bitmap.
    serializer.serializeVector(signatures);
    serializer.serializeBytes(bitmap);
  }

  static MultiKeySignature deserialize(Deserializer deserializer) {
    final signatures = deserializer.deserializeVector(AnySignature.deserialize);
    final bitmap = deserializer.deserializeBytes();
    return MultiKeySignature(signatures: signatures, bitmap: bitmap);
  }

  // endregion
}
