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

bool isExists = await aptosClient.accountExist(sender.address);
if (!isExists) {
  final faucetClient = FaucetClient(Constants.faucetDevAPI);
  await faucetClient.fundAccount(sender.address, "10000");
}

final coinClient = CoinClient(aptosClient);
final balance = await coinClient.checkBalance(sender.address);
print(balance);
```
