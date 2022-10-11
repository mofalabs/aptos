import 'package:aptos/constants.dart';
import 'package:aptos/http/http.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/models/transaction.dart';

class AptosClient {

  AptosClient(this.endpoint, {this.enableDebugLog = false}) {
    Constants.enableDebugLog = enableDebugLog;
  }

  final String endpoint;
  final bool enableDebugLog;

  /// Accounts ///

  Future<dynamic> getAccount(String address) async {
    final path = "$endpoint/accounts/$address";
    final resp = await http.get(path);
    return resp.data;
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

  Future<dynamic> simulateTransaction(TransactionRequest transaction) async {
    final path = "$endpoint/transactions/simulate";
    final resp = await http.post(path, data: transaction.toJson());
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

}