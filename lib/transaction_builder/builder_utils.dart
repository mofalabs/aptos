import 'dart:typed_data';

import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/identifier.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:aptos/hex_string.dart';

final stringStructTag = StructTag(
  AccountAddress.fromHex("0x1"),
  Identifier("string"),
  Identifier("String"),
  [],
);

void assertType(dynamic val, List<dynamic> types, {String? message}) {
  if (types.any((type) => val.runtimeType.toString() == type)) {
    throw ArgumentError(
        message ?? "Invalid arg: $val type should be ${types.join(" or ")}");
  }
}

StructTag optionStructTag(TypeTag typeArg) {
  return StructTag(AccountAddress.fromHex("0x1"), Identifier("option"), Identifier("Option"), [typeArg]);
}

StructTag objectStructTag(TypeTag typeArg) {
  return StructTag(AccountAddress.fromHex("0x1"), Identifier("object"), Identifier("Object"), [typeArg]);
}

void bail(String message) {
  throw ArgumentError(message);
}

bool isWhiteSpace(String c) {
  return RegExp(r"\s").hasMatch(c);
}

bool isValidAlphabetic(String c) {
  return RegExp(r"[_A-Za-z0-9]").hasMatch(c);
}

// Generic format is T<digits> - for example T1, T2, T10
bool isGeneric(String c) {
  if (RegExp(r"T\d+").hasMatch(c)) {
    return true;
  }
  return false;
}


typedef TokenType = String;
typedef TokenValue = String;
typedef Token = (String, String);

// Returns Token and Token byte size
((String, String) token, int size) nextToken(String tagStr, int pos) {
  final c = tagStr[pos];
  if (c == ":") {
    if (tagStr.substring(pos, pos + 2) == "::") {
      return (("COLON", "::"), 2);
    }
    bail("Unrecognized token.");
  } else if (c == "<") {
    return (("LT", "<"), 1);
  } else if (c == ">") {
    return (("GT", ">"), 1);
  } else if (c == ",") {
    return (("COMMA", ","), 1);
  } else if (isWhiteSpace(c)) {
    var res = "";
    for (int i = pos; i < tagStr.length; i += 1) {
      final char = tagStr[i];
      if (isWhiteSpace(char)) {
        res = "$res$char";
      } else {
        break;
      }
    }
    return (("SPACE", res), res.length);
  } else if (isValidAlphabetic(c)) {
    var res = "";
    for (int i = pos; i < tagStr.length; i += 1) {
      final char = tagStr[i];
      if (isValidAlphabetic(char)) {
        res = "$res$char";
      } else {
        break;
      }
    }
    if (isGeneric(res)) {
      return (("GENERIC", res), res.length);
    }
    return (("IDENT", res), res.length);
  }
  throw ArgumentError("Unrecognized token.");
}

List<Token> tokenize(String tagStr) {
  int pos = 0;
  final tokens = <Token>[];
  while (pos < tagStr.length) {
    final (token, size) = nextToken(tagStr, pos);
    if (token.$1 != "SPACE") {
      tokens.add(token);
    }
    pos += size;
  }
  return tokens;
}

class TypeTagParser {
  TypeTagParser(this.tagStr, [List<String>? typeTags]) {
    tokens = tokenize(tagStr);
    _typeTags = typeTags ?? <String>[];
  }

  final String tagStr;
  late List<Token> tokens;
  late List<String> _typeTags = <String>[];

  void _consume(String targetToken) {
    if (tokens.isEmpty) return;
    final token = tokens.removeAt(0);
    if (token.$2 != targetToken) {
      bail("Invalid type tag.");
    }
  }

  /// Consumes all of an unused generic field, mostly applicable to object
  ///
  /// Note: This is recursive.  it can be problematic if there's bad input
  void _consumeWholeGeneric() {
    _consume("<");
    while (tokens.isNotEmpty && tokens[0].$2 != ">") {
      // If it is nested, we have to consume another nested generic
      if (tokens[0].$2 == "<") {
        _consumeWholeGeneric();
      }
      if (tokens.isNotEmpty) {
        tokens.removeAt(0);
      }
    }
    _consume(">");
  }

  List<TypeTag> _parseCommaList(TokenValue endToken, bool allowTraillingComma) {
    final res = <TypeTag>[];
    if (tokens.isEmpty) {
      bail("Invalid type tag.");
    }

    while (tokens[0].$2 != endToken) {
      res.add(parseTypeTag());

      if (tokens.isNotEmpty && tokens[0].$2 == endToken) {
        break;
      }

      _consume(",");
      if (tokens.isNotEmpty &&
          tokens[0].$2 == endToken &&
          allowTraillingComma) {
        break;
      }

      if (tokens.isEmpty) {
        bail("Invalid type tag.");
      }
    }
    return res;
  }

