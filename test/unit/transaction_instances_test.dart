import 'dart:typed_data';

import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializable/entry_function_bytes.dart';
import 'package:aptos/src/bcs/serializable/move_primitives.dart';
import 'package:aptos/src/bcs/serializable/move_structs.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/account_address.dart';
import 'package:aptos/src/core/authentication_key.dart';
import 'package:aptos/src/core/crypto/public_key.dart';
import 'package:aptos/src/core/crypto/signature.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/transactions/instances/chain_id.dart';
import 'package:aptos/src/transactions/instances/encrypted_payload.dart';
import 'package:aptos/src/transactions/instances/identifier.dart';
import 'package:aptos/src/transactions/instances/module_id.dart';
import 'package:aptos/src/transactions/instances/multi_agent_transaction.dart';
import 'package:aptos/src/transactions/instances/raw_transaction.dart';
import 'package:aptos/src/transactions/instances/rotation_proof_challenge.dart';
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

/// A minimal PublicKey wrapping raw bytes, so this test does not depend on a
/// concrete crypto implementation.
class _RawPublicKey extends PublicKey {
  final Uint8List bytes;

  _RawPublicKey(this.bytes);

  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
  }) =>
      false;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(bytes);
  }
}

// Known-answer test vector. Ensures compatibility with other SDKs and nodes.
const turboTxn =
    '0x04000100000000000000000000000000000000000000000000000000000000000000010d6170746f735f6163636f756e74087472616e73666572000220bd3c821fc733b9e0a022c7fa2fe24e5a5a0c5b66c9624d5a63ea735628818f1008e8030000000000000000010001000000000000';

final sender = AccountAddress.from('0x1');
final recipient = AccountAddress.from('0x2');
final sponsor = AccountAddress.from('0x3');

Uint8List serializeToBytes(void Function(Serializer) fn) {
  final serializer = Serializer();
  fn(serializer);
  return serializer.toUint8List();
}

T roundTrip<T>(
  void Function(Serializer) serializeFn,
  T Function(Deserializer) deserialize,
) {
  final bytes = serializeToBytes(serializeFn);
  final deserializer = Deserializer(bytes);
  final value = deserialize(deserializer);
  deserializer.assertFinished();
  return value;
}

RawTransaction makeRawTransaction([BigInt? seq]) {
  final moduleId = ModuleId(AccountAddress.one, Identifier('coin'));
  final entry = EntryFunction(moduleId, Identifier('transfer'), [], []);
  final payload = TransactionPayloadEntryFunction(entry);
  return RawTransaction(
    sender,
    seq ?? BigInt.one,
    payload,
    BigInt.from(1000),
    BigInt.from(100),
    BigInt.from(999999),
    ChainId(4),
  );
}

