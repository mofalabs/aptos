import 'package:aptos/constants.dart';
import 'package:aptos/http/http.dart';
import 'package:aptos/models/response/account_data.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/models/transaction.dart';
import 'package:dio/dio.dart';

class AptosClient {

  AptosClient(this.endpoint, {this.enableDebugLog = false}) {
    Constants.enableDebugLog = enableDebugLog;
  }

  final String endpoint;
  final bool enableDebugLog;

  /// Accounts ///

  Future<AccountData> getAccount(String address) async {
    final path = "$endpoint/accounts/$address";
    final resp = await http.get(path);
    return AccountData.fromJson(resp.data);
  }

  Future<bool> accountExist(String address) async {
    try {
      await getAccount(address);
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<dynamic> getAccountResources(String address) async {
    final path = "$endpoint/accounts/$address/resources";
    final resp = await http.get(path);
    return resp.data;
  }

  Future<dynamic> getAccountResouce(String address, String resourceType) async {
    final path = "$endpoint/accounts/$address/resource/$resourceType";
    final resp = await http.get(path);
    return resp.data;
  }

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

}