import 'dart:convert';
import 'dart:typed_data';

import '../../core/hex.dart';
import '../../transactions/instances/transaction_argument.dart';
import '../../types/types.dart';
import '../deserializer.dart';
import '../serializer.dart';
import 'move_primitives.dart';

/// This class is the Aptos Dart SDK representation of a Move `vector<T>`,
/// where `T` represents either a primitive type (`bool`, `u8`, `u64`, ...)
/// or a BCS-serializable struct itself.
///
/// It is a BCS-serializable, array-like type that contains a list of values of
/// type [T], where [T] is a class that extends [Serializable].
///
/// The purpose of this class is to facilitate easy construction of
/// BCS-serializable Move `vector<T>` types.
///
/// ```dart
/// // in Move: `vector<u8> [1, 2, 3, 4];`
/// final vecOfU8s = MoveVector<U8>([U8(1), U8(2), U8(3), U8(4)]);
/// // in Move: `std::bcs::to_bytes(vector<u8> [1, 2, 3, 4]);`
/// final bcsBytes = vecOfU8s.bcsToBytes();
///
/// // vector<vector<u8>> [ vector<u8> [1], vector<u8> [1, 2, 3, 4] ];
/// final vecOfVecs = MoveVector<MoveVector<U8>>([
///   MoveVector<U8>([U8(1)]),
///   MoveVector.u8([1, 2, 3, 4]),
/// ]);
///
/// // vector<MoveString> [ std::string::utf8(b"hello"), std::string::utf8(b"world") ];
/// final vecOfStrings = MoveVector.string(['hello', 'world']);
/// ```
class MoveVector<T extends Serializable> extends Serializable
    implements TransactionArgument {
  List<T> values;

  MoveVector(this.values);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeVector(values);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  /// Serializes this vector as a script function argument.
  ///
  /// A `vector<u8>` uses the dedicated U8Vector variant; any other element
  /// type is BCS-serialized in full and wrapped in a [Serialized] argument.
  @override
  void serializeForScriptFunction(Serializer serializer) {
    if (values.isNotEmpty && values.first is! U8) {
      final serialized = Serialized(bcsToBytes());
      serialized.serializeForScriptFunction(serializer);
      return;
    }
    serializer.serializeU32AsUleb128(
        ScriptTransactionArgumentVariants.u8Vector.value);
    serializer.serialize(this);
  }

  /// Factory method to generate a `MoveVector<U8>` from a `List<int>`, a
  /// [Uint8List], or a hex string.
  ///
  /// ```dart
  /// final v = MoveVector.u8([1, 2, 3, 4]);
  /// ```
  static MoveVector<U8> u8(Object values) {
    List<int> numbers;

    if (values is Uint8List) {
      numbers = values;
    } else if (values is List<int>) {
      numbers = values;
    } else if (values is String) {
      numbers = Hex.fromHexInput(values).toUint8List();
    } else {
      throw ArgumentError(
        'Invalid input type, must be a List<int>, Uint8List, or hex string',
      );
    }

    return MoveVector<U8>(numbers.map(U8.new).toList());
  }

  /// Factory method to generate a `MoveVector<U16>` from a list of numbers.
  static MoveVector<U16> u16(List<int> values) =>
      MoveVector<U16>(values.map(U16.new).toList());

  /// Factory method to generate a `MoveVector<U32>` from a list of numbers.
  static MoveVector<U32> u32(List<int> values) =>
      MoveVector<U32>(values.map(U32.new).toList());

  /// Factory method to generate a `MoveVector<U64>` from a list of [BigInt]s.
  static MoveVector<U64> u64(List<BigInt> values) =>
      MoveVector<U64>(values.map(U64.new).toList());

  /// Factory method to generate a `MoveVector<U128>` from a list of [BigInt]s.
  static MoveVector<U128> u128(List<BigInt> values) =>
      MoveVector<U128>(values.map(U128.new).toList());

  /// Factory method to generate a `MoveVector<U256>` from a list of [BigInt]s.
  static MoveVector<U256> u256(List<BigInt> values) =>
      MoveVector<U256>(values.map(U256.new).toList());

  /// Factory method to generate a `MoveVector<Bool>` from a list of booleans.
  static MoveVector<Bool> boolean(List<bool> values) =>
      MoveVector<Bool>(values.map(Bool.new).toList());

  /// Factory method to generate a `MoveVector<I8>` from a list of numbers.
  static MoveVector<I8> i8(List<int> values) =>
      MoveVector<I8>(values.map(I8.new).toList());

  /// Factory method to generate a `MoveVector<I16>` from a list of numbers.
  static MoveVector<I16> i16(List<int> values) =>
      MoveVector<I16>(values.map(I16.new).toList());

  /// Factory method to generate a `MoveVector<I32>` from a list of numbers.
  static MoveVector<I32> i32(List<int> values) =>
      MoveVector<I32>(values.map(I32.new).toList());

  /// Factory method to generate a `MoveVector<I64>` from a list of [BigInt]s.
  static MoveVector<I64> i64(List<BigInt> values) =>
      MoveVector<I64>(values.map(I64.new).toList());

  /// Factory method to generate a `MoveVector<I128>` from a list of [BigInt]s.
  static MoveVector<I128> i128(List<BigInt> values) =>
      MoveVector<I128>(values.map(I128.new).toList());

  /// Factory method to generate a `MoveVector<I256>` from a list of [BigInt]s.
  static MoveVector<I256> i256(List<BigInt> values) =>
      MoveVector<I256>(values.map(I256.new).toList());

  /// Factory method to generate a `MoveVector<MoveString>` from a list of
  /// strings.
  ///
  /// ```dart
  /// final v = MoveVector.string(['hello', 'world']);
  /// ```
  static MoveVector<MoveString> string(List<String> values) =>
      MoveVector<MoveString>(values.map(MoveString.new).toList());

  /// Deserialize a `MoveVector` of type [T], specifically where [T] is a
  /// [Serializable] type.
  ///
  /// NOTE: This only works with a depth of one. Generics will not work.
  ///
  /// If you're looking for a more flexible deserialization function, you can
  /// use the [Deserializer.deserializeVector] function.
  ///
  /// ```dart
  /// final vec = MoveVector.deserialize(deserializer, U64.deserialize);
  /// ```
  static MoveVector<T> deserialize<T extends Serializable>(
    Deserializer deserializer,
    Deserializable<T> cls,
  ) {
    final length = deserializer.deserializeUleb128AsU32();
    final values = <T>[];
    for (var i = 0; i < length; i += 1) {
      values.add(cls(deserializer));
    }
    return MoveVector(values);
  }
}

