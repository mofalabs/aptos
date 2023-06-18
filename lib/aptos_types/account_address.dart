
import 'dart:typed_data';

import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:aptos/hex_string.dart';

class AccountAddress with Serializable {

  static const LENGTH = 32;
  static const CORE_CODE_ADDRESS = "0x1";

  final Uint8List address;

  AccountAddress(this.address) {
    if (address.length != AccountAddress.LENGTH) {
      throw ArgumentError("Expected address of length 32");
    }
  }

  String hexAddress() {
    return HexString.fromBuffer(address).hex();
  }
  
  static AccountAddress coreCodeAddress() {
    return AccountAddress.fromHex(CORE_CODE_ADDRESS);
  }

  static AccountAddress fromHex(String addr) {
    var address = HexString.ensure(addr);

    // If an address hex has odd number of digits, padd the hex string with 0
    // e.g. '1aa' would become '01aa'.
    if (address.noPrefix().length % 2 != 0) {
      address = HexString("0${address.noPrefix()}");
    }

    Uint8List addressBytes = address.toUint8Array();

    if (addressBytes.length > AccountAddress.LENGTH) {
      throw ArgumentError("Hex string is too long. Address's length is 32 bytes.");
    } else if (addressBytes.length == AccountAddress.LENGTH) {
      return AccountAddress(addressBytes);
    }

    final res = Uint8List(AccountAddress.LENGTH);
    res.setAll(AccountAddress.LENGTH - addressBytes.length, addressBytes);

    return AccountAddress(res);
  }

  static bool isValid(String addr) {
    // At least one zero is required
    if (addr.isEmpty) {
      return false;
    }

    var address = HexString.ensure(addr);

    // If an address hex has odd number of digits, padd the hex string with 0
    // e.g. '1aa' would become '01aa'.
    if (address.noPrefix().length % 2 != 0) {
      address = HexString("0${address.noPrefix()}");
    }

    final addressBytes = address.toUint8Array();

    return addressBytes.length <= AccountAddress.LENGTH;
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(address);
  }

  static AccountAddress deserialize(Deserializer deserializer) {
    return AccountAddress(deserializer.deserializeFixedBytes(AccountAddress.LENGTH));
  }

  static standardizeAddress(String address) {
    final lowercaseAddress = address.toLowerCase();
    final addressWithoutPrefix = lowercaseAddress.startsWith("0x") ? lowercaseAddress.substring(2) : lowercaseAddress;
    final addressWithPadding = addressWithoutPrefix.padLeft(64, "0");
    return "0x$addressWithPadding";
  }
}
