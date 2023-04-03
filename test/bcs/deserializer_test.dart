import 'dart:typed_data';

import 'package:aptos/bcs/deserializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test("deserializes a non-empty string", () {
    final deserializer = Deserializer(Uint8List.fromList(
      [
        24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, 0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88,
        0x82, 0xc6, 0x92, 0xe2, 0x88, 0xab,
      ]
    ));
    expect(deserializer.deserializeStr(), "çå∞≠¢õß∂ƒ∫");
  });

  test("deserializes an empty string", () {
    final deserializer =  Deserializer(Uint8List.fromList([0]));
    expect(deserializer.deserializeStr(), "");
  });

  test("deserializes dynamic length bytes", () {
    final deserializer = Deserializer(Uint8List.fromList([5, 0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(deserializer.deserializeBytes(), [0x41, 0x70, 0x74, 0x6f, 0x73]);
  });

  test("deserializes dynamic length bytes with zero elements", () {
    final deserializer = Deserializer(Uint8List.fromList([0]));
    expect(deserializer.deserializeBytes(), []);
  });

  test("deserializes fixed length bytes", () {
    final deserializer = Deserializer(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(deserializer.deserializeFixedBytes(5), [0x41, 0x70, 0x74, 0x6f, 0x73]);
  });

  test("deserializes fixed length bytes with zero element", () {
    final deserializer = Deserializer(Uint8List.fromList([]));
    expect(deserializer.deserializeFixedBytes(0), []);
  });

  test("deserializes a boolean value", () {
    var deserializer = Deserializer(Uint8List.fromList([0x01]));
    expect(deserializer.deserializeBool(), true);
    deserializer = Deserializer(Uint8List.fromList([0x00]));
    expect(deserializer.deserializeBool(), false);
  });

  test("throws when dserializing a boolean with disallowed values", () {
    expect(() {
      final deserializer = Deserializer(Uint8List.fromList([0x12]));
      deserializer.deserializeBool();
    }, throwsArgumentError);
  });

  test("deserializes a uint8", () {
    final deserializer = Deserializer(Uint8List.fromList([0xff]));
    expect(deserializer.deserializeU8(), 255);
  });

  test("deserializes a uint16", () {
    var deserializer = Deserializer(Uint8List.fromList([0xff, 0xff]));
    expect(deserializer.deserializeU16(), 65535);
    deserializer = Deserializer(Uint8List.fromList([0x34, 0x12]));
    expect(deserializer.deserializeU16(), 4660);
  });

  test("deserializes a uint32", () {
    var deserializer = Deserializer(Uint8List.fromList([0xff, 0xff, 0xff, 0xff]));
    expect(deserializer.deserializeU32(), 4294967295);
    deserializer = Deserializer(Uint8List.fromList([0x78, 0x56, 0x34, 0x12]));
    expect(deserializer.deserializeU32(), 305419896);
  });

  test("deserializes a uint64", () {
    var deserializer = Deserializer(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]));
    expect(deserializer.deserializeU64(), BigInt.tryParse("18446744073709551615")!);
    deserializer = Deserializer(Uint8List.fromList([0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12]));
    expect(deserializer.deserializeU64(), BigInt.tryParse("1311768467750121216")!);
  });

  test("deserializes a uint128", () {
    var deserializer = Deserializer(
      Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
    );
    expect(deserializer.deserializeU128(), BigInt.tryParse("340282366920938463463374607431768211455")!);
    deserializer = Deserializer(
      Uint8List.fromList([0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
    );
    expect(deserializer.deserializeU128(), BigInt.tryParse("1311768467750121216")!);
  });

  test("deserializes a uint256", ()  {
    var deserializer = Deserializer(
      Uint8List.fromList([
        0x31, 0x30, 0x29, 0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20, 0x19, 0x18, 0x17, 0x16, 0x15, 0x14,
        0x13, 0x12, 0x11, 0x10, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00,
      ]),
    );
    expect(deserializer.deserializeU256(),
      BigInt.tryParse("0x0001020304050607080910111213141516171819202122232425262728293031")
    );
  });

  test("deserializes a uleb128", () {
    var deserializer = Deserializer(Uint8List.fromList([0xcd, 0xea, 0xec, 0x31]));
    expect(deserializer.deserializeUleb128AsU32(), 104543565);

    deserializer = Deserializer(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x0f]));
    expect(deserializer.deserializeUleb128AsU32(), 4294967295);
  });

  test("throws when deserializing a uleb128 with out ranged value", () {
    expect(() {
      final deserializer = Deserializer(Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x10]));
      deserializer.deserializeUleb128AsU32();
    }, throwsArgumentError);
  });

  test("throws when deserializing against buffer that has been drained", () {
    expect(() {
      final deserializer = Deserializer(
        Uint8List.fromList([
          24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, 0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2,
          0x88, 0x82, 0xc6, 0x92, 0xe2, 0x88, 0xab,
        ]),
      );

      deserializer.deserializeStr();
      deserializer.deserializeStr();
    }, throwsArgumentError);
  });

}