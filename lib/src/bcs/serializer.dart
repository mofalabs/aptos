import 'dart:convert';
import 'dart:typed_data';

import '../core/hex.dart';
import 'consts.dart';

/// This class serves as a base class for all serializable types. It
/// facilitates composable serialization of complex types and enables the
/// serialization of instances to their BCS (Binary Canonical Serialization)
/// representation.
abstract class Serializable {
  void serialize(Serializer serializer);

  /// Serializes a [Serializable] value to its BCS representation.
  /// This function is the Dart SDK equivalent of `bcs::to_bytes` in Move.
  Uint8List bcsToBytes() {
    final serializer = Serializer();
    serialize(serializer);
    return serializer.toUint8List();
  }

  /// Converts the BCS-serialized bytes of a value into a [Hex] instance.
  Hex bcsToHex() => Hex(bcsToBytes());

  /// Returns the hex string representation of the value without the 0x prefix.
  String toStringWithoutPrefix() => bcsToHex().toStringWithoutPrefix();

  /// Returns the hex string representation of the value with the 0x prefix.
  @override
  String toString() => '0x${toStringWithoutPrefix()}';
}

/// Minimum buffer growth increment to avoid too many small reallocations.
const int _minBufferGrowth = 256;

/// A class for serializing various data types into a binary format.
/// It provides methods to serialize strings, bytes, numbers, and other
/// serializable objects using the Binary Canonical Serialization (BCS) layout.
/// The serialized data can be retrieved as a [Uint8List].
class Serializer {
  Uint8List _buffer;

  int _offset = 0;

  /// Constructs a serializer with a buffer of size [length] bytes, 64 bytes by
  /// default. The [length] must be greater than 0.
  Serializer([int length = 64]) : _buffer = Uint8List(_checkLength(length));

  static int _checkLength(int length) {
    if (length <= 0) {
      throw ArgumentError('Length needs to be greater than 0');
    }
    return length;
  }

  /// Ensures that the internal buffer can accommodate the specified number of
  /// bytes, dynamically resizing using a growth factor of 1.5x with a minimum
  /// growth increment.
  void _ensureBufferWillHandleSize(int bytes) {
    final requiredSize = _offset + bytes;
    if (_buffer.length >= requiredSize) {
      return;
    }

    final growthSize = (_buffer.length * 1.5).floor() >
            requiredSize + _minBufferGrowth
        ? (_buffer.length * 1.5).floor()
        : requiredSize + _minBufferGrowth;

    final newBuffer = Uint8List(growthSize);
    newBuffer.setRange(0, _offset, _buffer);
    _buffer = newBuffer;
  }

  /// Appends the specified values to the buffer.
  void _appendToBuffer(List<int> values) {
    _ensureBufferWillHandleSize(values.length);
    _buffer.setRange(_offset, _offset + values.length, values);
    _offset += values.length;
  }

  /// Serializes a string. UTF8 string is supported.
  /// The number of bytes in the string content is serialized first, as a
  /// uleb128-encoded u32 integer. Then the string content is serialized as
  /// UTF8 encoded bytes.
  ///
  /// BCS layout for "string": string_length | string_content
  /// where string_length is a u32 integer encoded as a uleb128 integer, equal
  /// to the number of bytes in string_content.
  ///
  /// ```dart
  /// final serializer = Serializer();
  /// serializer.serializeStr('1234abcd');
  /// assert(serializer.toUint8List() equals [8, 49, 50, 51, 52, 97, 98, 99, 100]);
  /// ```
  void serializeStr(String value) {
    serializeBytes(Uint8List.fromList(utf8.encode(value)));
  }

  /// Serializes an array of bytes.
  ///
  /// This function encodes the length of the byte array as a u32 integer in
  /// uleb128 format, followed by the byte array itself.
  /// BCS layout for "bytes": bytes_length | bytes
  void serializeBytes(Uint8List value) {
    serializeU32AsUleb128(value.length);
    _appendToBuffer(value);
  }

  /// Serializes an array of bytes with a known length, allowing for efficient
  /// deserialization without needing to serialize the length itself.
  /// When deserializing, the number of bytes to deserialize needs to be passed
  /// in.
  void serializeFixedBytes(Uint8List value) {
    _appendToBuffer(value);
  }

  /// Serializes a boolean value into a byte representation.
  ///
  /// The BCS layout for a boolean uses one byte, where "0x01" represents true
  /// and "0x00" represents false.
  void serializeBool(bool value) {
    _appendToBuffer([value ? 1 : 0]);
  }

