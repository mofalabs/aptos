import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/models/transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String address =
      "0xa19ad3e576eb3001394dccae2ce0bcb3486a822853506b93e84b4b1b39cce9eb";
  AptosClient aptos = AptosClient(Constants.mainnetAPI, enableDebugLog: true);

  const aptosCoinStore = "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>";

  group('apto client test', () {
    setUpAll(() async {
      final exist = await aptos.accountExist(address);
      if (!exist) {
        final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI, aptos);
        faucetClient.fundAccount(address, '10000');
        await Future.delayed(const Duration(seconds: 3));
      }
    });

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

    test('aptos get account resouce by resource type', () async {
      final result = await aptos.getAccountResource(address, "0x3::token::TokenStore");
      expect(result.length > 0, true);
    });

    test('aptos get account aptos coin', () async {
      final result = await aptos.getAccountResource(address, "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>");
      expect(result["type"] , "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>");
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
      final result =
          await aptos.getEventsByEventHandle(address, handle, fieldName);
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
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          signature: const Signature(
              type: "ed25519_signature",
              publicKey:
                  "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
              signature:
                  "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"));
      final result = await aptos.submitBatchTransactions([tx]);
    });

    test('aptos simulate transaction', () async {
      final tx = TransactionRequest(
          sender: address,
          sequenceNumber: "11",
          maxGasAmount: "63000",
          gasUnitPrice: "1000",
          expirationTimestampSecs: "1664996874708",
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          signature: const Signature(
              type: "ed25519_signature",
              publicKey:
                  "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
              signature:
                  "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"));
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
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          signature: const Signature(
              type: "ed25519_signature",
              publicKey:
                  "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
              signature:
                  "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"));
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
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          signature: const Signature(
              type: "ed25519_signature",
              publicKey:
                  "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
              signature:
                  "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"));
      final result = await aptos.estimateGasUnitPrice(tx);
      expect(result > BigInt.zero, true);
    });

    test('aptos estimate gas', () async {
      final tx = TransactionRequest(
          sender: address,
          sequenceNumber: "0",
          maxGasAmount: "63000",
          gasUnitPrice: "1000",
          expirationTimestampSecs: "1664996874708",
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          signature: const Signature(
              type: "ed25519_signature",
              publicKey:
                  "0x2b3a30c47712b5eddabfed336a9f22d2f12573d9ee6da20e1fe3c84b6f3e6a8c",
              signature:
                  "0xe11cd7d7dd6bf4d8d1900e5473def694c5483023aeca934dcf58d7e01b9fcd9a6bbeb212d4ddaca0b46d995253069fd3c7105118584b6b7ec746cf327224d504"));
      final (gasUnitPrice, gasUsed) = await aptos.estimateGas(tx);
      expect(gasUnitPrice > BigInt.zero, true);
      expect(gasUsed > BigInt.zero, true);
    });

    test('aptos get transaction by hash', () async {
      const hash =
          "0xfafe767a13e2dd8d7efcb287050647e7747ba964ecb42db8b5d13a272c16ab9b";
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
          payload: const Payload(
              type: "entry_function_payload",
              function: "0x1::aptos_account::transfer",
              typeArguments: [],
              arguments: [
                "0x96ab1e6d8485523e84dff030cfdecc2e7fb1ef318c33a2f066e8318e09d66012",
                "100"
              ]),
          secondarySigners: []);
      final result = await aptos.encodeSubmission(tx);
    });

    test('aptos estimate gas price', () async {
      final result = await aptos.estimateGasPrice();
      expect(result > 0, true);
    });

    test('transaction pending status', () async {
      const hash =
          "0xfafe767a13e2dd8d7efcb287050647e7747ba964ecb42db8b5d13a272c16ab9b";
      final isPending = await aptos.transactionPending(hash);
      expect(isPending, false);
    });

    test("submit transaction with remote ABI", () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI, client);

      final account1 = AptosAccount();
      await faucetClient.fundAccount(account1.address, "10000000");

      final account2 = AptosAccount();
      await faucetClient.fundAccount(account2.address, "0");

      final builder = TransactionBuilderRemoteABI(
          client, ABIBuilderConfig(sender: account1.address));
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
      final accountResource =
          (resources as List).firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "400", true);
    });

    test('submits bcs transaction', () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI, client);

      final account1 = AptosAccount();
      await faucetClient.fundAccount(account1.address, "10000000");

      final account2 = AptosAccount();
      await faucetClient.fundAccount(account2.address, "0");

      final token =
          TypeTagStruct(StructTag.fromString("0x1::aptos_coin::AptosCoin"));

      final entryFunctionPayload = TransactionPayloadEntryFunction(
        EntryFunction.natural(
          "0x1::coin",
          "transfer",
          [token],
          [
            bcsToBytes(AccountAddress.fromHex(account2.address)),
            bcsSerializeUint64(BigInt.from(717))
          ],
        ),
      );

      final rawTxn = await client.generateRawTransaction(
          account1.address, entryFunctionPayload);

      final bcsTxn = AptosClient.generateBCSTransaction(account1, rawTxn);

      final transactionRes = await client.submitSignedBCSTransaction(bcsTxn);

      await client.waitForTransaction(transactionRes["hash"]);

      final resources = await client.getAccountResources(account2.address);
      final accountResource =
          resources.firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "717", true);
    });

    test("submit multisig transaction simulation", () async {
      final client = AptosClient(Constants.devnetAPI);
      final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI, client);

      final account1 = AptosAccount();
      final account2 = AptosAccount();
      final account3 = AptosAccount();

      final multiSigPublicKey = MultiEd25519PublicKey([
        Ed25519PublicKey(account1.pubKey().toUint8Array()),
        Ed25519PublicKey(account2.pubKey().toUint8Array()),
        Ed25519PublicKey(account3.pubKey().toUint8Array())
      ], 2);

      final authKey =
          AuthenticationKey.fromMultiEd25519PublicKey(multiSigPublicKey);
      final multisigAccountAddress = authKey.derivedAddress().toString();
      await faucetClient.fundAccount(multisigAccountAddress, "50000000");

      await Future.delayed(const Duration(seconds: 3));
      var resources = await client.getAccountResources(multisigAccountAddress);
      var accountResource =
          resources.firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "50000000", true);

      final account4 = AptosAccount();
      await faucetClient.fundAccount(account4.address, "0");

      await Future.delayed(const Duration(seconds: 3));
      resources = await client.getAccountResources(account4.address);
      accountResource =
          resources.firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "0", true);

      final token =
          TypeTagStruct(StructTag.fromString("0x1::aptos_coin::AptosCoin"));
      final entryFunctionPayload =
          TransactionPayloadEntryFunction(EntryFunction.natural(
        "0x1::coin",
        "transfer",
        [token],
        [
          bcsToBytes(AccountAddress.fromHex(account4.address)),
          bcsSerializeUint64(BigInt.from(123))
        ],
      ));

      final rawTxn = await client.generateRawTransaction(
          multisigAccountAddress, entryFunctionPayload);

      final simuateTransactionRes = await client.simulateRawTransaction(
          multiSigPublicKey, rawTxn,
          estimateGasUnitPrice: true,
          estimateMaxGasAmount: true,
          estimatePrioritizedGasUnitPrice: true);

      expect(int.parse(simuateTransactionRes[0]["gas_used"]) > 0, true);
      expect(simuateTransactionRes[0]["success"], true);

      final txnBuilder =
          TransactionBuilderMultiEd25519(multiSigPublicKey, (signingMessage) {
        final sigHexStr1 = account1.signBuffer(signingMessage);
        final sigHexStr3 = account3.signBuffer(signingMessage);
        final bitmap = MultiEd25519Signature.createBitmap([0, 2]);
        final multiEd25519Sig = MultiEd25519Signature([
          Ed25519Signature(sigHexStr1.toUint8Array()),
          Ed25519Signature(sigHexStr3.toUint8Array())
        ], bitmap);
        return multiEd25519Sig;
      });

      // sign and sumit transaction
      final signedBcsTxn = txnBuilder.sign(rawTxn);
      final transactionRes =
          await client.submitSignedBCSTransaction(signedBcsTxn);

      await client.waitForTransaction(transactionRes["hash"]);

      resources = await client.getAccountResources(account4.address);
      accountResource =
          resources.firstWhere((r) => r["type"] == aptosCoinStore);
      expect(accountResource["data"]["coin"]["value"] == "123", true);
    });

    test('lookup original address', () async {
      final client = AptosClient(Constants.devnetAPI);
      final account1 = AptosAccount();

      final address = await client.lookupOriginalAddress(account1.address);
      expect(address.isNotEmpty, true);
    });

    test("rotates auth key ed25519", () async {
      final client = AptosClient(Constants.devnetAPI);
      final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI,
          client, enableDebugLog: true);

      final alice = AptosAccount();
      await faucetClient.fundAccount(alice.address, "100000000");

      final helperAccount = AptosAccount();

      final secretKey =
          Uint8List.fromList(helperAccount.signingKey.privateKey.bytes);
      final pendingTxn = await client.rotateAuthKeyEd25519(alice, secretKey);

      await client.waitForTransaction(pendingTxn["hash"]);

      final origAddressHex =
          await client.lookupOriginalAddress(helperAccount.address);
      // Sometimes the returned addresses do not have leading 0s. To be safe, converting hex addresses to AccountAddress
      final origAddress = AccountAddress.fromHex(origAddressHex);
      final aliceAddress = AccountAddress.fromHex(alice.address);

      expect(
          HexString.fromUint8Array(origAddress.address).hex() ==
              HexString.fromUint8Array(aliceAddress.address).hex(),
          true);
    });

    /// View ///

    test("view function", () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucet = FaucetClient.fromClient(Constants.faucetDevAPI, client);

      final alice = AptosAccount();
      await faucet.fundAccount(alice.address, "10000000");

      await Future.delayed(const Duration(seconds: 2));

      final balance = await client.view("0x1::coin::balance",
          ["0x1::aptos_coin::AptosCoin"], [alice.address]);

      expect(balance[0], "10000000");
    });
  });
}
