import '../../transactions/instances/transaction_argument.dart';
import '../../types/types.dart';
import '../deserializer.dart';
import '../serializer.dart';
import 'fixed_bytes.dart';

/// This class exists solely to represent a sequence of fixed bytes as a
/// serialized entry function, because serializing an entry function appends a
/// prefix that's *only* used for entry function arguments.
///
/// NOTE: Using this class for serialized script functions will lead to
/// erroneous and unexpected behavior.
///
/// If you wish to convert this class back to a TransactionArgument, you must
/// know the type of the argument beforehand, and use the appropriate class to
/// deserialize the bytes within an instance of this class.
class EntryFunctionBytes extends Serializable
    implements EntryFunctionArgument {
  final FixedBytes value;

  EntryFunctionBytes._(HexInput value) : value = FixedBytes(value);

  // Note that to see the Move, BCS-serialized representation of the underlying
  // fixed byte vector, we must not serialize the length prefix.
  //
  // In other words, this class is only used to represent a sequence of bytes
  // that are already BCS-serialized as a type. To represent those bytes
  // accurately, the BCS-serialized form is the same exact representation.
  @override
  void serialize(Serializer serializer) {
    serializer.serialize(value);
  }

  /// When we serialize these bytes as an entry function argument, we need to
  /// serialize the length prefix. This essentially converts the underlying
  /// fixed byte vector to a type-agnostic byte vector.
  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeU32AsUleb128(value.value.length);
    serializer.serialize(this);
  }

  /// The only way to create an instance of this class is to use this static
  /// method. This function should only be used when deserializing a sequence
  /// of EntryFunctionPayload arguments.
  static EntryFunctionBytes deserialize(Deserializer deserializer, int length) {
    final fixedBytes = FixedBytes.deserialize(deserializer, length);
    return EntryFunctionBytes._(fixedBytes.value);
  }
}
