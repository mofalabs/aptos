import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/authentication_key.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const ed25519TestObject = (
  publicKey: '0xde19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c',
  authKey: '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa',
);

void main() {
  group('AuthenticationKey', () {
    test('should create an instance with save the HexInput correctly', () {
      final authKey = AuthenticationKey(data: ed25519TestObject.authKey);
      expect(authKey.data.toString(), equals(ed25519TestObject.authKey));
    });

    test('should throw an error with invalid hex input length', () {
      const invalidHexInput = '0123456789abcdef'; // Invalid length
      expect(
        () => AuthenticationKey(data: invalidHexInput),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Authentication Key length should be 32'),
        )),
      );
    });

    test('should create AuthenticationKey from Ed25519PublicKey', () {
      final publicKey = Ed25519PublicKey(ed25519TestObject.publicKey);
      final authKey = publicKey.authKey();
      expect(authKey.data.toString(), equals(ed25519TestObject.authKey));
    });

    // TODO: "should create AuthenticationKey from MultiPublicKey" is
    // wired in the multi_ed25519 task.

    test('should derive an AccountAddress from AuthenticationKey with same string',
        () {
      final authKey = AuthenticationKey(data: ed25519TestObject.authKey);
      final accountAddress = authKey.derivedAddress();
      expect(accountAddress.toString(), equals(ed25519TestObject.authKey));
    });

    test('should serialize correctly', () {
      final authKey = AuthenticationKey(data: ed25519TestObject.authKey);
      final serializer = Serializer();
      authKey.serialize(serializer);
      final expected = Uint8List.fromList([
        32, 151, 140, 33, 57, 144, 196, 131, 61, 247, 21, 72, 223, 124, //
        228, 157, 84, 199, 89, 214, 182, 217, 50, 222, 34, 178, 77, 86, 6, //
        11, 122, 242, 170,
      ]);
      expect(serializer.toUint8List(), equals(expected));
    });

    test('should deserialize correctly', () {
      final serializedAuthKey = Uint8List.fromList([
        32, 151, 140, 33, 57, 144, 196, 131, 61, 247, 21, 72, 223, 124, //
        228, 157, 84, 199, 89, 214, 182, 217, 50, 222, 34, 178, 77, 86, 6, //
        11, 122, 242, 170,
      ]);
      final deserializer = Deserializer(serializedAuthKey);
      final authKeyDeserialized = AuthenticationKey.deserialize(deserializer);
      expect(authKeyDeserialized.data.toString(),
          equals(ed25519TestObject.authKey));
    });
  });
}
