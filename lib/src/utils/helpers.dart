import 'dart:convert';
import 'dart:typed_data';

import '../core/account/utils/address.dart';
import '../core/account_address.dart';

/// Maximum [BigInt] value that can be losslessly converted to a JS-safe
/// integer (2^53 - 1). Dart ints are 64-bit on the VM but only 53-bit safe
/// when compiled to JavaScript, so we use the stricter bound.
final BigInt _maxSafeU64 = BigInt.from(9007199254740991);

/// Narrows a u64 ([BigInt]) into an [int] with an explicit safety check.
///
/// Real-world expiry values are far below the unsafe range, so this check is
/// effectively a guard against corrupted or malicious BCS data rather than a
/// precision concern in normal operation. Throwing is correct behavior at the
/// BCS/JSON boundary.
int u64ToIntSafe(BigInt value, String fieldName) {
  if (value.isNegative) {
    throw RangeError(
        '$fieldName is negative ($value); expected an unsigned u64');
  }
  if (value > _maxSafeU64) {
    throw RangeError(
      '$fieldName ($value) exceeds the maximum safe integer ($_maxSafeU64); '
      'refusing to silently lose precision',
    );
  }
  return value.toInt();
}

/// Logs a warning message only in development environments (when assertions
/// are enabled). This helps reduce information leakage in production while
/// maintaining helpful warnings during development.
void warnIfDevelopment(String message) {
  assert(() {
    // ignore: avoid_print
    print('WARNING: $message');
    return true;
  }());
}

/// Sleep for the specified amount of time in milliseconds.
Future<void> sleep(int timeMs) =>
    Future.delayed(Duration(milliseconds: timeMs));

/// Get the error message from an unknown error.
String getErrorMessage(Object? error) => error.toString();

/// The current Unix timestamp in whole seconds.
int nowInSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Floors the given timestamp to the nearest whole hour.
/// This function is useful for normalizing timestamps to hourly intervals.
int floorToWholeHour(int timestampInSeconds) {
  return timestampInSeconds - (timestampInSeconds % 3600);
}

/// Decodes a base64 URL-encoded string into its original UTF-8 form.
String base64UrlDecode(String base64Url) {
  return utf8.decode(base64UrlToBytes(base64Url));
}

/// Encode a string or byte array as a base64url string (RFC 4648 §5) with no
/// padding. String input is interpreted as UTF-8.
String base64UrlEncode(Object input) {
  final Uint8List bytes;
  if (input is String) {
    bytes = Uint8List.fromList(utf8.encode(input));
  } else if (input is Uint8List) {
    bytes = input;
  } else {
    throw ArgumentError('Input must be a String or Uint8List');
  }
  return base64Url.encode(bytes).replaceAll(RegExp(r'=+$'), '');
}

/// Decodes a base64url string (with or without padding) into bytes.
Uint8List base64UrlToBytes(String base64UrlStr) {
  final padded = base64UrlStr.padRight(
    base64UrlStr.length + (4 - base64UrlStr.length % 4) % 4,
    '=',
  );
  return base64Url.decode(padded);
}

/// Amount is represented in the smallest unit format on chain, this function
/// converts a human-readable amount format to the smallest unit format.
///
/// For example, a human-readable amount of 500 with decimal 8 becomes
/// 50000000000 on chain.
num convertAmountFromHumanReadableToOnChain(num value, int decimal) =>
    value * BigInt.from(10).pow(decimal).toDouble();

/// Amount is represented in the smallest unit format on chain, this function
/// converts the smallest unit format to a human-readable amount format.
num convertAmountFromOnChainToHumanReadable(num value, int decimal) =>
    value / BigInt.from(10).pow(decimal).toDouble();

/// Convert a hex string with the `0x` prefix to an ascii string.
///
/// `0x6170746f735f636f696e` --> `aptos_coin`
String _hexToAscii(String hex) {
  final buffer = StringBuffer();
  for (var n = 2; n < hex.length; n += 2) {
    buffer.writeCharCode(int.parse(hex.substring(n, n + 2), radix: 16));
  }
  return buffer.toString();
}

/// Convert an encoded struct to a Move struct id string.
///
/// ```dart
/// final structObj = {
///   'account_address': '0x1',
///   'module_name': '0x6170746f735f636f696e',
///   'struct_name': '0x4170746f73436f696e',
/// };
/// // structId is "0x1::aptos_coin::AptosCoin"
/// final structId = parseEncodedStruct(structObj);
/// ```
String parseEncodedStruct(Map<String, dynamic> structObj) {
  final accountAddress = structObj['account_address'] as String;
  final moduleName = _hexToAscii(structObj['module_name'] as String);
  final structName = _hexToAscii(structObj['struct_name'] as String);
  return '$accountAddress::$moduleName::$structName';
}

/// Determines whether the given object is an encoded struct type with
/// account_address, module_name, and struct_name string properties.
bool isEncodedStruct(Object? structObj) =>
    structObj is Map &&
    structObj['account_address'] is String &&
    structObj['module_name'] is String &&
    structObj['struct_name'] is String;

/// Splits a function identifier in the format
/// "moduleAddress::moduleName::functionName" into its constituent parts.
///
/// Throws an [ArgumentError] if the function identifier does not contain
/// exactly three parts.
({String moduleAddress, String moduleName, String functionName})
    getFunctionParts(String functionArg) {
  final parts = functionArg.split('::');
  if (parts.length != 3) {
    throw ArgumentError('Invalid function $functionArg');
  }
  return (
    moduleAddress: parts[0],
    moduleName: parts[1],
    functionName: parts[2],
  );
}

/// Validates the provided function information.
bool isValidFunctionInfo(String functionInfo) {
  final parts = functionInfo.split('::');
  return parts.length == 3 && AccountAddress.isValid(input: parts[0]).valid;
}

/// Truncates the provided wallet address at the middle with an ellipsis.
String truncateAddress(String address, {int start = 6, int end = 5}) {
  return '${address.substring(0, start)}...${address.substring(address.length - end)}';
}

const String _aptosCoinTypeStr = '0x1::aptos_coin::AptosCoin';

/// Helper function to standardize a Move type string by converting all
/// addresses to short form, including addresses within nested type parameters.
String _standardizeMoveTypeString(String input) {
  final addressRegex = RegExp(r'0x[0-9a-fA-F]+');
  return input.replaceAllMapped(
    addressRegex,
    (match) => AccountAddress.from(match.group(0)!, maxMissingChars: 63)
        .toStringShort(),
  );
}

/// Calculates the paired FA metadata address for a given coin type.
/// This function is tolerant of various address formats in the coin type
/// string, including complex nested types.
///
/// ```dart
/// // All these formats are valid and produce the same result:
/// pairedFaMetadataAddress('0x1::aptos_coin::AptosCoin');
/// pairedFaMetadataAddress('0x00001::aptos_coin::AptosCoin');
/// pairedFaMetadataAddress('0x1::coin::Coin<0x1412::a::struct<0x0001::aptos_coin::AptosCoin>>');
/// ```
AccountAddress pairedFaMetadataAddress(String coinType) {
  final standardizedMoveTypeName = _standardizeMoveTypeString(coinType);
  return standardizedMoveTypeName == _aptosCoinTypeStr
      ? AccountAddress.a
      : createObjectAddress(AccountAddress.a, standardizedMoveTypeName);
}
