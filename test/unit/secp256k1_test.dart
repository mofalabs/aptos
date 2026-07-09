import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/private_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/types/types.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const secp256k1TestObject = (
  privateKey:
      'secp256k1-priv-0xd107155adf816a0a94c6db3c9489c13ad8a1eda7ada2e558ba3bfa47c020347e',
  privateKeyHex:
      '0xd107155adf816a0a94c6db3c9489c13ad8a1eda7ada2e558ba3bfa47c020347e',
  publicKey:
      '0x04acdd16651b839c24665b7e2033b55225f384554949fef46c397b5275f37f6ee95554d70fb5d9f93c5831ebf695c7206e7477ce708f03ae9bb2862dc6c9e033ea',
  address: '0x5792c985bc96f436270bd2a3c692210b09c7febb8889345ceefdbae4bacfe498',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0xd0d634e843b61339473b028105930ace022980708b2855954b977da09df84a770c0b68c29c8ca1b5409a5085b0ec263be80e433c83fcf6debb82f3447e71edca',
);

const secp256k1WalletTestObject = (
  address: '0x4b4aa8759fcef40ba49e999409eb73a98252f44f6612a4de2b23bad5c37b15a6',
  mnemonic:
      'shoot island position soft burden budget tooth cruel issue economy destroy above',
  path: "m/44'/637'/0'/0/0",
  privateKey:
      'secp256k1-priv-0x1eec55afc2f72c4ab7b46c84d761739035ac420a2b6b22cef3411adaf91ce1f7',
  publicKey:
      '0x04913871f1d6cb7b867e8671cf63cf7b4c43819539fa0074ff933434bf20bab825b335535251f720fff72fd8b567e414af84aacf2f26ec804562081f2e0b0c9478',
);

