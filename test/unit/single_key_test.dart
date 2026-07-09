import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/public_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/crypto/secp256r1.dart';
import 'package:aptos/src/core/crypto/signature.dart';
import 'package:aptos/src/core/crypto/single_key.dart';
import 'package:aptos/src/core/crypto/utils.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const singleSignerED25519 = (
  publicKey:
      '0xe425451a5dc888ac871976c3c724dec6118910e7d11d344b4b07a22cd94e8c2e',
  privateKey:
      'ed25519-priv-0xf508cbef4e0fe463204aab724a90791c9a9dbe60a53b4978bbddbc712b55f2fd',
  authKey: '0x5bdf77d5bf826c8c04273d4e7323f7bc4a85ee7ee34b37bd7458b7aed3639dd3',
);

const secp256k1TestObject = (
  publicKey:
      '0x04acdd16651b839c24665b7e2033b55225f384554949fef46c397b5275f37f6ee95554d70fb5d9f93c5831ebf695c7206e7477ce708f03ae9bb2862dc6c9e033ea',
  authKey: '0x5792c985bc96f436270bd2a3c692210b09c7febb8889345ceefdbae4bacfe498',
);

const singleSignerSecp256r1 = (
  publicKey:
      '0x046c761075b12769e9d0cc9995706275352e1bfb8e0085420625aa9cf849e6d62c2c140f0b3b7c53faf78c16648343966d769ccbc8f2fd14bb2c38f6befb91c77b',
  authKey: '0x9a5f9a9614e34f77295791db551e7072ff48d9801b19be97b38db1c05dfde817',
);

/// An inner public key type that no registry detector recognizes.
class _FakePublicKey extends PublicKey {
  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
  }) =>
      false;

  @override
  void serialize(Serializer serializer) {}
}

/// An inner signature type that no registry detector recognizes.
class _FakeSignature extends Signature {
  @override
  void serialize(Serializer serializer) {}
}

