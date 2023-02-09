
import 'package:aptos/aptos_types/account_address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';

void main() {
  const ADDRESS_LONG = "000000000000000000000000000000000000000000000000000000000a550c18";
  const ADDRESS_SHORT = "a550c18";

  test("gets created from full hex string", () {
    final addr = AccountAddress.fromHex(ADDRESS_LONG);
    expect(HEX.encode(addr.address), ADDRESS_LONG);
  });

  test("gets created from short hex string", () {
    final addr = AccountAddress.fromHex(ADDRESS_SHORT);
    expect(HEX.encode(addr.address), ADDRESS_LONG);
  });

  test("gets created from prefixed full hex string", () {
    final addr = AccountAddress.fromHex("0x$ADDRESS_LONG");
    expect(HEX.encode(addr.address), ADDRESS_LONG);
  });

  test("gets created from prefixed short hex string", () {
    final addr = AccountAddress.fromHex("0x$ADDRESS_SHORT");
    expect(HEX.encode(addr.address), ADDRESS_LONG);
  });

  test("throws exception when initiating from a long hex string", () {
    expect(() {
      AccountAddress.fromHex("1$ADDRESS_LONG");
    }, throwsArgumentError);
  });

  test("gets created from prefixed short hex string with leading 0s", () {
    final addr = AccountAddress.fromHex("0x000$ADDRESS_SHORT");
    expect(HEX.encode(addr.address), ADDRESS_LONG);
  });

  test("throws exception when initiating from a long hex string", () {
    expect(() {
      AccountAddress.fromHex("1$ADDRESS_LONG");
    }, throwsArgumentError);
  });

  test("isValid short with 0x", () {
    expect(AccountAddress.isValid("0x$ADDRESS_SHORT"), true);
  });

  test("isValid short with leading 0s 0x", () {
    expect(AccountAddress.isValid("0x000$ADDRESS_SHORT"), true);
  });

  test("isValid long with leading 0s without 0x", () {
    expect(AccountAddress.isValid(ADDRESS_LONG), true);
  });

  test("isValid long with leading 0s with 0x", () {
    expect(AccountAddress.isValid("0x$ADDRESS_LONG"), true);
  });

  test("not isValid empty string", () {
    expect(AccountAddress.isValid(""), false);
  });

  test("not isValid too long without 0x", () {
    expect(AccountAddress.isValid("00$ADDRESS_LONG"), false);
  });

  test("not isValid too long with 0x", () {
    expect(AccountAddress.isValid("0x00$ADDRESS_LONG"), false);
  });


}