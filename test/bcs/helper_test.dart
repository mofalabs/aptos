
import 'dart:typed_data';

import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test("serializes and deserializes a vector of serializables", () {
    final address0 = AccountAddress.fromHex("0x1");
    final address1 = AccountAddress.fromHex("0x2");

    final serializer = Serializer();
    serializeVector([address0, address1], serializer);

    final addresses = deserializeVector(Deserializer(serializer.getBytes()), AccountAddress.deserialize);

    expect(addresses[0].address, address0.address);
    expect(addresses[1].address, address1.address);
  });

  test("bcsToBytes", () {
    final address = AccountAddress.fromHex("0x1");
    bcsToBytes(address);

    expect(bcsToBytes(address),
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    );
  });

  test("bcsSerializeU8", () {
    expect(bcsSerializeU8(255), [0xff]);
  });

  test("bcsSerializeU16", () {
    expect(bcsSerializeU16(65535), [0xff, 0xff]);
  });

  test("bcsSerializeU32", () {
    expect(bcsSerializeU32(4294967295), [0xff, 0xff, 0xff, 0xff]);
  });

  test("bcsSerializeU64", () {
    expect(bcsSerializeUint64(BigInt.tryParse("18446744073709551615")!),
    [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
  });

  test("bcsSerializeU128", () {
    expect(bcsSerializeU128(BigInt.tryParse("340282366920938463463374607431768211455")!),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
    );
  });

  test("bcsSerializeBool", () {
    expect(bcsSerializeBool(true), [0x01]);
  });

  test("bcsSerializeStr", () {
    expect(bcsSerializeStr("çå∞≠¢õß∂ƒ∫"),
      [
        24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, 0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88,
        0x82, 0xc6, 0x92, 0xe2, 0x88, 0xab,
      ]
    );
  });


  test("bcsSerializeBytes", () {
    expect(bcsSerializeBytes(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73])),
      [5, 0x41, 0x70, 0x74, 0x6f, 0x73],
    );
  });

  test("bcsSerializeFixedBytes", () {
    expect(bcsSerializeFixedBytes(Uint8List.fromList([0x41, 0x70, 0x74, 0x6f, 0x73])),
      [0x41, 0x70, 0x74, 0x6f, 0x73],
    );
  });

  test("serializeVectorWithFunc", () {
    expect(serializeVectorWithFunc([false, true], "serializeBool"), [0x2, 0x0, 0x1]);
  });
}