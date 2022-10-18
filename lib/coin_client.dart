
import 'package:aptos/abis.dart';
import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/transaction_builder/builder.dart';

class CoinClient {

  static const APTOS_COIN = "0x1::aptos_coin::AptosCoin";

  late AptosClient aptosClient;
  late TransactionBuilderABI transactionBuilder;

  CoinClient(AptosClient client) {
    aptosClient = client;
    transactionBuilder = TransactionBuilderABI(
      COIN_ABIS.map((abi) => HexString(abi).toUint8Array()).toList()
    );
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
    coinType ??= APTOS_COIN;
    final payload = transactionBuilder.buildTransactionPayload(
      "0x1::coin::transfer",
      [coinType],
      [to, amount]
    );
    final txHash = aptosClient.generateSignSubmitTransaction(
      from, 
      payload,
      maxGasAmount: BigInt.tryParse(maxGasAmount ?? ""),
      gasUnitPrice: BigInt.tryParse(gasUnitPrice ?? ""),
      expireTimestamp: BigInt.tryParse(expireTimestamp ?? "")
    );
    return txHash;
  }

  Future<BigInt> checkBalance(String address, { String? coinType }) async {
    coinType ??= APTOS_COIN;
    String typeTag = "0x1::coin::CoinStore<$coinType>";
    final resources = await aptosClient.getAccountResources(address);
    final accountResource = resources.firstWhere((r) => r["type"] == typeTag);
    return BigInt.parse(accountResource["data"]["coin"]["value"]);
  }
}