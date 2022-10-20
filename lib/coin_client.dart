
import 'package:aptos/abis.dart';
import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/transaction_builder/builder.dart';

class CoinClient {

  late AptosClient aptosClient;

  CoinClient(AptosClient client) {
    aptosClient = client;
  }

  factory CoinClient.fromEndpoint(String endpoint, {bool enableDebugLog = false}) {
    return CoinClient(AptosClient(endpoint, enableDebugLog: enableDebugLog));
  }

  Future<String> transfer(
    AptosAccount from,
    String to,
    String amount,{
    String? maxGasAmount,
    String? gasUnitPrice,
    String? expireTimestamp,
    String? coinType
  }) async {
    coinType ??= AptosClient.APTOS_COIN;
    final submitTxn = await aptosClient.generateTransferTransaction(from, to, amount, coinType: coinType);
    final resp = await aptosClient.submitTransaction(submitTxn);
    return resp["hash"];
  }

  Future<BigInt> checkBalance(String address, { String? coinType }) async {
    coinType ??= AptosClient.APTOS_COIN;
    String typeTag = "0x1::coin::CoinStore<$coinType>";
    final resources = await aptosClient.getAccountResources(address);
    final accountResource = resources.firstWhere((r) => r["type"] == typeTag);
    return BigInt.parse(accountResource["data"]["coin"]["value"]);
  }
}