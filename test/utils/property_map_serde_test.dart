

import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/utils/property_map_serde.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test("test property_map_serializer", () {
    bool isSame(Uint8List array1, Uint8List array2) {
      return listEquals(array1, array2);
    }

    const values = [
      "false",
      "10",
      "18446744073709551615",
      "340282366920938463463374607431768211455",
      "hello",
      "0x1",
      "I am a string",
    ];
    const types = ["bool", "u8", "u64", "u128", "0x1::string::String", "address", "string"];
    final newValues = getPropertyValueRaw(values, types);
    expect(isSame(newValues[0], bcsSerializeBool(false)), true);
    expect(isSame(newValues[1], bcsSerializeU8(10)), true);
    expect(isSame(newValues[2], bcsSerializeUint64(BigInt.parse("18446744073709551615"))), true);
    expect(isSame(newValues[3], bcsSerializeU128(BigInt.parse("340282366920938463463374607431768211455"))), true);
    expect(isSame(newValues[4], bcsSerializeStr(values[4])), true);
    expect(isSame(newValues[5], bcsToBytes(AccountAddress.fromHex("0x1"))), true);
    expect(isSame(newValues[6], bcsSerializeStr("I am a string")), true);
  });

  test("test propertymap deserializer", () {
    String toHexString(Uint8List data) {
      return HexString.fromUint8Array(data).hex();
    }
    const values = [
      "false",
      "10",
      "18446744073709551615",
      "340282366920938463463374607431768211455",
      "hello",
      "0x0000000000000000000000000000000000000000000000000000000000000001",
      "I am a string",
    ];
    const types = ["bool", "u8", "u64", "u128", "0x1::string::String", "address", "string"];
    final newValues = getPropertyValueRaw(values, types);
    for (int i = 0; i < values.length; i += 1) {
      expect(deserializeValueBasedOnTypeTag(getPropertyType(types[i]), toHexString(newValues[i])), values[i]);
    }
  });

}
