
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

  /// Generate, sign, and submit a transaction to the Aptos blockchain API to
  /// transfer coins from one account to another. By default it transfers
  /// 0x1::aptos_coin::AptosCoin, but you can specify a different coin type
  /// with the `coinType` argument.
  ///
  /// You may set `createReceiverIfMissing` to true if you want to create the
  /// receiver account if it does not exist on chain yet. If you do not set
  /// this to true, the transaction will fail if the receiver account does not
  /// exist on-chain.
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
      [coinType],
      [to, amount],
    );

    final bcsTxn = AptosClient.generateBCSTransaction(from, rawTxn);
    final resp = await aptosClient.submitSignedBCSTransaction(bcsTxn);
    return resp["hash"];
  }

  Future<BigInt> checkBalance(String address, { String? coinType }) async {
    coinType ??= AptosClient.APTOS_COIN;
    String typeTag = "0x1::coin::CoinStore<$coinType>";
    final accountResource = await aptosClient.getAccountResource(address, typeTag);
    return BigInt.parse(accountResource["data"]["coin"]["value"]);
  }
}