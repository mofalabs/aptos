import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/src/account/ephemeral_key_pair.dart';
import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/ephemeral.dart';
import 'package:aptos/src/utils/helpers.dart';
import 'package:test/test.dart';

// Known-answer test fixtures.
final ed25519PrivateKey = Ed25519PrivateKey(
  'ed25519-priv-0x1111111111111111111111111111111111111111111111111111111111111111',
);

/// The fixture JWT used with the EPHEMERAL_KEY_PAIR fixture; its `nonce`
/// claim was derived from the ephemeral key pair below.
const keylessFixtureJwt =
    'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3QtcnNhIn0.eyJpc3MiOiJ0ZXN0Lm9pZGMucHJvdmlkZXIiLCJhdWQiOiJ0ZXN0LWtleWxlc3MtZGFwcCIsInN1YiI6InRlc3QtdXNlci0wIiwiZW1haWwiOiJ0ZXN0QGFwdG9zbGFicy5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaWF0Ijo5ODc2NTQzMjA5LCJleHAiOjk4NzY1NDMyMTAsIm5vbmNlIjoiMTk2NDM2OTg4NjEyNjU1Njc4MDQ5MDk5MTMxMzA1MDcyNDc4MTQ1MjY5MTM1NzAyMjgzMTY0MTczNzc5NjUxMDU2ODE3OTYxNzMwOTgifQ.C6QG9WyEIAqYEiLkY8-5yqTKYtCzmnu2RM4P7iqr17toRXhL2ZqCiQYgE2TpY60RlOqBI7_aiHOlxJRvF_iQghEQQSWkgWhkcjVkSvBJW0IHm0IrSRl9ZytQHi6x0vPa8bUff5L--9JfxMiH27wOTrGtTA1n8Fz3G8JKQfYNQF2VawzytJu3lywduRj6pZw9-FFTgPqPsZWQvwhiX75Tgud976CpDusKOrPAM3rA9fXgKo_aTKeOPiEIm11ezI1bsOJ3B4JhsxLT5vszZ11Ywytst8XXwqWHjnulkJWjM9QfVUJhsO-jEQ5T_dYDqMVnnkdzjJyMRbvgbyNPUkvx8Q';

EphemeralKeyPair makeFreshKeyPair({Ed25519PrivateKey? privateKey}) {
  return EphemeralKeyPair(
    privateKey: privateKey ?? ed25519PrivateKey,
    expiryDateSecs: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  );
}

