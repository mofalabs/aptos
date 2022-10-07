import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/serializer.dart';

class Identifier {
  final String value;

  Identifier(this.value);

  void serialize(Serializer serializer) {
    serializer.serializeStr(value);
  }

  static Identifier deserialize(Deserializer deserializer) {
    String value = deserializer.deserializeStr();
    return Identifier(value);
  }
}