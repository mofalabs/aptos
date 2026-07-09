import 'dart:typed_data';

import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../transactions/instances/transaction_argument.dart';
import '../types/types.dart';
import 'common.dart';
import 'hex.dart';

/// Provides reasons for an address was invalid.
enum AddressInvalidReason {
  incorrectNumberOfBytes('incorrect_number_of_bytes'),
  invalidHexChars('invalid_hex_chars'),
  tooShort('too_short'),
  tooLong('too_long'),
  leadingZeroXRequired('leading_zero_x_required'),
  longFormRequiredUnlessSpecial('long_form_required_unless_special'),
  invalidPaddingZeroes('invalid_padding_zeroes'),
  invalidPaddingStrictness('invalid_padding_strictness');

  const AddressInvalidReason(this.value);

  final String value;
}

/// The input for an account address, which can be a hex [String], a
/// [Uint8List], or an [AccountAddress].
typedef AccountAddressInput = Object;

/// NOTE: Only use this class for account addresses. For other hex data, e.g.
/// transaction hashes, use the [Hex] class.
///
/// AccountAddress is used for working with account addresses. Account
/// addresses, when represented as a string, generally look like these
/// examples:
/// - 0x1
/// - 0xaa86fe99004361f747f91342ca13c426ca0cccb0c1217677180c9493bad6ef0c
///
/// Proper formatting and parsing of account addresses is defined by AIP-40.
/// To learn more about the standard, read the AIP here:
/// https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-40.md.
///
/// The comments in this class make frequent reference to the LONG and SHORT
/// formats, as well as "special" addresses. To learn what these refer to see
/// AIP-40.
class AccountAddress extends Serializable implements TransactionArgument {
  /// This is the internal representation of an account address.
  final Uint8List data;

  /// The number of bytes that make up an account address.
  static const int length = 32;

  /// The length of an address string in LONG form without a leading 0x.
  static const int longStringLength = 64;

  static final AccountAddress zero = AccountAddress.from('0x0');

  static final AccountAddress one = AccountAddress.from('0x1');

  static final AccountAddress two = AccountAddress.from('0x2');

  static final AccountAddress three = AccountAddress.from('0x3');

  static final AccountAddress four = AccountAddress.from('0x4');

  static final AccountAddress a = AccountAddress.from('0xA');

  /// Creates an instance of AccountAddress from a [Uint8List].
  ///
  /// This function ensures that the input data is exactly 32 bytes long, which
  /// is required for a valid account address.
  ///
  /// Throws a [ParsingError] if the input length is not equal to 32 bytes.
  AccountAddress(this.data) {
    if (data.length != AccountAddress.length) {
      throw ParsingError(
        'AccountAddress data should be exactly 32 bytes long',
        AddressInvalidReason.incorrectNumberOfBytes,
      );
    }
  }

  /// Determines if the address is classified as special, which is defined as
  /// 0x0 to 0xf inclusive. In other words, the last byte of the address must
  /// be < 0b10000 (16) and every other byte must be zero.
  ///
  /// For more information on how special addresses are defined, see AIP-40.
  bool isSpecial() {
    for (var i = 0; i < data.length - 1; i += 1) {
      if (data[i] != 0) return false;
    }
    return data[data.length - 1] < 0x10;
  }

  // ===
  // Methods for representing an instance of AccountAddress as other types.
  // ===

  /// Return the AccountAddress as a string as per AIP-40.
  /// This representation returns special addresses in SHORT form (0xf)
  /// and other addresses in LONG form (0x + 64 characters).
  @override
  String toString() => '0x${toStringWithoutPrefix()}';

  /// Return the AccountAddress as a string conforming to AIP-40 but without
  /// the leading 0x.
  ///
  /// NOTE: Prefer to use [toString] where possible.
  @override
  String toStringWithoutPrefix() {
    var hex = Hex(data).toStringWithoutPrefix();
    if (isSpecial()) {
      hex = hex[hex.length - 1];
    }
    return hex;
  }

  /// Convert the account address to a string in LONG format, which is always
  /// 0x followed by 64 hex characters.
  ///
  /// NOTE: Prefer to use [toString] where possible, as it formats special
  /// addresses using the SHORT form (no leading 0s).
  String toStringLong() => '0x${toStringLongWithoutPrefix()}';