/// Represents a serialized data structure that encapsulates a byte array.
///
/// This is used to represent already BCS-serialized bytes passed as a script
/// function argument (the `Serialized` script argument variant).
class Serialized extends Serializable implements TransactionArgument {
  final Uint8List value;

  Serialized(HexInput value) : value = Hex.hexInputToUint8List(value);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serialize(serializer);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(
        ScriptTransactionArgumentVariants.serialized.value);
    serialize(serializer);
  }

  static Serialized deserialize(Deserializer deserializer) {
    return Serialized(deserializer.deserializeBytes());
  }

  /// Deserialize the inner bytes into a `MoveVector` of the specified type.
  MoveVector<T> toMoveVector<T extends Serializable>(Deserializable<T> cls) {
    final deserializer = Deserializer(bcsToBytes());
    deserializer.deserializeUleb128AsU32();
    final vec = deserializer.deserializeVector(cls);
    return MoveVector(vec);
  }
}

/// Represents a Move `std::string::String` value that can be serialized and
/// deserialized.
class MoveString extends Serializable implements TransactionArgument {
  String value;

  MoveString(this.value);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    // Serialize the string as a fixed byte string, i.e., without the length
    // prefix, put those bytes into a vector<u8> and serialize it as a script
    // function argument.
    final fixedStringBytes = Uint8List.fromList(utf8.encode(value));
    final vectorU8 = MoveVector.u8(fixedStringBytes);
    vectorU8.serializeForScriptFunction(serializer);
  }

  static MoveString deserialize(Deserializer deserializer) {
    return MoveString(deserializer.deserializeStr());
  }
}