  TypeTag parseTypeTag() {
    if (tokens.isEmpty) {
      bail("Invalid type tag.");
    }

    final item = tokens.removeAt(0);

    final (tokenTy, tokenVal) = item;
    if (tokenVal == "u8") {
      return TypeTagU8();
    }
    if (tokenVal == "u16") {
      return TypeTagU16();
    }
    if (tokenVal == "u32") {
      return TypeTagU32();
    }
    if (tokenVal == "u64") {
      return TypeTagU64();
    }
    if (tokenVal == "u128") {
      return TypeTagU128();
    }
    if (tokenVal == "u256") {
      return TypeTagU256();
    }
    if (tokenVal == "bool") {
      return TypeTagBool();
    }
    if (tokenVal == "address") {
      return TypeTagAddress();
    }
    if (tokenVal == "vector") {
      _consume("<");
      final res = parseTypeTag();
      _consume(">");
      return TypeTagVector(res);
    }
    if (tokenVal == "string") {
      return TypeTagStruct(stringStructTag);
    }
    if (tokenTy == "IDENT" &&
        (tokenVal.startsWith("0x") || tokenVal.startsWith("0X"))) {
      String address = tokenVal;
      _consume("::");
      var item = tokens.removeAt(0);
      final (moduleTokenTy, module) = item;
      if (moduleTokenTy != "IDENT") {
        bail("Invalid type tag.");
      }
      _consume("::");
      item = tokens.removeAt(0);
      final (nameTokenTy, name) = item;
      if (nameTokenTy != "IDENT") {
        bail("Invalid type tag.");
      }

      // Objects can contain either concrete types e.g. 0x1::object::ObjectCore or generics e.g. T
      // Neither matter as we can't do type checks, so just the address applies and we consume the entire generic.
      // TODO: Support parsing structs that don't come from core code address
      if (address == AccountAddress.CORE_CODE_ADDRESS && module == "object" && name == "Object") {
        _consumeWholeGeneric();
        return TypeTagAddress();
      }

      var tyTags = <TypeTag>[];
      // Check if the struct has ty args
      if (tokens.isNotEmpty && tokens[0].$2 == "<") {
        _consume("<");
        tyTags = _parseCommaList(">", true);
        _consume(">");
      }

      final structTag = StructTag(
        AccountAddress.fromHex(address),
        Identifier(module),
        Identifier(name),
        tyTags,
      );
      return TypeTagStruct(structTag);
    }

    if (tokenTy == "GENERIC") {
      if (_typeTags.isEmpty) {
        bail("Can't convert generic type since no typeTags were specified.");
      }
      // a generic tokenVal has the format of `T<digit>`, for example `T1`.
      // The digit (i.e 1) indicates the the index of this type in the typeTags array.
      // For a tokenVal == T1, should be parsed as the type in typeTags[1]
      final idx = int.parse(tokenVal.substring(1), radix: 10);
      return TypeTagParser(_typeTags[idx]).parseTypeTag();
    }

    throw ArgumentError("Invalid type tag.");
  }
}

bool ensureBoolean(dynamic val) {
  assertType(val, [bool, String]);
  if (val is bool) {
    return val;
  }

  if (val == "true") {
    return true;
  }
  if (val == "false") {
    return false;
  }

  throw ArgumentError("Invalid boolean string.");
}

int ensureNumber(dynamic val) {
  assertType(val, [int, String]);
  if (val is int) {
    return val;
  }

  final res = int.tryParse(val);
  if (res == null || res.isNaN) {
    throw ArgumentError("Invalid number string.");
  }

  return res;
}

BigInt ensureBigInt(dynamic val) {
  assertType(val, [int, BigInt, String]);
  return BigInt.tryParse(val.toString())!;
}

void serializeArg(dynamic argVal, TypeTag argType, Serializer serializer) {
  serializeArgInner(argVal, argType, serializer, 0);
}

void serializeArgInner(dynamic argVal, TypeTag argType, Serializer serializer, int depth) {
  if (argType is TypeTagBool) {
    serializer.serializeBool(ensureBoolean(argVal));
  } else if (argType is TypeTagU8) {
    serializer.serializeU8(ensureNumber(argVal));
  } else if (argType is TypeTagU16) {
    serializer.serializeU16(ensureNumber(argVal));
  } else if (argType is TypeTagU32) {
    serializer.serializeU32(ensureNumber(argVal));
  } else if (argType is TypeTagU64) {
    serializer.serializeU64(ensureBigInt(argVal));
  } else if (argType is TypeTagU128) {
    serializer.serializeU128(ensureBigInt(argVal));
  } else if (argType is TypeTagU256) {
    serializer.serializeU256(ensureBigInt(argVal));
  } else if (argType is TypeTagAddress) {
    _serializeAddress(argVal, serializer);
  } else if (argType is TypeTagVector) {
    _serializeVector(argVal, argType, serializer, depth);
  } else if (argType is TypeTagStruct) {
    _serializeStruct(argVal, argType, serializer, depth);
  } else {
    throw ArgumentError("Unsupported arg type.");
  }
}

