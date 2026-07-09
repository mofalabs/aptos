import 'dart:convert';
import 'dart:typed_data';

import '../core/hex.dart';
import '../types/types.dart';
import 'consts.dart';

/// Maximum allowed length for deserialized byte arrays and strings.
/// This prevents memory exhaustion attacks from malformed BCS data.
/// Set to 10MB which should be sufficient for any legitimate use case.
const int _maxDeserializeBytesLength = 10 * 1024 * 1024; // 10MB

/// Maximum allowed vector element count. Without this cap a malformed BCS blob
/// with a ULEB128 length close to `maxU32Number` (~4.29 billion) would cause
/// `deserializeVector` to spin for billions of iterations before the inner
/// read bounds check trips, effectively a CPU-exhaustion DoS. Matches the
/// canonical `MAX_SEQUENCE_LENGTH = 2^31 - 1` bound used elsewhere in BCS.
const int _maxDeserializeVectorLength = 2147483647; // 2^31 - 1

/// A function that deserializes a byte buffer into a type [T], typically a
/// tear-off of a static `deserialize` method, e.g. `AccountAddress.deserialize`.
///
/// This enables the alternative syntax `deserializer.deserialize(MyClass.deserialize)`
/// as well as `deserializer.deserializeVector(MyClass.deserialize)`.
typedef Deserializable<T> = T Function(Deserializer deserializer);

/// A class that provides methods for deserializing various data types from a
/// byte buffer. It supports deserialization of primitive types, strings, and
/// complex objects using a BCS (Binary Canonical Serialization) layout.
class Deserializer {
  final Uint8List _buffer;

  int _offset = 0;

  /// Creates a new instance of the class with a copy of the provided data
  /// buffer. This prevents outside mutation of the buffer.
  Deserializer(Uint8List data) : _buffer = Uint8List.fromList(data);

  static Deserializer fromHex(HexInput hex) {
    return Deserializer(Hex.hexInputToUint8List(hex));
  }

  /// Reads a specified number of bytes from the buffer and advances the
  /// offset. Returns a view into the buffer rather than copying for better
  /// performance.
  ///
  /// SECURITY NOTE: This returns a view, not a copy. Callers that expose the
  /// result externally MUST copy it first. Internal numeric deserializers only
  /// read values and don't expose the view. [deserializeBytes] and
  /// [deserializeFixedBytes] copy before returning.
  Uint8List _read(int length) {
    if (_offset + length > _buffer.length) {
      throw StateError('Reached to the end of buffer');
    }

    final bytes = Uint8List.sublistView(_buffer, _offset, _offset + length);
    _offset += length;
    return bytes;
  }

  /// Returns the number of bytes remaining in the buffer.
  ///
  /// This information is useful to determine if there's more data to be read.
  int remaining() => _buffer.length - _offset;

  /// Asserts that the buffer has no remaining bytes.
  ///
  /// Throws a [StateError] if there are remaining bytes in the buffer.
  void assertFinished() {
    if (remaining() != 0) {
      throw StateError('Buffer has remaining bytes');
    }
  }

  /// Deserializes a UTF-8 encoded string from a byte array. It first reads the
  /// length of the string in bytes, followed by the actual byte content, and
  /// decodes it into a string.
  ///
  /// BCS layout for "string": string_length | string_content
  ///
  /// ```dart
  /// final deserializer = Deserializer(Uint8List.fromList([8, 49, 50, 51, 52, 97, 98, 99, 100]));
  /// assert(deserializer.deserializeStr() == '1234abcd');
  /// ```
  String deserializeStr() {
    return utf8.decode(deserializeBytes());
  }

  /// Deserializes an optional deserializable value from the buffer.
  ///
  /// The BCS layout for `Option<T>` starts with a boolean byte (0 if none,
  /// 1 if some), followed by the value if present.
  ///
  /// ```dart
  /// final deserializer = Deserializer(Uint8List.fromList([0]));
  /// final optValue = deserializer.deserializeOption(MyClass.deserialize);
  /// // optValue == null
  /// ```
  T? deserializeOption<T>(Deserializable<T> cls) {
    final exists = deserializeBool();
    return exists ? cls(this) : null;
  }

