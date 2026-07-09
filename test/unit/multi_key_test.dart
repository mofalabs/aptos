import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/multi_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/crypto/single_key.dart';
import 'package:aptos/src/core/crypto/utils.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const multiKeyTestObject = (
  publicKeys: [
    // secp256k1
    '0x049a6f7caddff8064a7dd5800e4fb512bf1ff91daee965409385dfa040e3e63008ab7ef566f4377c2de5aeb2948208a01bcee2050c1c8578ce5fa6e0c3c507cca2',
    // ed25519
    '0x7a73df1afd028e75e7f9e23b2187a37d092a6ccebcb3edff6e02f93185cbde86',
    // ed25519
    '0x17fe89a825969c1c0e5f5e80b95f563a6cb6240f88c4246c19cb39c9535a1486',
  ],
  signaturesRequired: 2,
  // NOTE: the authKey below is derived as sha3_256(bcs(MultiKey) | 0x03)
  // over the byte-exact BCS fixture (stringBytes) plus the MultiKey scheme
  // byte (0x03).
  authKey: '0xd2b929b11e53fd69fd09d283fcea941337558060f5711c6a32261a77d9038270',
  bitmap: [160, 0, 0, 0],
  stringBytes:
      '0x030141049a6f7caddff8064a7dd5800e4fb512bf1ff91daee965409385dfa040e3e63008ab7ef566f4377c2de5aeb2948208a01bcee2050c1c8578ce5fa6e0c3c507cca200207a73df1afd028e75e7f9e23b2187a37d092a6ccebcb3edff6e02f93185cbde86002017fe89a825969c1c0e5f5e80b95f563a6cb6240f88c4246c19cb39c9535a148602',
);

MultiKey buildTestMultiKey({int signaturesRequired = 2}) {
  return MultiKey(
    publicKeys: [
      Secp256k1PublicKey(multiKeyTestObject.publicKeys[0]),
      Ed25519PublicKey(multiKeyTestObject.publicKeys[1]),
      Ed25519PublicKey(multiKeyTestObject.publicKeys[2]),
    ],
    signaturesRequired: signaturesRequired,
  );
}

