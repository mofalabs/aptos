import 'dart:convert';
import 'dart:typed_data';

import '../types/types.dart';
import 'common.dart';

/// Provides reasons for parsing failures related to hexadecimal values.
enum HexInvalidReason {
  tooShort('too_short'),
  invalidLength('invalid_length'),
  invalidHexChars('invalid_hex_chars');

  const HexInvalidReason(this.value);

  final String value;
}

/// NOTE: Do not use this class when working with account addresses; use
/// `AccountAddress` instead.
///
/// A helper class for working with hex data. Hex data, when represented as a
/// string, generally looks like this, for example: 0xaabbcc, 45cd32, etc.
///
/// When accepting hex data as input to a function, prefer to accept [HexInput]
/// and then use the static helper methods of this class to convert it into the
/// desired format. This enables the greatest flexibility for the developer.
///
/// Example usage:
/// ```dart
/// Future<Transaction> getTransactionByHash(HexInput txnHash) {
///   final txnHashString = Hex.fromHexInput(txnHash).toString();
///   return getTransactionByHashInner(txnHashString);
/// }
/// ```
/// This call to `Hex.fromHexInput(...).toString()` converts the [HexInput] to
/// a hex string with a leading 0x prefix, regardless of the input format.
class Hex {
  final Uint8List _data;

  /// Create a new Hex instance from a [Uint8List].
  const Hex(Uint8List data) : _data = data;

  // ===
  // Methods for representing an instance of Hex as other types.
  // ===

  /// Get the inner hex data as a [Uint8List]. The inner data is already a
  /// [Uint8List], so no conversion takes place.
  Uint8List toUint8List() => _data;

  /// Get the hex data as a string without the 0x prefix.
  String toStringWithoutPrefix() => _bytesToHex(_data);

  /// Get the hex data as a string with the 0x prefix.
  @override
  String toString() => '0x${toStringWithoutPrefix()}';

  // ===
  // Methods for creating an instance of Hex from other types.
  // ===

  /// Converts a hex string into a [Hex] instance, allowing for both prefixed
  /// and non-prefixed formats.
  ///
  /// Throws a [ParsingError] if the hex string is too short, has an odd number
  /// of characters, or contains invalid hex characters.
  static Hex fromHexString(String str) {
    var input = str;

    if (input.startsWith('0x')) {
      input = input.substring(2);
    }

    if (input.isEmpty) {
      throw ParsingError(
        'Hex string is too short, must be at least 1 char long, excluding the optional leading 0x.',
        HexInvalidReason.tooShort,
      );
    }

    if (input.length % 2 != 0) {
      throw ParsingError(
        'Hex string must be an even number of hex characters.',
        HexInvalidReason.invalidLength,
      );
    }

    try {
      return Hex(_hexToBytes(input));
    } on FormatException catch (error) {
      throw ParsingError(
        'Hex string contains invalid hex characters: ${error.message}',
        HexInvalidReason.invalidHexChars,
      );
    }
  }

  /// Converts an instance of [HexInput], which can be a [String] or a
  /// [Uint8List], into a [Hex] instance.
  static Hex fromHexInput(HexInput hexInput) {
    if (hexInput is Uint8List) return Hex(hexInput);
    if (hexInput is String) return Hex.fromHexString(hexInput);
    throw ArgumentError(
      'HexInput must be a String or Uint8List, got ${hexInput.runtimeType}',
    );
  }

  /// Converts an instance of [HexInput], which can be a [String] or a
  /// [Uint8List], into a [Uint8List].
  static Uint8List hexInputToUint8List(HexInput hexInput) {
    if (hexInput is Uint8List) return hexInput;
    return Hex.fromHexInput(hexInput).toUint8List();
  }

  /// Converts a [HexInput] (string or bytes) to a hex string with '0x' prefix.
  ///
  /// ```dart
  /// Hex.hexInputToString('1234')   // returns '0x1234'
  /// Hex.hexInputToString('0x1234') // returns '0x1234'
  /// ```
  static String hexInputToString(HexInput hexInput) {
    return Hex.fromHexInput(hexInput).toString();
  }

  /// Converts a [HexInput] (string or bytes) to a hex string without the '0x'
  /// prefix.
  static String hexInputToStringWithoutPrefix(HexInput hexInput) {
    return Hex.fromHexInput(hexInput).toStringWithoutPrefix();
  }

  // ===
  // Methods for checking validity.
  // ===

  /// Check if the provided string is a valid hexadecimal representation.
  static ParsingResult<HexInvalidReason> isValid(String str) {
    try {
      Hex.fromHexString(str);
      return const ParsingResult(valid: true);
    } on ParsingError<HexInvalidReason> catch (error) {
      return ParsingResult(
        valid: false,
        invalidReason: error.invalidReason,
        invalidReasonMessage: error.message,
      );
    }
  }

  /// Determine if two Hex instances are equal by comparing their underlying
  /// byte data.
  bool equals(Hex other) {
    if (_data.length != other._data.length) return false;
    for (var i = 0; i < _data.length; i += 1) {
      if (_data[i] != other._data[i]) return false;
    }
    return true;
  }
}

/// Decodes a hex string (with or without the 0x prefix) into its ASCII string
/// representation.
String hexToAsciiString(String hex) =>
    utf8.decode(Hex.fromHexInput(hex).toUint8List());

const String _hexAlphabet = '0123456789abcdef';

String _bytesToHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(_hexAlphabet[(byte >> 4) & 0x0f]);
    buffer.write(_hexAlphabet[byte & 0x0f]);
  }
  return buffer.toString();
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i += 1) {
    final byteStr = hex.substring(i * 2, i * 2 + 2);
    final byte = int.tryParse(byteStr, radix: 16);
    if (byte == null) {
      throw FormatException('Invalid byte sequence "$byteStr" in hex string');
    }
    result[i] = byte;
  }
  return result;
}
