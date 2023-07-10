
import 'package:aptos/aptos.dart';

abstract class TypeTag with Serializable {

  @override
  void serialize(Serializer serializer);

  static TypeTag deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return TypeTagBool.load(deserializer);
      case 1:
        return TypeTagU8.load(deserializer);
      case 2:
        return TypeTagU64.load(deserializer);
      case 3:
        return TypeTagU128.load(deserializer);
      case 4:
        return TypeTagAddress.load(deserializer);
      case 5:
        return TypeTagSigner.load(deserializer);
      case 6:
        return TypeTagVector.load(deserializer);
      case 7:
        return TypeTagStruct.load(deserializer);
      case 8:
        return TypeTagU16.load(deserializer);
      case 9:
        return TypeTagU32.load(deserializer);
      case 10:
        return TypeTagU256.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for TypeTag: $index");
    }
  }
}

class TypeTagBool extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
  }

  static TypeTagBool load(Deserializer deserializer) {
    return TypeTagBool();
  }
}

class TypeTagU8 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
  }

  static TypeTagU8 load(Deserializer deserializer) {
    return TypeTagU8();
  }
}

class TypeTagU16 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
  }

  static TypeTagU16 load(Deserializer deserializer) {
    return TypeTagU16();
  }
}

class TypeTagU32 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
  }

  static TypeTagU32 load(Deserializer deserializer) {
    return TypeTagU32();
  }
}

class TypeTagU64 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(2);
  }

  static TypeTagU64 load(Deserializer deserializer) {
    return TypeTagU64();
  }
}

class TypeTagU128 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(3);
  }

  static TypeTagU128 load(Deserializer deserializer) {
    return TypeTagU128();
  }
}

class TypeTagU256 extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
  }

  static TypeTagU256 load(Deserializer deserializer) {
    return TypeTagU256();
  }
}

class TypeTagAddress extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(4);
  }

  static TypeTagAddress load(Deserializer deserializer) {
    return TypeTagAddress();
  }
}

class TypeTagSigner extends TypeTag {

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(5);
  }

  static TypeTagSigner load(Deserializer deserializer) {
    return TypeTagSigner();
  }
}

class TypeTagVector extends TypeTag {
  TypeTagVector(this.value): super();

  final TypeTag value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(6);
    value.serialize(serializer);
  }

  static TypeTagVector load(Deserializer deserializer) {
    final value = TypeTag.deserialize(deserializer);
    return TypeTagVector(value);
  }
}

class TypeTagStruct extends TypeTag {
  TypeTagStruct(this.value): super();

  final StructTag value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(7);
    value.serialize(serializer);
  }

  static TypeTagStruct load(Deserializer deserializer) {
    final value = StructTag.deserialize(deserializer);
    return TypeTagStruct(value);
  }

  bool isStringTypeTag() {
    if (
      value.moduleName.value == "string" &&
      value.name.value == "String" &&
      value.address.hexAddress() == AccountAddress.fromHex("0x1").hexAddress()
    ) {
      return true;
    }
    return false;
  }
}

class StructTag with Serializable {
  StructTag(this.address, this.moduleName, this.name, this.typeArgs);

  final AccountAddress address;
  final Identifier moduleName;
  final Identifier name;
  final List<TypeTag> typeArgs;

  static StructTag fromString(String structTag) {
    final typeTagStruct = TypeTagParser(structTag).parseTypeTag() as TypeTagStruct;

    return StructTag(
      typeTagStruct.value.address,
      typeTagStruct.value.moduleName,
      typeTagStruct.value.name,
      typeTagStruct.value.typeArgs,
    );
  }

  @override
  void serialize(Serializer serializer) {
    address.serialize(serializer);
    moduleName.serialize(serializer);
    name.serialize(serializer);
    serializeVector<TypeTag>(typeArgs, serializer);
  }

  static StructTag deserialize(Deserializer deserializer) {
    final address = AccountAddress.deserialize(deserializer);
    final moduleName = Identifier.deserialize(deserializer);
    final name = Identifier.deserialize(deserializer);
    final typeArgs = deserializeVector<TypeTag>(deserializer, TypeTag);
    return StructTag(address, moduleName, name, typeArgs);
  }
}