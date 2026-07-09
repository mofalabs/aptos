import 'dart:typed_data';

import '../../core/hex.dart';
import '../../transactions/instances/transaction_argument.dart';
import '../../types/types.dart';
import '../deserializer.dart';
import '../serializer.dart';

/// Represents a contiguous sequence of already serialized BCS bytes.
///
/// This class differs from most other Serializable classes in that its
/// internal byte buffer is serialized to BCS bytes exactly as-is, without
/// prepending the length of the bytes. It is ideal for scenarios where custom
/// serialization is required, such as passing serialized bytes as transaction
/// arguments. Additionally, it serves as a representation of type-agnostic BCS
/// bytes, akin to a `vector<u8>`.
///
/// An example use case includes handling bytes resulting from entry function
/// arguments that have been serialized for an entry function.
///
/// ```dart
/// final yourCustomSerializedBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
/// final fixedBytes = FixedBytes(yourCustomSerializedBytes);
/// ```
///
/// See also [EntryFunctionBytes].
class FixedBytes extends Serializable implements TransactionArgument {
  final Uint8List value;

  /// Creates an instance of the class with a specified [HexInput], converted
  /// to a [Uint8List].
  FixedBytes(HexInput value) : value = Hex.hexInputToUint8List(value);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(value);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serialize(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer.serialize(this);
  }

  /// Deserializes a fixed-length byte array from the provided deserializer.
  static FixedBytes deserialize(Deserializer deserializer, int length) {
    final bytes = deserializer.deserializeFixedBytes(length);
    return FixedBytes(bytes);
  }
}