/// Represents a Move `std::option::Option<T>` value.
class MoveOption<T extends Serializable> extends Serializable
    implements EntryFunctionArgument {
  final MoveVector<T> _vec;

  final T? value;

  MoveOption([T? input])
      : _vec = MoveVector(input != null ? [input] : []),
        value = input;

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  /// Retrieves the inner value of the [MoveOption].
  ///
  /// This method is inspired by Rust's `Option<T>.unwrap()`.
  /// Throws a [StateError] if the value is not present.
  T unwrap() {
    if (!isSome()) {
      throw StateError('Called unwrap on a MoveOption with no value');
    }
    return _vec.values.first;
  }

  /// Check if the [MoveOption] has a value.
  bool isSome() => _vec.values.length == 1;

  @override
  void serialize(Serializer serializer) {
    // serialize 0 or 1, and if 1, serialize the value
    _vec.serialize(serializer);
  }

  /// Factory method to generate a `MoveOption<U8>` from an `int` or `null`.
  ///
  /// ```dart
  /// MoveOption.u8(1).isSome() == true;
  /// MoveOption.u8(null).isSome() == false;
  /// ```
  static MoveOption<U8> u8(int? value) =>
      MoveOption<U8>(value != null ? U8(value) : null);

  /// Factory method to generate a `MoveOption<U16>` from an `int` or `null`.
  static MoveOption<U16> u16(int? value) =>
      MoveOption<U16>(value != null ? U16(value) : null);

  /// Factory method to generate a `MoveOption<U32>` from an `int` or `null`.
  static MoveOption<U32> u32(int? value) =>
      MoveOption<U32>(value != null ? U32(value) : null);

  /// Factory method to generate a `MoveOption<U64>` from a [BigInt] or `null`.
  static MoveOption<U64> u64(BigInt? value) =>
      MoveOption<U64>(value != null ? U64(value) : null);

  /// Factory method to generate a `MoveOption<U128>` from a [BigInt] or `null`.
  static MoveOption<U128> u128(BigInt? value) =>
      MoveOption<U128>(value != null ? U128(value) : null);

  /// Factory method to generate a `MoveOption<U256>` from a [BigInt] or `null`.
  static MoveOption<U256> u256(BigInt? value) =>
      MoveOption<U256>(value != null ? U256(value) : null);

  /// Factory method to generate a `MoveOption<Bool>` from a `bool` or `null`.
  static MoveOption<Bool> boolean(bool? value) =>
      MoveOption<Bool>(value != null ? Bool(value) : null);

  /// Factory method to generate a `MoveOption<I8>` from an `int` or `null`.
  static MoveOption<I8> i8(int? value) =>
      MoveOption<I8>(value != null ? I8(value) : null);

  /// Factory method to generate a `MoveOption<I16>` from an `int` or `null`.
  static MoveOption<I16> i16(int? value) =>
      MoveOption<I16>(value != null ? I16(value) : null);

  /// Factory method to generate a `MoveOption<I32>` from an `int` or `null`.
  static MoveOption<I32> i32(int? value) =>
      MoveOption<I32>(value != null ? I32(value) : null);

  /// Factory method to generate a `MoveOption<I64>` from a [BigInt] or `null`.
  static MoveOption<I64> i64(BigInt? value) =>
      MoveOption<I64>(value != null ? I64(value) : null);

  /// Factory method to generate a `MoveOption<I128>` from a [BigInt] or `null`.
  static MoveOption<I128> i128(BigInt? value) =>
      MoveOption<I128>(value != null ? I128(value) : null);

  /// Factory method to generate a `MoveOption<I256>` from a [BigInt] or `null`.
  static MoveOption<I256> i256(BigInt? value) =>
      MoveOption<I256>(value != null ? I256(value) : null);

  /// Factory method to generate a `MoveOption<MoveString>` from a `String` or
  /// `null`.
  ///
  /// ```dart
  /// MoveOption.string('hello').isSome() == true;
  /// MoveOption.string('').isSome() == true;
  /// MoveOption.string(null).isSome() == false;
  /// ```
  static MoveOption<MoveString> string(String? value) =>
      MoveOption<MoveString>(value != null ? MoveString(value) : null);

  static MoveOption<U> deserialize<U extends Serializable>(
    Deserializer deserializer,
    Deserializable<U> cls,
  ) {
    final vector = MoveVector.deserialize(deserializer, cls);
    return MoveOption(vector.values.isNotEmpty ? vector.values.first : null);
  }
}
