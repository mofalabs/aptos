
import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_account.dart';
import 'package:aptos/coin_client.dart';
import 'package:aptos/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('check address balance', () async {
    final client = CoinClient.fromEndpoint(Constants.testnetAPI);
    final result = await client.checkBalance("0xf1d8bc4aab7462c572a7b96ecedfcc29fcf5df2e096945eb3dd7299316f01327");
    expect(result > BigInt.zero, true);
  });

  test('transfer aptos coin', () async {
    final from = AptosAccount(HexString("0xf244795a0d9524afc41489cb73b8e337a929fccec6465b9df7585063e6732560").toUint8Array());
    const to = "0x9d36a1531f1ac2fc0e9d0a78105357c38e55f1a97a504d98b547f2f62fbbe3c6";
    
    final client = CoinClient.fromEndpoint(Constants.testnetAPI);
    final txHash = await client.transfer(from, to, "1000");
    expect(txHash.isNotEmpty, true);
  });

}