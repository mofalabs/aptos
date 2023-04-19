
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/transaction_builder/builder_utils.dart';
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

}