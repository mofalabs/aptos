import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/coin_client.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/models/transaction.dart';
import 'package:aptos/transaction_builder/builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptos/aptos_client.dart';

void main() {

  String address = "0x9d36a1531f1ac2fc0e9d0a78105357c38e55f1a97a504d98b547f2f62fbbe3c6";
  AptosClient aptos = AptosClient(Constants.testnetAPI, enableDebugLog: true);

  const aptosCoinStore = "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>";

  test('aptos client node health', () async {
    final result = await aptos.checkBasicNodeHealth();
    expect(result, "aptos-node:ok");
  });

  test('aptos account exist', () async {
    final result = await aptos.accountExist(address);
    expect(result, true);
  });

  test('aptos get account', () async {
    final result = await aptos.getAccount(address);
    expect(int.parse(result.sequenceNumber) >= 0, true);
  });

  test('aptos get account resouces', () async {
    final result = await aptos.getAccountResources(address);
    expect(result.length > 0, true);
  });

  test('aptos get account resouce by type', () async {
    // final result = await aptos.getAccountResouce(address, "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>");
    // expect(result["type"] , "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>");

    final result1 = await aptos.getAccountResource("0xfaf52ae1b48f945014ab1ba2798f85498995848cedfb0fbd167fada7ccb2d66e", "0xfaf52ae1b48f945014ab1ba2798f85498995848cedfb0fbd167fada7ccb2d66e::chat::MessageStore");
    print(result1);
  });

  test('aptos get account modules', () async {
    final result = await aptos.getAccountModules(address);
    expect(result.length, 0);
  });

  test('aptos get account module by name', () async {
    final result = await aptos.getAccountModule(address, "coin");
    expect(result, null);
  });

  test('aptos get block by height', () async {
    final result = await aptos.getBlocksByHeight(0, false);
    expect(result["block_height"], "0");
  });

  test('aptos get block by version', () async {
    final result = await aptos.getBlocksByVersion(1, false);
    expect(result["last_version"], "1");
  });

  test('aptos get events by creation_number', () async {
    final result = await aptos.getEventsByCreationNumber(address, 0);
    expect(result[0]["guid"]["creation_number"], "0");
  });

  test('aptos get events by handle', () async {
    const handle = "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>";
    const fieldName = "withdraw_events";
    final result = await aptos.getEventsByEventHandle(address, handle, fieldName);
    expect(result[0]["type"], "0x1::coin::WithdrawEvent");
  });

  test('aptos show open_api explorer', () async {
    final result = await aptos.showOpenAPIExplorer();
    expect(result.length > 0, true);
  });

  test('aptos get ledger info', () async {
    final result = await aptos.getLedgerInfo();
    expect(result["chain_id"], 2);
  });

  test('aptos query table item', () async {
    const handle = "";
    final tableItem = TableItem("", "", "");
    final result = await aptos.queryTableItem(handle, tableItem);
  });

  test('aptos get transactions', () async {
    final result = await aptos.getTransactions(limit: 1);
    expect(result.length, 1);
  });

  test('aptos submit batch transactions', () async {
    final tx = TransactionRequest(
      sender: address,
      sequenceNumber: "6", 
      maxGasAmount: "63000", 
      gasUnitPrice: "1000", 
      expirationTimestampSecs: "1664996874708", 
      payload: Payload(
        "entry_function_payload",
        "0x1::aptos_account::transfer",
        [],
        ["0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012", "100"]
      ),
      signature: Signature(
        "ed25519_signature",
        "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
        "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"
      )
    );
    final result = await aptos.submitBatchTransactions([tx]);
  });

  test('aptos simulate transaction', () async {
    final tx = TransactionRequest(
      sender: address,
      sequenceNumber: "11", 
      maxGasAmount: "63000",
      gasUnitPrice: "1000",
      expirationTimestampSecs: "1664996874708", 
      payload: Payload(
        "entry_function_payload",
        "0x1::aptos_account::transfer",
        [],
        ["0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012", "100"]
      ),
      signature: Signature(
        "ed25519_signature",
        "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
        "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"
      )
    );
    final result = await aptos.simulateTransaction(tx);
    expect(result[0]["success"], true);
  });

  test('aptos estimate gas used amount', () async {
    final tx = TransactionRequest(
      sender: address,
      sequenceNumber: "11",
      maxGasAmount: "63000",
      gasUnitPrice: "1000",
      expirationTimestampSecs: "1664996874708",
      payload: Payload(
        "entry_function_payload",
        "0x1::aptos_account::transfer",
        [],
        ["0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012", "100"]
      ),
      signature: Signature(
        "ed25519_signature",
        "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
        "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"
      )
    );
    final result = await aptos.estimateGasAmount(tx);
    expect(result > BigInt.zero, true);
  });

  test('aptos estimate gas unit price', () async {
    final tx = TransactionRequest(
      sender: address,
      sequenceNumber: "11",
      maxGasAmount: "63000",
      gasUnitPrice: "1000",
      expirationTimestampSecs: "1664996874708",
      payload: Payload(
        "entry_function_payload",
        "0x1::aptos_account::transfer",
        [],
        ["0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012", "100"]
      ),
      signature: Signature(
        "ed25519_signature",
        "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
        "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"
      )
    );
    final result = await aptos.estimateGasUnitPrice(tx);
    expect(result > BigInt.zero, true);
  });

  test('aptos get transaction by hash', () async {
    const hash = "0xfafe767a13e2dd8d7efcb287050647e7747ba964ecb42db8b5d13a272c16ab9b";
    final result = await aptos.getTransactionByHash(hash);
    expect(result["hash"], hash);
  });

  test('aptos get transaction by version', () async {
    final result = await aptos.getTransactionByVersion("133823384");
    expect(result["version"], "133823384");
  });

  test('aptos get account transactions', () async {
    final result = await aptos.getAccountTransactions(address, limit: 1);
    expect(result.length, 1);
  });

  test('aptos encode submission', () async {
    final tx = TransactionEncodeSubmissionRequest(
      sender: address,
      sequenceNumber: "6",
      maxGasAmount: "100",
      gasUnitPrice: "10",
      expirationTimestampSecs: "1664996874708",
      payload: Payload(
        "entry_function_payload",
        "0x1::aptos_account::transfer",
        [],
        ["0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012", "100"]
      ),
      secondarySigners: []
    );
    final result = await aptos.encodeSubmission(tx);
  });

  test('aptos estimate gas price', () async {
    final result = await aptos.estimateGasPrice();
    expect(result > 0, true);
  });

  test('transaction pending status', () async {
    const hash = "0xfafe767a13e2dd8d7efcb287050647e7747ba964ecb42db8b5d13a272c16ab9b";
    final isPending = await aptos.transactionPending(hash);
    expect(isPending, false);
  });

  test(
    "test submitSignedBCSTransaction", () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client);
      // final coinClient = CoinClient(client);

      final privateArray = HexString("9e2dc8c01845a5b68d2abfb8e08cfb627325a9741b0041818076ce0910fce82b").toUint8Array();
      final account1 =  AptosAccount(privateArray);
      final account2 = AptosAccount();

      await faucetClient.fundAccount(account2.address, "0");

      final builder = TransactionBuilderRemoteABI(client, ABIBuilderConfig(sender: account1.address));
      final rawTxn = await builder.build(
        "0x1::coin::transfer",
        ["0x1::aptos_coin::AptosCoin"],
        [account2.address, 400],
      );

      final bcsTxn = AptosClient.generateBCSTransaction(account1, rawTxn);
      final transactionRes = await client.submitSignedBCSTransaction(bcsTxn);

      await Future.delayed(const Duration(seconds: 3));
      await client.waitForTransaction(transactionRes["hash"]);

      final resources = await client.getAccountResources(account2.address);
      final accountResource = (resources as List).firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "400", true);
    }
  );

  test('submits bcs transaction', () async {
    final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
    final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client);

    final privateArray = HexString("9e2dc8c01845a5b68d2abfb8e08cfb627325a9741b0041818076ce0910fce82b").toUint8Array();
    final account1 =  AptosAccount(privateArray);
    final account2 = AptosAccount();

    await faucetClient.fundAccount(account2.address, "0");

    final token = TypeTagStruct(StructTag.fromString("0x1::aptos_coin::AptosCoin"));

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        "0x1::coin",
        "transfer",
        [token],
        [bcsToBytes(AccountAddress.fromHex(account2.address)), bcsSerializeUint64(BigInt.from(717))],
      ),
    );

    final rawTxn = await client.generateRawTransaction(account1.address, entryFunctionPayload);

    final bcsTxn = AptosClient.generateBCSTransaction(account1, rawTxn);

    final transactionRes = await client.submitSignedBCSTransaction(bcsTxn);

    await client.waitForTransaction(transactionRes["hash"]);

    final resources = await client.getAccountResources(account2.address);
    final accountResource = resources.firstWhere((r) => r["type"] == aptosCoinStore);
    expect(accountResource != null, true);
  });

  test('lookup original address', () async {
    final client = AptosClient(Constants.devnetAPI);
    final account1 =  AptosAccount();

    final address = await client.lookupOriginalAddress(account1.address);
    expect(address.isNotEmpty, true);
  });

  test(
    "rotates auth key ed25519",
    () async {
      final client = AptosClient(Constants.devnetAPI);
      final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client, enableDebugLog: true);

      final alice = AptosAccount();
      await faucetClient.fundAccount(alice.address, "100000000");

      final helperAccount = AptosAccount();

      final secretKey = Uint8List.fromList(helperAccount.signingKey.privateKey.bytes);
      final pendingTxn = await client.rotateAuthKeyEd25519(alice, secretKey);

      await client.waitForTransaction(pendingTxn["hash"]);

      final origAddressHex = await client.lookupOriginalAddress(helperAccount.address);
      // Sometimes the returned addresses do not have leading 0s. To be safe, converting hex addresses to AccountAddress
      final origAddress = AccountAddress.fromHex(origAddressHex);
      final aliceAddress = AccountAddress.fromHex(alice.address);

      expect(HexString.fromUint8Array(origAddress.address).hex() ==
        HexString.fromUint8Array(aliceAddress.address).hex(), true
      );
    }
  );

}
