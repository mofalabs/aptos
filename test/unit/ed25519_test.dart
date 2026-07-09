import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const ed25519TestObject = (
  privateKey:
      'ed25519-priv-0xc5338cd251c22daa8c9c9cc94f498cc8a5c7e1d2e75287a5dda91096fe64efa5',
  privateKeyHex:
      '0xc5338cd251c22daa8c9c9cc94f498cc8a5c7e1d2e75287a5dda91096fe64efa5',
  publicKey: '0xde19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c',
  authKey: '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0x9e653d56a09247570bb174a389e85b9226abd5c403ea6c504b386626a145158cd4efd66fc5e071c0e19538a96a05ddbda24d3c51e1e6a9dacc6bb1ce775cce07',
);

const wallet = (
  address: '0x07968dab936c1bad187c60ce4082f307d030d780e91e694ae03aef16aba73f30',
  mnemonic:
      'shoot island position soft burden budget tooth cruel issue economy destroy above',
  path: "m/44'/637'/0'/0'/0'",
  privateKey:
      'ed25519-priv-0x5d996aa76b3212142792d9130796cd2e11e3c445a93118c08414df4f66bc60ec',
  publicKey: '0xea526ba1710343d953461ff68641f1b7df5f23b9042ffa2d2a798d3adb3f3d6c',
);

