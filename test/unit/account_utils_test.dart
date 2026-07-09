import 'dart:typed_data';

import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/account/account_utils.dart';
import 'package:aptos/src/account/ed25519_account.dart';
import 'package:aptos/src/account/ephemeral_key_pair.dart';
import 'package:aptos/src/account/federated_keyless_account.dart';
import 'package:aptos/src/account/keyless_account.dart';
import 'package:aptos/src/account/multi_key_account.dart';
import 'package:aptos/src/account/single_key_account.dart';
import 'package:aptos/src/account/utils.dart';
import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/keyless.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

// Known-answer serialization fixtures.

final proof = ZeroKnowledgeSig(
  proof: ZkProof(
    Groth16Zkp(a: Uint8List(32), b: Uint8List(64), c: Uint8List(32)),
    ZkpVariant.groth16,
  ),
  expHorizonSecs: 0,
);

final verificationKey = Groth16VerificationKey(
  alphaG1: Uint8List(32),
  betaG2: Uint8List(64),
  deltaG2: Uint8List(64),
  gammaAbcG1: [Uint8List(32), Uint8List(32)],
  gammaG2: Uint8List(64),
);

const jwt =
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ0ZXN0IiwiYXVkIjoidGVzdC1hdWQiLCJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNzMxMjE0NTIxLCJleHAiOjE3MzEyMTgxMjF9.jZeCpYDDWx0pW_WcBpg8b0NzDWCABvH3lSmmmub8BBg';

void testAccountSerializationDeserialization(Account account) {
  final bytes = AccountUtils.toBytes(account);
  final deserializedAccount = AccountUtils.fromBytes(bytes);
  expect(AccountUtils.toBytes(deserializedAccount), bytes);
}

