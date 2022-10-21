Aptos Dart SDK
-

Requirements
-

- sdk: ">=2.15.1 <3.0.0"
- flutter: ">=1.17.0"

Usage
-

```dart
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
}

final coinClient = CoinClient(aptosClient);

// Check account balance
final balance = await coinClient.checkBalance(sender.address);
if (balance != amount) {
  throw Exception("Fund ${sender.address} failed");
}

// Transfer Aptos Coin
final txHash = await coinClient.transfer(sender, receiver.address, "10000");

```
