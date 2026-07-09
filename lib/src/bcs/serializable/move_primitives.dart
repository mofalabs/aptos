import '../../transactions/instances/transaction_argument.dart';
import '../../types/types.dart';
import '../consts.dart';
import '../deserializer.dart';
import '../serializer.dart';

/// Represents a Move `bool` value that can be serialized and deserialized.
class Bool extends Serializable implements TransactionArgument {
  final bool value;

  Bool(this.value);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBool(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.boolean.value);
    serializer.serialize(this);
  }

  static Bool deserialize(Deserializer deserializer) {
    return Bool(deserializer.deserializeBool());
  }
}

/// Represents an unsigned 8-bit integer (U8) value.
class U8 extends Serializable implements TransactionArgument {
  final int value;

  U8(this.value) {
    validateNumberInRange(value, 0, maxU8Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU8(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.u8.value);
    serializer.serialize(this);
  }

  static U8 deserialize(Deserializer deserializer) {
    return U8(deserializer.deserializeU8());
  }
}

/// Represents an unsigned 16-bit integer (U16) value.
class U16 extends Serializable implements TransactionArgument {
  final int value;

  U16(this.value) {
    validateNumberInRange(value, 0, maxU16Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU16(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.u16.value);
    serializer.serialize(this);
  }

  static U16 deserialize(Deserializer deserializer) {
    return U16(deserializer.deserializeU16());
  }
}

/// Represents an unsigned 32-bit integer (U32) value.
class U32 extends Serializable implements TransactionArgument {
  final int value;

  U32(this.value) {
    validateNumberInRange(value, 0, maxU32Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.u32.value);
    serializer.serialize(this);
  }

  static U32 deserialize(Deserializer deserializer) {
    return U32(deserializer.deserializeU32());
  }
}

/// Represents an unsigned 64-bit integer (U64) value.
class U64 extends Serializable implements TransactionArgument {
  final BigInt value;

  U64(this.value) {
    validateBigIntInRange(value, BigInt.zero, maxU64BigInt);
  }

  U64.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU64(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.u64.value);
    serializer.serialize(this);
  }

  static U64 deserialize(Deserializer deserializer) {
    return U64(deserializer.deserializeU64());
  }
}

/// Represents an unsigned 128-bit integer (U128) value.
class U128 extends Serializable implements TransactionArgument {
  final BigInt value;

  U128(this.value) {
    validateBigIntInRange(value, BigInt.zero, maxU128BigInt);
  }

  U128.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU128(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.u128.value);
    serializer.serialize(this);
  }

  static U128 deserialize(Deserializer deserializer) {
    return U128(deserializer.deserializeU128());
  }
}

/// Represents an unsigned 256-bit integer (U256) value.
class U256 extends Serializable implements TransactionArgument {
  final BigInt value;

  U256(this.value) {
    validateBigIntInRange(value, BigInt.zero, maxU256BigInt);
  }

  U256.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU256(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.u256.value);
    serializer.serialize(this);
  }

  static U256 deserialize(Deserializer deserializer) {
    return U256(deserializer.deserializeU256());
  }
}

/// Represents a signed 8-bit integer (I8) value.
class I8 extends Serializable implements TransactionArgument {
  final int value;

  I8(this.value) {
    validateNumberInRange(value, minI8Number, maxI8Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI8(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.i8.value);
    serializer.serialize(this);
  }

  static I8 deserialize(Deserializer deserializer) {
    return I8(deserializer.deserializeI8());
  }
}

/// Represents a signed 16-bit integer (I16) value.
class I16 extends Serializable implements TransactionArgument {
  final int value;

  I16(this.value) {
    validateNumberInRange(value, minI16Number, maxI16Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI16(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.i16.value);
    serializer.serialize(this);
  }

  static I16 deserialize(Deserializer deserializer) {
    return I16(deserializer.deserializeI16());
  }
}

/// Represents a signed 32-bit integer (I32) value.
class I32 extends Serializable implements TransactionArgument {
  final int value;

  I32(this.value) {
    validateNumberInRange(value, minI32Number, maxI32Number);
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI32(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.i32.value);
    serializer.serialize(this);
  }

  static I32 deserialize(Deserializer deserializer) {
    return I32(deserializer.deserializeI32());
  }
}

/// Represents a signed 64-bit integer (I64) value.
class I64 extends Serializable implements TransactionArgument {
  final BigInt value;

  I64(this.value) {
    validateBigIntInRange(value, minI64BigInt, maxI64BigInt);
  }

  I64.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI64(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(ScriptTransactionArgumentVariants.i64.value);
    serializer.serialize(this);
  }

  static I64 deserialize(Deserializer deserializer) {
    return I64(deserializer.deserializeI64());
  }
}

/// Represents a signed 128-bit integer (I128) value.
class I128 extends Serializable implements TransactionArgument {
  final BigInt value;

  I128(this.value) {
    validateBigIntInRange(value, minI128BigInt, maxI128BigInt);
  }

  I128.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI128(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.i128.value);
    serializer.serialize(this);
  }

  static I128 deserialize(Deserializer deserializer) {
    return I128(deserializer.deserializeI128());
  }
}

/// Represents a signed 256-bit integer (I256) value.
class I256 extends Serializable implements TransactionArgument {
  final BigInt value;

  I256(this.value) {
    validateBigIntInRange(value, minI256BigInt, maxI256BigInt);
  }

  I256.fromInt(int value) : this(BigInt.from(value));

  @override
  void serialize(Serializer serializer) {
    serializer.serializeI256(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.i256.value);
    serializer.serialize(this);
  }

  static I256 deserialize(Deserializer deserializer) {
    return I256(deserializer.deserializeI256());
  }
}