void main() {
  final legacyEdAccount = Account.generate();
  final singleSignerEdAccount = Account.generate(
    scheme: SigningSchemeInput.ed25519,
    legacy: false,
  );
  final secp256k1Account = Account.generate(
    scheme: SigningSchemeInput.secp256k1Ecdsa,
  );
  final keylessAccount = KeylessAccount.create(
    proof: proof,
    ephemeralKeyPair: EphemeralKeyPair.generate(),
    pepper: Uint8List(31),
    jwt: jwt,
  );
  final keylessAccountWithVerificationKey = KeylessAccount.create(
    proof: proof,
    ephemeralKeyPair: EphemeralKeyPair.generate(),
    pepper: Uint8List(31),
    jwt: jwt,
    verificationKey: verificationKey,
  );
  final federatedKeylessAccount = FederatedKeylessAccount.create(
    ephemeralKeyPair: EphemeralKeyPair.generate(),
    pepper: Uint8List(31),
    jwt: jwt,
    jwkAddress: Account.generate().accountAddress,
    proof: proof,
  );
  final multiKeyAccount = MultiKeyAccount.fromPublicKeysAndSigners(
    publicKeys: [
      singleSignerEdAccount.publicKey,
      secp256k1Account.publicKey,
      Account.generate(legacy: false).publicKey,
    ],
    signaturesRequired: 2,
    signers: [singleSignerEdAccount, secp256k1Account],
  );
  final keylessAccountWithBackupSigner =
      MultiKeyAccount.fromPublicKeysAndSigners(
    publicKeys: [
      keylessAccount.publicKey,
      Account.generate(legacy: false).publicKey,
    ],
    signaturesRequired: 1,
    signers: [keylessAccount],
  );

  group('Account Serialization', () {
    test('legacy Ed25519 Account should serialize and deserialize properly',
        () {
      testAccountSerializationDeserialization(legacyEdAccount);
      final accountAsHex = AccountUtils.toHexString(legacyEdAccount);
      final restored = AccountUtils.ed25519AccountFromHex(accountAsHex);
      expect(restored, isA<Ed25519Account>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(legacyEdAccount),
      );
      expect(
        restored.accountAddress.toString(),
        legacyEdAccount.accountAddress.toString(),
      );
    });

    test('SingleKey Ed25519 Account should serialize and deserialize '
        'properly', () {
      testAccountSerializationDeserialization(singleSignerEdAccount);
      final accountAsHex = AccountUtils.toHexString(singleSignerEdAccount);
      final restored = AccountUtils.singleKeyAccountFromHex(accountAsHex);
      expect(restored, isA<SingleKeyAccount>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(singleSignerEdAccount),
      );
    });

    test('SingleKey Secp256k1 Account should serialize and deserialize '
        'properly', () {
      testAccountSerializationDeserialization(secp256k1Account);
      final accountAsHex = AccountUtils.toHexString(secp256k1Account);
      final restored = AccountUtils.singleKeyAccountFromHex(accountAsHex);
      expect(restored, isA<SingleKeyAccount>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(secp256k1Account),
      );
    });

    test('Keyless Account should serialize and deserialize properly', () {
      testAccountSerializationDeserialization(keylessAccount);
      final accountAsHex = AccountUtils.toHexString(keylessAccount);
      final restored = AccountUtils.keylessAccountFromHex(accountAsHex);
      expect(restored, isA<KeylessAccount>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(keylessAccount),
      );
      expect(restored.jwt, keylessAccount.jwt);
      expect(restored.uidKey, keylessAccount.uidKey);
      expect(restored.pepper, keylessAccount.pepper);
      expect(restored.verificationKeyHash, isNull);
      expect(
        restored.accountAddress.toString(),
        keylessAccount.accountAddress.toString(),
      );
    });

    test('Keyless Account with verification key should serialize and '
        'deserialize properly', () {
      testAccountSerializationDeserialization(
        keylessAccountWithVerificationKey,
      );
      final accountAsHex =
          AccountUtils.toHexString(keylessAccountWithVerificationKey);
      final restored = AccountUtils.keylessAccountFromHex(accountAsHex);
      expect(restored.verificationKeyHash, verificationKey.hash());
    });

    test('FederatedKeyless Account should serialize and deserialize '
        'properly', () {
      testAccountSerializationDeserialization(federatedKeylessAccount);
      final accountAsHex = AccountUtils.toHexString(federatedKeylessAccount);
      final restored =
          AccountUtils.federatedKeylessAccountFromHex(accountAsHex);
      expect(restored, isA<FederatedKeylessAccount>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(federatedKeylessAccount),
      );
      expect(
        restored.publicKey.jwkAddress.toString(),
        federatedKeylessAccount.publicKey.jwkAddress.toString(),
      );
      expect(restored.audless, false);
    });

    test('MultiKey Account should serialize and deserialize properly', () {
      testAccountSerializationDeserialization(multiKeyAccount);
      final accountAsHex = AccountUtils.toHexString(multiKeyAccount);
      final restored = AccountUtils.multiKeyAccountFromHex(accountAsHex);
      expect(restored, isA<MultiKeyAccount>());
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(multiKeyAccount),
      );
      expect(restored.signers.length, 2);
      expect(restored.signerIndicies, multiKeyAccount.signerIndicies);
    });

    test('MultiKey Account with backup signer should serialize and '
        'deserialize properly', () {
      testAccountSerializationDeserialization(keylessAccountWithBackupSigner);
      final accountAsHex =
          AccountUtils.toHexString(keylessAccountWithBackupSigner);
      final restored = AccountUtils.multiKeyAccountFromHex(accountAsHex);
      expect(
        AccountUtils.toBytes(restored),
        AccountUtils.toBytes(keylessAccountWithBackupSigner),
      );
      expect(restored.signers.single, isA<KeylessAccount>());
    });
  });

  group('AccountUtils.toHexStringWithoutPrefix', () {
    test('returns the serialized account hex without a 0x prefix', () {
      final withPrefix = AccountUtils.toHexString(legacyEdAccount);
      final withoutPrefix =
          AccountUtils.toHexStringWithoutPrefix(legacyEdAccount);
      expect(withPrefix.startsWith('0x'), true);
      expect(withoutPrefix.startsWith('0x'), false);
      expect(withPrefix, '0x$withoutPrefix');
    });
  });

  group('AccountUtils typed-fromHex guards', () {
    test('ed25519AccountFromHex rejects a non-Ed25519 account', () {
      final hex = AccountUtils.toHexString(secp256k1Account);
      expect(
        () => AccountUtils.ed25519AccountFromHex(hex),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Deserialization of Ed25519Account failed'),
        )),
      );
    });

    test('singleKeyAccountFromHex rejects a legacy Ed25519 account', () {
      final hex = AccountUtils.toHexString(legacyEdAccount);
      expect(
        () => AccountUtils.singleKeyAccountFromHex(hex),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Deserialization of SingleKeyAccount failed'),
        )),
      );
    });

    test('keylessAccountFromHex rejects a SingleKey Ed25519 account', () {
      final hex = AccountUtils.toHexString(singleSignerEdAccount);
      expect(
        () => AccountUtils.keylessAccountFromHex(hex),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Deserialization of KeylessAccount failed'),
        )),
      );
    });

    test('federatedKeylessAccountFromHex rejects a Secp256k1 account', () {
      final hex = AccountUtils.toHexString(secp256k1Account);
      expect(
        () => AccountUtils.federatedKeylessAccountFromHex(hex),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Deserialization of FederatedKeylessAccount failed'),
        )),
      );
    });

    test('multiKeyAccountFromHex rejects a single-signer account', () {
      final hex = AccountUtils.toHexString(legacyEdAccount);
      expect(
        () => AccountUtils.multiKeyAccountFromHex(hex),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Deserialization of MultiKeyAccount failed'),
        )),
      );
    });

    test('fromBytes round-trips the same way as fromHex', () {
      final bytes = AccountUtils.toBytes(secp256k1Account);
      final fromBytes = AccountUtils.fromBytes(bytes);
      expect(AccountUtils.toBytes(fromBytes), bytes);
    });

    test('deserialize rejects an invalid signing scheme variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => deserializeSchemeAndAddress(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SigningScheme variant 99 is invalid'),
        )),
      );
    });
  });
}
