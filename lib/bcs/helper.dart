
import 'dart:typed_data';

import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/serializer.dart';

mixin Serializable {
  void serialize(Serializer serializer);
}

void serializeVector<T extends Serializable>(List<T> value, Serializer serializer) {
  serializer.serializeU32AsUleb128(value.length);
  for (T item in value) {
    item.serialize(serializer);
  }
}

Uint8List serializeVectorWithFunc(List<dynamic> value, String func) {
  final serializer = Serializer();
  serializer.serializeU32AsUleb128(value.length);
  
  Function fn;
  switch (func) {
    case "serializeStr":
      fn = serializer.serializeStr;
      break;
    case "serializeBytes":
      fn = serializer.serializeBytes;
      break;
    case "serializeFixedBytes":
      fn = serializer.serializeFixedBytes;
      break;
    case "serializeBool":
      fn = serializer.serializeBool;
      break;
    case "serializeU8":
      fn = serializer.serializeU8;
      break;
    case "serializeU16":
      fn = serializer.serializeU16;
      break;
    case "serializeU32":
      fn = serializer.serializeU32;
      break;
    case "serializeU64":
      fn = serializer.serializeU64;
      break;
    case "serializeU128":
      fn = serializer.serializeU128;
      break;
    default:
      throw ArgumentError("Cannot found $func in Serializer");
  }

  for (var item in value) {
    fn.call(item);
  }
  return serializer.getBytes();
}

List<T> deserializeVector<T>(Deserializer deserializer, dynamic deserializeFunc) {
  int length = deserializer.deserializeUleb128AsU32();
  final list = <T>[];
  for (int i = 0; i < length; i += 1) {
    list.add(deserializeFunc(deserializer));
  }
  return list;
}

Uint8List bcsToBytes<T extends Serializable>(T value) {
  final serializer = Serializer();
  value.serialize(serializer);
  return serializer.getBytes();
}

Uint8List bcsSerializeUint64(BigInt value) {
  final serializer = Serializer();
  serializer.serializeU64(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeU8(int value) {
  final serializer = Serializer();
  serializer.serializeU8(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeU16(int value) {
  final serializer = Serializer();
  serializer.serializeU16(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeU32(int value) {
  final serializer = Serializer();
  serializer.serializeU32(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeU128(BigInt value) {
  final serializer = Serializer();
  serializer.serializeU128(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeBool(bool value) {
  final serializer = Serializer();
  serializer.serializeBool(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeStr(String value) {
  final serializer = Serializer();
  serializer.serializeStr(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeBytes(Uint8List value) {
  final serializer = Serializer();
  serializer.serializeBytes(value);
  return serializer.getBytes();
}

Uint8List bcsSerializeFixedBytes(Uint8List value) {
  final serializer = Serializer();
  serializer.serializeFixedBytes(value);
  return serializer.getBytes();
}
