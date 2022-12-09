import 'dart:typed_data';

import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/identifier.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:aptos/hex_string.dart';
import 'package:tuple/tuple.dart';

void assertType(dynamic val, List<dynamic> types, {String? message}) {
  if (types.any((type) => val.runtimeType.toString() == type)) {
    throw ArgumentError(
        message ?? "Invalid arg: $val type should be ${types.join(" or ")}");
  }
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

typedef TokenType = String;
typedef TokenValue = String;
typedef Token = Tuple2<String, String>;

// Returns Token and Token byte size
Tuple2<Tuple2<String, String>, int> nextToken(String tagStr, int pos) {
  final c = tagStr[pos];
  if (c == ":") {
    if (tagStr.substring(pos, pos + 2) == "::") {
      return const Tuple2(Tuple2("COLON", "::"), 2);
    }
    bail("Unrecognized token.");
  } else if (c == "<") {
    return const Tuple2(Tuple2("LT", "<"), 1);
  } else if (c == ">") {
    return const Tuple2(Tuple2("GT", ">"), 1);
  } else if (c == ",") {
    return const Tuple2(Tuple2("COMMA", ","), 1);
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
    return Tuple2(Tuple2("SPACE", res), res.length);
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
    return Tuple2(Tuple2("IDENT", res), res.length);
  }
  throw ArgumentError("Unrecognized token.");
}

List<Token> tokenize(String tagStr) {
  int pos = 0;
  final tokens = <Token>[];
  while (pos < tagStr.length) {
    final result = nextToken(tagStr, pos);
    if (result.item1.item1 != "SPACE") {
      tokens.add(result.item1);
    }
    pos += result.item2;
  }
  return tokens;
}

class TypeTagParser {
  TypeTagParser(this.tagStr) {
    this.tokens = tokenize(tagStr);
  }

  final String tagStr;
  late final List<Token> tokens;

  void _consume(String targetToken) {
    final token = tokens.removeAt(0);
    if (token.item2 != targetToken) {
      bail("Invalid type tag.");
    }
  }

  List<TypeTag> _parseCommaList(TokenValue endToken, bool allowTraillingComma) {
    final res = <TypeTag>[];
    if (tokens.isEmpty) {
      bail("Invalid type tag.");
    }

    while (tokens[0].item2 != endToken) {
      res.add(parseTypeTag());

      if (tokens.isNotEmpty && tokens[0].item2 == endToken) {
        break;
      }

      _consume(",");
      if (tokens.isNotEmpty &&
          tokens[0].item2 == endToken &&
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

    String tokenTy = item.item1;
    String tokenVal = item.item2;
    if (tokenVal == "u8") {
      return TypeTagU8();
    }
    if (tokenVal == "u64") {
      return TypeTagU64();
    }
    if (tokenVal == "u128") {
      return TypeTagU128();
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
    if (tokenTy == "IDENT" &&
        (tokenVal.startsWith("0x") || tokenVal.startsWith("0X"))) {
      String address = tokenVal;
      _consume("::");
      var item = tokens.removeAt(0);
      String moduleTokenTy = item.item1;
      String module = item.item2;
      if (moduleTokenTy != "IDENT") {
        bail("Invalid type tag.");
      }
      _consume("::");
      item = tokens.removeAt(0);
      String nameTokenTy = item.item1;
      String name = item.item2;
      if (nameTokenTy != "IDENT") {
        bail("Invalid type tag.");
      }

      var tyTags = <TypeTag>[];
      // Check if the struct has ty args
      if (tokens.isNotEmpty && tokens[0].item2 == "<") {
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
  if (argType is TypeTagBool) {
    serializer.serializeBool(ensureBoolean(argVal));
    return;
  }
  if (argType is TypeTagU8) {
    serializer.serializeU8(ensureNumber(argVal));
    return;
  }
  if (argType is TypeTagU64) {
    serializer.serializeU64(ensureBigInt(argVal));
    return;
  }
  if (argType is TypeTagU128) {
    serializer.serializeU128(ensureBigInt(argVal));
    return;
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
    addr.serialize(serializer);
    return;
  }
  if (argType is TypeTagVector) {
    // We are serializing a vector<u8>
    if (argType.value is TypeTagU8) {
      if (argVal is Uint8List) {
        serializer.serializeBytes(argVal);
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

    argVal.forEach((arg) => serializeArg(arg, argType.value, serializer));
    return;
  }

  if (argType is TypeTagStruct) {
    StructTag val = argType.value;
    if ("${HexString.fromUint8Array(val.address.address).toShortString()}::${val.moduleName.value}::${val.name.value}" !=
        "0x1::string::String") {
      throw ArgumentError(
          "The only supported struct arg is of type 0x1::string::String");
    }
    assertType(argVal, ["string"]);

    serializer.serializeStr(argVal);
    return;
  }
  throw ArgumentError("Unsupported arg type.");
}

TransactionArgument argToTransactionArgument(dynamic argVal, TypeTag argType) {
  if (argType is TypeTagBool) {
    return TransactionArgumentBool(ensureBoolean(argVal));
  }
  if (argType is TypeTagU8) {
    return TransactionArgumentU8(ensureNumber(argVal));
  }
  if (argType is TypeTagU64) {
    return TransactionArgumentU64(ensureBigInt(argVal));
  }
  if (argType is TypeTagU128) {
    return TransactionArgumentU128(ensureBigInt(argVal));
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
