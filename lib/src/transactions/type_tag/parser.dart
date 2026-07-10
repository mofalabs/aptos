import '../../core/account_address.dart';
import '../instances/identifier.dart';
import 'type_tag.dart';

/// Determines if the provided string is a valid Move identifier, which can
/// only contain alphanumeric characters and underscores.
bool _isValidIdentifier(String str) {
  return RegExp(r'^[_a-zA-Z0-9]+$').hasMatch(str);
}

/// Determines if the provided character is a whitespace character. This
/// function only works for single characters.
bool _isValidWhitespaceCharacter(String char) {
  return RegExp(r'\s').hasMatch(char);
}

/// Determines if a given string represents a generic type from the ABI,
/// specifically in the format T0, T1, etc.
bool _isGeneric(String str) {
  return RegExp(r'^T[0-9]+$').hasMatch(str);
}

/// Determines if the provided string is a reference type, which is indicated
/// by starting with an ampersand (&).
bool _isRef(String str) {
  return RegExp(r'^&.+$').hasMatch(str);
}

/// Determines if the provided string represents a primitive type.
bool _isPrimitive(String str) {
  switch (str) {
    case 'signer':
    case 'address':
    case 'bool':
    case 'u8':
    case 'u16':
    case 'u32':
    case 'u64':
    case 'u128':
    case 'u256':
    case 'i8':
    case 'i16':
    case 'i32':
    case 'i64':
    case 'i128':
    case 'i256':
      return true;
    default:
      return false;
  }
}

/// Consumes all whitespace characters in a string starting from a specified
/// position. Returns the new position in the string after consuming
/// whitespace.
int _consumeWhitespace(String tagStr, int pos) {
  var i = pos;
  for (; i < tagStr.length; i += 1) {
    final innerChar = tagStr[i];

    if (!_isValidWhitespaceCharacter(innerChar)) {
      // If it's not colons, and it's an invalid character, we will stop here
      break;
    }
  }
  return i;
}

/// State for TypeTag parsing, maintained on a stack to track the current
/// parsing state.
class _TypeTagState {
  final int savedExpectedTypes;
  final String savedStr;
  final List<TypeTag> savedTypes;

  _TypeTagState({
    required this.savedExpectedTypes,
    required this.savedStr,
    required this.savedTypes,
  });
}

/// Error types related to parsing type tags, indicating various issues
/// encountered during the parsing process.
enum TypeTagParserErrorType {
  invalidTypeTag('unknown type'),
  unexpectedGenericType('unexpected generic type'),
  unexpectedTypeArgumentClose("unexpected '>'"),
  unexpectedWhitespaceCharacter('unexpected whitespace character'),
  unexpectedComma("unexpected ','"),
  typeArgumentCountMismatch(
      "type argument count doesn't match expected amount"),
  missingTypeArgumentClose("no matching '>' for '<'"),
  missingTypeArgument("no type argument before ','"),
  unexpectedPrimitiveTypeArguments(
      'primitive types not expected to have type arguments'),
  unexpectedVectorTypeArgumentCount(
      'vector type expected to have exactly one type argument'),
  unexpectedStructFormat(
      'unexpected struct format, must be of the form 0xaddress::module_name::struct_name'),
  invalidModuleNameCharacter(
      "module name must only contain alphanumeric or '_' characters"),
  invalidStructNameCharacter(
      "struct name must only contain alphanumeric or '_' characters"),
  invalidAddress('struct address must be valid');

  const TypeTagParserErrorType(this.value);

  final String value;
}

/// Represents an error that occurs during the parsing of a type tag.
/// This error provides additional context regarding the specific type tag
/// that failed to parse and the reason for the failure.
class TypeTagParserError implements Exception {
  final String message;

  /// Constructs an error indicating a failure to parse a type tag.
  ///
  /// [typeTagStr] - The string representation of the type tag that failed to
  /// parse.
  /// [invalidReason] - The reason why the type tag is considered invalid.
  TypeTagParserError(String typeTagStr, TypeTagParserErrorType invalidReason)
      : message =
            "Failed to parse typeTag '$typeTagStr', ${invalidReason.value}";

  @override
  String toString() => message;
}

