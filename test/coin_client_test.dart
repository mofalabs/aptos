
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

}