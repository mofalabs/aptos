import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../types/types.dart';
import '../instances/identifier.dart';

/// Represents a type tag in the serialization framework, serving as a base
/// class for various specific type tags. This class provides methods for
/// serialization and deserialization of type tags, as well as type checking
/// methods to determine the specific type of the tag at runtime.
abstract class TypeTag extends Serializable {
  @override
  void serialize(Serializer serializer);

  /// Deserializes a TypeTag from the provided deserializer, dispatching on
  /// the ULEB128-encoded variant index.
  static TypeTag deserialize(Deserializer deserializer) {
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TypeTagVariants.boolean.value) {
      return TypeTagBool.load(deserializer);
    }
    if (index == TypeTagVariants.u8.value) {
      return TypeTagU8.load(deserializer);
    }
    if (index == TypeTagVariants.u64.value) {
      return TypeTagU64.load(deserializer);
    }
    if (index == TypeTagVariants.u128.value) {
      return TypeTagU128.load(deserializer);
    }
    if (index == TypeTagVariants.address.value) {
      return TypeTagAddress.load(deserializer);
    }
    if (index == TypeTagVariants.signer.value) {
      return TypeTagSigner.load(deserializer);
    }
    if (index == TypeTagVariants.vector.value) {
      return TypeTagVector.load(deserializer);
    }
    if (index == TypeTagVariants.struct.value) {
      return TypeTagStruct.load(deserializer);
    }
    if (index == TypeTagVariants.u16.value) {
      return TypeTagU16.load(deserializer);
    }
    if (index == TypeTagVariants.u32.value) {
      return TypeTagU32.load(deserializer);
    }
    if (index == TypeTagVariants.u256.value) {
      return TypeTagU256.load(deserializer);
    }
    if (index == TypeTagVariants.i8.value) {
      return TypeTagI8.load(deserializer);
    }
    if (index == TypeTagVariants.i16.value) {
      return TypeTagI16.load(deserializer);
    }
    if (index == TypeTagVariants.i32.value) {
      return TypeTagI32.load(deserializer);
    }
    if (index == TypeTagVariants.i64.value) {
      return TypeTagI64.load(deserializer);
    }
    if (index == TypeTagVariants.i128.value) {
      return TypeTagI128.load(deserializer);
    }
    if (index == TypeTagVariants.i256.value) {
      return TypeTagI256.load(deserializer);
    }
    if (index == TypeTagVariants.generic.value) {
      // This is only used for ABI representation, and cannot actually be used
      // as a type.
      return TypeTagGeneric.load(deserializer);
    }
    throw StateError('Unknown variant index for TypeTag: $index');
  }

  @override
  String toString();

  /// Determines if the current instance is of type [TypeTagBool].
  bool isBool() => this is TypeTagBool;

  /// Determines if the current instance is of type [TypeTagAddress].
  bool isAddress() => this is TypeTagAddress;

  /// Determines if the current instance is of type [TypeTagGeneric].
  bool isGeneric() => this is TypeTagGeneric;

  /// Determines if the current instance is a [TypeTagSigner].
  bool isSigner() => this is TypeTagSigner;

  /// Checks if the current instance is a vector type.
  bool isVector() => this is TypeTagVector;

  /// Determines if the current instance is a structure type.
  bool isStruct() => this is TypeTagStruct;

  /// Determines if the current instance is of type [TypeTagU8].
  bool isU8() => this is TypeTagU8;

  /// Checks if the current instance is of type [TypeTagU16].
  bool isU16() => this is TypeTagU16;

  /// Checks if the current instance is of type [TypeTagU32].
  bool isU32() => this is TypeTagU32;

  /// Checks if the current instance is of type [TypeTagU64].
  bool isU64() => this is TypeTagU64;

  /// Determines if the current instance is of the [TypeTagU128] type.
  bool isU128() => this is TypeTagU128;

  /// Checks if the current instance is of type [TypeTagU256].
  bool isU256() => this is TypeTagU256;

  /// Signed integer helpers
  bool isI8() => this is TypeTagI8;

  bool isI16() => this is TypeTagI16;

  bool isI32() => this is TypeTagI32;

  bool isI64() => this is TypeTagI64;

  bool isI128() => this is TypeTagI128;

  bool isI256() => this is TypeTagI256;

  bool isPrimitive() {
    return this is TypeTagSigner ||
        this is TypeTagAddress ||
        this is TypeTagBool ||
        this is TypeTagU8 ||
        this is TypeTagU16 ||
        this is TypeTagU32 ||
        this is TypeTagU64 ||
        this is TypeTagU128 ||
        this is TypeTagU256 ||
        this is TypeTagI8 ||
        this is TypeTagI16 ||
        this is TypeTagI32 ||
        this is TypeTagI64 ||
        this is TypeTagI128 ||
        this is TypeTagI256;
  }
}

