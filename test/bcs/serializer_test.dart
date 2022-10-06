
import 'dart:typed_data';

import 'package:aptos/bcs/serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  late Serializer serializer;

  setUp(() {
    serializer = Serializer();
  });

  test("serializes a non-empty string", () {
    serializer.serializeStr("çå∞≠¢õß∂ƒ∫");
    expect(serializer.getBytes(),
      Uint8List.fromList([
        24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, 0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88,
        0x82, 0xc6, 0x92, 0xe2, 0x88, 0xab,
      ]),
    );
  });

  test("serializes an empty string", () {
    serializer.serializeStr("");
    expect(serializer.getBytes(), [0]);
  });

  test("serializes dynamic length bytes", () {
    serializer.serializeBytes(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(serializer.getBytes(), [5, 0x41, 0x70, 0x74, 0x6f, 0x73]);
  });

  test("serializes dynamic length bytes with zero elements", () {
    serializer.serializeBytes(Uint8List.fromList([]));
    expect(serializer.getBytes(), [0]);
  });

  test("serializes fixed length bytes", () {
    serializer.serializeFixedBytes(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(serializer.getBytes(), [0x41, 0x70, 0x74, 0x6f, 0x73]);
  });

  test("serializes fixed length bytes with zero element", () {
    serializer.serializeFixedBytes(Uint8List.fromList([]));
    expect(serializer.getBytes(), []);
  });

  test("serializes a boolean value", () {
    serializer.serializeBool(true);
    expect(serializer.getBytes(), [0x01]);

    serializer = Serializer();
    serializer.serializeBool(false);
    expect(serializer.getBytes(), [0x00]);
  });

  test("serializes a uint8", () {
    serializer.serializeU8(255);
    expect(serializer.getBytes(), [0xff]);
  });

  test("throws when serializing uint8 with out of range value", () {
    expect(() => serializer.serializeU8(256), throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU8(-1);
    }, throwsArgumentError);
  });

  test("serializes a uint16", () {
    serializer.serializeU16(65535);
    expect(serializer.getBytes(), [0xff, 0xff]);

    serializer = Serializer();
    serializer.serializeU16(4660);
    expect(serializer.getBytes(), [0x34, 0x12]);
  });

  test("throws when serializing uint16 with out of range value", () {
    expect(() {
      serializer.serializeU16(65536);
    }, throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU16(-1);
    }, throwsArgumentError);
  });

  test("serializes a uint32", () {
    serializer.serializeU32(4294967295);
    expect(serializer.getBytes(), [0xff, 0xff, 0xff, 0xff]);

    serializer = Serializer();
    serializer.serializeU32(305419896);
    expect(serializer.getBytes(), [0x78, 0x56, 0x34, 0x12]);
  });

  test("throws when serializing uint32 with out of range value", () {
    expect(() {
      serializer.serializeU32(4294967296);
    }, throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU32(-1);
    }, throwsArgumentError);
  });

  test("serializes a uint64", ()  {
    serializer.serializeU64(BigInt.tryParse("18446744073709551615")!);
    expect(serializer.getBytes(), [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);

    serializer = Serializer();
    serializer.serializeU64(BigInt.tryParse("1311768467750121216")!);
    expect(serializer.getBytes(), [0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12]);
  });

  test("throws when serializing uint64 with out of range value", () {
    expect(() {
      serializer.serializeU64(BigInt.tryParse("18446744073709551616")!);
    }, throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU64(BigInt.tryParse("-1")!);
    }, throwsArgumentError);
  });

  test("serializes a uint128", () {
    serializer.serializeU128(BigInt.tryParse("340282366920938463463374607431768211455")!);
    expect(serializer.getBytes(), 
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );

    serializer = Serializer();
    serializer.serializeU128(BigInt.tryParse("1311768467750121216")!);
    expect(serializer.getBytes(), 
      [0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    );
  });

  test("throws when serializing uint128 with out of range value", () {
    expect(() {
      serializer.serializeU128(BigInt.tryParse("340282366920938463463374607431768211456")!);
    }, throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU128(BigInt.tryParse("-1")!);
    }, throwsArgumentError);
  });

  test("serializes a uleb128", () {
    serializer.serializeU32AsUleb128(104543565);
    expect(serializer.getBytes(), [0xcd, 0xea, 0xec, 0x31]);
  });

  test("throws when serializing uleb128 with out of range value", () {
    expect(() {
      serializer.serializeU32AsUleb128(4294967296);
    }, throwsArgumentError);

    expect(() {
      serializer = Serializer();
      serializer.serializeU32AsUleb128(-1);
    }, throwsArgumentError);
  });
}