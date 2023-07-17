
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('faucet fund account', () async {
    final client = FaucetClient.fromEndpoint(Constants.faucetTestAPI, Constants.testnetAPI);
    final result = await client.fundAccount(
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa', 
      "100000000"
    );
    expect(result.isNotEmpty, true);
  });

}