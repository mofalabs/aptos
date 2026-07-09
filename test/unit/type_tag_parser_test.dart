import 'package:aptos/src/core/account_address.dart';
import 'package:aptos/src/transactions/instances/identifier.dart';
import 'package:aptos/src/transactions/type_tag/parser.dart';
import 'package:aptos/src/transactions/type_tag/type_tag.dart';
import 'package:test/test.dart';

const tagStructName = '0x1::tag::Tag';
const aptosCoin = '0x1::aptos_coin::AptosCoin';

TypeTagStruct structTagType([List<TypeTag>? typeTags]) => TypeTagStruct(
      StructTag(
        AccountAddress.one,
        Identifier('tag'),
        Identifier('Tag'),
        typeTags ?? [],
      ),
    );

/// Structural equality check: same runtime type and same canonical Move
/// string (which fully captures nested type arguments).
void expectTag(TypeTag actual, TypeTag expected) {
  expect(actual.runtimeType, expected.runtimeType,
      reason: 'expected ${expected.runtimeType}, got ${actual.runtimeType}');
  expect(actual.toString(), expected.toString());
}

void typeTagParserError(
  String str,
  TypeTagParserErrorType errorType, [
  String? subStr,
]) {
  expect(
    () => parseTypeTag(str),
    throwsA(isA<TypeTagParserError>().having(
      (e) => e.message,
      'message',
      "Failed to parse typeTag '${subStr ?? str}', ${errorType.value}",
    )),
    reason: 'input: $str',
  );
}

/// These types are primitives, and we ignore casing on them
final primitives = <(String, TypeTag)>[
  ('signer', TypeTagSigner()),
  ('address', TypeTagAddress()),
  ('bool', TypeTagBool()),
  ('u8', TypeTagU8()),
  ('u16', TypeTagU16()),
  ('u32', TypeTagU32()),
  ('u64', TypeTagU64()),
  ('u128', TypeTagU128()),
  ('u256', TypeTagU256()),
  ('i8', TypeTagI8()),
  ('i16', TypeTagI16()),
  ('i32', TypeTagI32()),
  ('i64', TypeTagI64()),
  ('i128', TypeTagI128()),
  ('i256', TypeTagI256()),
];

/// Known struct types without inner arguments
final structTypes = <(String, TypeTag)>[
  ('0x1::string::String', TypeTagStruct(stringStructTag())),
  (aptosCoin, TypeTagStruct(aptosCoinStructTag())),
  ('0x1::option::Option<u8>', TypeTagStruct(optionStructTag(TypeTagU8()))),
  ('0x1::object::Object<u8>', TypeTagStruct(objectStructTag(TypeTagU8()))),
  (tagStructName, structTagType()),
  ('$tagStructName<u8>', structTagType([TypeTagU8()])),
  ('$tagStructName<u8, u8>', structTagType([TypeTagU8(), TypeTagU8()])),
  ('$tagStructName<u64, u8>', structTagType([TypeTagU64(), TypeTagU8()])),
  (
    '$tagStructName<$tagStructName<u8>, u8>',
    structTagType([
      structTagType([TypeTagU8()]),
      TypeTagU8(),
    ])
  ),
  (
    '$tagStructName<u8, $tagStructName<u8>>',
    structTagType([
      TypeTagU8(),
      structTagType([TypeTagU8()]),
    ])
  ),
];

/// Some examples with generics
final generics = <(String, TypeTag)>[
  ('T0', TypeTagGeneric(0)),
  ('T1', TypeTagGeneric(1)),
  ('T1337', TypeTagGeneric(1337)),
  ('$tagStructName<T0>', structTagType([TypeTagGeneric(0)])),
  (
    '$tagStructName<T0, T1>',
    structTagType([TypeTagGeneric(0), TypeTagGeneric(1)])
  ),
];

/// These types have no inner types
final combinedTypes = [...primitives, ...structTypes];
final combinedTypesWithGeneric = [...primitives, ...structTypes, ...generics];