  /// Deserializes an optional string.
  ///
  /// The BCS layout for `Option<String>` is 0 if none, else 1 followed by the
  /// string length and string content.
  String? deserializeOptionStr() {
    final exists = deserializeBool();
    return exists ? deserializeStr() : null;
  }

  /// Deserializes an optional byte array (length-prefixed when present).
  Uint8List? deserializeOptionBytes() {
    final exists = deserializeBool();
    return exists ? deserializeBytes() : null;
  }

  /// Deserializes an optional fixed byte array of length [len].
  Uint8List? deserializeOptionFixedBytes(int len) {
    final exists = deserializeBool();
    return exists ? deserializeFixedBytes(len) : null;
  }

  /// Deserializes an array of bytes.
  ///
  /// The BCS layout for "bytes" consists of a bytes_length followed by the
  /// bytes themselves, where bytes_length is a u32 integer encoded as a
  /// uleb128 integer, indicating the length of the bytes array.
  ///
  /// Returns a copy, safe to modify. Throws if the length exceeds the maximum
  /// allowed (10MB) to prevent memory exhaustion.
  Uint8List deserializeBytes() {
    final len = deserializeUleb128AsU32();
    // Security: Prevent memory exhaustion from malformed data
    if (len > _maxDeserializeBytesLength) {
      throw StateError(
        'Deserialization error: byte array length $len exceeds maximum allowed $_maxDeserializeBytesLength',
      );
    }
    // Return a copy so caller can safely modify without affecting buffer
    return Uint8List.fromList(_read(len));
  }

  /// Deserializes an array of bytes of a specified length.
  ///
  /// Returns a copy, safe to modify.
  Uint8List deserializeFixedBytes(int len) {
    // Return a copy so caller can safely modify without affecting buffer
    return Uint8List.fromList(_read(len));
  }

  /// Deserializes a boolean value from a byte stream.
  ///
  /// The BCS layout for a boolean uses one byte, where "0x01" represents true
  /// and "0x00" represents false. An error is thrown if the byte value is not
  /// valid.
  bool deserializeBool() {
    final value = _read(1)[0];
    if (value != 1 && value != 0) {
      throw StateError('Invalid boolean value');
    }
    return value == 1;
  }

  /// Deserializes a uint8 number from the binary data.
  ///
  /// BCS layout for "uint8": One byte.
  int deserializeU8() {
    return _read(1)[0];
  }

  /// Deserializes a uint16 number from a binary format in little-endian
  /// representation.
  ///
  /// BCS layout for "uint16": Two bytes.
  int deserializeU16() {
    final bytes = _read(2);
    return bytes[0] | (bytes[1] << 8);
  }