void main() {
  group('EphemeralKeyPair', () {
    test(
        'derives a stable nonce from privateKey + expiryDateSecs + blinder',
        () {
      final blinder = Uint8List(31)..fillRange(0, 31, 0x22);
      final a = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1000000000,
        blinder: blinder,
      );
      final b = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1000000000,
        blinder: blinder,
      );
      expect(a.nonce, b.nonce);
      expect(a.nonce.length, greaterThan(0));
    });

    test('nonce matches the known-answer fixture (EPHEMERAL_KEY_PAIR)',
        () {
      // EPHEMERAL_KEY_PAIR fixture: expiry 9876543210,
      // blinder of 31 zero bytes.
      final keyPair = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 9876543210,
        blinder: Uint8List(31),
      );
      // The nonce embedded in the fixture JWT was computed from this key
      // pair, so the nonce claim must match the derived nonce.
      final payload = jsonDecode(
        base64UrlDecode(keylessFixtureJwt.split('.')[1]),
      ) as Map<String, dynamic>;
      expect(keyPair.nonce, payload['nonce']);
    });

    test('generates a random blinder when none is provided', () {
      final a = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1000000000,
      );
      final b = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1000000000,
      );
      expect(a.blinder.length, EphemeralKeyPair.blinderLength);
      expect(a.blinder, isNot(equals(b.blinder)));
      expect(a.nonce, isNot(equals(b.nonce)));
    });

    test(
        'defaults expiryDateSecs to two weeks in the future at the hour '
        'boundary', () {
      final keyPair = EphemeralKeyPair(privateKey: ed25519PrivateKey);
      const twoWeeksInSeconds = 1209600;
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(keyPair.expiryDateSecs, greaterThan(nowSecs));
      expect(
        keyPair.expiryDateSecs - nowSecs,
        lessThanOrEqualTo(twoWeeksInSeconds),
      );
      expect(
        keyPair.expiryDateSecs - nowSecs,
        greaterThan(twoWeeksInSeconds - 3600),
      );
      // Floored to a whole hour.
      expect(keyPair.expiryDateSecs % 3600, 0);
    });

    test('returns the EphemeralPublicKey', () {
      final keyPair = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1000000000,
      );
      expect(keyPair.getPublicKey(), isA<EphemeralPublicKey>());
    });

    test('isExpired returns true when expiryDateSecs is in the past', () {
      final keyPair = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1,
      );
      expect(keyPair.isExpired(), true);
    });

    test('isExpired returns false when expiryDateSecs is in the future', () {
      expect(makeFreshKeyPair().isExpired(), false);
    });

    test('sign produces a verifiable EphemeralSignature on a fresh key pair',
        () {
      final keyPair = makeFreshKeyPair();
      const message = '0xcafebabe';
      final signature = keyPair.sign(message);
      expect(signature, isA<EphemeralSignature>());
      expect(
        keyPair
            .getPublicKey()
            .verifySignature(message: message, signature: signature),
        true,
      );
    });

    test('sign throws when the key pair has expired', () {
      final keyPair = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1,
      );
      expect(
        () => keyPair.sign('0x00'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('expired'),
        )),
      );
    });

    test('clear() zeroizes the blinder and disables signing', () {
      final keyPair = EphemeralKeyPair(
        privateKey: Ed25519PrivateKey(
          Uint8List(32)..fillRange(0, 32, 0x33),
        ),
        expiryDateSecs: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        blinder: Uint8List(31)..fillRange(0, 31, 0x44),
      );
      expect(keyPair.isCleared(), false);
      keyPair.clear();
      expect(keyPair.isCleared(), true);
      // Blinder is overwritten to zero in the final pass.
      expect(keyPair.blinder, List<int>.filled(31, 0));
      // sign() must throw after clear, even before the expiry check.
      expect(
        () => keyPair.sign('0x00'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('cleared from memory'),
        )),
      );
    });

    test('clear() is idempotent', () {
      final keyPair = makeFreshKeyPair(
        privateKey: Ed25519PrivateKey(
          Uint8List(32)..fillRange(0, 32, 0x55),
        ),
      );
      keyPair.clear();
      // Second call must not throw.
      expect(keyPair.clear, returnsNormally);
      expect(keyPair.isCleared(), true);
    });

    test('BCS serialize/deserialize round-trips the key pair', () {
      final original = EphemeralKeyPair(
        privateKey: ed25519PrivateKey,
        expiryDateSecs: 1700000000,
        blinder: Uint8List(31)..fillRange(0, 31, 0x77),
      );
      final bytes = original.bcsToBytes();
      final back = EphemeralKeyPair.fromBytes(bytes);
      expect(back.expiryDateSecs, original.expiryDateSecs);
      expect(back.blinder, original.blinder);
      expect(back.nonce, original.nonce);
      expect(back.bcsToBytes(), bytes);
    });

    test('deserialize rejects an unknown variant index', () {
      // Manually craft a buffer: ULEB128(99). Anything after is irrelevant
      // since the switch throws before reading more.
      final deserializer = Deserializer(Uint8List.fromList([99]));
      expect(
        () => EphemeralKeyPair.deserialize(deserializer),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for EphemeralPublicKey'),
        )),
      );
    });

    test('generate() produces a new Ed25519-backed key pair', () {
      final a = EphemeralKeyPair.generate();
      final b = EphemeralKeyPair.generate();
      expect(a.getPublicKey(), isA<EphemeralPublicKey>());
      // Two independently generated keys must differ (with overwhelming
      // probability).
      expect(a.bcsToBytes(), isNot(equals(b.bcsToBytes())));
    });
  });
}
