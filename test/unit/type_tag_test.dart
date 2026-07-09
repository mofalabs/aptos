import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/transactions/type_tag/parser.dart';
import 'package:aptos/src/transactions/type_tag/type_tag.dart';
import 'package:test/test.dart';

const expectedTypeTagString = '0x1::some_module::SomeResource';
const expectedTypeTagAddress = '0x1';

void main() {
  group('Deserialize TypeTags', () {
    test('deserializes a TypeTagBool correctly', () {
      final serializer = Serializer();
      final tag = TypeTagBool();
      expect(tag.isPrimitive(), true);
      expect(tag.isBool(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagBool>(),
      );
    });

    test('deserializes a TypeTagU8 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU8();
      expect(tag.isPrimitive(), true);
      expect(tag.isU8(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU8>(),
      );
    });

    test('deserializes a TypeTagU16 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU16();
      expect(tag.isPrimitive(), true);
      expect(tag.isU16(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU16>(),
      );
    });

    test('deserializes a TypeTagU32 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU32();
      expect(tag.isPrimitive(), true);
      expect(tag.isU32(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU32>(),
      );
    });

    test('deserializes a TypeTagU64 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU64();
      expect(tag.isPrimitive(), true);
      expect(tag.isU64(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU64>(),
      );
    });

    test('deserializes a TypeTagU128 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU128();
      expect(tag.isPrimitive(), true);
      expect(tag.isU128(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU128>(),
      );
    });

    test('deserializes a TypeTagU256 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagU256();
      expect(tag.isPrimitive(), true);
      expect(tag.isU256(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagU256>(),
      );
    });

    test('deserializes a TypeTagI8 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI8();
      expect(tag.isPrimitive(), true);
      expect(tag.isI8(), true);
      expect(tag.toString(), 'i8');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI8>());
      expect(deserialized.isI8(), true);
    });

    test('deserializes a TypeTagI16 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI16();
      expect(tag.isPrimitive(), true);
      expect(tag.isI16(), true);
      expect(tag.toString(), 'i16');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI16>());
      expect(deserialized.isI16(), true);
    });

    test('deserializes a TypeTagI32 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI32();
      expect(tag.isPrimitive(), true);
      expect(tag.isI32(), true);
      expect(tag.toString(), 'i32');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI32>());
      expect(deserialized.isI32(), true);
    });

    test('deserializes a TypeTagI64 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI64();
      expect(tag.isPrimitive(), true);
      expect(tag.isI64(), true);
      expect(tag.toString(), 'i64');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI64>());
      expect(deserialized.isI64(), true);
    });

    test('deserializes a TypeTagI128 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI128();
      expect(tag.isPrimitive(), true);
      expect(tag.isI128(), true);
      expect(tag.toString(), 'i128');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI128>());
      expect(deserialized.isI128(), true);
    });

    test('deserializes a TypeTagI256 correctly', () {
      final serializer = Serializer();
      final tag = TypeTagI256();
      expect(tag.isPrimitive(), true);
      expect(tag.isI256(), true);
      expect(tag.toString(), 'i256');

      tag.serialize(serializer);

      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized, isA<TypeTagI256>());
      expect(deserialized.isI256(), true);
    });

    test('deserializes a TypeTagAddress correctly', () {
      final serializer = Serializer();
      final tag = TypeTagAddress();
      expect(tag.isPrimitive(), true);
      expect(tag.isAddress(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagAddress>(),
      );
    });

    test('deserializes a TypeTagSigner correctly', () {
      final serializer = Serializer();
      final tag = TypeTagSigner();
      expect(tag.isSigner(), true);

      tag.serialize(serializer);

      expect(
        TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        isA<TypeTagSigner>(),
      );
    });

    test('deserializes TypeTagGeneric for ABI type parameters', () {
      final serializer = Serializer();
      final tag = TypeTagGeneric(3);
      expect(tag.toString(), 'T3');
      expect(tag.isGeneric(), true);

      tag.serialize(serializer);
      final restored =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(restored.isGeneric(), true);
      expect((restored as TypeTagGeneric).value, 3);
    });

    test('rejects negative generic type parameter indices', () {
      expect(
        () => TypeTagGeneric(-1),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('cannot be negative'),
        )),
      );
    });

    test('loads TypeTagReference via static load', () {
      final serializer = Serializer();
      TypeTagSigner().serialize(serializer);

      final restored =
          TypeTagReference.load(Deserializer(serializer.toUint8List()));
      expect(restored.value.isSigner(), true);
      expect(restored.toString(), '&signer');
    });

    test('parses reference type tags from Move syntax', () {
      final tag = parseTypeTag('&signer');
      expect(tag, isA<TypeTagReference>());
      final ref = tag as TypeTagReference;
      expect(ref.value.isSigner(), true);
      expect(ref.toString(), '&signer');
    });

    test('TypeTagReference serialize writes the reference variant tag', () {
      final ref = TypeTagReference(TypeTagSigner());
      final serializer = Serializer();
      ref.serialize(serializer);
      expect(serializer.toUint8List().length, greaterThan(0));
      expect(ref.toString(), '&signer');
    });

    test('primitive type tags expose stable Move syntax via toString', () {
      expect(TypeTagBool().toString(), 'bool');
      expect(TypeTagU128().toString(), 'u128');
      expect(TypeTagAddress().toString(), 'address');
    });

    test('TypeTagStruct toString includes generic type arguments', () {
      final parsed = parseTypeTag('0x1::some_module::SomeResource');
      expect(parsed.isStruct(), true);
      final parsedStruct = parsed as TypeTagStruct;
      final tag = TypeTagStruct(
        StructTag(
          parsedStruct.value.address,
          parsedStruct.value.moduleName,
          parsedStruct.value.name,
          [TypeTagU8()],
        ),
      );
      expect(tag.toString(), '0x1::some_module::SomeResource<u8>');
    });

    test('throws when deserializing an unknown TypeTag variant index', () {
      final serializer = Serializer();
      serializer.serializeU32AsUleb128(100);
      expect(
        () => TypeTag.deserialize(Deserializer(serializer.toUint8List())),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unknown variant index for TypeTag'),
        )),
      );
    });

    test('deserializes a TypeTagVector correctly', () {
      final serializer = Serializer();
      final tag = TypeTagVector(TypeTagU32());
      expect(tag.isPrimitive(), false);
      expect(tag.toString(), 'vector<u32>');

      tag.serialize(serializer);
      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized.isVector(), true);
      expect((deserialized as TypeTagVector).value, isA<TypeTagU32>());
    });

    test('deserializes a TypeTagStruct correctly', () {
      final serializer = Serializer();
      final tag = parseTypeTag(expectedTypeTagString);
      expect(tag.isPrimitive(), false);

      tag.serialize(serializer);
      final deserialized =
          TypeTag.deserialize(Deserializer(serializer.toUint8List()));
      expect(deserialized.isStruct(), true);
      final struct = deserialized as TypeTagStruct;
      expect(struct.value, isA<StructTag>());
      expect(struct.value.address.toString(), expectedTypeTagAddress);
      expect(struct.value.moduleName.identifier, 'some_module');
      expect(struct.value.name.identifier, 'SomeResource');
      expect(struct.value.typeArgs.length, 0);
    });
  });

  group('TypeTag helpers and BCS layout', () {
    test('TypeTagVector.u8 factory', () {
      final tag = TypeTagVector.u8();
      expect(tag.value, isA<TypeTagU8>());
      expect(tag.toString(), 'vector<u8>');
    });

    test('struct tag helper functions', () {
      expect(TypeTagStruct(aptosCoinStructTag()).toString(),
          '0x1::aptos_coin::AptosCoin');
      expect(TypeTagStruct(stringStructTag()).toString(), '0x1::string::String');
      expect(TypeTagStruct(optionStructTag(TypeTagU8())).toString(),
          '0x1::option::Option<u8>');
      expect(TypeTagStruct(objectStructTag(TypeTagU8())).toString(),
          '0x1::object::Object<u8>');

      final stringTag = TypeTagStruct(stringStructTag());
      expect(stringTag.isString(), true);
      expect(stringTag.isOption(), false);
      expect(stringTag.isObject(), false);
      expect(TypeTagStruct(optionStructTag(TypeTagU8())).isOption(), true);
      expect(TypeTagStruct(objectStructTag(TypeTagU8())).isObject(), true);
    });

    test('canonical Move string for nested struct type', () {
      final tag = parseTypeTag('0x1::coin::Coin<0x1::aptos_coin::AptosCoin>');
      expect(tag.toString(), '0x1::coin::Coin<0x1::aptos_coin::AptosCoin>');
    });

    test('StructTag BCS layout byte-matches the expected layout', () {
      // 0x1::aptos_coin::AptosCoin
      final structTag = aptosCoinStructTag();
      final bytes = structTag.bcsToBytes();
      final expected = <int>[
        // address 0x1 (32 bytes)
        ...List<int>.filled(31, 0), 1,
        // module name "aptos_coin" (uleb len + utf8)
        10, ...'aptos_coin'.codeUnits,
        // struct name "AptosCoin"
        9, ...'AptosCoin'.codeUnits,
        // typeArgs vector length 0
        0,
      ];
      expect(bytes, expected);
    });

    test('TypeTagStruct BCS layout writes struct variant then StructTag', () {
      final tag = TypeTagStruct(optionStructTag(TypeTagU8()));
      final bytes = tag.bcsToBytes();
      final expected = <int>[
        7, // struct variant
        ...List<int>.filled(31, 0), 1, // address 0x1
        6, ...'option'.codeUnits,
        6, ...'Option'.codeUnits,
        1, // one type argument
        1, // u8 variant
      ];
      expect(bytes, expected);
    });

    test('serialize/deserialize round trip preserves bytes', () {
      final tags = <TypeTag>[
        TypeTagBool(),
        TypeTagU8(),
        TypeTagU16(),
        TypeTagU32(),
        TypeTagU64(),
        TypeTagU128(),
        TypeTagU256(),
        TypeTagI8(),
        TypeTagI16(),
        TypeTagI32(),
        TypeTagI64(),
        TypeTagI128(),
        TypeTagI256(),
        TypeTagAddress(),
        TypeTagSigner(),
        TypeTagVector(TypeTagVector(TypeTagU8())),
        TypeTagStruct(optionStructTag(TypeTagVector(TypeTagU64()))),
      ];
      for (final tag in tags) {
        final bytes = tag.bcsToBytes();
        final restored = TypeTag.deserialize(Deserializer(bytes));
        expect(restored.bcsToBytes(), bytes);
        expect(restored.toString(), tag.toString());
      }
    });
  });
}