  /// Returns the account address as a string in LONG form without a leading
  /// 0x. This function will include leading zeroes and will produce a string
  /// of 64 hex characters.
  ///
  /// NOTE: Prefer to use [toString] where possible, as it formats special
  /// addresses using the SHORT form (no leading 0s).
  String toStringLongWithoutPrefix() => Hex(data).toStringWithoutPrefix();

  /// Convert the account address to a string in SHORT format, which is 0x
  /// followed by the shortest possible representation (no leading zeros).
  String toStringShort() => '0x${toStringShortWithoutPrefix()}';

  /// Returns a lossless short string representation of the address by trimming
  /// leading zeros. If the address consists of all zeros, returns "0".
  String toStringShortWithoutPrefix() {
    final hex = Hex(data)
        .toStringWithoutPrefix()
        .replaceFirst(RegExp(r'^0+'), '');
    return hex.isEmpty ? '0' : hex;
  }

  /// Get the inner data as a [Uint8List].
  /// The inner data is already a [Uint8List], so no conversion takes place.
  Uint8List toUint8List() => data;

  /// Serialize the AccountAddress to a [Serializer] instance's data buffer.
  ///
  /// ```dart
  /// final serializer = Serializer();
  /// final address = AccountAddress.fromString('0x1');
  /// address.serialize(serializer);
  /// final bytes = serializer.toUint8List();
  /// // `bytes` is now the BCS-serialized address.
  /// ```
  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(data);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    serializer.serializeAsBytes(this);
  }

  @override
  void serializeForScriptFunction(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(ScriptTransactionArgumentVariants.address.value);
    serializer.serialize(this);
  }

  /// Deserialize an AccountAddress from the byte buffer in a [Deserializer]
  /// instance.
  static AccountAddress deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeFixedBytes(AccountAddress.length);
    return AccountAddress(bytes);
  }

  // ===
  // Methods for creating an instance of AccountAddress from other types.
  // ===

  /// NOTE: This function has strict parsing behavior. For relaxed behavior,
  /// please use the [fromString] function.
  ///
  /// Creates an instance of AccountAddress from a hex string.
  ///
  /// This function allows only the strictest formats defined by AIP-40. In
  /// short this means only the following formats are accepted:
  ///
  /// - LONG (0x + 64 hex characters)
  /// - SHORT for special addresses (0x0 to 0xf inclusive without padding
  ///   zeroes)
  ///
  /// This means the following are not accepted:
  /// - SHORT for non-special addresses.
  /// - Any address without a leading 0x.
  ///
  /// Throws a [ParsingError] if the hex string does not start with 0x or is
  /// not in a valid format.
  static AccountAddress fromStringStrict(String input) {
    // Assert the string starts with 0x.
    if (!input.startsWith('0x')) {
      throw ParsingError(
        'Hex string must start with a leading 0x.',
        AddressInvalidReason.leadingZeroXRequired,
      );
    }

    final address = AccountAddress.fromString(input);

    // Check if the address is in LONG form. If it is not, this is only allowed
    // for special addresses, in which case we check it is in proper SHORT
    // form.
    if (input.length != AccountAddress.longStringLength + 2) {
      if (!address.isSpecial()) {
        throw ParsingError(
          'The given hex string $input is not a special address, it must be represented as 0x + 64 chars.',
          AddressInvalidReason.longFormRequiredUnlessSpecial,
        );
      } else if (input.length != 3) {
        // 0x + one hex char is the only valid SHORT form for special
        // addresses.
        throw ParsingError(
          'The given hex string $input is a special address not in LONG form, it must be 0x0 to 0xf without padding zeroes.',
          AddressInvalidReason.invalidPaddingZeroes,
        );
      }
    }

    return address;
  }

  /// NOTE: This function has relaxed parsing behavior. For strict behavior,
  /// please use the [fromStringStrict] function. Where possible use
  /// [fromStringStrict] rather than this function.
  ///
  /// Creates an instance of AccountAddress from a hex string.
  ///
  /// This function allows all formats defined by AIP-40. In short this means
  /// the following formats are accepted:
  ///
  /// - LONG, with or without leading 0x
  /// - SHORT*, with or without leading 0x
  ///
  /// Where:
  /// - LONG is 64 hex characters.
  /// - SHORT* is 1 to 63 hex characters inclusive. The address can have
  ///   missing values up to [maxMissingChars] before it is padded.
  /// - Padding zeroes are allowed, e.g. 0x0123 is valid.
  ///
  /// Throws a [ParsingError] if the hex string is too short, too long, or
  /// contains invalid characters.
  static AccountAddress fromString(String input, {int maxMissingChars = 4}) {
    var parsedInput = input;
    // Remove leading 0x for parsing.
    if (input.startsWith('0x')) {
      parsedInput = input.substring(2);
    }

    // Ensure the address string is at least 1 character long.
    if (parsedInput.isEmpty) {
      throw ParsingError(
        'Hex string is too short, must be 1 to 64 chars long, excluding the leading 0x.',
        AddressInvalidReason.tooShort,
      );
    }

    // Ensure the address string is not longer than 64 characters.
    if (parsedInput.length > 64) {
      throw ParsingError(
        'Hex string is too long, must be 1 to 64 chars long, excluding the leading 0x.',
        AddressInvalidReason.tooLong,
      );
    }

    // Ensure that the maxMissingChars is between or equal to 0 and 63.
    if (maxMissingChars > 63 || maxMissingChars < 0) {
      throw ParsingError(
        'maxMissingChars must be between or equal to 0 and 63. Received $maxMissingChars',
        AddressInvalidReason.invalidPaddingStrictness,
      );
    }

    Uint8List addressBytes;
    try {
      // Pad the address with leading zeroes, so it is 64 chars long and then
      // convert the hex string to bytes. Every two characters in a hex string
      // constitutes a single byte. So a 64 length hex string becomes a 32 byte
      // array.
      addressBytes =
          Hex.fromHexString(parsedInput.padLeft(64, '0')).toUint8List();
    } on ParsingError catch (error) {
      // At this point the only way this can fail is if the hex string contains
      // invalid characters.
      throw ParsingError(
        'Hex characters are invalid: ${error.message}',
        AddressInvalidReason.invalidHexChars,
      );
    }

    final address = AccountAddress(addressBytes);

    // Cannot pad the address if it has more than maxMissingChars missing.
    if (parsedInput.length < 64 - maxMissingChars) {
      if (!address.isSpecial()) {
        throw ParsingError(
          'Hex string is too short, must be ${64 - maxMissingChars} to 64 chars long, excluding the leading 0x. '
          'You may need to fix the address by padding it with 0s before passing it to `fromString` '
          "(e.g. addressString.padLeft(64, '0')). Received $input",
          AddressInvalidReason.tooShort,
        );
      }
    }

    return address;
  }

  /// Convenience method for creating an AccountAddress from various input
  /// types. This function accepts a hex [String], [Uint8List], or an existing
  /// [AccountAddress] instance and returns the corresponding AccountAddress.
  static AccountAddress from(
    AccountAddressInput input, {
    int maxMissingChars = 4,
  }) {
    if (input is String) {
      return AccountAddress.fromString(input, maxMissingChars: maxMissingChars);
    }
    if (input is Uint8List) {
      return AccountAddress(input);
    }
    if (input is AccountAddress) {
      return input;
    }
    throw ArgumentError(
      'AccountAddressInput must be a String, Uint8List, or AccountAddress, got ${input.runtimeType}',
    );
  }

  /// Create an AccountAddress from various input types using strict string
  /// parsing.
  static AccountAddress fromStrict(AccountAddressInput input) {
    if (input is String) {
      return AccountAddress.fromStringStrict(input);
    }
    return AccountAddress.from(input);
  }

  // ===
  // Methods for checking validity.
  // ===

  /// Check if the provided input is a valid AccountAddress.
  ///
  /// If [strict] is true, use strict parsing behavior; if false, use relaxed
  /// parsing behavior.
  static ParsingResult<AddressInvalidReason> isValid({
    required AccountAddressInput input,
    bool strict = false,
  }) {
    try {
      if (strict) {
        AccountAddress.fromStrict(input);
      } else {
        AccountAddress.from(input);
      }
      return const ParsingResult(valid: true);
    } on ParsingError<AddressInvalidReason> catch (error) {
      return ParsingResult(
        valid: false,
        invalidReason: error.invalidReason,
        invalidReasonMessage: error.message,
      );
    }
  }

  /// Determine if two AccountAddresses are equal based on their underlying
  /// byte data.
  bool equals(AccountAddress other) {
    if (data.length != other.data.length) return false;
    for (var i = 0; i < data.length; i += 1) {
      if (data[i] != other.data[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountAddress && equals(other);

  @override
  int get hashCode => toStringLong().hashCode;
}
