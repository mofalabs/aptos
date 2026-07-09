import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:test/test.dart';

void main() {
  group('BCS Deserializer', () {
    test('deserializes a non-empty string', () {
      final deserializer = Deserializer(Uint8List.fromList([
        24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, //
        0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88, 0x82, 0xc6, 0x92, 0xe2, 0x88,
        0xab,
      ]));
      expect(deserializer.deserializeStr(), equals('çå∞≠¢õß∂ƒ∫'));
    });

    test('deserializes an empty string', () {
      final deserializer = Deserializer(Uint8List.fromList([0]));
      expect(deserializer.deserializeStr(), equals(''));
    });

    test('deserializes dynamic length bytes', () {
      final deserializer =
          Deserializer(Uint8List.fromList([5, 0x41, 0x70, 0x74, 0x6f, 0x73]));
      expect(
        deserializer.deserializeBytes(),
        equals(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73])),
      );
    });

    test('deserializes fixed length bytes', () {
      final deserializer =
          Deserializer(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
      expect(
        deserializer.deserializeFixedBytes(5),
        equals(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73])),
      );
    });

    test('deserializes a boolean value and rejects invalid input', () {
      expect(
          Deserializer(Uint8List.fromList([0x01])).deserializeBool(), isTrue);
      expect(
          Deserializer(Uint8List.fromList([0x00])).deserializeBool(), isFalse);
      expect(
        () => Deserializer(Uint8List.fromList([0x12])).deserializeBool(),
        throwsStateError,
      );
    });

    test('deserializes unsigned integers', () {
      expect(Deserializer(Uint8List.fromList([0xff])).deserializeU8(),
          equals(255));
      expect(
        Deserializer(Uint8List.fromList([0x34, 0x12])).deserializeU16(),
        equals(4660),
      );
      expect(
        Deserializer(Uint8List.fromList([0x78, 0x56, 0x34, 0x12]))
            .deserializeU32(),
        equals(305419896),
      );
      expect(
        Deserializer(Uint8List.fromList(
            [0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12])).deserializeU64(),
        equals(BigInt.parse('1311768467750121216')),
      );
      expect(
        Deserializer(Uint8List.fromList(List.filled(16, 0xff)))
            .deserializeU128(),
        equals(BigInt.parse('340282366920938463463374607431768211455')),
      );
      expect(
        Deserializer(Uint8List.fromList(List.filled(32, 0xff)))
            .deserializeU256(),
        equals(maxU256BigInt),
      );
    });

    test('deserializes signed integers (two\'s complement)', () {
      expect(
          Deserializer(Uint8List.fromList([0xff])).deserializeI8(), equals(-1));
      expect(Deserializer(Uint8List.fromList([0x80])).deserializeI8(),
          equals(-128));
      expect(Deserializer(Uint8List.fromList([0x7f])).deserializeI8(),
          equals(127));
      expect(
        Deserializer(Uint8List.fromList([0xfe, 0xff])).deserializeI16(),
        equals(-2),
      );
      expect(
        Deserializer(Uint8List.fromList([0xff, 0xff, 0xff, 0xff]))
            .deserializeI32(),
        equals(-1),
      );
      expect(
        Deserializer(Uint8List.fromList(List.filled(8, 0xff))).deserializeI64(),
        equals(BigInt.from(-1)),
      );
      expect(
        Deserializer(Uint8List.fromList(List.filled(16, 0xff)))
            .deserializeI128(),
        equals(BigInt.from(-1)),
      );
      expect(
        Deserializer(Uint8List.fromList(List.filled(32, 0xff)))
            .deserializeI256(),
        equals(BigInt.from(-1)),
      );
    });

    test('deserializes a uleb128', () {
      expect(
        Deserializer(Uint8List.fromList([0xcd, 0xea, 0xec, 0x31]))
            .deserializeUleb128AsU32(),
        equals(104543565),
      );
      expect(
        Deserializer(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f]))
            .deserializeUleb128AsU32(),
        equals(4294967295),
      );
    });

    test('throws when uleb128 value overflows a u32', () {
      expect(
        () => Deserializer(Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x10]))
            .deserializeUleb128AsU32(),
        throwsStateError,
      );
    });

    test('throws when reading past the end of the buffer', () {
      final deserializer = Deserializer(Uint8List.fromList([0x01]));
      deserializer.deserializeU8();
      expect(deserializer.deserializeU8, throwsStateError);
    });

    test('remaining and assertFinished', () {
      final deserializer = Deserializer(Uint8List.fromList([0x01, 0x02]));
      expect(deserializer.remaining(), equals(2));
      deserializer.deserializeU8();
      expect(deserializer.remaining(), equals(1));
      expect(deserializer.assertFinished, throwsStateError);
      deserializer.deserializeU8();
      deserializer.assertFinished();
    });

    test('deserializes options', () {
      expect(
        Deserializer(Uint8List.fromList([0x00])).deserializeOptionStr(),
        isNull,
      );
      expect(
        Deserializer(
                Uint8List.fromList([1, 8, 49, 50, 51, 52, 97, 98, 99, 100]))
            .deserializeOptionStr(),
        equals('1234abcd'),
      );
      expect(
        Deserializer(Uint8List.fromList([0x01, 0xff]))
            .deserializeOption(U8.deserialize)
            ?.value,
        equals(255),
      );
      expect(
        Deserializer(Uint8List.fromList([0x00]))
            .deserializeOption(U8.deserialize),
        isNull,
      );
    });

    test('deserializes a vector via class tear-off', () {
      final serializer = Serializer();
      serializer.serializeVector([U64.fromInt(1), U64.fromInt(2)]);
      final deserializer = Deserializer(serializer.toUint8List());
      final values = deserializer.deserializeVector(U64.deserialize);
      expect(values.map((v) => v.value.toInt()), equals([1, 2]));
    });

    test('fromHex constructs a deserializer', () {
      final deserializer = Deserializer.fromHex('0x01ff');
      expect(deserializer.deserializeU8(), equals(1));
      expect(deserializer.deserializeU8(), equals(255));
    });

    test('constructor copies data to prevent outside mutation', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final deserializer = Deserializer(data);
      data[0] = 99;
      expect(deserializer.deserializeU8(), equals(1));
    });
  });

  group('Move structs round-trips', () {
    test('MoveVector<U8> round-trip and hex factory', () {
      final vec = MoveVector.u8([1, 2, 3, 4]);
      expect(vec.bcsToBytes(), equals(Uint8List.fromList([4, 1, 2, 3, 4])));

      final fromHex = MoveVector.u8('0x01020304');
      expect(fromHex.bcsToBytes(), equals(vec.bcsToBytes()));

      final deserialized = MoveVector.deserialize(
          Deserializer(vec.bcsToBytes()), U8.deserialize);
      expect(deserialized.values.map((v) => v.value), equals([1, 2, 3, 4]));
    });

    test('MoveString round-trip', () {
      final str = MoveString('hello');
      final deserialized =
          MoveString.deserialize(Deserializer(str.bcsToBytes()));
      expect(deserialized.value, equals('hello'));
    });

    test('MoveOption some/none', () {
      expect(MoveOption.u8(1).isSome(), isTrue);
      expect(MoveOption.u8(null).isSome(), isFalse);
      expect(MoveOption.string('').isSome(), isTrue);
      expect(
        MoveOption.u64(BigInt.one).bcsToBytes(),
        equals(Uint8List.fromList([1, 1, 0, 0, 0, 0, 0, 0, 0])),
      );
      expect(MoveOption.u8(null).bcsToBytes(), equals(Uint8List.fromList([0])));
      expect(() => MoveOption.u8(null).unwrap(), throwsStateError);
      expect(MoveOption.u8(7).unwrap().value, equals(7));

      final deserialized = MoveOption.deserialize(
        Deserializer(MoveOption.u8(7).bcsToBytes()),
        U8.deserialize,
      );
      expect(deserialized.value?.value, equals(7));
    });

    test('Serialized script argument round-trip', () {
      final vec = MoveVector.u64([BigInt.one, BigInt.two]);
      final serialized = Serialized(vec.bcsToBytes());
      final restored = serialized.toMoveVector(U64.deserialize);
      expect(restored.values.map((v) => v.value.toInt()), equals([1, 2]));
    });

    test('serializeForEntryFunction adds length prefix', () {
      final serializer = Serializer();
      U8(255).serializeForEntryFunction(serializer);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([1, 0xff])));
    });

    test('serializeForScriptFunction adds variant index', () {
      final serializer = Serializer();
      U8(255).serializeForScriptFunction(serializer);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0, 0xff])));

      final serializer2 = Serializer();
      Bool(true).serializeForScriptFunction(serializer2);
      expect(serializer2.toUint8List(), equals(Uint8List.fromList([5, 1])));

      // A vector of non-U8 elements is wrapped in a Serialized argument (variant 9).
      final serializer3 = Serializer();
      MoveVector.u64([BigInt.one]).serializeForScriptFunction(serializer3);
      expect(
        serializer3.toUint8List(),
        equals(Uint8List.fromList([9, 9, 1, 1, 0, 0, 0, 0, 0, 0, 0])),
      );
    });
  });

  group('Hex', () {
    test('creates from and converts between formats', () {
      expect(Hex.fromHexString('0x1234').toString(), equals('0x1234'));
      expect(Hex.fromHexString('1234').toStringWithoutPrefix(), equals('1234'));
      expect(
        Hex.fromHexInput(Uint8List.fromList([0x12, 0x34])).toString(),
        equals('0x1234'),
      );
      expect(Hex.hexInputToString('1234'), equals('0x1234'));
      expect(Hex.hexInputToStringWithoutPrefix('0x1234'), equals('1234'));
      expect(
        Hex.hexInputToUint8List('0x1234'),
        equals(Uint8List.fromList([0x12, 0x34])),
      );
    });

    test('rejects invalid input', () {
      expect(() => Hex.fromHexString(''), throwsA(isA<ParsingError>()));
      expect(() => Hex.fromHexString('0x'), throwsA(isA<ParsingError>()));
      expect(() => Hex.fromHexString('0x123'), throwsA(isA<ParsingError>()));
      expect(() => Hex.fromHexString('0xzz'), throwsA(isA<ParsingError>()));

      expect(Hex.isValid('0x12').valid, isTrue);
      expect(Hex.isValid('0x1').valid, isFalse);
      expect(
        Hex.isValid('0x1').invalidReason,
        equals(HexInvalidReason.invalidLength),
      );
      expect(
        Hex.isValid('').invalidReason,
        equals(HexInvalidReason.tooShort),
      );
    });

    test('equals compares byte data', () {
      expect(
        Hex.fromHexString('0x1234').equals(Hex.fromHexString('1234')),
        isTrue,
      );
      expect(
        Hex.fromHexString('0x1234').equals(Hex.fromHexString('0x12')),
        isFalse,
      );
    });
  });
}
