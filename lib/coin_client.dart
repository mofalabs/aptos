
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
    BigInt amount,{
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp,
    String? coinType
  }) async {
    coinType ??= AptosClient.APTOS_COIN;

    final config = ABIBuilderConfig(
      sender: from.address,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp
    );
    final builder = TransactionBuilderRemoteABI(aptosClient, config);
    final rawTxn = await builder.build(
      "0x1::coin::transfer",
      ["0x1::aptos_coin::AptosCoin"],
      [to, amount],
    );

    final bcsTxn = AptosClient.generateBCSTransaction(from, rawTxn);
    final resp = await aptosClient.submitSignedBCSTransaction(bcsTxn);
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