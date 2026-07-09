// Crypto-focused tests for EphemeralPublicKey and EphemeralSignature. The
// EphemeralKeyPair class itself belongs to the accounts module; these tests
// exercise the ephemeral public key and signature types directly.

import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/ephemeral.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:test/test.dart';

void main() {
  final privateKey = Ed25519PrivateKey(Uint8List.fromList(
    List<int>.filled(32, 0x11),
  ));

  group('EphemeralPublicKey', () {
    test('wraps an Ed25519 public key with the ed25519 variant', () {
      final publicKey = EphemeralPublicKey(privateKey.publicKey());
      expect(publicKey.variant.value, 0);
      expect(publicKey.publicKey, isA<Ed25519PublicKey>());
    });

    test('rejects unsupported key types', () {
      final secp256k1 = Secp256k1PrivateKey.generate().publicKey();
      expect(
        () => EphemeralPublicKey(secp256k1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BCS serialization is uleb128 variant + inner key', () {
      final inner = privateKey.publicKey();
      final publicKey = EphemeralPublicKey(inner);
      final bytes = publicKey.bcsToBytes();
      // variant 0, then the BCS of the Ed25519 key (length-prefixed 32
      // bytes).
      expect(bytes.length, 1 + 1 + 32);
      expect(bytes[0], 0);
      expect(bytes.sublist(1), inner.bcsToBytes());

      final restored = EphemeralPublicKey.deserialize(Deserializer(bytes));
      expect(restored.bcsToBytes(), bytes);
    });

    test('deserialize rejects an unknown variant index', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => EphemeralPublicKey.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('verifies a signature produced by the inner private key', () {
      final publicKey = EphemeralPublicKey(privateKey.publicKey());
      final message = Uint8List.fromList([0xca, 0xfe, 0xba, 0xbe]);
      final signature = EphemeralSignature(privateKey.signBytes(message));
      expect(
        publicKey.verifySignature(message: message, signature: signature),
        true,
      );
      final wrongMessage = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
      expect(
        publicKey.verifySignature(message: wrongMessage, signature: signature),
        false,
      );
    });
  });

  group('EphemeralSignature', () {
    test('BCS round-trips and fromHex agrees with deserialize', () {
      final message = Uint8List.fromList([1, 2, 3]);
      final signature = EphemeralSignature(privateKey.signBytes(message));
      final bytes = signature.bcsToBytes();
      expect(bytes.length, 1 + 1 + 64);
      expect(bytes[0], 0);

      final restored = EphemeralSignature.deserialize(Deserializer(bytes));
      expect(restored.bcsToBytes(), bytes);

      final fromHex = EphemeralSignature.fromHex(bytes);
      expect(fromHex.bcsToBytes(), bytes);
    });

    test('deserialize rejects an unknown variant index', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(7);
      expect(
        () => EphemeralSignature.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
