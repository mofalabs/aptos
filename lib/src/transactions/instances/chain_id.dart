import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';

/// Represents a ChainId that can be serialized and deserialized.
class ChainId extends Serializable {
  final int chainId;

  /// Initializes a new instance of the class with the specified chain ID.
  ///
  /// [chainId] - The ID of the blockchain network to be used.
  ChainId(this.chainId);

  /// Serializes the current object using the provided serializer.
  /// This function helps in converting the object into a format suitable for
  /// transmission or storage.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeU8(chainId);
  }

  /// Deserializes a ChainId from the provided deserializer.
  /// This function allows you to reconstruct a ChainId object from serialized
  /// data.
  static ChainId deserialize(Deserializer deserializer) {
    final chainId = deserializer.deserializeU8();
    return ChainId(chainId);
  }
}
