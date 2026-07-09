import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/multi_ed25519.dart';
import 'package:aptos/src/core/crypto/utils.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const multiEd25519PkTestObject = (
  publicKeys: [
    'b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200',
    'aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab',
    '8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d74',
  ],
  threshold: 2,
  bytesInStringWithoutPrefix:
      'b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d7402',
);

const multiEd25519SigTestObject = (
  signatures: [
    'e6f3ba05469b2388492397840183945d4291f0dd3989150de3248e06b4cefe0ddf6180a80a0f04c045ee8f362870cb46918478cd9b56c66076f94f3efd5a8805',
    '2ae0818b7e51b853f1e43dc4c89a1f5fabc9cb256030a908f9872f3eaeb048fb1e2b4ffd5a9d5d1caedd0c8b7d6155ed8071e913536fa5c5a64327b6f2d9a102',
  ],
  bitmap: 'c0000000',
  bytesInStringWithoutPrefix:
      'e6f3ba05469b2388492397840183945d4291f0dd3989150de3248e06b4cefe0ddf6180a80a0f04c045ee8f362870cb46918478cd9b56c66076f94f3efd5a88052ae0818b7e51b853f1e43dc4c89a1f5fabc9cb256030a908f9872f3eaeb048fb1e2b4ffd5a9d5d1caedd0c8b7d6155ed8071e913536fa5c5a64327b6f2d9a102c0000000',
);

// Known-answer auth key vector derived from a MultiPublicKey.
const multiEd25519AuthKey =
    '0xa81cfac3df59920593ff417b45fc347ead3d88f8e25112c0488d34d7c9eb20af';

MultiEd25519PublicKey buildTestPublicKey({int? threshold}) {
  return MultiEd25519PublicKey(
    publicKeys:
        multiEd25519PkTestObject.publicKeys.map(Ed25519PublicKey.new).toList(),
    threshold: threshold ?? multiEd25519PkTestObject.threshold,
  );
}

