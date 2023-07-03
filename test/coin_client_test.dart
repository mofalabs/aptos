
import 'package:aptos/aptos.dart';
import 'package:aptos/coin_client.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('check address balance', () async {
    final client = CoinClient.fromEndpoint(Constants.testnetAPI);
    final result = await client.checkBalance("0xf1d8bc4aab7462c572a7b96ecedfcc29fcf5df2e096945eb3dd7299316f01327");
    expect(result > BigInt.zero, true);
  });

  test('transfer aptos coin', () async {
    final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
    final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client);
    final coinClient = CoinClient(client);

    final privateArray = HexString("9e2dc8c01845a5b68d2abfb8e08cfb627325a9741b0041818076ce0910fce82b").toUint8Array();
    final account1 =  AptosAccount(privateArray);
    final account2 = AptosAccount();

    await faucetClient.fundAccount(account2.address, "0");

    final txHash = await coinClient.transfer(account1, account2.address, BigInt.from(333));
    expect(txHash.isNotEmpty, true);
  });

  test('transfer aptos coin with create account', () async {
    final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
    final coinClient = CoinClient(client);

    final privateArray = HexString("9e2dc8c01845a5b68d2abfb8e08cfb627325a9741b0041818076ce0910fce82b").toUint8Array();
    final account1 =  AptosAccount(privateArray);
    final account2 = AptosAccount();

    final txHash = await coinClient.transfer(account1, account2.address, BigInt.from(333), createReceiverIfMissing: true);
    expect(txHash.isNotEmpty, true);
  });

  test('register coin', () async {
    final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
    // final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client);
    final coinClient = CoinClient(client);

    final privateArray = HexString("9e2dc8c01845a5b68d2abfb8e08cfb627325a9741b0041818076ce0910fce82b").toUint8Array();
    final account1 =  AptosAccount(privateArray);

    const coinType = "0x5e156f1207d0ebfa19a9eeff00d62a282278fb8719f4fab3a586a0a2c0fffbea::coin::T";
    const resourceType = "0x1::coin::CoinStore<$coinType>";

    final txn = await coinClient.register(account1, coinType);
    print(txn);

    await Future.delayed(const Duration(seconds: 3));

    final resp = await client.getAccountResource(account1.address, resourceType);
    print(resp);

  });

  test('test all', () async {
    // Generate Aptos Account
    final mnemonics = AptosAccount.generateMnemonic();
    final sender = AptosAccount.generateAccount(mnemonics);
    final receiver = AptosAccount();

    // AptosClient connect with Aptos Node
    final aptosClient = AptosClient(Constants.devnetAPI, enableDebugLog: true);

    // Check and fund account
    final amount = BigInt.from(10000000);
    bool isExists = await aptosClient.accountExist(sender.address);
    if (!isExists) {
      final faucetClient = FaucetClient(Constants.faucetDevAPI);
      await faucetClient.fundAccount(sender.address, amount.toString());
      await faucetClient.fundAccount(receiver.address, "0");
      await Future.delayed(const Duration(seconds: 2));
    }

    final coinClient = CoinClient(aptosClient);

    // Check account balance
    final balance = await coinClient.checkBalance(sender.address);
    print(balance);

    // Transfer Aptos Coin
    final txHash = await coinClient.transfer(sender, receiver.address, BigInt.from(10000));
    print(txHash);
  });

}