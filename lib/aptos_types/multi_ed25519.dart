

import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_types/ed25519.dart';

const MAX_SIGNATURES_SUPPORTED = 32;

class MultiEd25519PublicKey with Serializable {

  final List<Ed25519PublicKey> publicKeys;
  final int threshold;

  MultiEd25519PublicKey(this.publicKeys, this.threshold) {
    if (threshold > MAX_SIGNATURES_SUPPORTED) {
      throw ArgumentError('"threshold" cannot be larger than $MAX_SIGNATURES_SUPPORTED');
    }
  }

  Uint8List toBytes() {
    final bytes = Uint8List(publicKeys.length * Ed25519PublicKey.LENGTH + 1);
    for (var i = 0; i < publicKeys.length; i++) {
      bytes.setAll(i * Ed25519PublicKey.LENGTH, publicKeys[i].value);
    }

    bytes[publicKeys.length * Ed25519PublicKey.LENGTH] = threshold;

    return bytes;
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toBytes());
  }

  static MultiEd25519PublicKey deserialize(Deserializer deserializer) {
    Uint8List bytes = deserializer.deserializeBytes();
    int threshold = bytes[bytes.length - 1];

    final keys = <Ed25519PublicKey>[];

    for (var i = 0; i < bytes.length - 1; i += Ed25519PublicKey.LENGTH) {
      int begin = i;
      keys.add((Ed25519PublicKey(bytes.sublist(begin, begin + Ed25519PublicKey.LENGTH))));
    }
    return MultiEd25519PublicKey(keys, threshold);
  }
}

class MultiEd25519Signature with Serializable {
  static int BITMAP_LEN = 4;

  final List<Ed25519Signature> signatures;
  final Uint8List bitmap;

  MultiEd25519Signature(this.signatures, this.bitmap) {
    if (bitmap.length != MultiEd25519Signature.BITMAP_LEN) {
      throw ArgumentError('"bitmap" length should be ${MultiEd25519Signature.BITMAP_LEN}');
    }
  }

  Uint8List toBytes() {
    final bytes = Uint8List(signatures.length * Ed25519Signature.LENGTH + MultiEd25519Signature.BITMAP_LEN);
    for (var i = 0; i < signatures.length; i++) {
      bytes.setAll(i * Ed25519Signature.LENGTH, signatures[i].value);
    }

    bytes.setAll(signatures.length * Ed25519Signature.LENGTH, bitmap);

    return bytes;
  }

  static Uint8List createBitmap(List<int> bits) {
    // Bits are read from left to right. e.g. 0b10000000 represents the first bit is set in one byte.
    // The decimal value of 0b10000000 is 128.
    const firstBitInByte = 128;
    final bitmap = Uint8List.fromList([0, 0, 0, 0]);

    // Check if duplicates exist in bits
    final dupCheckSet = Set();

    bits.forEach((bit) {
      if (bit >= MAX_SIGNATURES_SUPPORTED) {
        throw ArgumentError("Invalid bit value $bit.");
      }

      if (dupCheckSet.contains(bit)) {
        throw ArgumentError("Duplicated bits detected.");
      }

      dupCheckSet.add(bit);

      int byteOffset = (bit / 8).floor();

      int byte = bitmap[byteOffset];

      byte |= firstBitInByte >> bit % 8;

      bitmap[byteOffset] = byte;
    });

    return bitmap;
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(toBytes());
  }

  static MultiEd25519Signature deserialize(Deserializer deserializer) {
    Uint8List bytes = deserializer.deserializeBytes();
    Uint8List bitmap = bytes.sublist(bytes.length - 4);

    final sigs = <Ed25519Signature>[];

    for (int i = 0; i < bytes.length - bitmap.length; i += Ed25519Signature.LENGTH) {
      int begin = i;
      sigs.add(Ed25519Signature(bytes.sublist(begin, begin + Ed25519Signature.LENGTH)));
    }
    return MultiEd25519Signature(sigs, bitmap);
  }
}
