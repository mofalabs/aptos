
import 'package:aptos/aptos.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('faucet fund account', () async {
    final client = FaucetClient.fromEndpoint(
      Constants.faucetTestAPI, 
      Constants.testnetAPI,
      enableDebugLog: true
    );
    final result = await client.fundAccount(
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa', 
      "100000000"
    );
    expect(result.isNotEmpty, true);
  });

  test('faucet fund account from client', () async {
    final aptosClient = AptosClient(Constants.testnetAPI, enableDebugLog: true);
    final client = FaucetClient.fromClient(Constants.faucetTestAPI, aptosClient);
    final result = await client.fundAccount(
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa', 
      "100000000"
    );
    expect(result.isNotEmpty, true);
  });

  test('faucet fund account from network', () async {
    final client = FaucetClient.fromNetwork(Network.testnet, enableDebugLog: true);
    final result = await client.fundAccount(
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa', 
      "100000000"
    );
    expect(result.isNotEmpty, true);
  });

}