void main() {
  group('TypeTagParser', () {
    test('invalid types', () {
      // Missing 8
      typeTagParserError('8', TypeTagParserErrorType.invalidTypeTag);

      // Addr isn't a type
      typeTagParserError('addr', TypeTagParserErrorType.invalidTypeTag);

      // Standalone generic (with allow generics off)
      typeTagParserError('T1', TypeTagParserErrorType.unexpectedGenericType);

      // Not enough colons
      typeTagParserError(
          '0x1:tag::Tag', TypeTagParserErrorType.unexpectedStructFormat);
      typeTagParserError(
          '0x1::tag:Tag', TypeTagParserErrorType.unexpectedStructFormat);

      // Invalid inner type
      typeTagParserError(
          '0x1::tag::Tag<8>', TypeTagParserErrorType.invalidTypeTag, '8');

      // Invalid spacing around type arguments
      typeTagParserError('0x1::tag::Tag <u8>',
          TypeTagParserErrorType.unexpectedWhitespaceCharacter);

      // Invalid type argument combinations
      typeTagParserError('0x1::tag::Tag<<u8>',
          TypeTagParserErrorType.missingTypeArgumentClose);
      typeTagParserError('0x1::tag::Tag<<u8 u8>',
          TypeTagParserErrorType.unexpectedWhitespaceCharacter);
      typeTagParserError('0x1::tag::Tag<u8>>',
          TypeTagParserErrorType.unexpectedTypeArgumentClose);

      // Comma separated arguments not in type arguments
      typeTagParserError('u8, u8', TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('u8,u8', TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('u8 ,u8', TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('0x1::tag::Tag<u8>,0x1::tag::Tag',
          TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('0x1::tag::Tag<u8>, 0x1::tag::Tag',
          TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('0x1::tag::Tag<u8> ,0x1::tag::Tag',
          TypeTagParserErrorType.unexpectedComma);
      typeTagParserError('0x1::tag::Tag<u8> , 0x1::tag::Tag',
          TypeTagParserErrorType.unexpectedComma);

      typeTagParserError('0x1::tag::Tag<u8<u8>>',
          TypeTagParserErrorType.unexpectedPrimitiveTypeArguments, 'u8');

      typeTagParserError('0x1::tag::Tag<u8><u8>',
          TypeTagParserErrorType.unexpectedPrimitiveTypeArguments, 'u8');
      typeTagParserError('0x1<u8>::tag::Tag<u8>',
          TypeTagParserErrorType.unexpectedPrimitiveTypeArguments, 'u8');
      typeTagParserError('0x1::tag<u8>::Tag<u8>',
          TypeTagParserErrorType.unexpectedPrimitiveTypeArguments, 'u8');

      // Invalid type tags without arguments
      typeTagParserError(
          '0x1::tag::Tag<>', TypeTagParserErrorType.typeArgumentCountMismatch);
      typeTagParserError(
          '0x1::tag::Tag<,>', TypeTagParserErrorType.missingTypeArgument);
      typeTagParserError(
          '0x1::tag::Tag<, >', TypeTagParserErrorType.missingTypeArgument);
      typeTagParserError(
          '0x1::tag::Tag< ,>', TypeTagParserErrorType.missingTypeArgument);
      typeTagParserError(
          '0x1::tag::Tag< , >', TypeTagParserErrorType.missingTypeArgument);
      typeTagParserError('0x1::tag::Tag<u8,>',
          TypeTagParserErrorType.typeArgumentCountMismatch);
      typeTagParserError('0x1::tag::Tag<0x1::tag::Tag<>>>',
          TypeTagParserErrorType.typeArgumentCountMismatch);
      typeTagParserError('0x1::tag::Tag<0x1::tag::Tag<u8,>>>',
          TypeTagParserErrorType.typeArgumentCountMismatch);
      typeTagParserError('0x1::tag::Tag<0x1::tag::Tag<,u8>>>',
          TypeTagParserErrorType.missingTypeArgument);
      typeTagParserError(
          '0x1::tag::Tag<,u8>', TypeTagParserErrorType.missingTypeArgument);
    });

    test('invalid struct types', () {
      void expectErrorContains(String input, TypeTagParserErrorType errorType) {
        expect(
          () => parseTypeTag(input),
          throwsA(isA<TypeTagParserError>().having(
            (e) => e.message,
            'message',
            contains(errorType.value),
          )),
          reason: 'input: $input',
        );
      }

      expectErrorContains(
          'notAnAddress::tag::Tag<u8>', TypeTagParserErrorType.invalidAddress);
      expectErrorContains('0x1::not-a-module::Tag<u8>',
          TypeTagParserErrorType.invalidModuleNameCharacter);
      expectErrorContains('0x1::tag::Not-A-Name<u8>',
          TypeTagParserErrorType.invalidStructNameCharacter);
    });

    test('standard types', () {
      for (final (str, type) in combinedTypes) {
        expectTag(parseTypeTag(str), type);
        expectTag(parseTypeTag(' $str'), type);
        expectTag(parseTypeTag('$str '), type);
        expectTag(parseTypeTag(' $str '), type);
      }
    });

    test('capitalized primitive types', () {
      for (final (str, type) in primitives) {
        expectTag(parseTypeTag(str.toUpperCase()), type);
      }
    });

    test('reference types', () {
      for (final (str, type) in combinedTypes) {
        expectTag(parseTypeTag('&$str'), TypeTagReference(type));
      }
    });

    test('generic types with allow generics on', () {
      for (final (str, type) in combinedTypesWithGeneric) {
        expectTag(parseTypeTag(str, allowGenerics: true), type);
        expectTag(
          parseTypeTag('&$str', allowGenerics: true),
          TypeTagReference(type),
        );
        expectTag(
          parseTypeTag('vector<$str>', allowGenerics: true),
          TypeTagVector(type),
        );
        expectTag(
          parseTypeTag('0x1::tag::Tag<$str, $str>', allowGenerics: true),
          structTagType([type, type]),
        );
      }
    });

    test('generic types with allow generics off', () {
      for (final (str, _) in generics) {
        expect(
          () => parseTypeTag(str),
          throwsA(isA<TypeTagParserError>()),
          reason: 'input: $str',
        );
      }
    });

    test('vector', () {
      for (final (str, type) in combinedTypes) {
        expectTag(parseTypeTag('vector<$str>'), TypeTagVector(type));
        expectTag(parseTypeTag('vector< $str>'), TypeTagVector(type));
        expectTag(parseTypeTag('vector<$str >'), TypeTagVector(type));
        expectTag(parseTypeTag('vector< $str >'), TypeTagVector(type));
      }
    });

    test('nested vector', () {
      for (final (str, type) in combinedTypes) {
        expectTag(
          parseTypeTag('vector<vector<$str>>'),
          TypeTagVector(TypeTagVector(type)),
        );
      }
    });

    test('object', () {
      for (final (str, type) in structTypes) {
        expectTag(
          parseTypeTag('0x1::object::Object<$str>'),
          TypeTagStruct(objectStructTag(type)),
        );
      }
    });

    test('option', () {
      for (final (str, type) in combinedTypes) {
        expectTag(
          parseTypeTag('0x1::option::Option<$str>'),
          TypeTagStruct(optionStructTag(type)),
        );
      }
    });

    test('0x1::tag::Tag<0x1::tag::Tag<u8>, u8>', () {
      expectTag(
        parseTypeTag('0x1::tag::Tag<0x1::tag::Tag<u8>, u8>'),
        structTagType([
          structTagType([TypeTagU8()]),
          TypeTagU8(),
        ]),
      );
    });

    test('0x1::tag::Tag<0x1::tag::Tag<0x1::tag::Tag<u8>>, u8>', () {
      expectTag(
        parseTypeTag('0x1::tag::Tag<0x1::tag::Tag<0x1::tag::Tag<u8>>, u8>'),
        structTagType([
          structTagType([
            structTagType([TypeTagU8()]),
          ]),
          TypeTagU8(),
        ]),
      );
    });

    test('invalid type args', () {
      for (final (str, _) in primitives) {
        expect(
          () => parseTypeTag('$str<u8>'),
          throwsA(isA<TypeTagParserError>().having(
            (e) => e.message,
            'message',
            contains(
                TypeTagParserErrorType.unexpectedPrimitiveTypeArguments.value),
          )),
          reason: 'input: $str<u8>',
        );
      }
      expect(
        () => parseTypeTag('vector<>'),
        throwsA(isA<TypeTagParserError>().having(
          (e) => e.message,
          'message',
          contains(TypeTagParserErrorType.typeArgumentCountMismatch.value),
        )),
      );
      expect(
        () => parseTypeTag('vector<u8, u8>'),
        throwsA(isA<TypeTagParserError>().having(
          (e) => e.message,
          'message',
          contains(
              TypeTagParserErrorType.unexpectedVectorTypeArgumentCount.value),
        )),
      );
    });

    // These are debatable on whether they are valid or not
    test('edge case invalid types', () {
      expect(() => parseTypeTag('0x1::tag::Tag< , u8>'),
          throwsA(isA<TypeTagParserError>()));
      expect(() => parseTypeTag('0x1::tag::Tag<,u8>'),
          throwsA(isA<TypeTagParserError>()));
    });

    test('signed integer types', () {
      // Test basic parsing
      expectTag(parseTypeTag('i8'), TypeTagI8());
      expectTag(parseTypeTag('i16'), TypeTagI16());
      expectTag(parseTypeTag('i32'), TypeTagI32());
      expectTag(parseTypeTag('i64'), TypeTagI64());
      expectTag(parseTypeTag('i128'), TypeTagI128());
      expectTag(parseTypeTag('i256'), TypeTagI256());

      // Test case insensitivity
      expectTag(parseTypeTag('I8'), TypeTagI8());
      expectTag(parseTypeTag('I16'), TypeTagI16());
      expectTag(parseTypeTag('I32'), TypeTagI32());
      expectTag(parseTypeTag('I64'), TypeTagI64());
      expectTag(parseTypeTag('I128'), TypeTagI128());
      expectTag(parseTypeTag('I256'), TypeTagI256());

      // Test with whitespace
      expectTag(parseTypeTag(' i8 '), TypeTagI8());
      expectTag(parseTypeTag(' i64 '), TypeTagI64());
    });

    test('signed integers in vectors', () {
      expectTag(parseTypeTag('vector<i8>'), TypeTagVector(TypeTagI8()));
      expectTag(parseTypeTag('vector<i16>'), TypeTagVector(TypeTagI16()));
      expectTag(parseTypeTag('vector<i32>'), TypeTagVector(TypeTagI32()));
      expectTag(parseTypeTag('vector<i64>'), TypeTagVector(TypeTagI64()));
      expectTag(parseTypeTag('vector<i128>'), TypeTagVector(TypeTagI128()));
      expectTag(parseTypeTag('vector<i256>'), TypeTagVector(TypeTagI256()));
    });

    test('signed integers in struct type arguments', () {
      expectTag(
        parseTypeTag('$tagStructName<i8>'),
        structTagType([TypeTagI8()]),
      );
      expectTag(
        parseTypeTag('$tagStructName<i8, i16>'),
        structTagType([TypeTagI8(), TypeTagI16()]),
      );
      expectTag(
        parseTypeTag('$tagStructName<i64, u64>'),
        structTagType([TypeTagI64(), TypeTagU64()]),
      );
      expectTag(
        parseTypeTag('$tagStructName<$tagStructName<i32>, i64>'),
        structTagType([
          structTagType([TypeTagI32()]),
          TypeTagI64(),
        ]),
      );
    });

    test('signed integers with references', () {
      expectTag(parseTypeTag('&i8'), TypeTagReference(TypeTagI8()));
      expectTag(parseTypeTag('&i64'), TypeTagReference(TypeTagI64()));
      expectTag(parseTypeTag('&i128'), TypeTagReference(TypeTagI128()));
    });

    test('signed integers in option and object', () {
      expectTag(
        parseTypeTag('0x1::option::Option<i8>'),
        TypeTagStruct(optionStructTag(TypeTagI8())),
      );
      expectTag(
        parseTypeTag('0x1::option::Option<i64>'),
        TypeTagStruct(optionStructTag(TypeTagI64())),
      );
      expectTag(
        parseTypeTag('0x1::object::Object<0x1::tag::Tag<i32>>'),
        TypeTagStruct(objectStructTag(structTagType([TypeTagI32()]))),
      );
    });

    test('mixed unsigned and signed integers', () {
      expectTag(
        parseTypeTag('$tagStructName<u8, i8>'),
        structTagType([TypeTagU8(), TypeTagI8()]),
      );
      expectTag(
        parseTypeTag('$tagStructName<i16, u16, i32, u32>'),
        structTagType([TypeTagI16(), TypeTagU16(), TypeTagI32(), TypeTagU32()]),
      );
      expectTag(
        parseTypeTag('vector<$tagStructName<u64, i64>>'),
        TypeTagVector(structTagType([TypeTagU64(), TypeTagI64()])),
      );
    });

    test('signed integers cannot have type arguments', () {
      for (final input in ['i8<u8>', 'i64<i32>', 'i128<u128>']) {
        expect(
          () => parseTypeTag(input),
          throwsA(isA<TypeTagParserError>().having(
            (e) => e.message,
            'message',
            contains(
                TypeTagParserErrorType.unexpectedPrimitiveTypeArguments.value),
          )),
          reason: 'input: $input',
        );
      }
    });
  });
}