void main() {
  group('MultiKey', () {
    test('should throw when number of required signatures is less than 1', () {
      expect(
        () => buildTestMultiKey(signaturesRequired: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'should throw when number of public keys is less than the number of '
        'signatures required', () {
      expect(
        () => buildTestMultiKey(signaturesRequired: 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should convert to Uint8Array correctly', () {
      final multiKey = buildTestMultiKey();

      final expected = Uint8List.fromList([
        3, 1, 65, 4, 154, 111, 124, 173, 223, 248, 6, 74, 125, 213, 128, 14, //
        79, 181, 18, 191, 31, 249, 29, 174, 233, 101, 64, 147, 133, 223, 160, //
        64, 227, 230, 48, 8, 171, 126, 245, 102, 244, 55, 124, 45, 229, 174, //
        178, 148, 130, 8, 160, 27, 206, 226, 5, 12, 28, 133, 120, 206, 95, //
        166, 224, 195, 197, 7, 204, 162, 0, 32, 122, 115, 223, 26, 253, 2, //
        142, 117, 231, 249, 226, 59, 33, 135, 163, 125, 9, 42, 108, 206, 188, //
        179, 237, 255, 110, 2, 249, 49, 133, 203, 222, 134, 0, 32, 23, 254, //
        137, 168, 37, 150, 156, 28, 14, 95, 94, 128, 185, 95, 86, 58, 108, //
        182, 36, 15, 136, 196, 36, 108, 25, 203, 57, 201, 83, 90, 20, 134, 2,
      ]);
      expect(multiKey.toUint8Array(), equals(expected));
    });

    test('should serialize to bytes correctly', () {
      final multiKey = buildTestMultiKey();
      expect(multiKey.toString(), equals(multiKeyTestObject.stringBytes));
    });

    test('should deserialize from bytes correctly', () {
      final multiKey = buildTestMultiKey();

      final deserialized =
          MultiKey.deserialize(Deserializer(multiKey.toUint8Array()));
      expect(deserialized.bcsToBytes(), equals(multiKey.bcsToBytes()));
      expect(deserialized.signaturesRequired,
          equals(multiKey.signaturesRequired));
      expect(deserialized.publicKeys.length, equals(3));
      expect(deserialized.publicKeys[0].variant,
          equals(AnyPublicKeyVariant.secp256k1));
      expect(deserialized.publicKeys[1].variant,
          equals(AnyPublicKeyVariant.ed25519));
    });

    test('should throw when signatures in bitmap greater than public keys amount',
        () {
      final multiKey = buildTestMultiKey();
      expect(
        () => multiKey.createBitmap(bits: [0, 1, 2, 3]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw when there are duplicates in bitmap', () {
      final multiKey = buildTestMultiKey();
      expect(
        () => multiKey.createBitmap(bits: [0, 0]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should create bitmap correctly', () {
      final multiKey = buildTestMultiKey();
      final bitmap = multiKey.createBitmap(bits: [0, 2]);
      expect(bitmap, equals(Uint8List.fromList(multiKeyTestObject.bitmap)));
    });

    test('should derive the MultiKey auth key correctly', () {
      final multiKey = buildTestMultiKey();
      expect(
        multiKey.authKey().data.toString(),
        equals(multiKeyTestObject.authKey),
      );
    });

    test('getSignaturesRequired returns the threshold', () {
      expect(buildTestMultiKey().getSignaturesRequired(), equals(2));
    });

    test('accountPublicKeyToSigningScheme maps MultiKey to multiKey', () {
      expect(
        accountPublicKeyToSigningScheme(buildTestMultiKey()),
        equals(SigningScheme.multiKey),
      );
    });
  });

  group('MultiKey.getIndex', () {
    test('returns the index of a contained public key', () {
      final multiKey = buildTestMultiKey();
      // Raw keys are normalized to AnyPublicKey before the lookup.
      expect(
        multiKey.getIndex(Secp256k1PublicKey(multiKeyTestObject.publicKeys[0])),
        equals(0),
      );
      expect(
        multiKey.getIndex(Ed25519PublicKey(multiKeyTestObject.publicKeys[1])),
        equals(1),
      );
      // AnyPublicKey-wrapped keys are found as well.
      expect(
        multiKey.getIndex(
          AnyPublicKey(Ed25519PublicKey(multiKeyTestObject.publicKeys[2])),
        ),
        equals(2),
      );
    });

    test('throws when the public key is not in the set', () {
      final multiKey = buildTestMultiKey();
      final stranger = Ed25519PrivateKey.generate().publicKey();
      expect(
        () => multiKey.getIndex(stranger),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not found in multi key set'),
        )),
      );
    });
  });

  group('MultiKey verification', () {
    const message = 'deadbeef00';

    final signer1 = Ed25519PrivateKey.generate();
    final signer2 = Ed25519PrivateKey.generate();
    final signer3 = Ed25519PrivateKey.generate();
    final multiKey = MultiKey(
      publicKeys: [
        signer1.publicKey(),
        signer2.publicKey(),
        signer3.publicKey(),
      ],
      signaturesRequired: 2,
    );

    MultiKeySignature signWith(String msg) => MultiKeySignature(
          signatures: [signer1.sign(msg), signer2.sign(msg)],
          bitmap: [0, 1],
        );

    test('returns true for a valid 2-of-3 signature', () {
      expect(
        multiKey.verifySignature(message: message, signature: signWith(message)),
        isTrue,
      );
    });

    test('verifies a valid 2-of-3 signature by the 1st and 3rd signers', () {
      final signature = MultiKeySignature(
        signatures: [signer1.sign(message), signer3.sign(message)],
        bitmap: [0, 2],
      );
      expect(
        multiKey.verifySignature(message: message, signature: signature),
        isTrue,
      );
    });

    test('throws when the signature count does not match signaturesRequired',
        () {
      final stricter = MultiKey(
        publicKeys: multiKey.publicKeys,
        signaturesRequired: 3,
      );
      expect(
        () => stricter.verifySignature(
          message: message,
          signature: signWith(message),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains(
            'The number of signatures does not match the number of required '
            'signatures',
          ),
        )),
      );
    });

    test('returns false when a sub-signature does not match the message', () {
      expect(
        multiKey.verifySignature(
          message: '0badc0de00',
          signature: signWith(message),
        ),
        isFalse,
      );
    });

    test('verifies a valid signature asynchronously', () async {
      final ok = await multiKey.verifySignatureAsync(
        message: message,
        signature: signWith(message),
      );
      expect(ok, isTrue);
    });

    test(
        'verifySignatureAsync returns false for a non-MultiKeySignature '
        '(and rethrows with throwErrorWithReason)', () async {
      final wrongSignature = Ed25519Signature(Uint8List(64));

      final ok = await multiKey.verifySignatureAsync(
        message: message,
        signature: wrongSignature,
      );
      expect(ok, isFalse);

      await expectLater(
        multiKey.verifySignatureAsync(
          message: message,
          signature: wrongSignature,
          options: const VerifySignatureAsyncOptions(throwErrorWithReason: true),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Signature is not a MultiKeySignature'),
        )),
      );
    });
  });

  group('MultiKeySignature', () {
    test('normalizes raw signatures to AnySignature', () {
      final sig = MultiKeySignature(
        signatures: [Ed25519Signature(Uint8List(64))],
        bitmap: [0],
      );
      expect(sig.signatures.single, isA<AnySignature>());
      expect(sig.bitmap, equals(Uint8List.fromList([128, 0, 0, 0])));
    });

    test('roundtrips through BCS', () {
      final original = MultiKeySignature(
        signatures: [
          Ed25519Signature(Uint8List.fromList(List.filled(64, 7))),
          Ed25519Signature(Uint8List.fromList(List.filled(64, 9))),
        ],
        bitmap: [0, 2],
      );
      final back =
          MultiKeySignature.deserialize(Deserializer(original.bcsToBytes()));
      expect(back.bcsToBytes(), equals(original.bcsToBytes()));
      expect(back.bitmap, equals(original.bitmap));
    });

    test('bitMapToSignerIndices converts the bitmap to signer indices', () {
      final sig = MultiKeySignature(
        signatures: [
          Ed25519Signature(Uint8List(64)),
          Ed25519Signature(Uint8List(64)),
          Ed25519Signature(Uint8List(64)),
        ],
        bitmap: Uint8List.fromList([0x88, 0x40, 0x00, 0x00]),
      );
      expect(sig.bitMapToSignerIndices(), equals([0, 4, 9]));
    });

    test('throws when the bitmap does not match the number of signatures', () {
      expect(
        () => MultiKeySignature(
          signatures: [Ed25519Signature(Uint8List(64))],
          bitmap: [0, 1],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Expecting 2 signatures from the bitmap, but got 1'),
        )),
      );
    });

    test('throws for a bitmap with the wrong byte length', () {
      expect(
        () => MultiKeySignature(
          signatures: [Ed25519Signature(Uint8List(64))],
          bitmap: Uint8List(3),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"bitmap" length should be 4'),
        )),
      );
    });

    test('throws for more than the maximum supported signatures', () {
      final signatures =
          List.generate(33, (_) => Ed25519Signature(Uint8List(64)));
      expect(
        () => MultiKeySignature(signatures: signatures, bitmap: [0]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('cannot be greater than'),
        )),
      );
    });

    test('createBitmap rejects positions of 32 and above', () {
      expect(
        () => MultiKeySignature.createBitmap(bits: [32]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Cannot have a signature larger than 31.'),
        )),
      );
    });

    test('createBitmap rejects duplicate positions', () {
      expect(
        () => MultiKeySignature.createBitmap(bits: [1, 1]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Duplicate bits detected.'),
        )),
      );
    });
  });
}
