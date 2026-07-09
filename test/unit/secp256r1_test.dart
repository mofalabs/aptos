import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/private_key.dart';
import 'package:aptos/src/core/crypto/secp256r1.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/types/types.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const singleSignerSecp256r1 = (
  publicKey:
      '0x046c761075b12769e9d0cc9995706275352e1bfb8e0085420625aa9cf849e6d62c2c140f0b3b7c53faf78c16648343966d769ccbc8f2fd14bb2c38f6befb91c77b',
  privateKey:
      'secp256r1-priv-0xa814fde3edc91aedf78c0e75bacbcf5e479cd4b27746961cfa1dc8e9b0e4481c',
  address: '0x9a5f9a9614e34f77295791db551e7072ff48d9801b19be97b38db1c05dfde817',
  messageEncoded: '68656c6c6f20776f726c64', // "hello world"
  signatureHex:
      '0x4fc4bc5f8ed851aec68c64499fa56360b11ea0c8b73fe3f93279e97b700582e55cb9e2ada7ae38951c2bc33d7755529fffc6201504180405c7960715ae0d4ff5',
);

void main() {
  group('Secp256r1PublicKey', () {
    test('should create the instance correctly without error', () {
      // Create from string.
      final publicKey = Secp256r1PublicKey(singleSignerSecp256r1.publicKey);
      expect(publicKey.toString(), equals(singleSignerSecp256r1.publicKey));

      // Create from Uint8List.
      final hexUint8List =
          Hex.fromHexInput(singleSignerSecp256r1.publicKey).toUint8List();
      final publicKey2 = Secp256r1PublicKey(hexUint8List);
      expect(publicKey2.toUint8Array(), equals(hexUint8List));
    });

    test('should work with compressed public keys', () {
      final uncompressedPublicKey =
          Hex.fromHexInput(singleSignerSecp256r1.publicKey);
      expect(uncompressedPublicKey.toUint8List().length, equals(65));

      final point = ECCurve_secp256r1()
          .curve
          .decodePoint(uncompressedPublicKey.toUint8List())!;
      final compressedPublicKey = point.getEncoded(true);
      final compressedPublicKeyHex = Hex.fromHexInput(compressedPublicKey);
      expect(compressedPublicKey.length, equals(33));

      final publicKey1 = Secp256r1PublicKey(compressedPublicKeyHex.toString());
      // Note: compressed keys get expanded to uncompressed format internally.
      expect(publicKey1.toUint8Array().length, equals(65));

      final publicKey2 =
          Secp256r1PublicKey(compressedPublicKeyHex.toUint8List());
      expect(publicKey2.toUint8Array().length, equals(65));

      expect(publicKey1.toString(), equals(publicKey2.toString()));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Secp256r1PublicKey(invalidHexInput),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PublicKey length should be ${Secp256r1PublicKey.length}'),
        )),
      );
    });

    test('should verify the signature correctly', () {
      final pubKey = Secp256r1PublicKey(singleSignerSecp256r1.publicKey);
      final signature = Secp256r1Signature(singleSignerSecp256r1.signatureHex);

      // Convert message to hex.
      final hexMsg = Hex.fromHexString(singleSignerSecp256r1.messageEncoded);

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
      final invalidSignature = Secp256r1Signature(incorrectSignedMessage);
      expect(
        pubKey.verifySignature(
          message: singleSignerSecp256r1.messageEncoded,
          signature: invalidSignature,
        ),
        isFalse,
      );
    });

    test('should serialize correctly', () {
      final publicKey = Secp256r1PublicKey(singleSignerSecp256r1.publicKey);
      final serializer = Serializer();
      publicKey.serialize(serializer);

      final serialized = Hex.fromHexInput(serializer.toUint8List()).toString();
      final expected =
          '0x41${Hex.fromHexInput(singleSignerSecp256r1.publicKey).toStringWithoutPrefix()}';
      expect(serialized, equals(expected));
    });

    test('should deserialize correctly', () {
      final serializedPublicKeyStr =
          '0x41${Hex.fromHexInput(singleSignerSecp256r1.publicKey).toStringWithoutPrefix()}';
      final serializedPublicKey =
          Hex.fromHexString(serializedPublicKeyStr).toUint8List();
      final deserializer = Deserializer(serializedPublicKey);
      final publicKey = Secp256r1PublicKey.deserialize(deserializer);

      expect(publicKey.toString(), equals(singleSignerSecp256r1.publicKey));
    });
  });

  group('Secp256r1PrivateKey', () {
    test(
        'should create the instance correctly without error with AIP-80 compliant private key',
        () {
      final privateKey2 = Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
      expect(privateKey2.toString(), equals(singleSignerSecp256r1.privateKey));
    });

    test(
        'should create the instance correctly without error with hex private key',
        () {
      final privateKeyHex =
          singleSignerSecp256r1.privateKey.replaceAll('secp256r1-priv-', '');
      final privateKey = Secp256r1PrivateKey(privateKeyHex, false);
      expect(privateKey.toString(), equals(singleSignerSecp256r1.privateKey));
    });

    test(
        'should create the instance correctly without error with Uint8List private key',
        () {
      final hexUint8List = PrivateKey.parseHexInput(
        singleSignerSecp256r1.privateKey,
        PrivateKeyVariants.secp256r1,
        false,
      ).toUint8List();
      final privateKey3 = Secp256r1PrivateKey(hexUint8List);
      expect(privateKey3.toString(), equals(singleSignerSecp256r1.privateKey));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => Secp256r1PrivateKey(invalidHexInput, false),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('PrivateKey length should be ${Secp256r1PrivateKey.length}'),
        )),
      );
    });

    test('should sign the message correctly', () {
      final privateKey = Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
      final signedMessage =
          privateKey.sign(singleSignerSecp256r1.messageEncoded);

      // Verify the signature is valid by checking if the public key can
      // verify it.
      final publicKey = privateKey.publicKey();
      expect(
        publicKey.verifySignature(
          message: singleSignerSecp256r1.messageEncoded,
          signature: signedMessage,
        ),
        isTrue,
      );
    });

    test('should generate the correct public key', () {
      final privateKey = Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
      final publicKey = privateKey.publicKey();
      expect(publicKey.toString(), equals(singleSignerSecp256r1.publicKey));
    });

    test('should serialize correctly', () {
      final privateKey = Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final received = Hex.fromHexInput(serializer.toUint8List()).toString();
      final expectedHex =
          singleSignerSecp256r1.privateKey.replaceAll('secp256r1-priv-', '');
      final expected =
          '0x20${Hex.fromHexInput(expectedHex).toStringWithoutPrefix()}';
      expect(received, equals(expected));
    });

    test('should deserialize correctly', () {
      final privateKeyHex =
          singleSignerSecp256r1.privateKey.replaceAll('secp256r1-priv-', '');
      final serializedPrivateKeyStr =
          '0x20${Hex.fromHexInput(privateKeyHex).toStringWithoutPrefix()}';
      final serializedPrivateKey =
          Hex.fromHexString(serializedPrivateKeyStr).toUint8List();
      final deserializer = Deserializer(serializedPrivateKey);
      final privateKey = Secp256r1PrivateKey.deserialize(deserializer);

      expect(privateKey.toString(), equals(singleSignerSecp256r1.privateKey));
    });

    test('should serialize and deserialize correctly', () {
      final privateKey = Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
      final serializer = Serializer();
      privateKey.serialize(serializer);

      final deserializer = Deserializer(serializer.toUint8List());
      final deserializedPrivateKey =
          Secp256r1PrivateKey.deserialize(deserializer);

      expect(deserializedPrivateKey.toString(), equals(privateKey.toString()));
    });

    test('should generate a random private key', () {
      final privateKey1 = Secp256r1PrivateKey.generate();
      final privateKey2 = Secp256r1PrivateKey.generate();

      expect(privateKey1.toString(), isNot(privateKey2.toString()));
    });

    group('message-input parity with Ed25519/Secp256k1', () {
      test('accepts a non-hex string as UTF-8', () {
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        // "hello" is not valid hex; it flows through convertSigningMessage
        // and is encoded as the 5 UTF-8 bytes of "hello".
        final signature = privateKey.sign('hello');
        expect(
          publicKey.verifySignature(message: 'hello', signature: signature),
          isTrue,
        );
      });

      test(
          'a bare even-length hex string is interpreted as hex (documented ambiguity)',
          () {
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        // "cafe" parses as valid hex → signs/verifies the 2 bytes
        // [0xCA, 0xFE].
        final signature = privateKey.sign('cafe');
        expect(
          publicKey.verifySignature(
            message: Uint8List.fromList([0xca, 0xfe]),
            signature: signature,
          ),
          isTrue,
        );
      });

      test('0x-prefixed hex and matching Uint8List produce the same signature',
          () {
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        final sigFromBytes = privateKey.sign(bytes);
        // Both forms verify against either input shape.
        expect(
          publicKey.verifySignature(
              message: '0xdeadbeef', signature: sigFromBytes),
          isTrue,
        );
        expect(
          publicKey.verifySignature(message: bytes, signature: sigFromBytes),
          isTrue,
        );
      });
    });

    group('clear()', () {
      test('zeros the underlying byte buffer', () {
        final key = Secp256r1PrivateKey.generate();
        final bytes = key.toUint8Array();
        expect(bytes.any((b) => b != 0), isTrue);
        key.clear();
        // toUint8Array() now throws, but the captured `bytes` reference
        // points at the same backing buffer of the Hex wrapper, which is now
        // zeroed.
        expect(bytes.every((b) => b == 0), isTrue);
      });

      test('isCleared() flips from false to true', () {
        final key = Secp256r1PrivateKey.generate();
        expect(key.isCleared(), isFalse);
        key.clear();
        expect(key.isCleared(), isTrue);
      });

      test('clear() is idempotent', () {
        final key = Secp256r1PrivateKey.generate();
        key.clear();
        expect(() => key.clear(), returnsNormally);
        expect(key.isCleared(), isTrue);
      });

      final operations = <String, void Function(Secp256r1PrivateKey)>{
        'toUint8Array': (k) => k.toUint8Array(),
        'toString': (k) => k.toString(),
        'toHexString': (k) => k.toHexString(),
        'publicKey': (k) => k.publicKey(),
        'sign': (k) => k.sign('0x00'),
      };
      operations.forEach((label, op) {
        test('rejects $label() after clear()', () {
          final key = Secp256r1PrivateKey.generate();
          key.clear();
          expect(
            () => op(key),
            throwsA(isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('cleared from memory'),
            )),
          );
        });
      });

      test('normal operations work before clear()', () {
        final key = Secp256r1PrivateKey.generate();
        expect(() => key.publicKey(), returnsNormally);
        expect(() => key.toUint8Array(), returnsNormally);
        expect(() => key.toString(), returnsNormally);
        expect(() => key.sign('0x00'), returnsNormally);
      });
    });

    group('signBytes / signText (unambiguous API)', () {
      test('signBytes signs exact bytes; verifyBytes round-trips', () {
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        final sig = privateKey.signBytes(bytes);
        expect(publicKey.verifyBytes(message: bytes, signature: sig), isTrue);
      });

      test('signText UTF-8-encodes the string; verifyText round-trips', () {
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
        final sig = privateKey.signText('hello');
        expect(publicKey.verifyText(message: 'hello', signature: sig), isTrue);
      });

      test(
          'signText("cafe") and signBytes([0xCA, 0xFE]) are over different bytes',
          () {
        final privateKey = Secp256r1PrivateKey.generate();
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
        final privateKey = Secp256r1PrivateKey.generate();
        final publicKey = privateKey.publicKey();
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
        final privateKey = Secp256r1PrivateKey.generate();
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

  group('Secp256r1Signature', () {
    test('should create an instance correctly without error', () {
      // Create from string.
      final signatureStr =
          Secp256r1Signature(singleSignerSecp256r1.signatureHex);
      expect(
          signatureStr.toString(), equals(singleSignerSecp256r1.signatureHex));

      // Create from Uint8List.
      final validSigBytes =
          Hex.fromHexInput(singleSignerSecp256r1.signatureHex).toUint8List();
      final signature = Secp256r1Signature(validSigBytes);
      expect(signature.toUint8Array(), equals(validSigBytes));
    });

    test('should throw an error with invalid value length', () {
      final invalidSignatureValue =
          Uint8List(Secp256r1Signature.length - 1); // Invalid length
      expect(
        () => Secp256r1Signature(invalidSignatureValue),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Signature length should be ${Secp256r1Signature.length}'),
        )),
      );
    });

    test('should serialize correctly', () {
      final signature = Secp256r1Signature(singleSignerSecp256r1.signatureHex);
      final serializer = Serializer();
      signature.serialize(serializer);

      final received = Hex.fromHexInput(serializer.toUint8List()).toString();
      final expected =
          '0x40${Hex.fromHexInput(singleSignerSecp256r1.signatureHex).toStringWithoutPrefix()}';
      expect(received, equals(expected));
    });

    test('should deserialize correctly', () {
      final serializedSignature =
          '0x40${Hex.fromHexInput(singleSignerSecp256r1.signatureHex).toStringWithoutPrefix()}';
      final serializedSignatureUint8List =
          Hex.fromHexString(serializedSignature).toUint8List();
      final deserializer = Deserializer(serializedSignatureUint8List);
      final signature = Secp256r1Signature.deserialize(deserializer);

      expect(signature.toString(), equals(singleSignerSecp256r1.signatureHex));
    });
  });

  group('WebAuthnSignature', () {
    test(
        'round-trips signature, authenticator data, and client data JSON through BCS',
        () {
      final original = WebAuthnSignature(
        signature: Uint8List(64)..fillRange(0, 64, 0xaa),
        authenticatorData: Uint8List.fromList([0x01, 0x02, 0x03]),
        clientDataJSON:
            Uint8List.fromList(utf8.encode('{"type":"webauthn.get"}')),
      );

      final serializer = Serializer();
      original.serialize(serializer);
      final restored = WebAuthnSignature.deserialize(
        Deserializer(serializer.toUint8List()),
      );

      expect(
          restored.signature.toString(), equals(original.signature.toString()));
      expect(restored.authenticatorData.toString(),
          equals(original.authenticatorData.toString()));
      expect(restored.clientDataJSON.toString(),
          equals(original.clientDataJSON.toString()));
      expect(restored.bcsToHex().toString(),
          equals(original.bcsToHex().toString()));
    });

    test('throws when deserializing an unknown WebAuthnSignature variant id',
        () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(1);
      expect(
        () => WebAuthnSignature.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Invalid id for WebAuthnSignature'),
        )),
      );
    });
  });
}