  /// Deserializes a uint32 number from a binary format in little-endian
  /// representation.
  ///
  /// BCS layout for "uint32": Four bytes.
  int deserializeU32() {
    final bytes = _read(4);
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  /// Deserializes a uint64 number.
  ///
  /// This function combines two 32-bit values to return a 64-bit unsigned
  /// integer in little-endian representation.
  BigInt deserializeU64() {
    final low = deserializeU32();
    final high = deserializeU32();

    // combine the two 32-bit values and return (little endian)
    return (BigInt.from(high) << 32) | BigInt.from(low);
  }

  /// Deserializes a uint128 number from its binary representation.
  BigInt deserializeU128() {
    final low = deserializeU64();
    final high = deserializeU64();

    // combine the two 64-bit values and return (little endian)
    return (high << 64) | low;
  }

  /// Deserializes a uint256 number from its binary representation.
  ///
  /// The BCS layout for "uint256" consists of thirty-two bytes in
  /// little-endian format.
  BigInt deserializeU256() {
    final low = deserializeU128();
    final high = deserializeU128();

    // combine the two 128-bit values and return (little endian)
    return (high << 128) | low;
  }

  /// Deserializes an 8-bit signed integer from the binary data.
  int deserializeI8() {
    final unsigned = deserializeU8();
    return unsigned >= 128 ? unsigned - 256 : unsigned;
  }

  /// Deserializes a 16-bit signed integer from a binary format in
  /// little-endian representation.
  int deserializeI16() {
    final unsigned = deserializeU16();
    return unsigned >= 32768 ? unsigned - 65536 : unsigned;
  }

  /// Deserializes a 32-bit signed integer from a binary format in
  /// little-endian representation.
  int deserializeI32() {
    final unsigned = deserializeU32();
    return unsigned >= 2147483648 ? unsigned - 4294967296 : unsigned;
  }

  /// Deserializes a 64-bit signed integer, converting from the unsigned
  /// representation using two's complement.
  BigInt deserializeI64() {
    final unsigned = deserializeU64();
    final signBit = BigInt.one << 63;
    if (unsigned >= signBit) {
      return unsigned - (BigInt.one << 64);
    }
    return unsigned;
  }

  /// Deserializes a 128-bit signed integer from its binary representation.
  BigInt deserializeI128() {
    final unsigned = deserializeU128();
    final signBit = BigInt.one << 127;
    if (unsigned >= signBit) {
      return unsigned - (BigInt.one << 128);
    }
    return unsigned;
  }

  /// Deserializes a 256-bit signed integer from its binary representation.
  BigInt deserializeI256() {
    final unsigned = deserializeU256();
    final signBit = BigInt.one << 255;
    if (unsigned >= signBit) {
      return unsigned - (BigInt.one << 256);
    }
    return unsigned;
  }

  /// Deserializes a uleb128 encoded uint32 number.
  ///
  /// This function is used for interpreting lengths of variable-length
  /// sequences and tags of enum values in BCS encoding.
  ///
  /// Throws a [StateError] if the parsed value exceeds the maximum uint32
  /// number or the uleb128 encoding is malformed.
  int deserializeUleb128AsU32() {
    var value = 0;
    var shift = 0;
    // Maximum 5 bytes for uleb128-encoded u32 (7 bits per byte, 5*7=35 bits > 32 bits needed)
    const maxUleb128Bytes = 5;
    var bytesRead = 0;

    while (bytesRead < maxUleb128Bytes) {
      final byte = deserializeU8();
      bytesRead += 1;

      value |= (byte & 0x7f) << shift;

      // Early overflow check before continuing
      if (value > maxU32Number) {
        throw StateError('Overflow while parsing uleb128-encoded uint32 value');
      }

      if ((byte & 0x80) == 0) {
        break;
      }

      shift += 7;
    }

    return value;
  }

  /// Helper function that primarily exists to support alternative syntax for
  /// deserialization. That is, instead of `MyClass.deserialize(deserializer)`,
  /// we can call `deserializer.deserialize(MyClass.deserialize)`.
  T deserialize<T>(Deserializable<T> cls) {
    return cls(this);
  }

  /// Deserializes an array of BCS deserializable values given an existing
  /// [Deserializer] instance with a loaded byte buffer.
  ///
  /// ```dart
  /// final deserializer = Deserializer(serializedBytes);
  /// final addresses = deserializer.deserializeVector(AccountAddress.deserialize);
  /// ```
  List<T> deserializeVector<T>(Deserializable<T> cls) {
    final length = deserializeUleb128AsU32();
    if (length > _maxDeserializeVectorLength) {
      throw StateError(
        'Vector length $length exceeds maximum allowed length of $_maxDeserializeVectorLength',
      );
    }
    final vector = <T>[];
    for (var i = 0; i < length; i += 1) {
      vector.add(cls(this));
    }
    return vector;
  }
}