void main() {
  final edPriv =
      Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 3)), false);
  final edPub = edPriv.publicKey();
  final secpPub =
      Secp256k1PrivateKey(Uint8List.fromList(List.filled(32, 5)), false)
          .publicKey();

  group('AnyPublicKey constructor', () {
    test('picks the Ed25519 variant for an Ed25519 inner key', () {
      final pk = AnyPublicKey(edPub);
      expect(pk.variant, equals(AnyPublicKeyVariant.ed25519));
    });

    test('picks the Secp256k1 variant for a Secp256k1 inner key', () {
      final pk = AnyPublicKey(secpPub);
      expect(pk.variant, equals(AnyPublicKeyVariant.secp256k1));
    });

    test('picks the Secp256r1 variant for a Secp256r1 inner key', () {
      final pk =
          AnyPublicKey(Secp256r1PublicKey(singleSignerSecp256r1.publicKey));
      expect(pk.variant, equals(AnyPublicKeyVariant.secp256r1));
    });

    test('honors an explicit variant override', () {
      // Even though the inner key is Ed25519, the explicit variant wins.
      final pk = AnyPublicKey(edPub, AnyPublicKeyVariant.secp256k1);
      expect(pk.variant, equals(AnyPublicKeyVariant.secp256k1));
    });

    test('rejects an unsupported inner public key type', () {
      expect(
        () => AnyPublicKey(_FakePublicKey()),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported public key type'),
        )),
      );
    });
  });

  group('AnyPublicKey BCS', () {
    test('serializes to the variant-indexed BCS layout (byte exact)', () {
      final pk = AnyPublicKey(Ed25519PublicKey(singleSignerED25519.publicKey));
      // uleb128(variant=0) + bytes(len=32, inner key).
      expect(
        pk.toString(),
        equals(
          '0x0020${singleSignerED25519.publicKey.substring(2)}',
        ),
      );
    });

    test('roundtrips an Ed25519-variant AnyPublicKey', () {
      final original = AnyPublicKey(edPub);
      final serializer = Serializer();
      original.serialize(serializer);
      final back =
          AnyPublicKey.deserialize(Deserializer(serializer.toUint8List()));
      expect(back.variant, equals(AnyPublicKeyVariant.ed25519));
      expect(back.publicKey.toUint8Array(), equals(edPub.toUint8Array()));
    });

    test('roundtrips a Secp256k1-variant AnyPublicKey', () {
      final original = AnyPublicKey(secpPub);
      final serializer = Serializer();
      original.serialize(serializer);
      final back =
          AnyPublicKey.deserialize(Deserializer(serializer.toUint8List()));
      expect(back.variant, equals(AnyPublicKeyVariant.secp256k1));
      expect(back.publicKey.toUint8Array(), equals(secpPub.toUint8Array()));
    });

    test('roundtrips a Secp256r1-variant AnyPublicKey', () {
      final original =
          AnyPublicKey(Secp256r1PublicKey(singleSignerSecp256r1.publicKey));
      final serializer = Serializer();
      original.serialize(serializer);
      final back =
          AnyPublicKey.deserialize(Deserializer(serializer.toUint8List()));
      expect(back.variant, equals(AnyPublicKeyVariant.secp256r1));
      expect(back.bcsToBytes(), equals(original.bcsToBytes()));
    });

    test('throws a descriptive error for an unknown variant index', () {
      // 99 is not a registered AnyPublicKeyVariant.
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => AnyPublicKey.deserialize(Deserializer(serializer.toUint8List())),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for AnyPublicKey'),
        )),
      );
    });
  });

  group('AnyPublicKey static checks', () {
    test('isInstance returns true for an AnyPublicKey', () {
      expect(AnyPublicKey.isInstance(AnyPublicKey(edPub)), isTrue);
    });

    test('isInstance returns false for a bare Ed25519PublicKey', () {
      expect(AnyPublicKey.isInstance(edPub), isFalse);
    });

    test('isEd25519 / isSecp256k1PublicKey reflect the inner key type', () {
      final edAny = AnyPublicKey(edPub);
      final secpAny = AnyPublicKey(secpPub);
      expect(edAny.isEd25519(), isTrue);
      expect(edAny.isSecp256k1PublicKey(), isFalse);
      expect(secpAny.isEd25519(), isFalse);
      expect(secpAny.isSecp256k1PublicKey(), isTrue);
    });

    test('toUint8Array returns the BCS-encoded bytes', () {
      final pk = AnyPublicKey(edPub);
      expect(pk.toUint8Array(), equals(pk.bcsToBytes()));
    });
  });

  group('AnyPublicKey.authKey', () {
    test('derives the SingleKey auth key for an Ed25519 inner key', () {
      final pk = AnyPublicKey(Ed25519PublicKey(singleSignerED25519.publicKey));
      expect(pk.authKey().data.toString(), equals(singleSignerED25519.authKey));
    });

    test('derives the SingleKey auth key for a Secp256k1 inner key', () {
      final pk =
          AnyPublicKey(Secp256k1PublicKey(secp256k1TestObject.publicKey));
      expect(pk.authKey().data.toString(), equals(secp256k1TestObject.authKey));
    });

    test('derives the SingleKey auth key for a Secp256r1 inner key', () {
      final pk =
          AnyPublicKey(Secp256r1PublicKey(singleSignerSecp256r1.publicKey));
      expect(
        pk.authKey().data.toString(),
        equals(singleSignerSecp256r1.authKey),
      );
    });
  });

  group('AnyPublicKey.verifySignature', () {
    test('verifies a real Ed25519 signature via the inner key', () {
      const message = '0xfeedface';
      final sig = edPriv.sign(message);
      final pk = AnyPublicKey(edPub);
      expect(
        pk.verifySignature(message: message, signature: AnySignature(sig)),
        isTrue,
      );
    });

    test('returns false when the signature does not match the message', () {
      final sig = edPriv.sign('0xfeedface');
      final pk = AnyPublicKey(edPub);
      expect(
        pk.verifySignature(
          message: '0xdeadbeef',
          signature: AnySignature(sig),
        ),
        isFalse,
      );
    });
  });

  group('AnyPublicKey.verifySignatureAsync', () {
    test(
        'returns false when the signature is not an AnySignature (silent default)',
        () async {
      final pk = AnyPublicKey(edPub);
      // Pass a non-AnySignature; the function returns false without throwing.
      final rawSig = Ed25519Signature(Uint8List(64));
      final ok = await pk.verifySignatureAsync(
        message: '0xfeedface',
        signature: rawSig,
      );
      expect(ok, isFalse);
    });

    test(
        'throws with throwErrorWithReason when the signature is not an AnySignature',
        () async {
      final pk = AnyPublicKey(edPub);
      final rawSig = Ed25519Signature(Uint8List(64));
      await expectLater(
        pk.verifySignatureAsync(
          message: '0xfeedface',
          signature: rawSig,
          options:
              const VerifySignatureAsyncOptions(throwErrorWithReason: true),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Signature must be an instance of AnySignature'),
        )),
      );
    });
  });

  group('AnySignature constructor', () {
    test('infers the Ed25519 variant from an Ed25519Signature', () {
      final sig = AnySignature(Ed25519Signature(Uint8List(64)));
      // Serializing exposes the variant via the ULEB128 prefix.
      final serializer = Serializer();
      sig.serialize(serializer);
      expect(serializer.toUint8List()[0], equals(0)); // ed25519 = 0
    });

    test('infers the Secp256k1 variant from a Secp256k1Signature', () {
      final sig = AnySignature(Secp256k1Signature(Uint8List(64)));
      final serializer = Serializer();
      sig.serialize(serializer);
      expect(serializer.toUint8List()[0], equals(1)); // secp256k1 = 1
    });

    test('infers the WebAuthn variant from a WebAuthnSignature', () {
      final sig = AnySignature(WebAuthnSignature(
        signature: Uint8List(64),
        authenticatorData: Uint8List(0),
        clientDataJSON: Uint8List(0),
      ));
      final serializer = Serializer();
      sig.serialize(serializer);
      expect(serializer.toUint8List()[0], equals(2)); // webAuthn = 2
    });

    test('rejects an unsupported inner signature type', () {
      expect(
        () => AnySignature(_FakeSignature()),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported signature type'),
        )),
      );
    });
  });

  group('AnySignature BCS', () {
    test('roundtrips an Ed25519-variant AnySignature', () {
      const message = '0xfeedface';
      final original = AnySignature(edPriv.sign(message));
      final back =
          AnySignature.deserialize(Deserializer(original.bcsToBytes()));
      expect(back.bcsToBytes(), equals(original.bcsToBytes()));
      expect(back.signature, isA<Ed25519Signature>());
    });

    test('throws for an unknown variant index', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => AnySignature.deserialize(Deserializer(serializer.toUint8List())),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for AnySignature'),
        )),
      );
    });
  });

  group('AnySignature statics', () {
    test('isInstance returns true for an AnySignature', () {
      expect(
        AnySignature.isInstance(AnySignature(Ed25519Signature(Uint8List(64)))),
        isTrue,
      );
    });

    test('isInstance returns false for a bare signature', () {
      expect(AnySignature.isInstance(Ed25519Signature(Uint8List(64))), isFalse);
    });

    test('toUint8Array returns the BCS bytes', () {
      final sig = AnySignature(
          Ed25519Signature(Uint8List.fromList(List.filled(64, 7))));
      expect(sig.toUint8Array(), equals(sig.bcsToBytes()));
    });
  });

  group('accountPublicKeyToBaseAccountPublicKey / signing scheme', () {
    test('passes base public key types through unchanged', () {
      final ed = Ed25519PublicKey(singleSignerED25519.publicKey);
      final any = AnyPublicKey(ed);
      expect(accountPublicKeyToBaseAccountPublicKey(ed), same(ed));
      expect(accountPublicKeyToBaseAccountPublicKey(any), same(any));
    });

    test('maps base public key types to their signing schemes', () {
      final ed = Ed25519PublicKey(singleSignerED25519.publicKey);
      expect(
          accountPublicKeyToSigningScheme(ed), equals(SigningScheme.ed25519));
      expect(
        accountPublicKeyToSigningScheme(AnyPublicKey(ed)),
        equals(SigningScheme.singleKey),
      );
    });
  });
}