/// Represents a boolean type tag in the type system.
class TypeTagBool extends TypeTag {
  @override
  String toString() => 'bool';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.boolean.value);
  }

  static TypeTagBool load(Deserializer deserializer) {
    return TypeTagBool();
  }
}

/// Represents a type tag for an 8-bit unsigned integer (u8).
class TypeTagU8 extends TypeTag {
  @override
  String toString() => 'u8';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u8.value);
  }

  static TypeTagU8 load(Deserializer deserializer) {
    return TypeTagU8();
  }
}

/// Represents a type tag for an 8-bit signed integer (i8).
class TypeTagI8 extends TypeTag {
  @override
  String toString() => 'i8';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i8.value);
  }

  static TypeTagI8 load(Deserializer deserializer) {
    return TypeTagI8();
  }
}

/// Represents a type tag for unsigned 16-bit integers (u16).
class TypeTagU16 extends TypeTag {
  @override
  String toString() => 'u16';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u16.value);
  }

  static TypeTagU16 load(Deserializer deserializer) {
    return TypeTagU16();
  }
}

/// Represents a type tag for signed 16-bit integers (i16).
class TypeTagI16 extends TypeTag {
  @override
  String toString() => 'i16';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i16.value);
  }

  static TypeTagI16 load(Deserializer deserializer) {
    return TypeTagI16();
  }
}

/// Represents a type tag for a 32-bit unsigned integer (u32).
class TypeTagU32 extends TypeTag {
  @override
  String toString() => 'u32';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u32.value);
  }

  static TypeTagU32 load(Deserializer deserializer) {
    return TypeTagU32();
  }
}

/// Represents a type tag for a 32-bit signed integer (i32).
class TypeTagI32 extends TypeTag {
  @override
  String toString() => 'i32';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i32.value);
  }

  static TypeTagI32 load(Deserializer deserializer) {
    return TypeTagI32();
  }
}

/// Represents a type tag for 64-bit unsigned integers (u64).
class TypeTagU64 extends TypeTag {
  @override
  String toString() => 'u64';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u64.value);
  }

  static TypeTagU64 load(Deserializer deserializer) {
    return TypeTagU64();
  }
}

/// Represents a type tag for 64-bit signed integers (i64).
class TypeTagI64 extends TypeTag {
  @override
  String toString() => 'i64';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i64.value);
  }

  static TypeTagI64 load(Deserializer deserializer) {
    return TypeTagI64();
  }
}

/// Represents a type tag for the u128 data type.
class TypeTagU128 extends TypeTag {
  @override
  String toString() => 'u128';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u128.value);
  }

  static TypeTagU128 load(Deserializer deserializer) {
    return TypeTagU128();
  }
}

/// Represents a type tag for the i128 data type.
class TypeTagI128 extends TypeTag {
  @override
  String toString() => 'i128';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i128.value);
  }

  static TypeTagI128 load(Deserializer deserializer) {
    return TypeTagI128();
  }
}

/// Represents a type tag for the U256 data type.
class TypeTagU256 extends TypeTag {
  @override
  String toString() => 'u256';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.u256.value);
  }

  static TypeTagU256 load(Deserializer deserializer) {
    return TypeTagU256();
  }
}

/// Represents a type tag for the I256 data type.
class TypeTagI256 extends TypeTag {
  @override
  String toString() => 'i256';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.i256.value);
  }

  static TypeTagI256 load(Deserializer deserializer) {
    return TypeTagI256();
  }
}

/// Represents a type tag for an address in the system.
class TypeTagAddress extends TypeTag {
  @override
  String toString() => 'address';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.address.value);
  }

  static TypeTagAddress load(Deserializer deserializer) {
    return TypeTagAddress();
  }
}

/// Represents a type tag for a signer in the system.
class TypeTagSigner extends TypeTag {
  @override
  String toString() => 'signer';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.signer.value);
  }

  static TypeTagSigner load(Deserializer deserializer) {
    return TypeTagSigner();
  }
}

/// Represents a reference to a type tag in the type system.
class TypeTagReference extends TypeTag {
  /// The TypeTag to reference.
  final TypeTag value;

  /// Initializes a new instance of the class with the specified parameters.
  TypeTagReference(this.value);

  @override
  String toString() => '&$value';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.reference.value);
  }

  static TypeTagReference load(Deserializer deserializer) {
    final value = TypeTag.deserialize(deserializer);
    return TypeTagReference(value);
  }
}

/// Represents a generic type tag used for type parameters in entry functions.
/// Generics are not serialized into a real type, so they cannot be used as a
/// type directly.
class TypeTagGeneric extends TypeTag {
  final int value;

  TypeTagGeneric(this.value) {
    if (value < 0) {
      throw ArgumentError('Generic type parameter index cannot be negative');
    }
  }

  @override
  String toString() => 'T$value';

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.generic.value);
    serializer.serializeU32(value);
  }

  static TypeTagGeneric load(Deserializer deserializer) {
    final value = deserializer.deserializeU32();
    return TypeTagGeneric(value);
  }
}

