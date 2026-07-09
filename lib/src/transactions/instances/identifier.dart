import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';

/// Represents an Identifier that can be serialized and deserialized.
/// This class is used to denote the module "name" in "ModuleId" and
/// the "function name" in "EntryFunction".
class Identifier extends Serializable {
  String identifier;

  /// Creates an instance of the class with a specified identifier.
  Identifier(this.identifier);

  /// Serializes the identifier of the current instance using the provided
  /// serializer.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(identifier);
  }

  /// Deserializes an identifier from the provided deserializer.
  /// This function is useful for reconstructing an Identifier object from a
  /// serialized format.
  static Identifier deserialize(Deserializer deserializer) {
    final identifier = deserializer.deserializeStr();
    return Identifier(identifier);
  }
}
