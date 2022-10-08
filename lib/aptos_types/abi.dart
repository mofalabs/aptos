import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';

class TypeArgumentABI with Serializable {
  
  TypeArgumentABI(this.name);

  final String name;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(name);
  }

  static TypeArgumentABI deserialize(Deserializer deserializer) {
    final name = deserializer.deserializeStr();
    return TypeArgumentABI(name);
  }
}

class ArgumentABI with Serializable {

  ArgumentABI(this.name, this.typeTag);

  final String name;
  final TypeTag typeTag;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(name);
    typeTag.serialize(serializer);
  }

  static ArgumentABI deserialize(Deserializer deserializer) {
    final name = deserializer.deserializeStr();
    final typeTag = TypeTag.deserialize(deserializer);
    return ArgumentABI(name, typeTag);
  }
}

abstract class ScriptABI with Serializable {

  @override
  void serialize(Serializer serializer);

  static ScriptABI deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return TransactionScriptABI.load(deserializer);
      case 1:
        return EntryFunctionABI.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for TransactionPayload: $index");
    }
  }
}

class TransactionScriptABI extends ScriptABI {

  TransactionScriptABI(this.name, this.doc, this.code, this.tyArgs, this.args): super();

  final String name;
  final String doc;
  final Uint8List code;
  final List<TypeArgumentABI> tyArgs;
  final List<ArgumentABI> args;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    serializer.serializeStr(name);
    serializer.serializeStr(doc);
    serializer.serializeBytes(code);
    serializeVector<TypeArgumentABI>(tyArgs, serializer);
    serializeVector<ArgumentABI>(args, serializer);
  }

  static TransactionScriptABI load(Deserializer deserializer) {
    final name = deserializer.deserializeStr();
    final doc = deserializer.deserializeStr();
    final code = deserializer.deserializeBytes();
    final tyArgs = deserializeVector<TypeArgumentABI>(deserializer, TypeArgumentABI.deserialize);
    final args = deserializeVector<ArgumentABI>(deserializer, ArgumentABI.deserialize);
    return TransactionScriptABI(name, doc, code, tyArgs, args);
  }
}

class EntryFunctionABI extends ScriptABI {

  EntryFunctionABI(this.name, this.moduleName, this.doc, this.tyArgs, this.args): super();

  final String name;
  final ModuleId moduleName;
  final String doc;
  final List<TypeArgumentABI> tyArgs;
  final List<ArgumentABI> args;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
    serializer.serializeStr(name);
    moduleName.serialize(serializer);
    serializer.serializeStr(doc);
    serializeVector<TypeArgumentABI>(tyArgs, serializer);
    serializeVector<ArgumentABI>(args, serializer);
  }

  static EntryFunctionABI load(Deserializer deserializer) {
    final name = deserializer.deserializeStr();
    final moduleName = ModuleId.deserialize(deserializer);
    final doc = deserializer.deserializeStr();
    final tyArgs = deserializeVector<TypeArgumentABI>(deserializer, TypeArgumentABI.deserialize);
    final args = deserializeVector<ArgumentABI>(deserializer, ArgumentABI.deserialize);
    return EntryFunctionABI(name, moduleName, doc, tyArgs, args);
  }
}