void main() {
  group('Ed25519PublicKey', () {
    test('should create the instance correctly without error', () {
      // Create from string.
      const hexStr =
          '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final publicKey = Ed25519PublicKey(hexStr);
      expect(publicKey.toString(), equals(hexStr));

      // Create from Uint8List.
      final hexUint8List = Uint8List.fromList([
        1, 35, 69, 103, 137, 171, 205, 239, 1, 35, 69, 103, 137, 171, 205, //
        239, 1, 35, 69, 103, 137, 171, 205, 239, 1, 35, 69, 103, 137, 171, //
        205, 239,
      ]);
      final publicKey2 = Ed25519PublicKey(hexUint8List);
      expect(publicKey2.toUint8Array(), equals(hexUint8List));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Ed25519PublicKey(invalidHexInput),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PublicKey length should be ${Ed25519PublicKey.length}'),
        )),
      );
    });

    test('should verify the signature correctly', () {
      final pubKey = Ed25519PublicKey(ed25519TestObject.publicKey);
      final signature = Ed25519Signature(ed25519TestObject.signatureHex);

      // Verify with correct signed message.
      expect(
        pubKey.verifySignature(
          message: ed25519TestObject.messageEncoded,
          signature: signature,
        ),
        isTrue,
      );

      // Verify with incorrect signed message.
      const incorrectSignedMessage =
          '0xc5de9e40ac00b371cd83b1c197fa5b665b7449b33cd3cdd305bb78222e06a671a49625ab9aea8a039d4bb70e275768084d62b094bc1b31964f2357b7c1af7e0a';
      final invalidSignature = Ed25519Signature(incorrectSignedMessage);
      expect(
        pubKey.verifySignature(
          message: ed25519TestObject.messageEncoded,
          signature: invalidSignature,
        ),
        isFalse,
      );
    });

    test('should fail malleable signatures', () {
      // Here we make a signature exactly with the L.
      final signature = Ed25519Signature(
        '0x0000000000000000000000000000000000000000000000000000000000000000edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010',
      );
      expect(isCanonicalEd25519Signature(signature), isFalse);

      // We now check with L + 1.
      final signature2 = Ed25519Signature(
        '0x0000000000000000000000000000000000000000000000000000000000000000edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000011',
      );
      expect(isCanonicalEd25519Signature(signature2), isFalse);
    });

    test('should serialize correctly', () {
      final publicKey = Ed25519PublicKey(ed25519TestObject.publicKey);
      final serializer = Serializer();
      publicKey.serialize(serializer);

      final expectedUint8List = Uint8List.fromList([
        32, 222, 25, 229, 209, 136, 12, 172, 135, 213, 116, 132, 206, 158, //
        210, 232, 76, 240, 249, 89, 159, 18, 231, 204, 58, 82, 228, 231, //
        101, 122, 118, 63, 44,
      ]);
      expect(serializer.toUint8List(), equals(expectedUint8List));
    });

    test('should deserialize correctly', () {
      final serializedPublicKey = Uint8List.fromList([
        32, 222, 25, 229, 209, 136, 12, 172, 135, 213, 116, 132, 206, 158, //
        210, 232, 76, 240, 249, 89, 159, 18, 231, 204, 58, 82, 228, 231, //
        101, 122, 118, 63, 44,
      ]);
      final deserializer = Deserializer(serializedPublicKey);
      final publicKey = Ed25519PublicKey.deserialize(deserializer);

      expect(publicKey.toString(), equals(ed25519TestObject.publicKey));
    });

    test('should serialize and deserialize correctly', () {
      const hexInput =
          '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final publicKey = Ed25519PublicKey(hexInput);
      final serializer = Serializer();
      publicKey.serialize(serializer);

      final deserializer = Deserializer(serializer.toUint8List());
      final deserializedPublicKey = Ed25519PublicKey.deserialize(deserializer);

      expect(deserializedPublicKey.toUint8Array(),
          equals(publicKey.toUint8Array()));
    });
  });

  group('Ed25519PrivateKey', () {
    test(
        'should create the instance correctly without error with AIP-80 compliant private key',
        () {
      final privateKey2 = Ed25519PrivateKey(ed25519TestObject.privateKey, false);
      expect(privateKey2.toString(), equals(ed25519TestObject.privateKey));
    });

    test(
        'should create the instance correctly without error with non-AIP-80 compliant private key',
        () {
      final privateKey = Ed25519PrivateKey(ed25519TestObject.privateKey, false);
      expect(privateKey.toString(), equals(ed25519TestObject.privateKey));
    });

    test(
        'should create the instance correctly without error with Uint8List private key',
        () {
      final hexUint8List = Uint8List.fromList([
        197, 51, 140, 210, 81, 194, 45, 170, 140, 156, 156, 201, 79, 73, //
        140, 200, 165, 199, 225, 210, 231, 82, 135, 165, 221, 169, 16, 150, //
        254, 100, 239, 165,
      ]);
      final privateKey3 = Ed25519PrivateKey(hexUint8List, false);
      expect(
        privateKey3.toHexString(),
        equals(Hex.fromHexInput(hexUint8List).toString()),
      );
    });

    test('should print in AIP-80 format', () {
      final privateKey =
          Ed25519PrivateKey(ed25519TestObject.privateKeyHex, false);
      expect(privateKey.toString(), equals(ed25519TestObject.privateKey));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Ed25519PrivateKey(invalidHexInput, false),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PrivateKey length should be ${Ed25519PrivateKey.length}'),
        )),
      );
    });

    test('should sign the message correctly', () {
      final privateKey = Ed25519PrivateKey(ed25519TestObject.privateKey);
      final signedMessage = privateKey.sign(ed25519TestObject.messageEncoded);
      expect(signedMessage.toString(), equals(ed25519TestObject.signatureHex));
    });

    test('should serialize correctly', () {
      final privateKey = Ed25519PrivateKey(ed25519TestObject.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final expectedUint8List = Uint8List.fromList([
        32, 197, 51, 140, 210, 81, 194, 45, 170, 140, 156, 156, 201, 79, //
        73, 140, 200, 165, 199, 225, 210, 231, 82, 135, 165, 221, 169, 16, //
        150, 254, 100, 239, 165,
      ]);
      expect(serializer.toUint8List(), equals(expectedUint8List));
    });

    test('should deserialize correctly', () {
      final serializedPrivateKey = Uint8List.fromList([
        32, 197, 51, 140, 210, 81, 194, 45, 170, 140, 156, 156, 201, 79, //
        73, 140, 200, 165, 199, 225, 210, 231, 82, 135, 165, 221, 169, 16, //
        150, 254, 100, 239, 165,
      ]);
      final deserializer = Deserializer(serializedPrivateKey);
      final privateKey = Ed25519PrivateKey.deserialize(deserializer);

      expect(privateKey.toString(), equals(ed25519TestObject.privateKey));
    });

    test('should serialize and deserialize correctly', () {
      final privateKey = Ed25519PrivateKey(ed25519TestObject.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final deserializer = Deserializer(serializer.toUint8List());
      final deserializedPrivateKey =
          Ed25519PrivateKey.deserialize(deserializer);

      expect(deserializedPrivateKey.toString(), equals(privateKey.toString()));
    });

    test('should generate a random private key correctly', () {
      // Make sure it generates a new PrivateKey successfully.
      final privateKey = Ed25519PrivateKey.generate();
      expect(privateKey.toUint8Array().length,
          equals(Ed25519PrivateKey.length));

      // Make sure it generates different private keys.
      final anotherPrivateKey = Ed25519PrivateKey.generate();
      expect(anotherPrivateKey.toString(), isNot(privateKey.toString()));
    });

    test('should derive the public key correctly', () {
      final privateKey = Ed25519PrivateKey(ed25519TestObject.privateKey);
      final publicKey = privateKey.publicKey();
      expect(publicKey.toString(), equals(ed25519TestObject.publicKey));
    });

    test('should prevent an invalid bip44 path', () {
      const path = '1234';
      expect(
        () => Ed25519PrivateKey.fromDerivationPath(path, wallet.mnemonic),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Invalid derivation path'),
        )),
      );
    });

    test('should derive from path and mnemonic', () {
      final key =
          Ed25519PrivateKey.fromDerivationPath(wallet.path, wallet.mnemonic);
      expect(key.toString(), equals(wallet.privateKey));
    });

    group('signBytes / signText (unambiguous API)', () {
      test('signBytes signs exact bytes; verifyBytes round-trips', () {
        final privateKey = Ed25519PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        final sig = privateKey.signBytes(bytes);
        expect(
          publicKey.verifyBytes(message: bytes, signature: sig),
          isTrue,
        );
      });

      test('signText UTF-8-encodes the string; verifyText round-trips', () {
        final privateKey = Ed25519PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final sig = privateKey.signText('hello');
        expect(
          publicKey.verifyText(message: 'hello', signature: sig),
          isTrue,
        );
      });

      test(
          'signText("cafe") produces the SAME signature as signBytes(utf8("cafe")) — no hex heuristic',
          () {
        final privateKey = Ed25519PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final sigText = privateKey.signText('cafe');
        final sigBytes = privateKey
            .signBytes(Uint8List.fromList(utf8.encode('cafe')));
        expect(sigText.toString(), equals(sigBytes.toString()));
        // And does NOT match a signature over the hex bytes [0xCA, 0xFE].
        final sigHexBytes =
            privateKey.signBytes(Uint8List.fromList([0xca, 0xfe]));
        expect(sigText.toString(), isNot(sigHexBytes.toString()));
        // Cross-verify rejects the wrong interpretation.
        expect(
          publicKey.verifyBytes(
            message: Uint8List.fromList([0xca, 0xfe]),
            signature: sigText,
          ),
          isFalse,
        );
        expect(
          publicKey.verifyText(message: 'cafe', signature: sigHexBytes),
          isFalse,
        );
      });

      test(
          'legacy sign(HexInput) still produces a signature that verifyBytes accepts',
          () {
        final privateKey = Ed25519PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        // "cafe" is bare hex via the legacy heuristic → 2 bytes [0xCA, 0xFE].
        final legacySig = privateKey.sign('cafe');
        expect(
          publicKey.verifyBytes(
            message: Uint8List.fromList([0xca, 0xfe]),
            signature: legacySig,
          ),
          isTrue,
        );
      });

      test('signBytes throws after clear()', () {
        final privateKey = Ed25519PrivateKey.generate();
        privateKey.clear();
        expect(
          () => privateKey.signBytes(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cleared from memory'),
          )),
        );
        expect(
          () => privateKey.signText('hello'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cleared from memory'),
          )),
        );
      });
    });
  });

  group('Signature', () {
    test('should create an instance correctly without error', () {
      // Create from string.
      final signatureStr = Ed25519Signature(ed25519TestObject.signatureHex);
      expect(signatureStr.toString(), equals(ed25519TestObject.signatureHex));

      // Create from Uint8List.
      final signatureValue = Uint8List(Ed25519Signature.length);
      final signature = Ed25519Signature(signatureValue);
      expect(signature.toUint8Array(), equals(signatureValue));
    });

    test('should throw an error with invalid value length', () {
      final invalidSignatureValue =
          Uint8List(Ed25519Signature.length - 1); // Invalid length
      expect(
        () => Ed25519Signature(invalidSignatureValue),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Signature length should be ${Ed25519Signature.length}'),
        )),
      );
    });

    test('should serialize correctly', () {
      final signature = Ed25519Signature(ed25519TestObject.signatureHex);
      final serializer = Serializer();
      signature.serialize(serializer);
      final expectedUint8List = Uint8List.fromList([
        64, 158, 101, 61, 86, 160, 146, 71, 87, 11, 177, 116, 163, 137, //
        232, 91, 146, 38, 171, 213, 196, 3, 234, 108, 80, 75, 56, 102, 38, //
        161, 69, 21, 140, 212, 239, 214, 111, 197, 224, 113, 192, 225, 149, //
        56, 169, 106, 5, 221, 189, 162, 77, 60, 81, 225, 230, 169, 218, //
        204, 107, 177, 206, 119, 92, 206, 7,
      ]);
      expect(serializer.toUint8List(), equals(expectedUint8List));
    });

    test('should deserialize correctly', () {
      final serializedSignature = Uint8List.fromList([
        64, 158, 101, 61, 86, 160, 146, 71, 87, 11, 177, 116, 163, 137, //
        232, 91, 146, 38, 171, 213, 196, 3, 234, 108, 80, 75, 56, 102, 38, //
        161, 69, 21, 140, 212, 239, 214, 111, 197, 224, 113, 192, 225, 149, //
        56, 169, 106, 5, 221, 189, 162, 77, 60, 81, 225, 230, 169, 218, //
        204, 107, 177, 206, 119, 92, 206, 7,
      ]);
      final deserializer = Deserializer(serializedSignature);
      final signature = Ed25519Signature.deserialize(deserializer);

      expect(signature.toString(), equals(ed25519TestObject.signatureHex));
    });

    test('should serialize and deserialize correctly', () {
      final signatureValue = Uint8List(Ed25519Signature.length);
      final signature = Ed25519Signature(signatureValue);
      final serializer = Serializer();
      signature.serialize(serializer);

      final deserializer = Deserializer(serializer.toUint8List());
      final deserializedSignature = Ed25519Signature.deserialize(deserializer);

      expect(
        deserializedSignature.toUint8Array(),
        equals(signature.toUint8Array()),
      );
    });
  });
}