  /// Serializes a uint8 value and appends it to the buffer.
  /// BCS layout for "uint8": One byte. Binary format in little-endian
  /// representation.
  void serializeU8(int value) {
    validateNumberInRange(value, 0, maxU8Number);
    _appendToBuffer([value]);
  }

  /// Serializes a 16-bit unsigned integer value into a binary format.
  /// BCS layout for "uint16": Two bytes. Binary format in little-endian
  /// representation.
  ///
  /// ```dart
  /// final serializer = Serializer();
  /// serializer.serializeU16(4660);
  /// assert(serializer.toUint8List() equals [0x34, 0x12]);
  /// ```
  void serializeU16(int value) {
    validateNumberInRange(value, 0, maxU16Number);
    _appendToBuffer([value & 0xff, (value >> 8) & 0xff]);
  }

  /// Serializes a 32-bit unsigned integer value into a binary format.
  ///
  /// ```dart
  /// final serializer = Serializer();
  /// serializer.serializeU32(305419896);
  /// assert(serializer.toUint8List() equals [0x78, 0x56, 0x34, 0x12]);
  /// ```
  void serializeU32(int value) {
    validateNumberInRange(value, 0, maxU32Number);
    _appendToBuffer([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  /// Serializes a 64-bit unsigned integer in little-endian order.
  ///
  /// ```dart
  /// final serializer = Serializer();
  /// serializer.serializeU64(BigInt.parse('1311768467750121216'));
  /// assert(serializer.toUint8List() equals [0x00, 0xEF, 0xCD, 0xAB, 0x78, 0x56, 0x34, 0x12]);
  /// ```
  void serializeU64(BigInt value) {
    validateBigIntInRange(value, BigInt.zero, maxU64BigInt);
    final low = value & BigInt.from(maxU32Number);
    final high = value >> 32;

    // write little endian number
    serializeU32(low.toInt());
    serializeU32(high.toInt());
  }

  /// Serializes a U128 value in little-endian order.
  void serializeU128(BigInt value) {
    validateBigIntInRange(value, BigInt.zero, maxU128BigInt);
    final low = value & maxU64BigInt;
    final high = value >> 64;

    // write little endian number
    serializeU64(low);
    serializeU64(high);
  }

  /// Serializes a U256 value in little-endian order.
  void serializeU256(BigInt value) {
    validateBigIntInRange(value, BigInt.zero, maxU256BigInt);
    final low = value & maxU128BigInt;
    final high = value >> 128;

    // write little endian number
    serializeU128(low);
    serializeU128(high);
  }

  /// Serializes an 8-bit signed integer value.
  /// BCS layout for "int8": One byte, two's complement representation.
  void serializeI8(int value) {
    validateNumberInRange(value, minI8Number, maxI8Number);
    _appendToBuffer([value & 0xff]);
  }

  /// Serializes a 16-bit signed integer value into a binary format.
  /// BCS layout for "int16": Two bytes in little-endian representation.
  void serializeI16(int value) {
    validateNumberInRange(value, minI16Number, maxI16Number);
    final unsigned = value & 0xffff;
    _appendToBuffer([unsigned & 0xff, (unsigned >> 8) & 0xff]);
  }

  /// Serializes a 32-bit signed integer value into a binary format.
  void serializeI32(int value) {
    validateNumberInRange(value, minI32Number, maxI32Number);
    final unsigned = value & 0xffffffff;
    _appendToBuffer([
      unsigned & 0xff,
      (unsigned >> 8) & 0xff,
      (unsigned >> 16) & 0xff,
      (unsigned >> 24) & 0xff,
    ]);
  }

  /// Serializes a 64-bit signed integer using two's complement representation
  /// for negative values.
  void serializeI64(BigInt value) {
    validateBigIntInRange(value, minI64BigInt, maxI64BigInt);
    // Convert to unsigned representation using two's complement
    final unsigned =
        value.isNegative ? (BigInt.one << 64) + value : value;
    final low = unsigned & BigInt.from(maxU32Number);
    final high = unsigned >> 32;

    // write little endian number
    serializeU32(low.toInt());
    serializeU32(high.toInt());
  }

  /// Serializes a 128-bit signed integer value.
  void serializeI128(BigInt value) {
    validateBigIntInRange(value, minI128BigInt, maxI128BigInt);
    // Convert to unsigned representation using two's complement
    final unsigned =
        value.isNegative ? (BigInt.one << 128) + value : value;
    final low = unsigned & maxU64BigInt;
    final high = unsigned >> 64;

    // write little endian number
    serializeU64(low);
    serializeU64(high);
  }

  /// Serializes a 256-bit signed integer value.
  void serializeI256(BigInt value) {
    validateBigIntInRange(value, minI256BigInt, maxI256BigInt);
    // Convert to unsigned representation using two's complement
    final unsigned =
        value.isNegative ? (BigInt.one << 256) + value : value;
    final low = unsigned & maxU128BigInt;
    final high = unsigned >> 128;

    // write little endian number
    serializeU128(low);
    serializeU128(high);
  }

  /// Serializes a 32-bit unsigned integer as a variable-length ULEB128 encoded
  /// byte array.
  /// BCS uses uleb128 encoding in two cases: (1) lengths of variable-length
  /// sequences and (2) tags of enum values.
  void serializeU32AsUleb128(int val) {
    validateNumberInRange(val, 0, maxU32Number);
    var value = val;
    final valueList = <int>[];
    while (value >>> 7 != 0) {
      valueList.add((value & 0x7f) | 0x80);
      value >>>= 7;
    }
    valueList.add(value);
    _appendToBuffer(valueList);
  }

  /// Returns the buffered bytes as a [Uint8List] copy of only the used portion
  /// of the buffer.
  Uint8List toUint8List() {
    return _buffer.sublist(0, _offset);
  }

  /// Resets the serializer to its initial state, allowing the buffer to be
  /// reused. This clears the buffer contents to prevent data leakage between
  /// uses.
  void reset() {
    if (_offset > 0) {
      _buffer.fillRange(0, _offset, 0);
    }
    _offset = 0;
  }

  /// Returns the current number of bytes written to the serializer.
  int getOffset() => _offset;

  /// Serializes a [Serializable] value, facilitating composable serialization.
  void serialize(Serializable value) {
    // NOTE: The `serialize` method called by `value` is defined in `value`'s
    // class, not the one defined in this class.
    value.serialize(this);
  }

  /// Serializes a [Serializable] value as a byte array with a length prefix.
  /// This is the pattern used for entry function argument serialization.
  void serializeAsBytes(Serializable value) {
    serializeBytes(value.bcsToBytes());
  }

  /// Serializes an array of BCS [Serializable] values to a serializer
  /// instance. The bytes are added to the serializer instance's byte buffer.
  ///
  /// ```dart
  /// final addresses = [
  ///   AccountAddress.from('0x1'),
  ///   AccountAddress.from('0x2'),
  /// ];
  /// final serializer = Serializer();
  /// serializer.serializeVector(addresses);
  /// // The equivalent value in Move would be:
  /// // `bcs::to_bytes(&vector<address> [@0x1, @0x2])`;
  /// ```
  void serializeVector(List<Serializable> values) {
    serializeU32AsUleb128(values.length);
    for (final item in values) {
      item.serialize(this);
    }
  }

  /// Serializes an optional [Serializable] value.
  ///
  /// The BCS layout for `Option<T>` is a boolean byte (0 if none, 1 if some)
  /// followed by the value if present.
  void serializeOption(Serializable? value) {
    final hasValue = value != null;
    serializeBool(hasValue);
    if (hasValue) {
      value.serialize(this);
    }
  }

  /// Serializes an optional byte array (length-prefixed when present).
  void serializeOptionBytes(Uint8List? value) {
    final hasValue = value != null;
    serializeBool(hasValue);
    if (hasValue) {
      serializeBytes(value);
    }
  }

  /// Serializes an optional fixed byte array (no length prefix when present).
  void serializeOptionFixedBytes(Uint8List? value) {
    final hasValue = value != null;
    serializeBool(hasValue);
    if (hasValue) {
      serializeFixedBytes(value);
    }
  }

  /// Serializes an optional string using UTF8 encoding.
  ///
  /// BCS layout for optional "string": 1 | string_length | string_content,
  /// or 0 when absent.
  void serializeOptionStr(String? value) {
    final hasValue = value != null;
    serializeBool(hasValue);
    if (hasValue) {
      serializeStr(value);
    }
  }
}

String outOfRangeErrorMessage(Object value, Object min, Object max) =>
    '$value is out of range: [$min, $max]';

/// Validates that a given [int] is within a specified range, throwing an error
/// if the value is outside the defined minimum and maximum bounds.
void validateNumberInRange(int value, int minValue, int maxValue) {
  if (value > maxValue || value < minValue) {
    throw ArgumentError(outOfRangeErrorMessage(value, minValue, maxValue));
  }
}

/// Validates that a given [BigInt] is within a specified range, throwing an
/// error if the value is outside the defined minimum and maximum bounds.
void validateBigIntInRange(BigInt value, BigInt minValue, BigInt maxValue) {
  if (value > maxValue || value < minValue) {
    throw ArgumentError(outOfRangeErrorMessage(value, minValue, maxValue));
  }
}