/// Represents a vector type tag, which encapsulates a single type tag value.
class TypeTagVector extends TypeTag {
  final TypeTag value;

  TypeTagVector(this.value);

  @override
  String toString() => 'vector<$value>';

  /// Creates a new TypeTagVector instance with a TypeTagU8 type.
  static TypeTagVector u8() {
    return TypeTagVector(TypeTagU8());
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.vector.value);
    value.serialize(serializer);
  }

  static TypeTagVector load(Deserializer deserializer) {
    final value = TypeTag.deserialize(deserializer);
    return TypeTagVector(value);
  }
}

/// Represents a structured type tag in the system, extending the base TypeTag
/// class. This class encapsulates information about a specific structure,
/// including its address, module name, and type arguments, and provides
/// methods for serialization and type checking.
class TypeTagStruct extends TypeTag {
  /// The StructTag instance containing the details of the structured type.
  final StructTag value;

  TypeTagStruct(this.value);

  @override
  String toString() {
    // Collect type args and add it if there are any
    var typePredicate = '';
    if (value.typeArgs.isNotEmpty) {
      typePredicate =
          '<${value.typeArgs.map((typeArg) => typeArg.toString()).join(', ')}>';
    }

    return '${value.address}::${value.moduleName.identifier}::'
        '${value.name.identifier}$typePredicate';
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TypeTagVariants.struct.value);
    value.serialize(serializer);
  }

  static TypeTagStruct load(Deserializer deserializer) {
    final value = StructTag.deserialize(deserializer);
    return TypeTagStruct(value);
  }

  /// Determines if the provided address, module name, and struct name match
  /// the current type tag.
  bool isTypeTag(AccountAddress address, String moduleName, String structName) {
    return value.moduleName.identifier == moduleName &&
        value.name.identifier == structName &&
        value.address.equals(address);
  }

  /// Checks if the current struct tag is the standard string type
  /// `0x1::string::String`.
  bool isString() {
    return isTypeTag(AccountAddress.one, 'string', 'String');
  }

  /// Checks if the current struct tag is the standard option type
  /// `0x1::option::Option`.
  bool isOption() {
    return isTypeTag(AccountAddress.one, 'option', 'Option');
  }

  /// Checks if the current struct tag is the standard object type
  /// `0x1::object::Object`.
  bool isObject() {
    return isTypeTag(AccountAddress.one, 'object', 'Object');
  }

  /// Checks if the provided value is a 'DelegationKey' for permissioned
  /// signers.
  bool isDelegationKey() {
    return isTypeTag(
      AccountAddress.one,
      'permissioned_delegation',
      'DelegationKey',
    );
  }

  /// Checks if the provided value is of type `RateLimiter`.
  bool isRateLimiter() {
    return isTypeTag(AccountAddress.one, 'rate_limiter', 'RateLimiter');
  }
}

/// Represents a structured tag that includes an address, module name,
/// name, and type arguments. This class is used to define and manage
/// structured data types within the SDK.
class StructTag extends Serializable {
  final AccountAddress address;

  final Identifier moduleName;

  final Identifier name;

  final List<TypeTag> typeArgs;

  StructTag(this.address, this.moduleName, this.name, this.typeArgs);

  @override
  void serialize(Serializer serializer) {
    serializer.serialize(address);
    serializer.serialize(moduleName);
    serializer.serialize(name);
    serializer.serializeVector(typeArgs);
  }

  static StructTag deserialize(Deserializer deserializer) {
    final address = AccountAddress.deserialize(deserializer);
    final moduleName = Identifier.deserialize(deserializer);
    final name = Identifier.deserialize(deserializer);
    final typeArgs = deserializer.deserializeVector(TypeTag.deserialize);
    return StructTag(address, moduleName, name, typeArgs);
  }
}

/// Retrieves the StructTag for the AptosCoin, which represents the Aptos Coin
/// in the Aptos blockchain.
StructTag aptosCoinStructTag() {
  return StructTag(
    AccountAddress.one,
    Identifier('aptos_coin'),
    Identifier('AptosCoin'),
    [],
  );
}

/// Returns a new StructTag representing a string type.
StructTag stringStructTag() {
  return StructTag(
    AccountAddress.one,
    Identifier('string'),
    Identifier('String'),
    [],
  );
}

/// Creates a new StructTag for the Option type with the specified type
/// argument.
StructTag optionStructTag(TypeTag typeArg) {
  return StructTag(
    AccountAddress.one,
    Identifier('option'),
    Identifier('Option'),
    [typeArg],
  );
}

/// Creates a new StructTag for the Object type with the specified type
/// argument.
StructTag objectStructTag(TypeTag typeArg) {
  return StructTag(
    AccountAddress.one,
    Identifier('object'),
    Identifier('Object'),
    [typeArg],
  );
}