void _serializeAddress(dynamic argVal, Serializer serializer) {
  AccountAddress addr;
  if (argVal is String || argVal is HexString) {
    addr = AccountAddress.fromHex(argVal);
  } else if (argVal is AccountAddress) {
    addr = argVal;
  } else {
    throw ArgumentError("Invalid account address.");
  }
  addr.serialize(serializer);
}

void _serializeVector(dynamic argVal, TypeTagVector argType, Serializer serializer, int depth) {
  if (argType.value is TypeTagU8) {
    if (argVal is Uint8List) {
      serializer.serializeBytes(argVal);
      return;
    }

    if (argVal is HexString) {
      serializer.serializeBytes(argVal.toUint8Array());
      return;
    }

    if (argVal is String) {
      serializer.serializeStr(argVal);
      return;
    }
  }

  if (argVal is! Iterable) {
    throw ArgumentError("Invalid vector args $argVal.");
  }

  serializer.serializeU32AsUleb128(argVal.length);

  argVal.forEach((arg) => serializeArgInner(arg, argType.value, serializer, depth + 1));
}

void _serializeStruct(dynamic argVal, TypeTag argType, Serializer serializer, int depth) {
  final tagStruct = (argType as TypeTagStruct).value;
  final address = tagStruct.address;
  final moduleName = tagStruct.moduleName;
  final name = tagStruct.name;
  final typeArgs = tagStruct.typeArgs;

  final structType = "${HexString.fromUint8Array(address.address).toShortString()}::${moduleName.value}::${name.value}";
  if (structType == "0x1::string::String") {
    assertType(argVal, ["string"]);
    serializer.serializeStr(argVal);
  } else if (structType == "0x1::object::Object") {
    _serializeAddress(argVal, serializer);
  } else if (structType == "0x1::option::Option") {
    if (typeArgs.length != 1) {
      throw ArgumentError("Option has the wrong number of type arguments ${typeArgs.length}");
    }
    _serializeOption(argVal, typeArgs[0], serializer, depth);
  } else {
    throw ArgumentError("Unsupported struct type in function argument");
  }
}

void _serializeOption(dynamic argVal, TypeTag argType, Serializer serializer, int depth) {
  // For option, we determine if it's empty or not empty first
  // empty option is nothing, we specifically check for undefined to prevent fuzzy matching
  if (argVal == null) {
    serializer.serializeU32AsUleb128(0);
  } else {
    // Something means we need an array of 1
    serializer.serializeU32AsUleb128(1);

    // Serialize the inner type arg, ensuring that depth is tracked
    serializeArgInner(argVal, argType, serializer, depth + 1);
  }
}

TransactionArgument argToTransactionArgument(dynamic argVal, TypeTag argType) {
  if (argType is TypeTagBool) {
    return TransactionArgumentBool(ensureBoolean(argVal));
  }
  if (argType is TypeTagU8) {
    return TransactionArgumentU8(ensureNumber(argVal));
  }
  if (argType is TypeTagU16) {
    return TransactionArgumentU16(ensureNumber(argVal));
  }
  if (argType is TypeTagU32) {
    return TransactionArgumentU32(ensureNumber(argVal));
  }
  if (argType is TypeTagU64) {
    return TransactionArgumentU64(ensureBigInt(argVal));
  }
  if (argType is TypeTagU128) {
    return TransactionArgumentU128(ensureBigInt(argVal));
  }
  if (argType is TypeTagU256) {
    return TransactionArgumentU256(ensureBigInt(argVal));
  }
  if (argType is TypeTagAddress) {
    AccountAddress addr;
    if (argVal is String || argVal is HexString) {
      addr = AccountAddress.fromHex(argVal);
    } else if (argVal is AccountAddress) {
      addr = argVal;
    } else {
      throw ArgumentError("Invalid account address.");
    }
    return TransactionArgumentAddress(addr);
  }
  if (argType is TypeTagVector && argType.value is TypeTagU8) {
    if (argVal is! Iterable<int>) {
      throw ArgumentError("$argVal should be an instance of Uint8Array");
    }

    return TransactionArgumentU8Vector(Uint8List.fromList(argVal.toList()));
  }

  throw ArgumentError("Unknown type for TransactionArgument.");
}