void main() {
  group('Secp256k1PublicKey', () {
    test('should create the instance correctly without error', () {
      // Create from string.
      final publicKey = Secp256k1PublicKey(secp256k1TestObject.publicKey);
      expect(publicKey.toString(), equals(secp256k1TestObject.publicKey));

      // Create from Uint8List.
      final hexUint8List =
          Hex.fromHexInput(secp256k1TestObject.publicKey).toUint8List();
      final publicKey2 = Secp256k1PublicKey(hexUint8List);
      expect(publicKey2.toUint8Array(), equals(hexUint8List));
    });

    test('should work with compressed public keys', () {
      final expectedPublicKey =
          Secp256k1PublicKey(secp256k1TestObject.publicKey);
      final uncompressedPublicKey =
          Hex.fromHexInput(secp256k1TestObject.publicKey);
      expect(uncompressedPublicKey.toUint8List().length, equals(65));

      final point = ECCurve_secp256k1()
          .curve
          .decodePoint(uncompressedPublicKey.toUint8List())!;
      final compressedPublicKey = point.getEncoded(true);
      final compressedPublicKeyHex = Hex.fromHexInput(compressedPublicKey);
      expect(compressedPublicKey.length, equals(33));

      final publicKey1 = Secp256k1PublicKey(compressedPublicKeyHex.toString());
      expect(publicKey1.toString(), equals(expectedPublicKey.toString()));

      final publicKey2 =
          Secp256k1PublicKey(compressedPublicKeyHex.toUint8List());
      expect(publicKey2.toString(), equals(expectedPublicKey.toString()));

      expect(publicKey1.toString(), equals(publicKey2.toString()));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Secp256k1PublicKey(invalidHexInput),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PublicKey length should be ${Secp256k1PublicKey.length}'),
        )),
      );
    });

    test('should verify the signature correctly', () {
      final pubKey = Secp256k1PublicKey(secp256k1TestObject.publicKey);
      final signature = Secp256k1Signature(secp256k1TestObject.signatureHex);

      // Convert message to hex.
      final hexMsg = Hex.fromHexString(secp256k1TestObject.messageEncoded);

      // Verify with correct signed message.
      expect(
        pubKey.verifySignature(
          message: hexMsg.toUint8List(),
          signature: signature,
        ),
        isTrue,
      );

      // Verify with incorrect signed message.
      const incorrectSignedMessage =
          '0xc5de9e40ac00b371cd83b1c197fa5b665b7449b33cd3cdd305bb78222e06a671a49625ab9aea8a039d4bb70e275768084d62b094bc1b31964f2357b7c1af7e0a';
      final invalidSignature = Secp256k1Signature(incorrectSignedMessage);
      expect(
        pubKey.verifySignature(
          message: secp256k1TestObject.messageEncoded,
          signature: invalidSignature,
        ),
        isFalse,
      );
    });

    test('should serialize correctly', () {
      final publicKey = Secp256k1PublicKey(secp256k1TestObject.publicKey);
      final serializer = Serializer();
      publicKey.serialize(serializer);

      final serialized = Hex.fromHexInput(serializer.toUint8List()).toString();
      const expected =
          '0x4104acdd16651b839c24665b7e2033b55225f384554949fef46c397b5275f37f6ee95554d70fb5d9f93c5831ebf695c7206e7477ce708f03ae9bb2862dc6c9e033ea';
      expect(serialized, equals(expected));
    });

    test('should deserialize correctly', () {
      const serializedPublicKeyStr =
          '0x4104acdd16651b839c24665b7e2033b55225f384554949fef46c397b5275f37f6ee95554d70fb5d9f93c5831ebf695c7206e7477ce708f03ae9bb2862dc6c9e033ea';
      final serializedPublicKey =
          Hex.fromHexString(serializedPublicKeyStr).toUint8List();
      final deserializer = Deserializer(serializedPublicKey);
      final publicKey = Secp256k1PublicKey.deserialize(deserializer);

      expect(publicKey.toString(), equals(secp256k1TestObject.publicKey));
    });
  });

  group('Secp256k1PrivateKey', () {
    test(
        'should create the instance correctly without error with AIP-80 compliant private key',
        () {
      final privateKey2 =
          Secp256k1PrivateKey(secp256k1TestObject.privateKey, false);
      expect(privateKey2.toString(), equals(secp256k1TestObject.privateKey));
    });

    test(
        'should create the instance correctly without error with non-AIP-80 compliant private key',
        () {
      final privateKey =
          Secp256k1PrivateKey(secp256k1TestObject.privateKeyHex, false);
      expect(privateKey.toString(), equals(secp256k1TestObject.privateKey));
    });

    test(
        'should create the instance correctly without error with Uint8List private key',
        () {
      final hexUint8List = PrivateKey.parseHexInput(
        secp256k1TestObject.privateKey,
        PrivateKeyVariants.secp256k1,
        false,
      ).toUint8List();
      final privateKey3 = Secp256k1PrivateKey(hexUint8List, false);
      expect(
        privateKey3.toHexString(),
        equals(Hex.fromHexInput(hexUint8List).toString()),
      );
    });

    test('should print in AIP-80 format', () {
      final privateKey =
          Secp256k1PrivateKey(secp256k1TestObject.privateKeyHex, false);
      expect(privateKey.toString(), equals(secp256k1TestObject.privateKey));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Secp256k1PrivateKey(invalidHexInput, false),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PrivateKey length should be ${Secp256k1PrivateKey.length}'),
        )),
      );
    });

    test('should sign the message correctly', () {
      final privateKey = Secp256k1PrivateKey(secp256k1TestObject.privateKey);
      final signedMessage = privateKey.sign(secp256k1TestObject.messageEncoded);
      expect(
          signedMessage.toString(), equals(secp256k1TestObject.signatureHex));
    });

    test('should serialize correctly', () {
      final privateKey = Secp256k1PrivateKey(secp256k1TestObject.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final received = Hex.fromHexInput(serializer.toUint8List()).toString();
      const expected =
          '0x20d107155adf816a0a94c6db3c9489c13ad8a1eda7ada2e558ba3bfa47c020347e';
      expect(received, equals(expected));
    });

    test('should deserialize correctly', () {
      const serializedPrivateKeyStr =
          '0x20d107155adf816a0a94c6db3c9489c13ad8a1eda7ada2e558ba3bfa47c020347e';
      final serializedPrivateKey =
          Hex.fromHexString(serializedPrivateKeyStr).toUint8List();
      final deserializer = Deserializer(serializedPrivateKey);
      final privateKey = Secp256k1PrivateKey.deserialize(deserializer);

      expect(privateKey.toString(), equals(secp256k1TestObject.privateKey));
    });

    test('should serialize and deserialize correctly', () {
      final privateKey = Secp256k1PrivateKey(secp256k1TestObject.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final deserializer = Deserializer(serializer.toUint8List());
      final deserializedPrivateKey =
          Secp256k1PrivateKey.deserialize(deserializer);

      expect(deserializedPrivateKey.toString(), equals(privateKey.toString()));
    });

    test('should prevent an invalid bip44 path', () {
      const path = '1234';
      expect(
        () => Secp256k1PrivateKey.fromDerivationPath(
            path, secp256k1WalletTestObject.mnemonic),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Invalid derivation path'),
        )),
      );
    });

    test('should derive from path and mnemonic', () {
      final key = Secp256k1PrivateKey.fromDerivationPath(
        secp256k1WalletTestObject.path,
        secp256k1WalletTestObject.mnemonic,
      );
      expect(key.toString(), equals(secp256k1WalletTestObject.privateKey));
    });

    group('signBytes / signText (unambiguous API)', () {
      test('signBytes signs exact bytes; verifyBytes round-trips', () {
        final privateKey = Secp256k1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        final sig = privateKey.signBytes(bytes);
        expect(publicKey.verifyBytes(message: bytes, signature: sig), isTrue);
      });

      test('signText UTF-8-encodes the string; verifyText round-trips', () {
        final privateKey = Secp256k1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final sig = privateKey.signText('hello');
        expect(publicKey.verifyText(message: 'hello', signature: sig), isTrue);
      });

      test(
          'signText("cafe") differs from signBytes([0xCA, 0xFE]) — no hex heuristic',
          () {
        final privateKey = Secp256k1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final sigText = privateKey.signText('cafe');
        final sigHexBytes =
            privateKey.signBytes(Uint8List.fromList([0xca, 0xfe]));
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
        final privateKey = Secp256k1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        // Bare hex "cafe" via legacy heuristic → 2 bytes [0xCA, 0xFE].
        final legacySig = privateKey.sign('cafe');
        expect(
          publicKey.verifyBytes(
            message: Uint8List.fromList([0xca, 0xfe]),
            signature: legacySig,
          ),
          isTrue,
        );
      });

      test('signBytes / signText throw after clear()', () {
        final privateKey = Secp256k1PrivateKey.generate();
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

  group('Secp256k1Signature', () {
    test('should create an instance correctly without error', () {
      // Create from string.
      final signatureStr = Secp256k1Signature(secp256k1TestObject.signatureHex);
      expect(signatureStr.toString(), equals(secp256k1TestObject.signatureHex));

      // Create from Uint8List.
      final signatureValue = Uint8List(Secp256k1Signature.length);
      final signature = Secp256k1Signature(signatureValue);
      expect(signature.toUint8Array(), equals(signatureValue));
    });

    test('should throw an error with invalid value length', () {
      final invalidSignatureValue =
          Uint8List(Secp256k1Signature.length - 1); // Invalid length
      expect(
        () => Secp256k1Signature(invalidSignatureValue),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Signature length should be ${Secp256k1Signature.length}'),
        )),
      );
    });

    test('should serialize correctly', () {
      final signature = Secp256k1Signature(secp256k1TestObject.signatureHex);
      final serializer = Serializer();
      signature.serialize(serializer);

      final received = Hex.fromHexInput(serializer.toUint8List()).toString();
      const expected =
          '0x40d0d634e843b61339473b028105930ace022980708b2855954b977da09df84a770c0b68c29c8ca1b5409a5085b0ec263be80e433c83fcf6debb82f3447e71edca';
      expect(received, equals(expected));
    });

    test('should deserialize correctly', () {
      const serializedSignature =
          '0x40d0d634e843b61339473b028105930ace022980708b2855954b977da09df84a770c0b68c29c8ca1b5409a5085b0ec263be80e433c83fcf6debb82f3447e71edca';
      final serializedSignatureUint8List =
          Hex.fromHexString(serializedSignature).toUint8List();
      final deserializer = Deserializer(serializedSignatureUint8List);
      final signature = Secp256k1Signature.deserialize(deserializer);

      expect(signature.toString(), equals(secp256k1TestObject.signatureHex));
    });
  });
}
