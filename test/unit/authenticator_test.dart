// BCS round-trip tests for transactions/authenticator/{account,transaction}
// and instances/signed_transaction.
//
// Each variant: serialize → deserialize via the abstract base class dispatch
// → assert field-by-field equality and that the returned subclass matches,
// plus byte-exact variant index assertions and the default-branch error for
// unknown variant indices.

import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/account_address.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/multi_ed25519.dart';
import 'package:aptos/src/core/crypto/multi_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/crypto/single_key.dart';
import 'package:aptos/src/transactions/authenticator/account.dart';
import 'package:aptos/src/transactions/authenticator/transaction.dart';
import 'package:aptos/src/transactions/instances/chain_id.dart';
import 'package:aptos/src/transactions/instances/identifier.dart';
import 'package:aptos/src/transactions/instances/module_id.dart';
import 'package:aptos/src/transactions/instances/raw_transaction.dart';
import 'package:aptos/src/transactions/instances/signed_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:test/test.dart';

Uint8List serializeToBytes(Serializable value) {
  final serializer = Serializer();
  value.serialize(serializer);
  return serializer.toUint8List();
}

/// Serializes [value] and deserializes the bytes back with [deserialize],
/// asserting the whole buffer is consumed.
T roundTrip<T>(Serializable value, T Function(Deserializer) deserialize) {
  final deserializer = Deserializer(serializeToBytes(value));
  final result = deserialize(deserializer);
  deserializer.assertFinished();
  return result;
}

/// Deterministic Ed25519 key pair and signature from a fixed seed so
/// failures reproduce.
final Ed25519PrivateKey ed25519Sk =
    Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 0x42)), false);
final Ed25519PublicKey ed25519Pk = ed25519Sk.publicKey();
final Ed25519Signature ed25519Sig =
    ed25519Sk.sign(Uint8List.fromList([1, 2, 3]));

AccountAuthenticatorEd25519 makeEd25519AccountAuthenticator() =>
    AccountAuthenticatorEd25519(ed25519Pk, ed25519Sig);

Ed25519PrivateKey deterministicKey(int fill) =>
    Ed25519PrivateKey(Uint8List.fromList(List.filled(32, fill)), false);

RawTransaction makeRawTransaction() {
  final moduleId = ModuleId(AccountAddress.one, Identifier('coin'));
  final entry = EntryFunction(moduleId, Identifier('transfer'), [], []);
  return RawTransaction(
    AccountAddress.from('0x1'),
    BigInt.one,
    TransactionPayloadEntryFunction(entry),
    BigInt.from(1000),
    BigInt.from(100),
    BigInt.from(999999),
    ChainId(4),
  );
}