void main() {
  group('MultiEd25519PublicKey', () {
    test('should verify the signature correctly', () {
      final publicKeys = [
        '98e12a20fc5f4de3c9b075399dc5cba113307a1b3a913847932b2374c5fbc2f9',
        'ab2ef6bdaf26dbb9df86640ebe6ca197529e2a53495d6daca8ec6c14eefb3f5d',
        '5224654234c2de966f6c190670cde06ba68f3ce27598a5c9c00d92070934d0ec',
      ].map(Ed25519PublicKey.new).toList();

      const signingMessage = '0xdeadbeef';

      final signatures = [
        '10f88e602b0b6b248ad25b64b8071db3c8cfea55f0bad95b1c7815f885358f0fa0d765213c378079dbd5befdf5a1efabc5b48a54c59b90f55dd0e3bc3975eb09',
        'ee818fda2af9528386b08f8489094634ff5e9f61ca5a87702d8d545df0892867e17ec43b06eede4b6bf7039d97165cc1fed147bb4ca8412fe6003279831b9c0a',
        'd94428f514ce5b60ed7849041a485b9fecd8d4d639bfba59364e231a71352122568b3a5d0b701750eb7362f1ef94fb7ce60b0ce4977575f8f6f6927311cc160d',
      ].map(Ed25519Signature.new).toList();

      final multiEd25519PublicKey = MultiEd25519PublicKey(
        publicKeys: publicKeys,
        threshold: 2,
      );

      expect(
        multiEd25519PublicKey.verifySignature(
          message: signingMessage,
          signature: MultiEd25519Signature(
            signatures: [signatures[0], signatures[1]],
            bitmap: [0, 1],
          ),
        ),
        isTrue,
      );

      expect(
        multiEd25519PublicKey.verifySignature(
          message: signingMessage,
          signature: MultiEd25519Signature(
            signatures: [signatures[1], signatures[2]],
            bitmap: [1, 2],
          ),
        ),
        isTrue,
      );

      expect(
        multiEd25519PublicKey.verifySignature(
          message: signingMessage,
          signature: MultiEd25519Signature(
            signatures: [signatures[0], signatures[2]],
            bitmap: [0, 2],
          ),
        ),
        isTrue,
      );

      expect(
        multiEd25519PublicKey.verifySignature(
          message: signingMessage,
          signature: MultiEd25519Signature(
            signatures: [signatures[0], signatures[1]],
            bitmap: [0, 2],
          ),
        ),
        isFalse,
      );
    });

    test('should convert to Uint8Array correctly', () {
      const publicKey1 =
          'b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200';
      const publicKey2 =
          'aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab';
      const publicKey3 =
          '8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d74';

      final multiPubKey = MultiEd25519PublicKey(
        publicKeys: [
          Ed25519PublicKey(publicKey1),
          Ed25519PublicKey(publicKey2),
          Ed25519PublicKey(publicKey3),
        ],
        threshold: 2,
      );

      final expected = Uint8List.fromList([
        185, 198, 238, 22, 48, 239, 62, 113, 17, 68, 166, 72, 219, 6, 187, //
        178, 40, 79, 114, 116, 207, 190, 229, 63, 252, 238, 80, 60, 193, 164, //
        146, 0, 174, 243, 244, 164, 184, 236, 161, 223, 195, 67, 54, 27, 248, //
        228, 54, 189, 66, 222, 146, 89, 192, 75, 131, 20, 235, 142, 32, 84, //
        221, 110, 130, 171, 138, 87, 98, 226, 26, 193, 205, 179, 135, 4, 66, //
        199, 123, 76, 58, 245, 140, 124, 237, 184, 119, 157, 2, 112, 230, //
        212, 241, 226, 247, 54, 125, 116, 2,
      ]);
      expect(multiPubKey.toUint8Array(), equals(expected));
    });

    test('should serialize to bytes correctly', () {
      final pubKeyMultiSig = buildTestPublicKey();

      expect(
        Hex.fromHexInput(pubKeyMultiSig.toUint8Array()).toStringWithoutPrefix(),
        equals(multiEd25519PkTestObject.bytesInStringWithoutPrefix),
      );
    });

    test('should deserialize from bytes correctly', () {
      final pubKeyMultiSig = buildTestPublicKey();

      final serializer = Serializer();
      serializer.serialize(pubKeyMultiSig);
      final deserialized = MultiEd25519PublicKey.deserialize(
        Deserializer(serializer.toUint8List()),
      );
      expect(
        deserialized.toUint8Array(),
        equals(pubKeyMultiSig.toUint8Array()),
      );
      expect(deserialized.threshold, equals(pubKeyMultiSig.threshold));
    });

    test('should create AuthenticationKey from MultiPublicKey', () {
      final pubKeyMultiSig = buildTestPublicKey();
      final authKey = pubKeyMultiSig.authKey();
      expect(authKey.data.toString(), equals(multiEd25519AuthKey));
    });

    test('accountPublicKeyToSigningScheme maps to multiEd25519', () {
      expect(
        accountPublicKeyToSigningScheme(buildTestPublicKey()),
        equals(SigningScheme.multiEd25519),
      );
    });

    test('getSignaturesRequired returns the threshold', () {
      expect(buildTestPublicKey().getSignaturesRequired(), equals(2));
    });

    test('getIndex returns the index of a contained public key', () {
      final pubKeyMultiSig = buildTestPublicKey();
      expect(
        pubKeyMultiSig.getIndex(
          Ed25519PublicKey(multiEd25519PkTestObject.publicKeys[1]),
        ),
        equals(1),
      );
      expect(
        () => pubKeyMultiSig.getIndex(
          Ed25519PublicKey(Uint8List.fromList(List.filled(32, 9))),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not found in multi key set'),
        )),
      );
    });
  });

  group('MultiEd25519PublicKey validation', () {
    test('rejects too few or too many public keys', () {
      final pk = Ed25519PublicKey(Uint8List.fromList(List.filled(32, 1)));
      expect(
        () => MultiEd25519PublicKey(publicKeys: [pk], threshold: 1),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('between 2 and'),
        )),
      );
      final tooMany = List.generate(
        33,
        (_) => Ed25519PublicKey(Uint8List.fromList(List.filled(32, 2))),
      );
      expect(
        () => MultiEd25519PublicKey(publicKeys: tooMany, threshold: 2),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('between 2 and'),
        )),
      );
    });

    test('rejects invalid threshold values', () {
      final pks = [
        Ed25519PublicKey(Uint8List.fromList(List.filled(32, 1))),
        Ed25519PublicKey(Uint8List.fromList(List.filled(32, 2))),
      ];
      expect(
        () => MultiEd25519PublicKey(publicKeys: pks, threshold: 0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Threshold must be between'),
        )),
      );
      expect(
        () => MultiEd25519PublicKey(publicKeys: pks, threshold: 3),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Threshold must be between'),
        )),
      );
    });

    test('deserializeWithoutLength reconstructs the same public key', () {
      final original = buildTestPublicKey();
      final restored = MultiEd25519PublicKey.deserializeWithoutLength(
        Deserializer(original.toUint8Array()),
      );
      expect(restored.threshold, equals(original.threshold));
      expect(restored.toString(), equals(original.toString()));
    });
  });

  group('MultiEd25519Signature', () {
    test('should serialize to bytes correctly', () {
      final edSigsArray = multiEd25519SigTestObject.signatures
          .map((sig) => Ed25519Signature(Hex.fromHexString(sig).toUint8List()))
          .toList();

      final multisig = MultiEd25519Signature(
        signatures: edSigsArray,
        bitmap:
            Hex.fromHexString(multiEd25519SigTestObject.bitmap).toUint8List(),
      );

      expect(
        Hex.fromHexInput(multisig.toUint8Array()).toStringWithoutPrefix(),
        equals(multiEd25519SigTestObject.bytesInStringWithoutPrefix),
      );
    });

    test('should deserialize from bytes correctly', () {
      final edSigsArray = multiEd25519SigTestObject.signatures
          .map((sig) => Ed25519Signature(Hex.fromHexString(sig).toUint8List()))
          .toList();

      final multisig = MultiEd25519Signature(
        signatures: edSigsArray,
        bitmap:
            Hex.fromHexString(multiEd25519SigTestObject.bitmap).toUint8List(),
      );

      final serializer = Serializer();
      serializer.serialize(multisig);
      final deserialized = MultiEd25519Signature.deserialize(
        Deserializer(serializer.toUint8List()),
      );
      expect(deserialized.toUint8Array(), equals(multisig.toUint8Array()));
    });

    test('should create a valid bitmap', () {
      expect(
        MultiEd25519Signature.createBitmap(bits: [0, 2, 31]),
        equals(Uint8List.fromList([0xa0, 0x00, 0x00, 0x01])),
      );
    });

    test('should throw exception when creating a bitmap with wrong bits', () {
      expect(
        () => MultiEd25519Signature.createBitmap(bits: [32]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Cannot have a signature larger than 31.'),
        )),
      );
    });

    test('should throw exception when creating a bitmap with unsorted bits',
        () {
      expect(
        () => MultiEd25519Signature.createBitmap(bits: [2, 1]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('The bits need to be sorted in ascending order.'),
        )),
      );
    });

    test('rejects bitmaps with the wrong byte length', () {
      expect(
        () => MultiEd25519Signature(
          signatures: [Ed25519Signature(Uint8List(64))],
          bitmap: Uint8List(3),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"bitmap" length should be'),
        )),
      );
    });

    test('rejects more than the maximum supported signatures', () {
      final signatures =
          List.generate(33, (_) => Ed25519Signature(Uint8List(64)));
      expect(
        () => MultiEd25519Signature(signatures: signatures, bitmap: [0]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('cannot be greater than'),
        )),
      );
    });

    test('verifySignature throws when bitmap and signature counts mismatch',
        () {
      final multiPub = buildTestPublicKey();
      final sig = MultiEd25519Signature(
        signatures: [Ed25519Signature(Uint8List(64))],
        bitmap: [0, 1],
      );
      expect(
        () => multiPub.verifySignature(message: '0x00', signature: sig),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Bitmap and signatures length mismatch'),
        )),
      );
    });

    test('verifySignature returns false for a non-MultiEd25519Signature', () {
      final multiPub = buildTestPublicKey();
      expect(
        multiPub.verifySignature(
          message: '0x00',
          signature: Ed25519Signature(Uint8List(64)),
        ),
        isFalse,
      );
    });
  });
}
