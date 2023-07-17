
import 'dart:math';

import 'package:aptos/aptos.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/plugins/ans_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  final alice = AptosAccount.fromPrivateKey("0xc5338cd251c22daa8c9c9cc94f498cc8a5c7e1d2e75287a5dda91096fe64efa5de19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c");
  final ACCOUNT_ADDRESS = AccountAddress.standardizeAddress(alice.address);

  const ANS_OWNER_PK = "0xde19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c";

  final ansClient = AnsClient(Network.testnet);

  group("ANS", () {

    String DOMAIN_NAME = "4jepog";
    String SUBDOMAIN_NAME = "1lf154z";

    test(
      "init reverse lookup registry for contract admin",
      () async {
        final owner = AptosAccount(HexString(ANS_OWNER_PK).toUint8Array());
        final txnHash = await ansClient.initReverseLookupRegistry(owner);
        await ansClient.aptosClient.waitForTransactionWithResult(txnHash, checkSuccess: true);
      }
    );

    test(
      "mint name",
      () async {
        final txnHash = await ansClient.mintAptosName(alice, DOMAIN_NAME);
        await ansClient.aptosClient.waitForTransactionWithResult(txnHash, checkSuccess: true);
      },
    );

    test(
      "mint subdomain name",
      () async {
        final txnHash = await ansClient.mintAptosSubdomain(alice, SUBDOMAIN_NAME, DOMAIN_NAME);
        await ansClient.aptosClient.waitForTransactionWithResult(txnHash, checkSuccess: true);

        final txnHashForSet = await ansClient.setSubdomainAddress(alice, SUBDOMAIN_NAME, DOMAIN_NAME, ACCOUNT_ADDRESS);
        await ansClient.aptosClient.waitForTransactionWithResult(txnHashForSet, checkSuccess: true);
      }
    );

    test(
      "get name by address",
      () async {
        final name = await ansClient.getPrimaryNameByAddress(ACCOUNT_ADDRESS);
        expect(name, DOMAIN_NAME);
      },
    );

    test(
      "get address by name",
      () async {
        final address = await ansClient.getAddressByName(DOMAIN_NAME);
        final standardizeAddress = AccountAddress.standardizeAddress(address!);
        expect(standardizeAddress, ACCOUNT_ADDRESS);
      }
    );

    test(
      "get address by name with .apt",
      () async {
        final address = await ansClient.getAddressByName("$DOMAIN_NAME.apt");
        final standardizeAddress = AccountAddress.standardizeAddress(address!);
        expect(standardizeAddress, ACCOUNT_ADDRESS);
      },
    );

    test(
      "get address by subdomain_name",
      () async {
        final address = await ansClient.getAddressByName("$SUBDOMAIN_NAME.$DOMAIN_NAME");
        final standardizeAddress = AccountAddress.standardizeAddress(address!);
        expect(standardizeAddress, ACCOUNT_ADDRESS);
      }
    );

    test(
      "get address by subdomain_name with .apt",
      () async {
        final address = await ansClient.getAddressByName("$SUBDOMAIN_NAME.$DOMAIN_NAME.apt");
        final standardizeAddress = AccountAddress.standardizeAddress(address!);
        expect(standardizeAddress, ACCOUNT_ADDRESS);
      }
    );

    test(
      "returns null for an invalid domain",
      () async {
        final address = await ansClient.getAddressByName("$DOMAIN_NAME-");
        expect(address, null);
      }
    );

    test(
      "returns null for an invalid subdomain",
      () async {
        final address = await ansClient.getAddressByName("$SUBDOMAIN_NAME.$DOMAIN_NAME.apt-");
        expect(address, null);
      }
    );
  });

}