/// Parses a type string into a structured representation of type tags,
/// accommodating various formats including generics and nested types.
///
/// All types are made of a few parts they're either:
/// 1. A simple type e.g. `u8`
/// 2. A standalone struct e.g. `0x1::account::Account`
/// 3. A nested struct e.g. `0x1::coin::Coin<0x1234::coin::MyCoin>`
///
/// There are a few more special cases that need to be handled, however.
/// 1. Multiple generics e.g. `0x1::pair::Pair<u8, u16>`
/// 2. Spacing in the generics e.g. `0x1::pair::Pair< u8 , u16>`
/// 3. Nested generics of different depths e.g.
///    `0x1::pair::Pair<0x1::coin::Coin<0x1234::coin::MyCoin>, u8>`
/// 4. Generics for types in ABIs are filled in with placeholders e.g. `T1`,
///    `T2`, `T3`
///
/// [typeStr] - The string representation of the type to be parsed.
/// [allowGenerics] - A flag indicating whether to allow generics in the
/// parsing process.
///
/// Throws a [TypeTagParserError] if the type string is malformed or does not
/// conform to expected formats.
TypeTag parseTypeTag(String typeStr, {bool allowGenerics = false}) {
  final saved = <_TypeTagState>[];
  // This represents the internal types for a type tag e.g.
  // '0x1::coin::Coin<innerTypes>'
  var innerTypes = <TypeTag>[];
  // This represents the current parsed types in a comma list e.g. 'u8, u8'
  var curTypes = <TypeTag>[];
  // This represents the current character index
  var cur = 0;
  // This represents the current working string as a type or struct name
  var currentStr = '';
  var expectedTypes = 1;

  // Iterate through each character, and handle the border conditions
  while (cur < typeStr.length) {
    final char = typeStr[cur];

    if (char == '<') {
      // Start of a type argument, push current state onto a stack
      saved.add(_TypeTagState(
        savedExpectedTypes: expectedTypes,
        savedStr: currentStr,
        savedTypes: curTypes,
      ));

      // Clear current state
      currentStr = '';
      curTypes = [];
      expectedTypes = 1;
    } else if (char == '>') {
      // Process last type, if there is no type string, then don't parse it
      if (currentStr != '') {
        final newType =
            _parseTypeTagInner(currentStr, innerTypes, allowGenerics);
        curTypes.add(newType);
      }

      // Pop off stack outer type, if there's nothing left, there were too
      // many '>'
      if (saved.isEmpty) {
        throw TypeTagParserError(
          typeStr,
          TypeTagParserErrorType.unexpectedTypeArgumentClose,
        );
      }
      final savedPop = saved.removeLast();

      // If the expected types don't match the number of commas, then we also
      // fail
      if (expectedTypes != curTypes.length) {
        throw TypeTagParserError(
          typeStr,
          TypeTagParserErrorType.typeArgumentCountMismatch,
        );
      }

      // Add in the new created type, shifting the current types to the inner
      // types
      innerTypes = curTypes;
      curTypes = savedPop.savedTypes;
      currentStr = savedPop.savedStr;
      expectedTypes = savedPop.savedExpectedTypes;
    } else if (char == ',') {
      // Comma means we need to start parsing a new tag, push the previous one
      // to the curTypes

      // No top level commas (not in a type <> are allowed)
      if (saved.isEmpty) {
        throw TypeTagParserError(
          typeStr,
          TypeTagParserErrorType.unexpectedComma,
        );
      }
      // If there was no actual value before the comma, then it's missing a
      // type argument
      if (currentStr.isEmpty) {
        throw TypeTagParserError(
          typeStr,
          TypeTagParserErrorType.missingTypeArgument,
        );
      }

      // Process characters before as a type
      final newType = _parseTypeTagInner(currentStr, innerTypes, allowGenerics);

      // parse type tag and push it on the types
      innerTypes = [];
      curTypes.add(newType);
      currentStr = '';
      expectedTypes += 1;
    } else if (_isValidWhitespaceCharacter(char)) {
      // This means we should save what we have and everything else should
      // skip until the next
      var parsedTypeTag = false;
      if (currentStr.isNotEmpty) {
        final newType =
            _parseTypeTagInner(currentStr, innerTypes, allowGenerics);

        // parse type tag and push it on the types
        innerTypes = [];
        curTypes.add(newType);
        currentStr = '';
        parsedTypeTag = true;
      }

      // Skip ahead on any more whitespace
      cur = _consumeWhitespace(typeStr, cur);

      // The next space MUST be a comma, or a closing > if there was something
      // parsed before e.g. `u8 u8` is invalid but `u8, u8` is valid
      if (cur < typeStr.length && parsedTypeTag) {
        final nextChar = typeStr[cur];
        if (nextChar != ',' && nextChar != '>') {
          throw TypeTagParserError(
            typeStr,
            TypeTagParserErrorType.unexpectedWhitespaceCharacter,
          );
        }
      }

      continue;
    } else {
      // Any other characters just append to the current string
      currentStr += char;
    }

    cur += 1;
  }

  // This prevents a missing '>' on type arguments
  if (saved.isNotEmpty) {
    throw TypeTagParserError(
      typeStr,
      TypeTagParserErrorType.missingTypeArgumentClose,
    );
  }

  // This prevents 'u8, u8' as an input
  switch (curTypes.length) {
    case 0:
      return _parseTypeTagInner(currentStr, innerTypes, allowGenerics);
    case 1:
      if (currentStr == '') {
        return curTypes[0];
      }
      throw TypeTagParserError(typeStr, TypeTagParserErrorType.unexpectedComma);
    default:
      throw TypeTagParserError(
        typeStr,
        TypeTagParserErrorType.unexpectedWhitespaceCharacter,
      );
  }
}

