
import 'package:aptos/aptos.dart';
import 'package:flutter_test/flutter_test.dart';


class ExpectedTypeTag {
    static const String string = "0x0000000000000000000000000000000000000000000000000000000000000001::aptos_coin::AptosCoin";
    static const String address = "0x0000000000000000000000000000000000000000000000000000000000000001";
    static const String moduleName = "aptos_coin";
    static const String name = "AptosCoin";
}

void main() {

  group("StructTag", () {
    test("make sure StructTag.fromString works with un-nested type tag", () {
      final structTag = StructTag.fromString(ExpectedTypeTag.string);
      expect(structTag.address.hexAddress() == ExpectedTypeTag.address, true);
      expect(structTag.moduleName.value == ExpectedTypeTag.moduleName, true);
      expect(structTag.name.value == ExpectedTypeTag.name, true);
      expect(structTag.typeArgs.isEmpty, true);
    });

    test("make sure StructTag.fromString works with nested type tag", () {
      final structTag = StructTag.fromString(
        "${ExpectedTypeTag.string}<${ExpectedTypeTag.string}, ${ExpectedTypeTag.string}>",
      );
      expect(structTag.address.hexAddress() == ExpectedTypeTag.address, true);
      expect(structTag.moduleName.value == ExpectedTypeTag.moduleName, true);
      expect(structTag.name.value == ExpectedTypeTag.name, true);
      expect(structTag.typeArgs.length == 2, true);

      // make sure the nested type tag is correct
      for (final typeArg in structTag.typeArgs) {
        final nestedTypeTag = typeArg as TypeTagStruct;
        expect(nestedTypeTag.value.address.hexAddress() == ExpectedTypeTag.address, true);
        expect(nestedTypeTag.value.moduleName.value == ExpectedTypeTag.moduleName, true);
        expect(nestedTypeTag.value.name.value == ExpectedTypeTag.name, true);
        expect(nestedTypeTag.value.typeArgs.isEmpty, true);
      }
    });
  });

  group("TypeTagParser", () {
    test("make sure parseTypeTag throws TypeTagParserError 'Invalid type tag' if invalid format", () {
      String typeTag = "0x000";
      var parser = TypeTagParser(typeTag);

      expect(() {
        parser.parseTypeTag();
      }, throwsArgumentError);

      typeTag = "0x1::aptos_coin::AptosCoin<0x1>";
      parser = TypeTagParser(typeTag);

      expect(() {
        parser.parseTypeTag();
      }, throwsArgumentError);
    });

    test("make sure parseTypeTag works with un-nested type tag", () {
      final parser = TypeTagParser(ExpectedTypeTag.string);
      final result = parser.parseTypeTag() as TypeTagStruct;
      expect(result.value.address.hexAddress() == ExpectedTypeTag.address, true);
      expect(result.value.moduleName.value == ExpectedTypeTag.moduleName, true);
      expect(result.value.name.value == ExpectedTypeTag.name, true);
      expect(result.value.typeArgs.isEmpty, true);
    });

    test("make sure parseTypeTag works with nested type tag", () {
      const typeTag = "0x1::aptos_coin::AptosCoin<0x1::aptos_coin::AptosCoin, 0x1::aptos_coin::AptosCoin>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag() as TypeTagStruct;
      expect(result.value.address.hexAddress() == ExpectedTypeTag.address, true);
      expect(result.value.moduleName.value == ExpectedTypeTag.moduleName, true);
      expect(result.value.name.value == ExpectedTypeTag.name, true);
      expect(result.value.typeArgs.length == 2, true);

      // make sure the nested type tag is correct
      for (final typeArg in result.value.typeArgs) {
        final nestedTypeTag = typeArg as TypeTagStruct;
        expect(nestedTypeTag.value.address.hexAddress() == ExpectedTypeTag.address, true);
        expect(nestedTypeTag.value.moduleName.value == ExpectedTypeTag.moduleName, true);
        expect(nestedTypeTag.value.name.value == ExpectedTypeTag.name, true);
        expect(nestedTypeTag.value.typeArgs.isEmpty, true);
      }
    });
  });

  group("parse Object type", () {
    test("TypeTagParser successfully parses an Object type", () {
      const typeTag = "0x1::object::Object<T>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag();
      expect(result is TypeTagAddress, true);
    });

    test("TypeTagParser successfully parses complex Object types", () {
      const typeTag = "0x1::object::Object<T>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag();
      expect(result is TypeTagAddress, true);

      const typeTag2 = "0x1::object::Object<0x1::coin::Fun<A, B<C>>>";
      final parser2 = TypeTagParser(typeTag2);
      final result2 = parser2.parseTypeTag();
      expect(result2 is TypeTagAddress, true);
    });

    test("TypeTagParser does not parse unofficial objects", () {
      const typeTag = "0x12345::object::Object<T>";
      final parser = TypeTagParser(typeTag);
      expect(() => parser.parseTypeTag(), throwsArgumentError);
    });

    test("TypeTagParser successfully parses an Option type", () {
      const typeTag = "0x1::option::Option<u8>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag();

      if (result is TypeTagStruct) {
        final u8TypeTag = optionStructTag(TypeTagU8());
        expect(result.value.address.hexAddress(), equals(u8TypeTag.address.hexAddress()));
        expect(result.value.moduleName.value, equals(u8TypeTag.moduleName.value));
        expect(result.value.name.value, equals(u8TypeTag.name.value));
      } else {
        fail("Not an option $result");
      }
    });

    test("TypeTagParser successfully parses a strcut with a nested Object type", () {
      const typeTag = "0x1::some_module::SomeResource<0x1::object::Object<T>>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag() as TypeTagStruct;
      expect(result.value.address.hexAddress(), ExpectedTypeTag.address);
      expect(result.value.moduleName.value, "some_module");
      expect(result.value.name.value, "SomeResource");
      expect(result.value.typeArgs[0] is TypeTagAddress, true);
    });

    test("TypeTagParser successfully parses a strcut with a nested Object and Struct types", () {
      const typeTag = "0x1::some_module::SomeResource<0x1::object::Object<T>, 0x1::some_module::SomeResource>";
      final parser = TypeTagParser(typeTag);
      final result = parser.parseTypeTag() as TypeTagStruct;
      expect(result.value.address.hexAddress(), ExpectedTypeTag.address);
      expect(result.value.moduleName.value, "some_module");
      expect(result.value.name.value, "SomeResource");
      expect(result.value.typeArgs.length, 2);
      expect(result.value.typeArgs[0] is TypeTagAddress, true);
      expect(result.value.typeArgs[1] is TypeTagStruct, true);
    });
  });

  group("supports generic types", () {
    test("throws an error when the type to use is not provided", () {
      const typeTag = "T0";
      final parser = TypeTagParser(typeTag);
      expect(() {
        parser.parseTypeTag();
      }, throwsArgumentError);
    });

    test("successfully parses a generic type tag to the provided type", () {
      const typeTag = "T0";
      final parser = TypeTagParser(typeTag, ["bool"]);
      final result = parser.parseTypeTag();
      expect(result is TypeTagBool, true);
    });
  });

group("Deserialize TypeTags", () {
  test("deserializes a TypeTagBool correctly", () {
    final serializer = Serializer();
    final tag = TypeTagBool();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagBool, true);
  });

  test("deserializes a TypeTagU8 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU8();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU8, true);
  });

  test("deserializes a TypeTagU16 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU16();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU16, true);
  });

  test("deserializes a TypeTagU32 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU32();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU32, true);
  });

  test("deserializes a TypeTagU64 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU64();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU64, true);
  });

  test("deserializes a TypeTagU128 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU128();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU128, true);
  });

  test("deserializes a TypeTagU256 correctly", () {
    final serializer = Serializer();
    final tag = TypeTagU256();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagU256, true);
  });

  test("deserializes a TypeTagAddress correctly", () {
    final serializer = Serializer();
    final tag = TypeTagAddress();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagAddress, true);
  });

  test("deserializes a TypeTagSigner correctly", () {
    final serializer = Serializer();
    final tag = TypeTagSigner();

    tag.serialize(serializer);

    expect(TypeTag.deserialize(Deserializer(serializer.getBytes())) is TypeTagSigner, true);
  });

  test("deserializes a TypeTagVector correctly", () {
    final serializer = Serializer();
    final tag = TypeTagVector(TypeTagU32());

    tag.serialize(serializer);
    final deserialized = TypeTag.deserialize(Deserializer(serializer.getBytes())) as TypeTagVector;
    expect(deserialized.value is TypeTagU32, true);
  });

  test("deserializes a TypeTagStruct correctly", () {
    final serializer = Serializer();
    final tag = TypeTagStruct(StructTag.fromString(ExpectedTypeTag.string));

    tag.serialize(serializer);
    final deserialized = TypeTag.deserialize(Deserializer(serializer.getBytes())) as TypeTagStruct;
    expect(deserialized.value.address.hexAddress(), ExpectedTypeTag.address);
    expect(deserialized.value.moduleName.value, ExpectedTypeTag.moduleName);
    expect(deserialized.value.name.value, ExpectedTypeTag.name);
    expect(deserialized.value.typeArgs.length, 0);
  });
});

}