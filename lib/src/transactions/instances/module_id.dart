import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import 'identifier.dart';

/// Represents a ModuleId that can be serialized and deserialized.
/// A ModuleId consists of a module address (e.g., "0x1") and a module name
/// (e.g., "coin").
class ModuleId extends Serializable {
  final AccountAddress address;

  final Identifier name;

  /// Initializes a new instance of the module with the specified account
  /// address and name.
  ///
  /// [address] - The account address, e.g., "0x1".
  /// [name] - The module name under the specified address, e.g., "coin".
  ModuleId(this.address, this.name);

  /// Converts a string literal in the format "account_address::module_name"
  /// to a ModuleId.
  ///
  /// Throws an [ArgumentError] if the provided moduleId is not in the correct
  /// format.
  static ModuleId fromStr(String moduleId) {
    final parts = moduleId.split('::');
    if (parts.length != 2) {
      throw ArgumentError('Invalid module id.');
    }
    return ModuleId(AccountAddress.fromString(parts[0]), Identifier(parts[1]));
  }

  /// Serializes the address and name properties using the provided serializer.
  /// This function is essential for converting the object's data into a format
  /// suitable for transmission or storage.
  @override
  void serialize(Serializer serializer) {
    address.serialize(serializer);
    name.serialize(serializer);
  }

  /// Deserializes a ModuleId from the provided deserializer.
  /// This function retrieves the account address and identifier to construct
  /// a ModuleId instance.
  static ModuleId deserialize(Deserializer deserializer) {
    final address = AccountAddress.deserialize(deserializer);
    final name = Identifier.deserialize(deserializer);
    return ModuleId(address, name);
  }
}
