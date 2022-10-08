
import 'dart:typed_data';

import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/identifier.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/transaction_builder/builder_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("BuilderUtils", (){
    test("parses a bool TypeTag", () {
      expect(TypeTagParser("bool").parseTypeTag() is TypeTagBool, true);
    });

    test("parses a u8 TypeTag", () {
      expect(TypeTagParser("u8").parseTypeTag() is TypeTagU8, true);
    });

    test("parses a u64 TypeTag", () {
      expect(TypeTagParser("u64").parseTypeTag() is TypeTagU64, true);
    });

    test("parses a u128 TypeTag", () {
      expect(TypeTagParser("u128").parseTypeTag() is TypeTagU128, true);
    });

    test("parses a address TypeTag", () {
      expect(TypeTagParser("address").parseTypeTag() is TypeTagAddress, true);
    });

    test("parses a vector TypeTag", () {
      final vectorAddress = TypeTagParser("vector<address>").parseTypeTag();
      expect(vectorAddress is TypeTagVector, true);
      expect((vectorAddress as TypeTagVector).value is TypeTagAddress, true);

      final vectorU64 = TypeTagParser(" vector < u64 > ").parseTypeTag();
      expect(vectorU64 is TypeTagVector, true);
      expect((vectorU64 as TypeTagVector).value is TypeTagU64, true);
    });

    test("parses a sturct TypeTag", () {
      // ignore: prefer_function_declarations_over_variables
      final assertStruct = (TypeTagStruct struct, String accountAddress, String moduleName, String structName) {
        expect(HexString.fromUint8Array(struct.value.address.address).toShortString(), accountAddress);
        expect(struct.value.moduleName.value, moduleName);
        expect(struct.value.name.value, structName);
      };
      final coin = TypeTagParser("0x1::test_coin::Coin").parseTypeTag();
      expect(coin is TypeTagStruct, true);
      assertStruct(coin as TypeTagStruct, "0x1", "test_coin", "Coin");

      final aptosCoin = TypeTagParser(
        "0x1::coin::CoinStore < 0x1::test_coin::AptosCoin1 ,  0x1::test_coin::AptosCoin2 > ",
      ).parseTypeTag();
      expect(aptosCoin is TypeTagStruct, true);
      assertStruct(aptosCoin as TypeTagStruct, "0x1", "coin", "CoinStore");

      final aptosCoinTrailingComma = TypeTagParser(
        "0x1::coin::CoinStore < 0x1::test_coin::AptosCoin1 ,  0x1::test_coin::AptosCoin2, > ",
      ).parseTypeTag();
      expect(aptosCoinTrailingComma is TypeTagStruct, true);
      assertStruct(aptosCoinTrailingComma as TypeTagStruct, "0x1", "coin", "CoinStore");

      final structTypeTags = aptosCoin.value.typeArgs;
      expect(structTypeTags.length, 2);

      final structTypeTag1 = structTypeTags[0];
      assertStruct(structTypeTag1 as TypeTagStruct, "0x1", "test_coin", "AptosCoin1");

      final structTypeTag2 = structTypeTags[1];
      assertStruct(structTypeTag2 as TypeTagStruct, "0x1", "test_coin", "AptosCoin2");

      final coinComplex = TypeTagParser(
        "0x1::coin::CoinStore < 0x2::coin::LPCoin < 0x1::test_coin::AptosCoin1 <u8>, vector<0x1::test_coin::AptosCoin2 > > >",
      ).parseTypeTag();

      expect(coinComplex is TypeTagStruct, true);
      assertStruct(coinComplex as TypeTagStruct, "0x1", "coin", "CoinStore");
      final coinComplexTypeTag = coinComplex.value.typeArgs[0];
      assertStruct(coinComplexTypeTag as TypeTagStruct, "0x2", "coin", "LPCoin");

      expect(() {
        TypeTagParser("0x1::test_coin").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::test_coin::CoinStore<0x1::test_coin::AptosCoin").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::test_coin::CoinStore<0x1::test_coin>").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1:test_coin::AptosCoin").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x!::test_coin::AptosCoin").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::test_coin::AptosCoin<").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::test_coin::CoinStore<0x1::test_coin::AptosCoin,").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::<::CoinStore<0x1::test_coin::AptosCoin,").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("0x1::test_coin::><0x1::test_coin::AptosCoin,").parseTypeTag();
      }, throwsArgumentError);

      expect(() {
        TypeTagParser("u32").parseTypeTag();
      }, throwsArgumentError);

    });

    test("serializes a boolean arg", () {
      var serializer = Serializer();
      serializeArg(true, TypeTagBool(), serializer);
      expect(serializer.getBytes(), Uint8List.fromList([0x01]));
      serializer = Serializer();
      expect(() {
        serializeArg(123, TypeTagBool(), serializer);
      }, throwsArgumentError);
    });

    test("serializes a u8 arg", () {
      var serializer = Serializer();
      serializeArg(255, TypeTagU8(), serializer);
      expect(serializer.getBytes(), [0xff]);

      serializer = Serializer();
      expect(() {
        serializeArg("u8", TypeTagU8(), serializer);
      }, throwsArgumentError);
    });

    test("serializes a u64 arg", () {
      var serializer = Serializer();
      serializeArg(BigInt.tryParse("18446744073709551615")!, TypeTagU64(), serializer);
      expect(serializer.getBytes(), [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);

      serializer = Serializer();
      expect(() {
        serializeArg("u64", TypeTagU64(), serializer);
      }, throwsA(isA<TypeError>()));
    });

    test("serializes a u128 arg", () {
      var serializer = Serializer();
      serializeArg(BigInt.tryParse("340282366920938463463374607431768211455")!, TypeTagU128(), serializer);
      expect(serializer.getBytes(),
        [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
      );

      serializer = Serializer();
      expect(() {
        serializeArg("u128", TypeTagU128(), serializer);
      }, throwsA(isA<TypeError>()));
    });

    test("serializes an AccountAddress arg", () {
      var serializer = Serializer();
      serializeArg("0x1", TypeTagAddress(), serializer);
      expect(HexString.fromUint8Array(serializer.getBytes()).toShortString(), "0x1");

      serializer = Serializer();
      serializeArg(AccountAddress.fromHex("0x1"), TypeTagAddress(), serializer);
      expect(HexString.fromUint8Array(serializer.getBytes()).toShortString(), "0x1");

      serializer = Serializer();
      expect(() {
        serializeArg(123456, TypeTagAddress(), serializer);
      }, throwsArgumentError);
    });

    test("serializes a vector arg", () {
      var serializer = Serializer();
      serializeArg([255], TypeTagVector(TypeTagU8()), serializer);
      expect(serializer.getBytes(), [0x1, 0xff]);

      serializer = Serializer();
      serializeArg("abc", TypeTagVector(TypeTagU8()), serializer);
      expect(serializer.getBytes(), [0x3, 0x61, 0x62, 0x63]);

      serializer = Serializer();
      serializeArg([0x61, 0x62, 0x63], TypeTagVector(TypeTagU8()), serializer);
      expect(serializer.getBytes(), [0x3, 0x61, 0x62, 0x63]);

      serializer = Serializer();
      expect(() {
        serializeArg(123456, TypeTagVector(TypeTagU8()), serializer);
      }, throwsArgumentError);
    });

    test("serializes a struct arg", () {
      var serializer = Serializer();
      serializeArg(
        "abc",
        TypeTagStruct(
          StructTag(AccountAddress.fromHex("0x1"), Identifier("string"), Identifier("String"), []),
        ),
        serializer,
      );
      expect(serializer.getBytes(), [0x3, 0x61, 0x62, 0x63]);

      serializer = Serializer();
      expect(() {
        serializeArg(
          "abc",
          TypeTagStruct(
            StructTag(AccountAddress.fromHex("0x3"), Identifier("token"), Identifier("Token"), []),
          ),
          serializer,
        );
      }, throwsArgumentError);
    });

    test("converts a boolean TransactionArgument", () {
      final res = argToTransactionArgument(true, TypeTagBool());
      expect((res as TransactionArgumentBool).value, true);
      expect(() {
        argToTransactionArgument(123, TypeTagBool());
      }, throwsArgumentError);
    });

    test("converts a u8 TransactionArgument", () {
      final res = argToTransactionArgument(123, TypeTagU8());
      expect((res as TransactionArgumentU8).value, 123);
      expect(() {
        argToTransactionArgument("u8", TypeTagBool());
      }, throwsArgumentError);
    });

    test("converts a u64 TransactionArgument", () {
      final res = argToTransactionArgument(123, TypeTagU64());
      expect((res as TransactionArgumentU64).value, BigInt.from(123));
      expect(() {
        argToTransactionArgument("u64", TypeTagU64());
      }, throwsA(isA<TypeError>()));
    });

    test("converts a u128 TransactionArgument", () {
      final res = argToTransactionArgument(123, TypeTagU128());
      expect((res as TransactionArgumentU128).value, BigInt.from(123));
      expect(() {
        argToTransactionArgument("u128", TypeTagU128());
      }, throwsA(isA<TypeError>()));
    });

    test("converts an AccountAddress TransactionArgument", () {
      var res = argToTransactionArgument("0x1", TypeTagAddress()) as TransactionArgumentAddress;
      expect(HexString.fromUint8Array(res.value.address).toShortString(), "0x1");

      res = argToTransactionArgument(AccountAddress.fromHex("0x2"), TypeTagAddress()) as TransactionArgumentAddress;
      expect(HexString.fromUint8Array(res.value.address).toShortString(), "0x2");

      expect(() {
        argToTransactionArgument(123456, TypeTagAddress());
      }, throwsArgumentError);
    });

    test("converts a vector TransactionArgument", ()  {
      final res = argToTransactionArgument(
        [0x1],
        TypeTagVector(TypeTagU8()),
      ) as TransactionArgumentU8Vector;
      expect(res.value, [0x1]);

      expect(() {
        argToTransactionArgument(123456, TypeTagVector(TypeTagU8()));
      }, throwsArgumentError);
    });

    test("ensures a boolean", () {
      expect(ensureBoolean(false), false);
      expect(ensureBoolean(true), true);
      expect(ensureBoolean("true"), true);
      expect(ensureBoolean("false"), false);
      expect(() => ensureBoolean("True"), throwsArgumentError);
    });

    test("ensures a number", () {
      expect(ensureNumber(10), 10);
      expect(ensureNumber("123"), 123);
      expect(() => ensureNumber("True"), throwsArgumentError);
    });

    test("ensures a bigint", () {
      expect(ensureBigInt(10), BigInt.from(10));
      expect(ensureBigInt("123"), BigInt.from(123));
      expect(() => ensureBigInt("True"), throwsA(isA<TypeError>()));
    });

  });
}