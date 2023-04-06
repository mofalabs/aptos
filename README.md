Aptos Dart SDK
-

[![Pub](https://img.shields.io/badge/pub-v0.0.3-blue)](https://pub.dev/packages/aptos)

Installation
-

```
dependencies:
  aptos: ^0.0.3
```

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
  await Future.delayed(const Duration(seconds: 2));
}

final coinClient = CoinClient(aptosClient);

// Check account balance
final balance = await coinClient.checkBalance(sender.address);
print(balance);

// Transfer Aptos Coin
final txHash = await coinClient.transfer(
  sender, 
  receiver.address, 
  BigInt.from(10000),
  createReceiverIfMissing: true);
print(txHash);
```