/// Parses a type tag with internal types associated, allowing for the
/// inclusion of generics if specified. This function helps in constructing
/// the appropriate type tags based on the provided string representation and
/// associated types.
TypeTag _parseTypeTagInner(
  String str,
  List<TypeTag> types,
  bool allowGenerics,
) {
  final trimmedStr = str.trim();
  final lowerCaseTrimmed = trimmedStr.toLowerCase();
  if (_isPrimitive(lowerCaseTrimmed)) {
    if (types.isNotEmpty) {
      throw TypeTagParserError(
        str,
        TypeTagParserErrorType.unexpectedPrimitiveTypeArguments,
      );
    }
  }

  switch (lowerCaseTrimmed) {
    case 'signer':
      return TypeTagSigner();
    case 'bool':
      return TypeTagBool();
    case 'address':
      return TypeTagAddress();
    case 'u8':
      return TypeTagU8();
    case 'u16':
      return TypeTagU16();
    case 'u32':
      return TypeTagU32();
    case 'u64':
      return TypeTagU64();
    case 'u128':
      return TypeTagU128();
    case 'u256':
      return TypeTagU256();
    case 'i8':
      return TypeTagI8();
    case 'i16':
      return TypeTagI16();
    case 'i32':
      return TypeTagI32();
    case 'i64':
      return TypeTagI64();
    case 'i128':
      return TypeTagI128();
    case 'i256':
      return TypeTagI256();
    case 'vector':
      if (types.length != 1) {
        throw TypeTagParserError(
          str,
          TypeTagParserErrorType.unexpectedVectorTypeArgumentCount,
        );
      }
      return TypeTagVector(types[0]);
    default:
      // Reference will have to handle the inner type
      if (_isRef(trimmedStr)) {
        final actualType = trimmedStr.substring(1);
        return TypeTagReference(
          _parseTypeTagInner(actualType, types, allowGenerics),
        );
      }

      // Generics are always expected to be T0 or T1
      if (_isGeneric(trimmedStr)) {
        if (allowGenerics) {
          return TypeTagGeneric(int.parse(trimmedStr.substring(1)));
        }
        throw TypeTagParserError(
          str,
          TypeTagParserErrorType.unexpectedGenericType,
        );
      }

      // If the value doesn't contain a colon, then we'll assume it isn't
      // trying to be a struct
      if (!trimmedStr.contains(':')) {
        throw TypeTagParserError(str, TypeTagParserErrorType.invalidTypeTag);
      }

      // Parse for a struct tag
      final structParts = trimmedStr.split('::');
      if (structParts.length != 3) {
        throw TypeTagParserError(
          str,
          TypeTagParserErrorType.unexpectedStructFormat,
        );
      }

      // Validate struct address
      AccountAddress address;
      try {
        address = AccountAddress.fromString(structParts[0]);
      } catch (_) {
        throw TypeTagParserError(str, TypeTagParserErrorType.invalidAddress);
      }

      // Validate identifier characters
      if (!_isValidIdentifier(structParts[1])) {
        throw TypeTagParserError(
          str,
          TypeTagParserErrorType.invalidModuleNameCharacter,
        );
      }
      if (!_isValidIdentifier(structParts[2])) {
        throw TypeTagParserError(
          str,
          TypeTagParserErrorType.invalidStructNameCharacter,
        );
      }

      return TypeTagStruct(
        StructTag(
          address,
          Identifier(structParts[1]),
          Identifier(structParts[2]),
          types,
        ),
      );
  }
}
