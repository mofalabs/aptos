
import 'dart:typed_data';

import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/multi_ed25519.dart';
import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/hex_string.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("public key serializes to bytes correctly", () {
    const publicKey1 = "b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200";
    const publicKey2 = "aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab";
    const publicKey3 = "8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d74";

    final pubKeyMultiSig = MultiEd25519PublicKey(
      [
        Ed25519PublicKey(HexString(publicKey1).toUint8Array()),
        Ed25519PublicKey(HexString(publicKey2).toUint8Array()),
        Ed25519PublicKey(HexString(publicKey3).toUint8Array()),
      ],
      2,
    );

    expect(HexString.fromUint8Array(pubKeyMultiSig.toBytes()).noPrefix(),
      "b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d7402",
    );
  });

  test("public key deserializes from bytes correctly", () {
    const publicKey1 = "b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200";
    const publicKey2 = "aef3f4a4b8eca1dfc343361bf8e436bd42de9259c04b8314eb8e2054dd6e82ab";
    const publicKey3 = "8a5762e21ac1cdb3870442c77b4c3af58c7cedb8779d0270e6d4f1e2f7367d74";

    final pubKeyMultiSig = MultiEd25519PublicKey(
      [
        Ed25519PublicKey(HexString(publicKey1).toUint8Array()),
        Ed25519PublicKey(HexString(publicKey2).toUint8Array()),
        Ed25519PublicKey(HexString(publicKey3).toUint8Array()),
      ],
      2,
    );
    final deserialzed = MultiEd25519PublicKey.deserialize(Deserializer(bcsToBytes(pubKeyMultiSig)));
    expect(HexString.fromUint8Array(deserialzed.toBytes()).noPrefix(),
      HexString.fromUint8Array(pubKeyMultiSig.toBytes()).noPrefix(),
    );
  });

  test("signature serializes to bytes correctly", () {
    const sig1 =
      "e6f3ba05469b2388492397840183945d4291f0dd3989150de3248e06b4cefe0ddf6180a80a0f04c045ee8f362870cb46918478cd9b56c66076f94f3efd5a8805";
    const sig2 =
      "2ae0818b7e51b853f1e43dc4c89a1f5fabc9cb256030a908f9872f3eaeb048fb1e2b4ffd5a9d5d1caedd0c8b7d6155ed8071e913536fa5c5a64327b6f2d9a102";
    const bitmap = "c0000000";

    final multisig = MultiEd25519Signature(
      [
        Ed25519Signature(HexString(sig1).toUint8Array()),
        Ed25519Signature(HexString(sig2).toUint8Array()),
      ],
      HexString(bitmap).toUint8Array(),
    );

    expect(HexString.fromUint8Array(multisig.toBytes()).noPrefix(),
      "e6f3ba05469b2388492397840183945d4291f0dd3989150de3248e06b4cefe0ddf6180a80a0f04c045ee8f362870cb46918478cd9b56c66076f94f3efd5a88052ae0818b7e51b853f1e43dc4c89a1f5fabc9cb256030a908f9872f3eaeb048fb1e2b4ffd5a9d5d1caedd0c8b7d6155ed8071e913536fa5c5a64327b6f2d9a102c0000000",
    );
  });

  test("signature deserializes from bytes correctly", () {
    const sig1 =
      "e6f3ba05469b2388492397840183945d4291f0dd3989150de3248e06b4cefe0ddf6180a80a0f04c045ee8f362870cb46918478cd9b56c66076f94f3efd5a8805";
    const sig2 =
      "2ae0818b7e51b853f1e43dc4c89a1f5fabc9cb256030a908f9872f3eaeb048fb1e2b4ffd5a9d5d1caedd0c8b7d6155ed8071e913536fa5c5a64327b6f2d9a102";
    const bitmap = "c0000000";

    final multisig = MultiEd25519Signature(
      [
        Ed25519Signature(HexString(sig1).toUint8Array()),
        Ed25519Signature(HexString(sig2).toUint8Array()),
      ],
      HexString(bitmap).toUint8Array(),
    );

    final deserialzed = MultiEd25519Signature.deserialize(Deserializer(bcsToBytes(multisig)));
    expect(HexString.fromUint8Array(deserialzed.toBytes()).noPrefix(),
      HexString.fromUint8Array(multisig.toBytes()).noPrefix(),
    );
  });

  test("creates a valid bitmap", () {
    expect(MultiEd25519Signature.createBitmap([0, 2, 31]),
      [0xA0, 0x00, 0x00, 0x01]
    );
  });

  test("throws exception when creating a bitmap with wrong bits", () {
    expect(() {
      MultiEd25519Signature.createBitmap([32]);
    }, throwsArgumentError);
  });

  test("throws exception when creating a bitmap with duplicate bits", () {
    expect(() {
      MultiEd25519Signature.createBitmap([2, 2]);
    }, throwsArgumentError);
  });
}