void main() {
  group('parseEncodedTransactions', () {
    test('parse a valid orderless transaction', () {
      final des = Deserializer(Hex.fromHexInput(turboTxn).toUint8List());
      final payload = TransactionPayload.deserialize(des);
      des.assertFinished();
      expect(payload, isA<TransactionInnerPayloadV1>());

      final inner = payload as TransactionInnerPayloadV1;
      expect(inner.executable, isA<TransactionExecutableEntryFunction>());
      final entry = (inner.executable as TransactionExecutableEntryFunction)
          .entryFunction;
      expect(
          entry.moduleName.address.toString(), AccountAddress.one.toString());
      expect(entry.moduleName.name.identifier, 'aptos_account');
      expect(entry.functionName.identifier, 'transfer');
      expect(entry.typeArgs, isEmpty);
      expect(entry.args, hasLength(2));

      final config = inner.extraConfig as TransactionExtraConfigV1;
      expect(config.multisigAddress, isNull);
      expect(config.replayProtectionNonce, BigInt.from(256));
    });

    test('serializes and deserializes an orderless transaction byte-exactly',
        () {
      final input = Hex.fromHexInput(turboTxn).toUint8List();
      final payload = TransactionPayload.deserialize(Deserializer(input));

      final serialized = serializeToBytes(payload.serialize);
      expect(serialized, equals(input));

      final rePayload =
          TransactionPayload.deserialize(Deserializer(serialized));
      expect(serializeToBytes(rePayload.serialize), equals(input));
    });

    test('building an orderless transaction payload', () {
      final payload = TransactionInnerPayloadV1(
        TransactionExecutableEntryFunction(
          EntryFunction.build('0x1::aptos_account', 'transfer', [], []),
        ),
        TransactionExtraConfigV1(),
      );

      final serialized = serializeToBytes(payload.serialize);
      // Top level variant 4 (Payload), inner variant 0 (V1), executable
      // variant 1 (EntryFunction).
      expect(serialized[0], 4);
      expect(serialized[1], 0);
      expect(serialized[2], 1);

      final rePayload =
          TransactionPayload.deserialize(Deserializer(serialized));
      expect(serializeToBytes(rePayload.serialize), equals(serialized));
    });
  });

  group('MultiSigTransactionPayload', () {
    test('serializes and deserializes with EntryFunction (variant 0)', () {
      final entryFunction =
          EntryFunction.build('0x1::aptos_account', 'transfer', [], []);
      final payload = MultiSigTransactionPayload(entryFunction);

      final bytes = serializeToBytes(payload.serialize);
      expect(bytes[0], 0);

      final deserialized =
          MultiSigTransactionPayload.deserialize(Deserializer(bytes));
      expect(deserialized.transactionPayload, isA<EntryFunction>());
      expect(serializeToBytes(deserialized.serialize), equals(bytes));
    });

    test('serializes and deserializes with Script (variant 1)', () {
      final script =
          Script(Uint8List.fromList([0xde, 0xad]), [], [U64(BigInt.from(42))]);
      final payload = MultiSigTransactionPayload(script);

      final bytes = serializeToBytes(payload.serialize);
      expect(bytes[0], 1);

      final deserialized =
          MultiSigTransactionPayload.deserialize(Deserializer(bytes));
      expect(deserialized.transactionPayload, isA<Script>());
      expect(serializeToBytes(deserialized.serialize), equals(bytes));
    });

    test('rejects payload types other than EntryFunction and Script', () {
      expect(
        () => MultiSigTransactionPayload(U64(BigInt.one)),
        throwsArgumentError,
      );
    });

    test(
        'round-trips a full multisig script payload through '
        'TransactionPayloadMultiSig', () {
      final script = Script(Uint8List.fromList([0xca, 0xfe]), [], []);
      final multisig =
          MultiSig(AccountAddress.one, MultiSigTransactionPayload(script));
      final txPayload = TransactionPayloadMultiSig(multisig);

      final bytes = serializeToBytes(txPayload.serialize);
      // Top level variant 3 (Multisig).
      expect(bytes[0], 3);

      final deserialized = TransactionPayload.deserialize(Deserializer(bytes));
      expect(deserialized, isA<TransactionPayloadMultiSig>());
      final msPayload = deserialized as TransactionPayloadMultiSig;
      expect(
        msPayload.multiSig.transactionPayload?.transactionPayload,
        isA<Script>(),
      );
      expect(serializeToBytes(deserialized.serialize), equals(bytes));
    });

    test('round-trips MultiSig without an on-chain payload', () {
      final multisigAddress = AccountAddress.from(
        '0x000000000000000000000000000000000000000000000000000000000000beef',
      );
      final multisig = MultiSig(multisigAddress);
      final txPayload = TransactionPayloadMultiSig(multisig);

      final bytes = serializeToBytes(txPayload.serialize);
      final deserialized = TransactionPayload.deserialize(Deserializer(bytes));

      expect(deserialized, isA<TransactionPayloadMultiSig>());
      final ms = (deserialized as TransactionPayloadMultiSig).multiSig;
      expect(ms.multisigAddress.toString(), multisigAddress.toString());
      expect(ms.transactionPayload, isNull);
    });

    test('throws when deserializing an unknown variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => MultiSigTransactionPayload.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown MultisigTransactionPayload variant'),
        )),
      );
    });

    test('building an orderless multisig script payload', () {
      final script = Script(Uint8List.fromList([0xbe, 0xef]), [], []);
      final payload = TransactionInnerPayloadV1(
        TransactionExecutableScript(script),
        TransactionExtraConfigV1(multisigAddress: AccountAddress.one),
      );

      final serialized = serializeToBytes(payload.serialize);
      final rePayload =
          TransactionPayload.deserialize(Deserializer(serialized));
      expect(serializeToBytes(rePayload.serialize), equals(serialized));

      final inner = rePayload as TransactionInnerPayloadV1;
      expect(inner.executable, isA<TransactionExecutableScript>());
      final config = inner.extraConfig as TransactionExtraConfigV1;
      expect(config.multisigAddress.toString(), AccountAddress.one.toString());
      expect(config.replayProtectionNonce, isNull);
    });
  });

  group('TransactionPayload variants', () {
    test('round-trips a TransactionPayloadEntryFunction', () {
      final moduleId = ModuleId(AccountAddress.one, Identifier('coin'));
      final original = TransactionPayloadEntryFunction(
        EntryFunction(moduleId, Identifier('transfer'), [], []),
      );

      final bytes = serializeToBytes(original.serialize);
      // Variant index 2 (EntryFunction).
      expect(bytes[0], 2);

      final restored =
          roundTrip(original.serialize, TransactionPayload.deserialize)
              as TransactionPayloadEntryFunction;
      expect(
        restored.entryFunction.moduleName.address.toString(),
        original.entryFunction.moduleName.address.toString(),
      );
      expect(restored.entryFunction.moduleName.name.identifier, 'coin');
      expect(restored.entryFunction.functionName.identifier, 'transfer');
    });

    test('round-trips a TransactionPayloadScript with no args/type tags', () {
      final original = TransactionPayloadScript(
        Script(Uint8List.fromList([0xa1, 0x1c]), [], []),
      );

      final bytes = serializeToBytes(original.serialize);
      // Variant index 0 (Script).
      expect(bytes[0], 0);

      final restored =
          roundTrip(original.serialize, TransactionPayload.deserialize)
              as TransactionPayloadScript;
      expect(restored.script.bytecode, equals([0xa1, 0x1c]));
      expect(restored.script.typeArgs, isEmpty);
      expect(restored.script.args, isEmpty);
    });

    test('deserialize throws on an unknown variant index', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => TransactionPayload.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for TransactionPayload'),
        )),
      );
    });
  });

  group('EntryFunction', () {
    test(
        'serializes args with a length prefix and deserializes them as '
        'EntryFunctionBytes', () {
      final entry = EntryFunction.build(
        '0x1::aptos_account',
        'transfer',
        [],
        [AccountAddress.two, U64(BigInt.from(1000))],
      );

      final bytes = serializeToBytes(entry.serialize);
      final restored = EntryFunction.deserialize(Deserializer(bytes));

      expect(restored.args, hasLength(2));
      expect(restored.args[0], isA<EntryFunctionBytes>());
      expect(restored.args[1], isA<EntryFunctionBytes>());
      // The raw fixed bytes are the BCS bytes of the original arguments.
      expect(
        (restored.args[0] as EntryFunctionBytes).value.value,
        equals(AccountAddress.two.bcsToBytes()),
      );
      expect(
        (restored.args[1] as EntryFunctionBytes).value.value,
        equals(U64(BigInt.from(1000)).bcsToBytes()),
      );

      // Re-serialization is byte-identical.
      expect(serializeToBytes(restored.serialize), equals(bytes));
    });

    test('build rejects malformed module ids', () {
      expect(
        () => EntryFunction.build('0x1', 'transfer', [], []),
        throwsArgumentError,
      );
    });
  });

  group('Script arguments', () {
    test('round-trips every script argument variant', () {
      final args = <Object>[
        U8(255),
        U64(BigInt.from(42)),
        U128(BigInt.parse('340282366920938463463374607431768211455')),
        AccountAddress.two,
        MoveVector.u8([1, 2, 3, 4]),
        Bool(true),
        U16(65535),
        U32(4294967295),
        U256(BigInt.parse('2') << 200),
        Serialized(Uint8List.fromList([9, 9, 9])),
        I8(-1),
        I16(-2),
        I32(-3),
        I64(BigInt.from(-4)),
        I128(BigInt.from(-5)),
        I256(BigInt.from(-6)),
      ];
      final script = Script(
        Uint8List.fromList([0xa1, 0x1c, 0xeb, 0x0b]),
        [],
        args.cast(),
      );

      final bytes = serializeToBytes(script.serialize);
      final restored = Script.deserialize(Deserializer(bytes));

      expect(restored.args, hasLength(args.length));
      for (var i = 0; i < args.length; i += 1) {
        expect(restored.args[i].runtimeType, args[i].runtimeType,
            reason: 'arg $i type');
      }
      // MoveVector round-trips as MoveVector<U8>.
      final vec = restored.args[4] as MoveVector;
      expect(vec.values.map((v) => (v as U8).value), equals([1, 2, 3, 4]));
      expect((restored.args[0] as U8).value, 255);
      expect((restored.args[10] as I8).value, -1);
      expect((restored.args[15] as I256).value, BigInt.from(-6));

      // Byte-identical re-serialization.
      expect(serializeToBytes(restored.serialize), equals(bytes));
    });

    test('deserializeFromScriptArgument throws on unknown variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => deserializeFromScriptArgument(
          Deserializer(serializer.toUint8List()),
        ),
        throwsStateError,
      );
    });
  });

  group('Orderless types byte layout', () {
    test('TransactionExtraConfigV1 with no options encodes as 00 00 00', () {
      final config = TransactionExtraConfigV1();
      expect(config.bcsToBytes(), equals([0, 0, 0]));
    });

    test('TransactionExtraConfigV1 option encodings are byte-exact', () {
      final config = TransactionExtraConfigV1(
        multisigAddress: AccountAddress.one,
        replayProtectionNonce: BigInt.from(256),
      );
      final expected = <int>[
        0, // TransactionExtraConfigVariants.V1
        1, // Option<AccountAddress>: Some
        ...List.filled(31, 0), 1, // 32-byte address 0x1
        1, // Option<U64>: Some
        0, 1, 0, 0, 0, 0, 0, 0, // u64 256 little-endian
      ];
      expect(config.bcsToBytes(), equals(expected));

      final restored = roundTrip(
        config.serialize,
        TransactionExtraConfig.deserialize,
      ) as TransactionExtraConfigV1;
      expect(
          restored.multisigAddress.toString(), AccountAddress.one.toString());
      expect(restored.replayProtectionNonce, BigInt.from(256));
    });

    test('TransactionExecutable variant indices', () {
      final script = TransactionExecutableScript(
        Script(Uint8List.fromList([0x01]), [], []),
      );
      final entry = TransactionExecutableEntryFunction(
        EntryFunction.build('0x1::coin', 'transfer', [], []),
      );
      final empty = TransactionExecutableEmpty();
      final encrypted = TransactionExecutableEncrypted();

      expect(script.bcsToBytes()[0], 0);
      expect(entry.bcsToBytes()[0], 1);
      expect(empty.bcsToBytes(), equals([2]));
      expect(encrypted.bcsToBytes(), equals([3]));

      for (final executable in [script, entry, empty, encrypted]) {
        final restored = roundTrip(
          executable.serialize,
          TransactionExecutable.deserialize,
        );
        expect(restored.runtimeType, executable.runtimeType);
        expect(restored.bcsToBytes(), equals(executable.bcsToBytes()));
      }
    });

    test('TransactionExecutable.deserialize throws on unknown variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => TransactionExecutable.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsStateError,
      );
    });

    test('TransactionInnerPayload.deserialize throws on unknown variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => TransactionInnerPayload.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsStateError,
      );
    });

    test('TransactionExtraConfig.deserialize throws on unknown variant', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => TransactionExtraConfig.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsStateError,
      );
    });
  });

  group('RawTransaction', () {
    test('round-trips with correct field order and values', () {
      final txSender = AccountAddress.fromString(
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      );
      final payload = TransactionPayloadEntryFunction(
        EntryFunction(
          ModuleId(AccountAddress.one, Identifier('aptos_account')),
          Identifier('transfer'),
          [],
          [AccountAddress.two, U64(BigInt.from(1000))],
        ),
      );

      final rawTxn = RawTransaction(
        txSender,
        BigInt.zero,
        payload,
        BigInt.from(100000),
        BigInt.from(100),
        BigInt.from(1735689600),
        ChainId(1),
      );

      final restored = roundTrip(rawTxn.serialize, RawTransaction.deserialize);

      expect(restored.sender.toString(), txSender.toString());
      expect(restored.sequenceNumber, BigInt.zero);
      expect(restored.maxGasAmount, BigInt.from(100000));
      expect(restored.gasUnitPrice, BigInt.from(100));
      expect(restored.expirationTimestampSecs, BigInt.from(1735689600));
      expect(restored.chainId.chainId, 1);
      expect(restored.bcsToBytes(), equals(rawTxn.bcsToBytes()));
    });
  });

  group('RawTransactionWithData', () {
    test('round-trips MultiAgentRawTransaction with secondary signers', () {
      final original = MultiAgentRawTransaction(
        makeRawTransaction(BigInt.from(11)),
        [recipient, sponsor],
      );

      final bytes = serializeToBytes(original.serialize);
      // Variant index 0 (MultiAgentTransaction).
      expect(bytes[0], 0);

      final restored =
          roundTrip(original.serialize, RawTransactionWithData.deserialize);
      expect(restored, isA<MultiAgentRawTransaction>());
      final multi = restored as MultiAgentRawTransaction;
      expect(
        multi.secondarySignerAddresses.map((a) => a.toString()),
        equals([recipient.toString(), sponsor.toString()]),
      );
      expect(multi.rawTxn.sequenceNumber, BigInt.from(11));
    });

    test('round-trips FeePayerRawTransaction', () {
      final original = FeePayerRawTransaction(
        makeRawTransaction(BigInt.from(15)),
        [recipient],
        sponsor,
      );

      final bytes = serializeToBytes(original.serialize);
      // Variant index 1 (FeePayerTransaction).
      expect(bytes[0], 1);

      final restored =
          roundTrip(original.serialize, RawTransactionWithData.deserialize);
      expect(restored, isA<FeePayerRawTransaction>());
      final feePayer = restored as FeePayerRawTransaction;
      expect(feePayer.feePayerAddress.toString(), sponsor.toString());
      expect(feePayer.secondarySignerAddresses, hasLength(1));
      expect(feePayer.rawTxn.sequenceNumber, BigInt.from(15));
    });

    test('throws for unknown variant indices', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(99);
      expect(
        () => RawTransactionWithData.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for RawTransactionWithData'),
        )),
      );
    });
  });

  group('SimpleTransaction', () {
    test('round-trips without a fee payer (boolean tag 0)', () {
      final original = SimpleTransaction(makeRawTransaction(BigInt.from(3)));

      final bytes = serializeToBytes(original.serialize);
      expect(bytes.last, 0);

      final restored =
          roundTrip(original.serialize, SimpleTransaction.deserialize);
      expect(restored.feePayerAddress, isNull);
      expect(restored.rawTransaction.sequenceNumber, BigInt.from(3));
      expect(restored.secondarySignerAddresses, isNull);
    });

    test('round-trips with a fee payer (boolean tag 1)', () {
      final original =
          SimpleTransaction(makeRawTransaction(BigInt.from(8)), sponsor);

      final restored =
          roundTrip(original.serialize, SimpleTransaction.deserialize);
      expect(restored.feePayerAddress?.toString(), sponsor.toString());
      expect(restored.rawTransaction.sequenceNumber, BigInt.from(8));
    });
  });

  group('MultiAgentTransaction', () {
    test('round-trips with one secondary signer and no fee payer', () {
      final original = MultiAgentTransaction(makeRawTransaction(), [recipient]);

      final restored =
          roundTrip(original.serialize, MultiAgentTransaction.deserialize);
      expect(restored.feePayerAddress, isNull);
      expect(restored.secondarySignerAddresses, hasLength(1));
      expect(
        restored.secondarySignerAddresses[0].toString(),
        recipient.toString(),
      );
      expect(restored.rawTransaction.sequenceNumber, BigInt.one);
      expect(restored.rawTransaction.sender.toString(), sender.toString());
    });

    test('round-trips with multiple secondary signers AND a fee payer', () {
      final seconds = [recipient, AccountAddress.from('0x4')];
      final original = MultiAgentTransaction(
        makeRawTransaction(BigInt.from(7)),
        seconds,
        sponsor,
      );

      final restored =
          roundTrip(original.serialize, MultiAgentTransaction.deserialize);
      expect(restored.feePayerAddress?.toString(), sponsor.toString());
      expect(
        restored.secondarySignerAddresses.map((a) => a.toString()),
        equals(seconds.map((a) => a.toString())),
      );
      expect(restored.rawTransaction.sequenceNumber, BigInt.from(7));
    });

    test('produces deterministic bytes for identical inputs', () {
      final a = MultiAgentTransaction(
        makeRawTransaction(BigInt.from(5)),
        [recipient],
        sponsor,
      );
      final b = MultiAgentTransaction(
        makeRawTransaction(BigInt.from(5)),
        [recipient],
        sponsor,
      );
      expect(a.bcsToBytes(), equals(b.bcsToBytes()));
    });
  });

  group('AnyRawTransaction', () {
    test('SimpleTransaction and MultiAgentTransaction implement it', () {
      final AnyRawTransaction simple = SimpleTransaction(makeRawTransaction());
      final AnyRawTransaction multi =
          MultiAgentTransaction(makeRawTransaction(), [recipient]);

      // Union discrimination: SimpleTransaction has no secondary signer
      // addresses.
      expect(simple.secondarySignerAddresses, isNull);
      expect(multi.secondarySignerAddresses, isNotNull);
      expect(simple.rawTransaction.sender.toString(), sender.toString());
    });

    test('feePayerAddress is mutable (set at signing time)', () {
      final AnyRawTransaction simple = SimpleTransaction(makeRawTransaction());
      final AnyRawTransaction multi =
          MultiAgentTransaction(makeRawTransaction(), [recipient]);

      expect(simple.feePayerAddress, isNull);
      simple.feePayerAddress = sponsor;
      expect(simple.feePayerAddress?.toString(), sponsor.toString());

      multi.feePayerAddress = sponsor;
      expect(multi.feePayerAddress?.toString(), sponsor.toString());

      // Mutation is reflected in serialization (fee payer boolean tag flips).
      final restored = roundTrip(
        (simple as SimpleTransaction).serialize,
        SimpleTransaction.deserialize,
      );
      expect(restored.feePayerAddress?.toString(), sponsor.toString());
    });
  });

  group('RotationProofChallenge', () {
    final newPublicKey = _RawPublicKey(Uint8List(32)..fillRange(0, 32, 1));

    test('uses the well-known 0x1::account::RotationProofChallenge identifier',
        () {
      final challenge = RotationProofChallenge(
        sequenceNumber: BigInt.zero,
        originator: sender,
        currentAuthKey: AccountAddress.zero,
        newPublicKey: newPublicKey,
      );

      // Constants — these are part of the on-chain ABI; locking them ensures
      // a future rename can't accidentally drift.
      expect(
          challenge.accountAddress.toString(), AccountAddress.one.toString());
      expect(challenge.moduleName.value, 'account');
      expect(challenge.structName.value, 'RotationProofChallenge');
    });

    test('serializes to a known layout (address + module + struct framing)',
        () {
      final challenge = RotationProofChallenge(
        sequenceNumber: BigInt.zero,
        originator: sender,
        currentAuthKey: AccountAddress.zero,
        newPublicKey: newPublicKey,
      );

      final bytes = challenge.bcsToBytes();

      // Deterministic for fixed inputs.
      expect(challenge.bcsToBytes(), equals(bytes));

      // The first 32 bytes are AccountAddress.ONE = 0x...01.
      for (var i = 0; i < 31; i += 1) {
        expect(bytes[i], 0);
      }
      expect(bytes[31], 1);

      // "account" as a BCS string.
      expect(bytes[32], 7);
      expect(String.fromCharCodes(bytes.sublist(33, 40)), 'account');
      // "RotationProofChallenge" as a BCS string.
      expect(bytes[40], 22);
      expect(
        String.fromCharCodes(bytes.sublist(41, 63)),
        'RotationProofChallenge',
      );
      // u64 sequence number + originator + currentAuthKey +
      // vector<u8> public key (1 length byte + 32 bytes).
      expect(bytes.length, 63 + 8 + 32 + 32 + 1 + 32);
      // The public key vector length prefix and content.
      expect(bytes[63 + 8 + 32 + 32], 32);
      expect(bytes.sublist(63 + 8 + 32 + 32 + 1), everyElement(1));
    });
  });

  group('Encrypted payload structures', () {
    BIBECiphertext makeBibe() => BIBECiphertext(
          idBytes: Uint8List.fromList([1, 2, 3, 4]),
          ctG2Bytes: Uint8List.fromList(List.filled(288, 7)),
          paddedKey: Uint8List.fromList(List.filled(16, 8)),
          gcmNonce: Uint8List.fromList(List.filled(12, 9)),
          ctBody: Uint8List.fromList([1, 1, 2, 3, 5, 8]),
        );

    Ciphertext makeCiphertext() => Ciphertext(
          Uint8List.fromList(List.filled(32, 5)),
          makeBibe(),
          Uint8List.fromList([0xaa, 0xbb]),
          Uint8List.fromList(List.filled(64, 6)),
        );

    test('ClaimedEntryFunction round-trips with and without function name', () {
      final moduleId = ModuleId(AccountAddress.one, Identifier('coin'));

      final withName = ClaimedEntryFunction(moduleId, Identifier('transfer'));
      final restoredWithName = roundTrip(
        withName.serialize,
        ClaimedEntryFunction.deserialize,
      );
      expect(restoredWithName.functionName?.identifier, 'transfer');
      expect(restoredWithName.moduleId.name.identifier, 'coin');

      final withoutName = ClaimedEntryFunction(moduleId);
      final restoredWithoutName = roundTrip(
        withoutName.serialize,
        ClaimedEntryFunction.deserialize,
      );
      expect(restoredWithoutName.functionName, isNull);
    });

    test('ClaimedEntryFunction.fromEntryFunction honors includeFunctionName',
        () {
      final entry = EntryFunction.build('0x1::coin', 'transfer', [], []);

      final full = ClaimedEntryFunction.fromEntryFunction(entry);
      expect(full.functionName?.identifier, 'transfer');

      final moduleOnly = ClaimedEntryFunction.fromEntryFunction(
        entry,
        includeFunctionName: false,
      );
      expect(moduleOnly.functionName, isNull);
    });

    test('DecryptedPlaintext round-trips and validates nonce length', () {
      final nonce = Uint8List.fromList(List.generate(16, (i) => i));
      final plaintext = DecryptedPlaintext(TransactionExecutableEmpty(), nonce);

      final restored = roundTrip(
        plaintext.serialize,
        DecryptedPlaintext.deserialize,
      );
      expect(restored.executable, isA<TransactionExecutableEmpty>());
      expect(restored.decryptionNonce, equals(nonce));

      expect(
        () => DecryptedPlaintext(TransactionExecutableEmpty(), Uint8List(8)),
        throwsArgumentError,
      );
    });

    test('DecryptedPlaintext.hash matches the domain-separated SHA3 vector',
        () {
      // Cross-checked with Python:
      //   salt = sha3_256(b"APTOS::DecryptedPlaintext").digest()
      //   sha3_256(salt + bytes([0x02]) + bytes(range(16))).hexdigest()
      final nonce = Uint8List.fromList(List.generate(16, (i) => i));
      final plaintext = DecryptedPlaintext(TransactionExecutableEmpty(), nonce);
      expect(
        Hex.fromHexInput(plaintext.hash()).toStringWithoutPrefix(),
        '62417fe908080ce69d539b46e1f7187aa1c210f1b380ce9e4106b409ea2519eb',
      );
    });

    test('PayloadAssociatedData round-trips and rejects empty signer list', () {
      final authKey = AuthenticationKey(data: Uint8List(32)..[31] = 0xcd);
      final data = PayloadAssociatedData(sender, [
        SignerAuthKeyPair(address: recipient, authenticationKey: authKey),
      ]);

      final bytes = serializeToBytes(data.serialize);
      // Variant V1 = 0.
      expect(bytes[0], 0);

      final restored = roundTrip(
        data.serialize,
        PayloadAssociatedData.deserialize,
      );
      expect(restored.sender.toString(), sender.toString());
      expect(restored.signerAuthKeys, hasLength(1));
      expect(
        restored.signerAuthKeys[0].address.toString(),
        recipient.toString(),
      );
      expect(
        restored.signerAuthKeys[0].authenticationKey.toString(),
        authKey.toString(),
      );

      expect(() => PayloadAssociatedData(sender, []), throwsArgumentError);
    });

    test('Ciphertext and BIBECiphertext round-trip byte-exactly', () {
      final ciphertext = makeCiphertext();
      final restored = roundTrip(
        ciphertext.serialize,
        Ciphertext.deserialize,
      );
      expect(restored.bcsToBytes(), equals(ciphertext.bcsToBytes()));
      expect(restored.vk, equals(ciphertext.vk));
      expect(restored.signature, equals(ciphertext.signature));
      expect(restored.bibeCt.idBytes, equals(ciphertext.bibeCt.idBytes));
      expect(restored.bibeCt.ctG2Bytes, equals(ciphertext.bibeCt.ctG2Bytes));
      expect(restored.bibeCt.ctBody, equals(ciphertext.bibeCt.ctBody));

      expect(
        () => Ciphertext(
          Uint8List(31),
          makeBibe(),
          Uint8List(0),
          Uint8List(64),
        ),
        throwsArgumentError,
      );
      expect(
        () => Ciphertext(
          Uint8List(32),
          makeBibe(),
          Uint8List(0),
          Uint8List(63),
        ),
        throwsArgumentError,
      );
    });

    test('TransactionPayloadEncryptedPayload round-trips (variant 5 | 0)', () {
      final payload = TransactionPayloadEncryptedPayload(
        makeCiphertext(),
        TransactionExtraConfigV1(replayProtectionNonce: BigInt.from(77)),
        Uint8List.fromList(List.filled(32, 0xab)),
        BigInt.from(12),
        ClaimedEntryFunction(
          ModuleId(AccountAddress.one, Identifier('coin')),
          Identifier('transfer'),
        ),
      );

      final bytes = serializeToBytes(payload.serialize);
      expect(bytes[0], 5); // TransactionPayloadVariants.EncryptedPayload
      expect(bytes[1], 0); // EncryptedPayloadVariants.Encrypted

      final restored = roundTrip(
        payload.serialize,
        TransactionPayload.deserialize,
      ) as TransactionPayloadEncryptedPayload;
      expect(restored.payloadHash, equals(payload.payloadHash));
      expect(restored.encryptionEpoch, BigInt.from(12));
      expect(
        restored.claimedEntryFunction?.functionName?.identifier,
        'transfer',
      );
      expect(serializeToBytes(restored.serialize), equals(bytes));
    });

    test(
        'TransactionPayloadEncryptedPayload validates hash length and inner variant',
        () {
      expect(
        () => TransactionPayloadEncryptedPayload(
          makeCiphertext(),
          TransactionExtraConfigV1(),
          Uint8List(31),
          BigInt.one,
        ),
        throwsArgumentError,
      );

      // Variant 5 followed by an unsupported inner variant (1).
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(5);
      serializer.serializeU32AsUleb128(1);
      expect(
        () => TransactionPayload.deserialize(
          Deserializer(serializer.toUint8List()),
        ),
        throwsStateError,
      );
    });
  });
}
