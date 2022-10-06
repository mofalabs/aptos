import 'dart:typed_data';
import 'package:hex/hex.dart';

class HexString {

  late String _hexString;

  static HexString fromBuffer(Uint8List buffer) {
    return HexString.fromUint8Array(buffer);
  }

  static HexString fromUint8Array(Uint8List arr) {
    return HexString(HEX.encode(arr.toList()));
  }

  static HexString ensure(String hexString) {
      return HexString(hexString);
  }

  HexString(String hexString) {
    if (hexString.startsWith("0x")) {
      _hexString = hexString;
    } else {
      _hexString = "0x$hexString";
    }
  }

  String hex() {
    return _hexString;
  }

  String noPrefix() {
    return _hexString.substring(2);
  }

  @override
  String toString() {
    return hex();
  }

  String toShortString() {
    String trimmed = _hexString.replaceAll(RegExp("^0x0*"), "");
    return "0x$trimmed";
  }

  Uint8List toUint8Array() {
    return Uint8List.fromList(HEX.decode(noPrefix()));
  }
}