void main() {
  group('transactions/authenticator/account — variant round trips', () {
    test(
        'Ed25519 variant: round-trip via AccountAuthenticator.deserialize '
        'returns same subclass + fields', () {
      final original = makeEd25519AccountAuthenticator();

      final bytes = serializeToBytes(original);
      final restored = AccountAuthenticator.deserialize(Deserializer(bytes));

      expect(restored, isA<AccountAuthenticatorEd25519>());
      expect(restored.isEd25519(), isTrue);
      final r = restored as AccountAuthenticatorEd25519;
      expect(r.publicKey.toUint8Array(), equals(ed25519Pk.toUint8Array()));
      expect(r.signature.toUint8Array(), equals(ed25519Sig.toUint8Array()));
      // The byte stream must start with the variant uleb128 (Ed25519 == 0).
      expect(bytes[0], 0);
    });

    test('MultiEd25519 variant: 1-of-2 round trip', () {
      final k1 = deterministicKey(0x01);
      final k2 = deterministicKey(0x02);
      final publicKey = MultiEd25519PublicKey(
        publicKeys: [k1.publicKey(), k2.publicKey()],
        threshold: 1,
      );
      final signature = MultiEd25519Signature(
        signatures: [
          k1.sign(Uint8List.fromList([1, 2, 3]))
        ],
        bitmap: [0],
      );
      final original = AccountAuthenticatorMultiEd25519(publicKey, signature);

      final bytes = serializeToBytes(original);
      // Variant index 1.
      expect(bytes[0], 1);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorMultiEd25519>());
      expect(restored.isMultiEd25519(), isTrue);
      final r = restored as AccountAuthenticatorMultiEd25519;
      expect(r.publicKey.toUint8Array(), equals(publicKey.toUint8Array()));
      expect(r.signature.toUint8Array(), equals(signature.toUint8Array()));
    });

    test('SingleKey variant: AnyPublicKey + AnySignature round trip', () {
      final sk = deterministicKey(0x11);
      final anyPk = AnyPublicKey(sk.publicKey());
      final anySig = AnySignature(sk.sign(Uint8List.fromList([9])));

      final original = AccountAuthenticatorSingleKey(anyPk, anySig);
      final bytes = serializeToBytes(original);
      // Variant index 2.
      expect(bytes[0], 2);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorSingleKey>());
      expect(restored.isSingleKey(), isTrue);
      final r = restored as AccountAuthenticatorSingleKey;
      expect(serializeToBytes(r.publicKey), equals(serializeToBytes(anyPk)));
      expect(serializeToBytes(r.signature), equals(serializeToBytes(anySig)));
    });

    test('MultiKey variant: 2-of-3 round trip preserves participant indices',
        () {
      final a = deterministicKey(0x0a);
      final b = deterministicKey(0x0b);
      final c = deterministicKey(0x0c);
      final mk = MultiKey(
        publicKeys: [
          AnyPublicKey(a.publicKey()),
          AnyPublicKey(b.publicKey()),
          AnyPublicKey(c.publicKey()),
        ],
        signaturesRequired: 2,
      );
      final message = Uint8List.fromList([1]);
      final mkSig = MultiKeySignature(
        signatures: [
          AnySignature(a.sign(message)),
          AnySignature(b.sign(message)),
        ],
        bitmap: [0, 1],
      );

      final original = AccountAuthenticatorMultiKey(mk, mkSig);
      final bytes = serializeToBytes(original);
      // Variant index 3.
      expect(bytes[0], 3);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorMultiKey>());
      expect(restored.isMultiKey(), isTrue);
      final r = restored as AccountAuthenticatorMultiKey;
      expect(r.publicKeys.publicKeys, hasLength(3));
      expect(r.publicKeys.signaturesRequired, 2);
      expect(r.signatures.signatures, hasLength(2));
      expect(serializeToBytes(restored), equals(bytes));
    });

    test(
        'NoAccountAuthenticator: serializes to a single uleb128 byte '
        '(no payload)', () {
      final original = AccountAuthenticatorNoAccountAuthenticator();
      final bytes = serializeToBytes(original);
      // Variant index 4 — single byte for small ulebs.
      expect(bytes, hasLength(1));
      expect(bytes[0], 4);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorNoAccountAuthenticator>());
    });

    test('AccountAuthenticator.deserialize throws on an unknown variant', () {
      final s = Serializer();
      s.serializeU32AsUleb128(99);
      expect(
        () => AccountAuthenticator.deserialize(Deserializer(s.toUint8List())),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for AccountAuthenticator'),
        )),
      );
    });

    test('type guards return the right boolean for each instance', () {
      final ed = makeEd25519AccountAuthenticator();
      final none = AccountAuthenticatorNoAccountAuthenticator();
      expect(ed.isEd25519(), isTrue);
      expect(ed.isMultiKey(), isFalse);
      expect(ed.isSingleKey(), isFalse);
      expect(ed.isMultiEd25519(), isFalse);
      expect(none.isEd25519(), isFalse);
    });
  });

  group('transactions/authenticator/transaction — variant round trips', () {
    final sponsor = AccountAddress.from('0x9');
    final secondary = AccountAddress.from('0xa');

    test('Ed25519 variant: round-trip via TransactionAuthenticator.deserialize',
        () {
      final original = TransactionAuthenticatorEd25519(ed25519Pk, ed25519Sig);
      final bytes = serializeToBytes(original);
      // Variant index 0.
      expect(bytes[0], 0);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorEd25519>());
      expect(restored.isEd25519(), isTrue);
      final r = restored as TransactionAuthenticatorEd25519;
      expect(r.publicKey.toUint8Array(), equals(ed25519Pk.toUint8Array()));
      expect(r.signature.toUint8Array(), equals(ed25519Sig.toUint8Array()));
    });

    test('MultiEd25519 variant: round trip', () {
      final k1 = deterministicKey(0x01);
      final k2 = deterministicKey(0x02);
      final publicKey = MultiEd25519PublicKey(
        publicKeys: [k1.publicKey(), k2.publicKey()],
        threshold: 1,
      );
      final signature = MultiEd25519Signature(
        signatures: [
          k2.sign(Uint8List.fromList([4, 5, 6]))
        ],
        bitmap: [1],
      );
      final original =
          TransactionAuthenticatorMultiEd25519(publicKey, signature);
      final bytes = serializeToBytes(original);
      // Variant index 1.
      expect(bytes[0], 1);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorMultiEd25519>());
      expect(restored.isMultiEd25519(), isTrue);
      expect(serializeToBytes(restored), equals(bytes));
    });

    test('SingleSender variant: wraps an AccountAuthenticator and round-trips',
        () {
      final inner = makeEd25519AccountAuthenticator();
      final original = TransactionAuthenticatorSingleSender(inner);
      final bytes = serializeToBytes(original);
      // Variant index 4.
      expect(bytes[0], 4);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorSingleSender>());
      final r = restored as TransactionAuthenticatorSingleSender;
      expect(r.sender, isA<AccountAuthenticatorEd25519>());
    });

    test(
        'MultiAgent variant: sender + N secondary signer addresses + N '
        'secondary authenticators', () {
      final inner = makeEd25519AccountAuthenticator();
      final original = TransactionAuthenticatorMultiAgent(
        inner,
        [secondary, sponsor],
        [inner, inner],
      );

      final bytes = serializeToBytes(original);
      // Variant index 2.
      expect(bytes[0], 2);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorMultiAgent>());
      final r = restored as TransactionAuthenticatorMultiAgent;
      expect(
        r.secondarySignerAddresses.map((a) => a.toString()).toList(),
        equals([secondary.toString(), sponsor.toString()]),
      );
      expect(r.secondarySigners, hasLength(2));
      expect(serializeToBytes(restored), equals(bytes));
    });

    test(
        'FeePayer variant: round-trip preserves the feePayer '
        '{address, authenticator}', () {
      final inner = makeEd25519AccountAuthenticator();
      final feePayerAuth = makeEd25519AccountAuthenticator();
      final original = TransactionAuthenticatorFeePayer(
        inner,
        [secondary],
        [inner],
        (address: sponsor, authenticator: feePayerAuth),
      );

      final bytes = serializeToBytes(original);
      // Variant index 3.
      expect(bytes[0], 3);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorFeePayer>());
      final r = restored as TransactionAuthenticatorFeePayer;
      expect(r.feePayer.address.toString(), sponsor.toString());
      expect(r.feePayer.authenticator, isA<AccountAuthenticatorEd25519>());
      expect(serializeToBytes(restored), equals(bytes));
    });

    test('TransactionAuthenticator.deserialize throws on an unknown variant',
        () {
      final s = Serializer();
      s.serializeU32AsUleb128(99);
      expect(
        () => TransactionAuthenticator.deserialize(
          Deserializer(s.toUint8List()),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for TransactionAuthenticator'),
        )),
      );
    });

    test('type guards: each subclass reports its own variant', () {
      final ed = TransactionAuthenticatorEd25519(ed25519Pk, ed25519Sig);
      expect(ed.isEd25519(), isTrue);
      expect(ed.isMultiAgent(), isFalse);
      expect(ed.isFeePayer(), isFalse);
      expect(ed.isSingleSender(), isFalse);
    });

    test('identical inputs produce identical bytes (determinism)', () {
      final a = TransactionAuthenticatorEd25519(ed25519Pk, ed25519Sig);
      final b = TransactionAuthenticatorEd25519(ed25519Pk, ed25519Sig);
      expect(serializeToBytes(a), equals(serializeToBytes(b)));
    });
  });

  group('transactions/authenticator/account — abstraction variant', () {
    const functionInfo = '0x1::account::authenticate';
    final digest = Uint8List.fromList([1, 2, 3, 4]);
    final signature = Uint8List.fromList([9, 9, 9]);

    test('V1 abstraction authenticator round-trips without account identity',
        () {
      final original =
          AccountAuthenticatorAbstraction(functionInfo, digest, signature);
      final bytes = serializeToBytes(original);
      // Variant index 5.
      expect(bytes[0], 5);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorAbstraction>());
      final r = restored as AccountAuthenticatorAbstraction;
      expect(r.functionInfo, functionInfo);
      expect(r.signingMessageDigest.toUint8List(), equals(digest));
      expect(r.abstractionSignature, equals(signature));
      expect(r.accountIdentity, isNull);
      expect(serializeToBytes(restored), equals(bytes));
    });

    test(
        'DerivableV1 abstraction authenticator round-trips with account '
        'identity', () {
      final identity = Uint8List.fromList([7, 7]);
      final original = AccountAuthenticatorAbstraction(
        functionInfo,
        digest,
        signature,
        identity,
      );
      final bytes = serializeToBytes(original);
      expect(bytes[0], 5);

      final restored = roundTrip(original, AccountAuthenticator.deserialize);
      expect(restored, isA<AccountAuthenticatorAbstraction>());
      final r = restored as AccountAuthenticatorAbstraction;
      expect(r.functionInfo, functionInfo);
      expect(r.abstractionSignature, equals(signature));
      expect(r.accountIdentity, equals(identity));
      expect(serializeToBytes(restored), equals(bytes));
    });

    test('rejects invalid function info at construction', () {
      expect(
        () => AccountAuthenticatorAbstraction(
          'not-a-function',
          digest,
          signature,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Invalid function info'),
        )),
      );
    });

    test('AccountAbstractionMessage round-trips', () {
      final original = AccountAbstractionMessage(digest, functionInfo);
      final restored =
          roundTrip(original, AccountAbstractionMessage.deserialize);
      expect(restored.functionInfo, functionInfo);
      expect(restored.originalSigningMessage.toUint8List(), equals(digest));
      // The byte stream must start with the AASigningDataVariant.V1 uleb128.
      expect(serializeToBytes(original)[0], 0);
    });
  });

  group('authenticator cross-cutting: Secp256k1 SingleSender round-trip', () {
    test(
        'SingleSender wrapping a SingleKey AnyPublicKey of Secp256k1 '
        'round-trips', () {
      final sk = Secp256k1PrivateKey(
        Uint8List.fromList(List.filled(32, 0x07)),
        false,
      );
      final pk = sk.publicKey();
      final sig = sk.sign(Uint8List.fromList([5, 5, 5]));

      final inner =
          AccountAuthenticatorSingleKey(AnyPublicKey(pk), AnySignature(sig));
      final original = TransactionAuthenticatorSingleSender(inner);

      final restored =
          roundTrip(original, TransactionAuthenticator.deserialize);
      expect(restored, isA<TransactionAuthenticatorSingleSender>());
      final r = restored as TransactionAuthenticatorSingleSender;
      expect(r.sender, isA<AccountAuthenticatorSingleKey>());
      expect(serializeToBytes(restored), equals(serializeToBytes(original)));
    });
  });

  group('transactions/instances/signed_transaction', () {
    test('SignedTransaction round-trips with an Ed25519 authenticator', () {
      final rawTxn = makeRawTransaction();
      final signingMessage = serializeToBytes(rawTxn);
      final signature = ed25519Sk.sign(signingMessage);
      final authenticator =
          TransactionAuthenticatorEd25519(ed25519Pk, signature);
      final original = SignedTransaction(rawTxn, authenticator);

      final restored = roundTrip(original, SignedTransaction.deserialize);
      expect(restored.rawTxn.sender.toString(), rawTxn.sender.toString());
      expect(restored.rawTxn.sequenceNumber, rawTxn.sequenceNumber);
      expect(restored.rawTxn.chainId.chainId, rawTxn.chainId.chainId);
      expect(restored.authenticator, isA<TransactionAuthenticatorEd25519>());
      expect(serializeToBytes(restored), equals(serializeToBytes(original)));
    });

    test('SignedTransaction round-trips with a FeePayer authenticator', () {
      final rawTxn = makeRawTransaction();
      final inner = makeEd25519AccountAuthenticator();
      final authenticator = TransactionAuthenticatorFeePayer(
        inner,
        [],
        [],
        (address: AccountAddress.from('0x3'), authenticator: inner),
      );
      final original = SignedTransaction(rawTxn, authenticator);

      final restored = roundTrip(original, SignedTransaction.deserialize);
      final restoredAuth =
          restored.authenticator as TransactionAuthenticatorFeePayer;
      expect(
        restoredAuth.feePayer.address.toString(),
        AccountAddress.from('0x3').toString(),
      );
      expect(serializeToBytes(restored), equals(serializeToBytes(original)));
    });
  });
}
