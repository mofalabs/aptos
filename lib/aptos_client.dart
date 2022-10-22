import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_types/rotation_proof_challenge.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/http/http.dart';
import 'package:aptos/models/entry_function_payload.dart';
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/response/account_data.dart';
import 'package:aptos/models/signature.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/models/transaction.dart';
import 'package:dio/dio.dart';

class AptosClient with AptosClientInterface {

  static const APTOS_COIN = "0x1::aptos_coin::AptosCoin";

  AptosClient(this.endpoint, {this.enableDebugLog = false}) {
    Constants.enableDebugLog = enableDebugLog;
  }

  final String endpoint;
  final bool enableDebugLog;

  /// Accounts ///

  @override
  Future<AccountData> getAccount(String address) async {
    final path = "$endpoint/accounts/$address";
    final resp = await http.get(path);
    return AccountData.fromJson(resp.data);
  }

  Future<bool> accountExist(String address) async {
    try {
      await getAccount(address);
      return true;
    } catch (e) {
      dynamic err = e;
      if (err.response.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  Future<dynamic> getAccountResources(String address) async {
    final path = "$endpoint/accounts/$address/resources";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getAccountResource(String address, String resourceType) async {
    final path = "$endpoint/accounts/$address/resource/$resourceType";
    final resp = await http.get(path);
    return resp.data;
  }

  @override
  Future<dynamic> getAccountModules(String address) async {
    final path = "$endpoint/accounts/$address/modules";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getAccountModule(String address, String moduleName) async {
    final path = "$endpoint/accounts/$address/module/$moduleName";
    try {
      final resp = await http.get(path);
      return resp.data;
    } catch(err) {
      return null;
    }
  }


  /// Blocks ///
  
  Future<dynamic> getBlocksByHeight(int blockHeight, [bool withTransactioins = false]) async {
    final path = "$endpoint/blocks/by_height/$blockHeight?with_transactions=$withTransactioins";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getBlocksByVersion(int version, [bool withTransactioins = false]) async {
    final path = "$endpoint/blocks/by_version/$version?with_transactions=$withTransactioins";
    final resp = await http.get(path);
    return resp.data;
  }

  /// Events ///
  
  Future<dynamic> getEventsByCreationNumber(String address, int creationNumber, {String? start, int? limit}) async {
    final params = <String, dynamic>{};
    if (start != null) params["start"] = start;
    if (limit != null) params["limit"] = limit;

    final path = "$endpoint/accounts/$address/events/$creationNumber";
    final resp = await http.get(path, queryParameters: params);
    return resp.data;
  }

  Future<dynamic> getEventsByEventHandle(String address, String eventHandle, String fieldName, {String? start, int? limit}) async {
    final params = <String, dynamic>{};
    if (start != null) params["start"] = start;
    if (limit != null) params["limit"] = limit;

    final path = "$endpoint/accounts/$address/events/$eventHandle/$fieldName";
    final resp = await http.get(path, queryParameters: params);
    return resp.data;
  }

  /// General ///
  
  Future<dynamic> showOpenAPIExplorer() async {
    final path = "$endpoint/spec";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<String> checkBasicNodeHealth() async {
    final path = "$endpoint/-/healthy";
    final resp = await http.get(path);
    return resp.data["message"];
  }

  Future<dynamic> getLedgerInfo() async {
    final path = "$endpoint";
    final resp = await http.get(path);
    return resp.data;
  }

  @override
  Future<int> getChainId() async {
    final ledgerInfo = await getLedgerInfo();
    final chainId = ledgerInfo["chain_id"];
    return chainId;
  }


  /// Table ///

  Future<dynamic> queryTableItem(String tableHandle, TableItem tableItem) async {
    final path = "$endpoint/tables/$tableHandle/item";
    final data = <String, String>{};
    data["key_type"] = tableItem.keyType;
    data["value_type"] = tableItem.valueType;
    data["key"] = tableItem.key;
    final resp = await http.post(path, data: data);
    return resp.data;
  }


  /// Transactions ///

  Future<dynamic> getTransactions({String? start, int? limit}) async {
    final params = <String, dynamic>{};
    if (start != null) params["start"] = start;
    if (limit != null) params["limit"] = limit;

    final path = "$endpoint/transactions";
    final resp = await http.get(path, queryParameters: params);
    return resp.data;
  }

  Future<dynamic> submitTransaction(TransactionRequest transaction) async {
    final path = "$endpoint/transactions";
    final resp = await http.post(path, data: transaction);
    return resp.data;
  }

  Future<dynamic> submitSignedBCSTransaction(Uint8List signedTxn) async {
    final path = "$endpoint/transactions";
    final file = MultipartFile.fromBytes(signedTxn).finalize();
    final options = Options(contentType: "application/x.aptos.signed_transaction+bcs");
    final resp = await http.post(path, data: file, options: options);
    return resp.data;
  }

  Future<dynamic> submitBCSTransaction(Uint8List signedTxn) async {
    return submitSignedBCSTransaction(signedTxn);
  }

  Future<dynamic> submitBatchTransactions(List<TransactionRequest> transactions) async {
    final path = "$endpoint/transactions/batch";
    final resp = await http.post(path, data: transactions);
    return resp.data;
  }

  Future<dynamic> simulateTransaction(
    TransactionRequest transaction,
    { bool estimateGasUnitPrice = false,
      bool estimateMaxGasAmount = false}) async {
    final params = <String, bool>{
      "estimate_gas_unit_price": estimateGasUnitPrice,
      "estimate_max_gas_amount": estimateMaxGasAmount
    };
    final path = "$endpoint/transactions/simulate";
    final resp = await http.post(path, data: transaction.toJson(), queryParameters: params);
    return resp.data;
  }

  Future<dynamic> getTransactionByHash(String txHash) async {
    final path = "$endpoint/transactions/by_hash/$txHash";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getTransactionByVersion(String txVersion) async {
    final path = "$endpoint/transactions/by_version/$txVersion";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getAccountTransactions(String address, {String? start, int? limit}) async {
    final params = <String, dynamic>{};
    if (start != null) params["start"] = start;
    if (limit != null) params["limit"] = limit;

    final path = "$endpoint/accounts/$address/transactions";
    final resp = await http.get(path, queryParameters: params);
    return resp.data;
  }

  Future<String> encodeSubmission(TransactionEncodeSubmissionRequest transaction) async {
    final path = "$endpoint/transactions/encode_submission";
    final resp = await http.post(path, data: transaction);
    return resp.data;
  }

  @override
  Future<int> estimateGasPrice() async {
    final path = "$endpoint/estimate_gas_price";
    final resp = await http.get(path);
    return resp.data["gas_estimate"];
  }

  Future<BigInt> estimateGasUnitPrice(TransactionRequest transaction) async {
    final txData = await simulateTransaction(transaction, estimateGasUnitPrice: true);
    final txInfo = txData[0];
    bool isSuccess = txInfo["success"];
    if (!isSuccess) throw Exception({txInfo["vm_status"]});
    final maxGasAmount = txInfo["gas_unit_price"].toString();
    return BigInt.parse(maxGasAmount);
  }

  Future<BigInt> estimateGasAmount(TransactionRequest transaction) async {
    final txData = await simulateTransaction(transaction, estimateMaxGasAmount: true);
    final txInfo = txData[0];
    bool isSuccess = txInfo["success"];
    if (!isSuccess) throw Exception({txInfo["vm_status"]});
    final maxGasAmount = txInfo["gas_used"].toString();
    return BigInt.parse(maxGasAmount);
  }

  Future<bool> transactionPending(String txnHash) async {
    final response = await getTransactionByHash(txnHash);
    return response["type"] == "pending_transaction";
  }

  Future<dynamic> waitForTransactionWithResult(
    String txnHash,
    { int? timeoutSecs, bool? checkSuccess }
  ) async {
    timeoutSecs = timeoutSecs ?? 20;
    checkSuccess = checkSuccess ?? false;

    var isPending = true;
    var count = 0;
    dynamic lastTxn;
    while (isPending) {
      if (count >= timeoutSecs) {
        break;
      }
      try {
        lastTxn = await getTransactionByHash(txnHash);
        isPending = lastTxn["type"] == "pending_transaction";
        if (!isPending) {
          break;
        }
      } catch (e) {
        final isDioError = e is DioError;
        int statusCode = 0;
        if (isDioError) {
          statusCode = e.response?.statusCode ?? 0;
        }
        if (isDioError && statusCode != 404 && statusCode >= 400 && statusCode < 500) {
          rethrow;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
      count += 1;
    }

    if (lastTxn == null) {
      throw Exception("Waiting for transaction $txnHash failed");
    }

    if (isPending) {
      throw Exception(
        "Waiting for transaction $txnHash timed out after $timeoutSecs seconds"
      );
    }
    if (!checkSuccess) {
      return lastTxn;
    }
    if (!(lastTxn.success)) {
      throw Exception(
        "Transaction $txnHash committed to the blockchain but execution failed"
      );
    }
    return lastTxn;
  }

  Future<void> waitForTransaction(
    String txnHash,
    { int? timeoutSecs, bool? checkSuccess }
  ) async {
    await waitForTransactionWithResult(
      txnHash, 
      timeoutSecs: timeoutSecs, 
      checkSuccess: checkSuccess);
  }

  // Generates a signed transaction that can be submitted to the chain for execution.
  static Uint8List generateBCSTransaction(AptosAccount accountFrom, RawTransaction rawTxn) {
    final txnBuilder = TransactionBuilderEd25519(
      accountFrom.pubKey().toUint8Array(), 
      (Uint8List signingMessage) => Ed25519Signature(accountFrom.signBuffer(signingMessage).toUint8Array())
    );

    return txnBuilder.sign(rawTxn);
  }

  static SignedTransaction generateBCSRawTransaction(AptosAccount accountFrom, RawTransaction rawTxn) {
    final txnBuilder = TransactionBuilderEd25519(
      accountFrom.pubKey().toUint8Array(), 
      (Uint8List signingMessage) => Ed25519Signature(accountFrom.signBuffer(signingMessage).toUint8Array())
    );

    return txnBuilder.rawToSigned(rawTxn);
  }

  // Future<TransactionRequest> generateTransferTransaction(
  //   AptosAccount accountFrom,
  //   String receiverAddress,
  //   String amount,{
  //   String? coinType,
  //   BigInt? maxGasAmount,
  //   BigInt? gasUnitPrice,
  //   BigInt? expireTimestamp
  // }) async {
  //   const function = "0x1::coin::transfer";
  //   coinType ??= AptosClient.APTOS_COIN;

  //   final account = await getAccount(accountFrom.address);
  //   maxGasAmount ??= BigInt.from(20000);
  //   gasUnitPrice ??= BigInt.from(await estimateGasPrice());
  //   expireTimestamp ??= BigInt.from((DateTime.now().add(const Duration(seconds: 10)).microsecondsSinceEpoch));

  //   final token = TypeTagStruct(StructTag.fromString(coinType));
  //   final entryFunctionPayload = TransactionPayloadEntryFunction(
  //     EntryFunction.natural(
  //       function.split("::").take(2).join("::"),
  //       function.split("::").last,
  //       [token],
  //       [bcsToBytes(AccountAddress.fromHex(receiverAddress)), bcsSerializeUint64(BigInt.parse(amount))],
  //     ),
  //   );
    
  //   final rawTxn = await generateRawTransaction(
  //     accountFrom.accountAddress, 
  //     entryFunctionPayload, 
  //     maxGasAmount: maxGasAmount, 
  //     gasUnitPrice: gasUnitPrice, 
  //     expireTimestamp: expireTimestamp
  //   );

  //   final signedTxn = AptosClient.generateBCSRawTransaction(accountFrom, rawTxn);
  //   final txAuthEd25519 = signedTxn.authenticator as TransactionAuthenticatorEd25519;
  //   final signature = txAuthEd25519.signature.value;

  //   return TransactionRequest(
  //     sender: accountFrom.address,
  //     sequenceNumber: account.sequenceNumber,
  //     payload: Payload(
  //       "entry_function_payload",
  //       function,
  //       [coinType],
  //       [receiverAddress, amount]
  //     ),
  //     maxGasAmount: maxGasAmount.toString(),
  //     gasUnitPrice: gasUnitPrice.toString(),
  //     expirationTimestampSecs: expireTimestamp.toString(),
  //     signature: Signature(
  //       "ed25519_signature",
  //       accountFrom.pubKey().hex(),
  //       HexString.fromUint8Array(signature).hex()
  //     )
  //   );
  // }


// Note: Unless you have a specific reason for using this, it'll probably be simpler
// to use `simulateTransaction`.
// Generates a BCS transaction that can be submitted to the chain for simulation.
static Future<Uint8List> generateBCSSimulation(AptosAccount accountFrom, RawTransaction rawTxn) async {
  final txnBuilder = TransactionBuilderEd25519(
    accountFrom.pubKey().toUint8Array(), 
    (Uint8List _signingMessage) => Ed25519Signature(Uint8List(64)));

  return txnBuilder.sign(rawTxn);
}

  Future<RawTransaction> generateRawTransaction(
    String accountFrom,
    TransactionPayload payload,{
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    final account = await getAccount(accountFrom);
    final chainId = await getChainId();

    maxGasAmount ??= BigInt.from(20000);
    gasUnitPrice ??= BigInt.from(await estimateGasPrice());
    expireTimestamp ??= BigInt.from((DateTime.now().millisecondsSinceEpoch / 1000).floor() + 20);

    return RawTransaction(
      AccountAddress.fromHex(accountFrom),
      BigInt.parse(account.sequenceNumber),
      payload,
      maxGasAmount,
      gasUnitPrice,
      expireTimestamp,
      ChainId(chainId),
    );
  }

  Future<dynamic> generateSignSubmitTransaction(
    AptosAccount sender,
    TransactionPayload payload,{
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    final rawTransaction = await generateRawTransaction(
      sender.address, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
    final bcsTxn = AptosClient.generateBCSTransaction(sender, rawTransaction);
    final pendingTransaction = await submitSignedBCSTransaction(bcsTxn);
    return pendingTransaction;
  }

  Future<RawTransaction> generateTransaction(
    AptosAccount sender,
    EntryFunctionPayload payload,{
    String? sequenceNumber,
    String? gasUnitPrice,
    String? maxGasAmount,
    String? expirationTimestampSecs
  }) async {
    final builderConfig = ABIBuilderConfig(
      sender: sender.address,
      sequenceNumber: sequenceNumber != null ? BigInt.parse(sequenceNumber) : null,
      gasUnitPrice: gasUnitPrice != null ? BigInt.parse(gasUnitPrice) : null,
      maxGasAmount: maxGasAmount != null ? BigInt.parse(maxGasAmount) : null,
      expSecFromNow: expirationTimestampSecs != null ? BigInt.parse(expirationTimestampSecs) : null
    );
    final builder = TransactionBuilderRemoteABI(this, builderConfig);
    return await builder.build(payload.functionId, payload.typeArguments, payload.arguments);
  }

  /// Rotate an account's auth key. After rotation, only the new private key can be used to sign txns for
  /// the account.
  /// WARNING: You must create a new instance of AptosAccount after using this function.
  Future<dynamic> rotateAuthKeyEd25519(
    AptosAccount forAccount,
    Uint8List toPrivateKeyBytes,
  ) async {
    final accountInfo = await getAccount(forAccount.address);
    final sequenceNumber = accountInfo.sequenceNumber;
    final authKey = accountInfo.authenticationKey;

    final helperAccount = AptosAccount(toPrivateKeyBytes);

    final challenge = RotationProofChallenge(
      AccountAddress.coreCodeAddress(),
      "account",
      "RotationProofChallenge",
      BigInt.parse(sequenceNumber),
      AccountAddress.fromHex(forAccount.address),
      AccountAddress(HexString(authKey).toUint8Array()),
      helperAccount.pubKey().toUint8Array(),
    );

    final challengeBytes = bcsToBytes(challenge);

    final proofSignedByCurrentPrivateKey = forAccount.signBuffer(challengeBytes);

    final proofSignedByNewPrivateKey = helperAccount.signBuffer(challengeBytes);

    final payload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        "0x1::account",
        "rotate_authentication_key",
        [],
        [
          bcsSerializeU8(0), // ed25519 scheme
          bcsSerializeBytes(forAccount.pubKey().toUint8Array()),
          bcsSerializeU8(0), // ed25519 scheme
          bcsSerializeBytes(helperAccount.pubKey().toUint8Array()),
          bcsSerializeBytes(proofSignedByCurrentPrivateKey.toUint8Array()),
          bcsSerializeBytes(proofSignedByNewPrivateKey.toUint8Array()),
        ],
      ),
    );

    final rawTransaction = await generateRawTransaction(forAccount.address, payload);
    final bcsTxn = AptosClient.generateBCSTransaction(forAccount, rawTransaction);
    return submitSignedBCSTransaction(bcsTxn);
  }

  Future<String> lookupOriginalAddress(String addressOrAuthKey) async {
    final resource = await getAccountResource("0x1", "0x1::account::OriginatingAddress");
    final handle = resource["data"]["address_map"]["handle"];
    final tableItem = TableItem("address", "address", HexString.ensure(addressOrAuthKey).hex());
    final origAddress = await queryTableItem(handle, tableItem);
    return origAddress.toString();
  }

}