import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:test/test.dart';

void main() {
  late Serializer serializer;

  setUp(() {
    serializer = Serializer();
  });

  group('BCS Serializer', () {
    test('serializes a non-empty string', () {
      serializer.serializeStr('çå∞≠¢õß∂ƒ∫');
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([
          24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0,
          0xc2, //
          0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88, 0x82, 0xc6, 0x92, 0xe2,
          0x88,
          0xab,
        ])),
      );

      serializer = Serializer();
      serializer.serializeStr('abcd1234');
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(
            [8, 0x61, 0x62, 0x63, 0x64, 0x31, 0x32, 0x33, 0x34])),
      );
    });

    test('serializes an empty string', () {
      serializer.serializeStr('');
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0])));
    });

    test('serializes dynamic length bytes', () {
      serializer
          .serializeBytes(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([5, 0x41, 0x70, 0x74, 0x6f, 0x73])),
      );
    });

    test('serializes dynamic length bytes with zero elements', () {
      serializer.serializeBytes(Uint8List.fromList([]));
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0])));
    });

    test('serializes fixed length bytes', () {
      serializer.serializeFixedBytes(
          Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73])),
      );
    });

    test('serializes fixed length bytes with zero element', () {
      serializer.serializeFixedBytes(Uint8List.fromList([]));
      expect(serializer.toUint8List(), equals(Uint8List.fromList([])));
    });

    test('serializes a boolean value', () {
      serializer.serializeBool(true);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x01])));

      serializer = Serializer();
      serializer.serializeBool(false);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x00])));
    });

    test('serializes a uint8', () {
      serializer.serializeU8(255);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0xff])));
    });

    test('throws when serializing uint8 with out of range value', () {
      expect(() => serializer.serializeU8(256), throwsArgumentError);
      expect(() => serializer.serializeU8(-1), throwsArgumentError);
    });

    test('serializes a uint16', () {
      serializer.serializeU16(65535);
      expect(
          serializer.toUint8List(), equals(Uint8List.fromList([0xff, 0xff])));

      serializer = Serializer();
      serializer.serializeU16(4660);
      expect(
          serializer.toUint8List(), equals(Uint8List.fromList([0x34, 0x12])));
    });

    test('throws when serializing uint16 with out of range value', () {
      expect(() => serializer.serializeU16(65536), throwsArgumentError);
      expect(() => serializer.serializeU16(-1), throwsArgumentError);
    });

    test('serializes a uint32', () {
      serializer.serializeU32(4294967295);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0xff, 0xff, 0xff, 0xff])),
      );

      serializer = Serializer();
      serializer.serializeU32(305419896);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0x78, 0x56, 0x34, 0x12])),
      );
    });

    test('throws when serializing uint32 with out of range value', () {
      expect(() => serializer.serializeU32(4294967296), throwsArgumentError);
      expect(() => serializer.serializeU32(-1), throwsArgumentError);
    });

    test('serializes a uint64', () {
      serializer.serializeU64(BigInt.parse('18446744073709551615'));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(
            [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])),
      );

      serializer = Serializer();
      serializer.serializeU64(BigInt.parse('1311768467750121216'));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(
            [0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12])),
      );
    });

    test('throws when serializing uint64 with out of range value', () {
      expect(
        () => serializer.serializeU64(BigInt.parse('18446744073709551616')),
        throwsArgumentError,
      );
      expect(
        () => serializer.serializeU64(BigInt.from(-1)),
        throwsArgumentError,
      );
    });

    test('serializes a uint128', () {
      serializer.serializeU128(
          BigInt.parse('340282366920938463463374607431768211455'));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(List.filled(16, 0xff))),
      );

      serializer = Serializer();
      serializer.serializeU128(BigInt.parse('1311768467750121216'));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([
          0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12, //
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ])),
      );
    });

    test('serializes a uint256', () {
      serializer.serializeU256(maxU256BigInt);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(List.filled(32, 0xff))),
      );

      serializer = Serializer();
      serializer.serializeU256(BigInt.parse('1311768467750121216'));
      final expected = List<int>.filled(32, 0);
      expected.setRange(0, 8, [0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12]);
      expect(serializer.toUint8List(), equals(Uint8List.fromList(expected)));
    });

    test('serializes a uleb128', () {
      serializer.serializeU32AsUleb128(104543565);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0xcd, 0xea, 0xec, 0x31])),
      );

      serializer = Serializer();
      serializer.serializeU32AsUleb128(127);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x7f])));

      serializer = Serializer();
      serializer.serializeU32AsUleb128(4294967295);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f])),
      );
    });

    test('serializes signed integers (two\'s complement)', () {
      serializer.serializeI8(-1);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0xff])));

      serializer = Serializer();
      serializer.serializeI8(-128);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x80])));

      serializer = Serializer();
      serializer.serializeI16(-2);
      expect(
          serializer.toUint8List(), equals(Uint8List.fromList([0xfe, 0xff])));

      serializer = Serializer();
      serializer.serializeI32(-1);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0xff, 0xff, 0xff, 0xff])),
      );

      serializer = Serializer();
      serializer.serializeI64(BigInt.from(-1));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(List.filled(8, 0xff))),
      );

      serializer = Serializer();
      serializer.serializeI128(BigInt.from(-1));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(List.filled(16, 0xff))),
      );

      serializer = Serializer();
      serializer.serializeI256(BigInt.from(-1));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList(List.filled(32, 0xff))),
      );
    });

    test('throws when serializing out of range signed integers', () {
      expect(() => serializer.serializeI8(128), throwsArgumentError);
      expect(() => serializer.serializeI8(-129), throwsArgumentError);
      expect(() => serializer.serializeI16(32768), throwsArgumentError);
      expect(() => serializer.serializeI32(2147483648), throwsArgumentError);
      expect(
        () => serializer.serializeI64(maxI64BigInt + BigInt.one),
        throwsArgumentError,
      );
    });

    test('serializes multiple types of values', () {
      serializer.serializeBool(true);
      serializer.serializeU8(254);
      serializer.serializeU64(BigInt.parse('18446744073709551615'));
      serializer.serializeU128(
          BigInt.parse('340282366920938463463374607431768211455'));
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([
          0x01, 0xfe, //
          ...List.filled(8, 0xff),
          ...List.filled(16, 0xff),
        ])),
      );
    });

    test('serializes options', () {
      serializer.serializeOptionStr(null);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x00])));

      serializer = Serializer();
      serializer.serializeOptionStr('abcd');
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([0x01, 4, 0x61, 0x62, 0x63, 0x64])),
      );

      serializer = Serializer();
      serializer.serializeOption(U8(255));
      expect(
          serializer.toUint8List(), equals(Uint8List.fromList([0x01, 0xff])));

      serializer = Serializer();
      serializer.serializeOption(null);
      expect(serializer.toUint8List(), equals(Uint8List.fromList([0x00])));
    });

    test('serializes a vector of Serializables', () {
      serializer.serializeVector([U8(1), U8(2), U8(3)]);
      expect(
        serializer.toUint8List(),
        equals(Uint8List.fromList([3, 1, 2, 3])),
      );
    });

    test('grows the internal buffer beyond its initial size', () {
      final serializer = Serializer(1);
      final bytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      serializer.serializeFixedBytes(bytes);
      expect(serializer.toUint8List(), equals(bytes));
    });

    test('reset clears the buffer', () {
      serializer.serializeU8(1);
      serializer.reset();
      expect(serializer.getOffset(), equals(0));
      expect(serializer.toUint8List(), equals(Uint8List.fromList([])));
    });
  });

  group('Serializable', () {
    test('bcsToBytes and bcsToHex', () {
      final value = U64(BigInt.from(1));
      expect(
        value.bcsToBytes(),
        equals(Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])),
      );
      expect(value.bcsToHex().toString(), equals('0x0100000000000000'));
      expect(value.toString(), equals('0x0100000000000000'));
    });
  });
}
