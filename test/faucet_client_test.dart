
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('faucet fund account', () async {
    final client = FaucetClient(Constants.faucetDevAPI);
    final result = await client.fundAccount(
      '0xf1d8bc4aab7462c572a7b96ecedfcc29fcf5df2e096945eb3dd7299316f01327', 
      "1000000"
    );
    expect(result.isNotEmpty, true);
  });

}