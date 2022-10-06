
import 'dart:convert';
import 'dart:typed_data';
import 'package:aptos/bcs/consts.dart';

class Deserializer {

  Uint8List buffer = Uint8List(64);
  int offset = 0;

  Deserializer(Uint8List data) {
    // copies data to prevent outside mutation of buffer.
    buffer = Uint8List.fromList(data);
    offset = 0;
  }

  Uint8List read(int length) {
    if (offset + length > buffer.lengthInBytes) {
      throw RangeError("Reached to the end of buffer");
    }

    final bytes = buffer.sublist(offset, offset + length);
    offset += length;
    return bytes;
  }

  String deserializeStr() {
    final value = deserializeBytes();
    return utf8.decode(value);
  }

  Uint8List deserializeBytes() {
    int len = deserializeUleb128AsU32();
    return read(len);
  }

  Uint8List deserializeFixedBytes(int len) {
    return read(len);
  }

  bool deserializeBool() {
    int bool = read(1)[0];
    if (bool != 1 && bool != 0) {
      throw ArgumentError("Invalid boolean value");
    }
    return bool == 1;
  }

  int deserializeU8() {
    return ByteData.sublistView(read(1)).getUint8(0);
  }

  int deserializeU16() {
    return ByteData.sublistView(read(2)).getUint16(0, Endian.little);
  }

  int deserializeU32() {
    return ByteData.sublistView(read(4)).getUint32(0, Endian.little);
  }

  BigInt deserializeU64() {
    int low = deserializeU32();
    int high = deserializeU32();

    // combine the two 32-bit values and return (little endian)
    return (BigInt.from(high) << 32) | BigInt.from(low);
  }

  BigInt deserializeU128() {
    BigInt low = deserializeU64();
    BigInt high = deserializeU64();

    // combine the two 64-bit values and return (little endian)
    return (high << 64) | low;
  }

  int deserializeUleb128AsU32() {
    var value = BigInt.zero;
    var shift = 0;

    while (value < BigInt.from(MAX_U32_NUMBER)) {
      int byte = deserializeU8();
      value |= BigInt.from(byte & 0x7f) << shift;

      if ((byte & 0x80) == 0) {
        break;
      }
      shift += 7;
    }

    if (value > BigInt.from(MAX_U32_NUMBER)) {
      throw ArgumentError("Overflow while parsing uleb128-encoded uint32 value");
    }

    return value.toInt();
  }

}