import 'dart:typed_data';

import '../../bcs/serializer.dart';
import '../../core/hex.dart';

/// Represents an argument for entry functions, providing methods to serialize
/// the argument to BCS-serialized bytes and convert it to different formats.
abstract class EntryFunctionArgument {
  /// Serialize an argument to BCS-serialized bytes.
  void serialize(Serializer serializer);

  /// Serialize an argument as a type-agnostic, fixed byte sequence. The byte
  /// sequence contains the number of the following bytes followed by the
  /// BCS-serialized bytes for a typed argument.
  void serializeForEntryFunction(Serializer serializer);

  /// Convert the argument to BCS-serialized bytes.
  Uint8List bcsToBytes();

  /// Converts the BCS-serialized bytes of an argument into a hexadecimal
  /// representation.
  Hex bcsToHex();
}

/// Represents an argument for script functions, providing methods to serialize
/// and convert to bytes.
abstract class ScriptFunctionArgument {
  /// Serialize an argument to BCS-serialized bytes.
  void serialize(Serializer serializer);

  /// Serialize an argument to BCS-serialized bytes as a type aware byte
  /// sequence. The byte sequence contains an enum variant index followed by
  /// the BCS-serialized bytes for a typed argument.
  void serializeForScriptFunction(Serializer serializer);

  Uint8List bcsToBytes();

  Hex bcsToHex();
}

/// An argument that can be used in both entry functions and script functions.
abstract class TransactionArgument
    implements EntryFunctionArgument, ScriptFunctionArgument {}
