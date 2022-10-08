

import 'dart:typed_data';

import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/transaction_builder/builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

void main() {

  const ADDRESS_1 = "0x1222";
  const ADDRESS_2 = "0xdd";
  const ADDRESS_3 = "0x0a550c18";
  const ADDRESS_4 = "0x01";
  const PRIVATE_KEY = "9bf49a6a0755f953811fce125f2683d50429c3bb49e074147e0089a52eae155f";
  const TXN_EXPIRE = "18446744073709551615";

  String hexSignedTxn(Uint8List signedTxn) {
    return HEX.encode(signedTxn);
  }

  Uint8List sign(RawTransaction rawTxn){
    final privateKeyBytes = HexString(PRIVATE_KEY).toUint8Array();
    final signingKey = ed25519.newKeyFromSeed(privateKeyBytes.sublist(0, 32));
    final publicKey = ed25519.public(signingKey);

    final txnBuilder = TransactionBuilderEd25519(
      Uint8List.fromList(publicKey.bytes),
      (signingMessage) => Ed25519Signature(ed25519.sign(signingKey, signingMessage).sublist(0, 64)),
    );

    return txnBuilder.sign(rawTxn);
  }

  test("serialize entry function payload with no type args", () {
    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        "$ADDRESS_1::aptos_coin",
        "transfer",
        [],
        [bcsToBytes(AccountAddress.fromHex(ADDRESS_2)), bcsSerializeUint64(BigInt.one)],
      ),
    );

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(HexString(ADDRESS_3).hex()),
      BigInt.zero,
      entryFunctionPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c1800000000000000000200000000000000000000000000000000000000000000000000000000000012220a6170746f735f636f696e087472616e7366657200022000000000000000000000000000000000000000000000000000000000000000dd080100000000000000d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200409c570996380897f38b8d7008d726fb45d6ded0689216e56b73f523492cba92deb6671c27e9a44d2a6fdfdb497420d00c621297a23d6d0298895e0d58cff6060c",
    );
  });

  test("serialize entry function payload with type args", () {
    final token = TypeTagStruct(StructTag.fromString("$ADDRESS_4::aptos_coin::AptosCoin"));

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        "$ADDRESS_1::coin",
        "transfer",
        [token],
        [bcsToBytes(AccountAddress.fromHex(ADDRESS_2)), bcsSerializeUint64(BigInt.one)],
      ),
    );

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      entryFunctionPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c18000000000000000002000000000000000000000000000000000000000000000000000000000000122204636f696e087472616e73666572010700000000000000000000000000000000000000000000000000000000000000010a6170746f735f636f696e094170746f73436f696e00022000000000000000000000000000000000000000000000000000000000000000dd080100000000000000d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a4920040112162f543ca92b4f14c1b09b7f52894a127f5428b0d407c09c8efb3a136cff50e550aea7da1226f02571d79230b80bd79096ea0d796789ad594b8fbde695404",
    );
  });

  test("serialize entry function payload with type args but no function args", () {
    final token = TypeTagStruct(StructTag.fromString("$ADDRESS_4::aptos_coin::AptosCoin"));

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural("$ADDRESS_1::coin", "fake_func", [token], []),
    );

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      entryFunctionPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c18000000000000000002000000000000000000000000000000000000000000000000000000000000122204636f696e0966616b655f66756e63010700000000000000000000000000000000000000000000000000000000000000010a6170746f735f636f696e094170746f73436f696e0000d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200400e2d1cc4a27893cbae36d8b6a7150977c7620e065f359840413c5478a25f20a383250a9cdcb4fd71f7d171856f38972da30a9d10072e164614d96379004aa500",
    );
  });

  test("serialize script payload with no type args and no function args", () {
    final script = HEX.decode("a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102");

    final scriptPayload = TransactionPayloadScript(Script(Uint8List.fromList(script), [], []));

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      scriptPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c1800000000000000000026a11ceb0b030000000105000100000000050601000000000000000600000000000000001a01020000d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a4920040266935990105df40f3a82a3f41ad9ceb4b79451495403dd976191382bb07f8c9b401702968a64b5176762e62036f75c6fc2b770a0988716e41d469fff2349a08",
    );
  });

  test("serialize script payload with type args but no function args", () {
    final token = TypeTagStruct(StructTag.fromString("$ADDRESS_4::aptos_coin::AptosCoin"));

    final script = HEX.decode("a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102");

    final scriptPayload = TransactionPayloadScript(Script(Uint8List.fromList(script), [token], []));

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      scriptPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c1800000000000000000026a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102010700000000000000000000000000000000000000000000000000000000000000010a6170746f735f636f696e094170746f73436f696e0000d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a4920040bd241a6f31dfdfca0031ca5874fbf81800b5f632642321a11c41b4fead4b41d808617e91dd655fde7e9f263127f07bb5d56c7c925fe797728dcc9b55be120604",
    );
  });

  test("serialize script payload with type arg and function arg", () {
    final token = TypeTagStruct(StructTag.fromString("$ADDRESS_4::aptos_coin::AptosCoin"));

    final argU8 = TransactionArgumentU8(2);

    final script = HEX.decode("a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102");

    final scriptPayload = TransactionPayloadScript(Script(Uint8List.fromList(script), [token], [argU8]));
    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      scriptPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c1800000000000000000026a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102010700000000000000000000000000000000000000000000000000000000000000010a6170746f735f636f696e094170746f73436f696e00010002d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a49200409936b8d22cec685e720761f6c6135e020911f1a26e220e2a0f3317f5a68942531987259ac9e8688158c77df3e7136637056047d9524edad88ee45d61a9346602",
    );
  });

  test("serialize script payload with one type arg and two function args", () {
    final token = TypeTagStruct(StructTag.fromString("$ADDRESS_4::aptos_coin::AptosCoin"));

    final argU8Vec = TransactionArgumentU8Vector(bcsSerializeUint64(BigInt.one));
    final argAddress = TransactionArgumentAddress(AccountAddress.fromHex("0x01"));

    final script = HEX.decode("a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102");

    final scriptPayload = TransactionPayloadScript(Script(Uint8List.fromList(script), [token], [argU8Vec, argAddress]));

    final rawTxn = RawTransaction(
      AccountAddress.fromHex(ADDRESS_3),
      BigInt.zero,
      scriptPayload,
      BigInt.from(2000),
      BigInt.zero,
      BigInt.tryParse(TXN_EXPIRE)!,
      ChainId(4),
    );

    final signedTxn = sign(rawTxn);

    expect(hexSignedTxn(signedTxn),
      "000000000000000000000000000000000000000000000000000000000a550c1800000000000000000026a11ceb0b030000000105000100000000050601000000000000000600000000000000001a0102010700000000000000000000000000000000000000000000000000000000000000010a6170746f735f636f696e094170746f73436f696e000204080100000000000000030000000000000000000000000000000000000000000000000000000000000001d0070000000000000000000000000000ffffffffffffffff040020b9c6ee1630ef3e711144a648db06bbb2284f7274cfbee53ffcee503cc1a492004055c7499795ea68d7acfa64a58f19efa2ba3b977fa58ae93ae8c0732c0f6d6dd084d92bbe4edc2a0d687031cae90da117abfac16ebd902e764bdc38a2154a2102",
    );
  });

}
