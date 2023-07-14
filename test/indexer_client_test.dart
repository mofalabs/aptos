
import 'package:aptos/constants.dart';
import 'package:aptos/indexer_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  final client = IndexerClient(Constants.mainnetIndexer);
  final address = "0xde55351c8af908cd8f742701f637779c83951e2b34f68cc6e936bd662c666753";

  test('test getIndexerLedgerInfo', () async {
    final result = await client.getIndexerLedgerInfo();
    expect(result["ledger_infos"][0]["chain_id"], 1);
  });

  test('test getAccountNFTs', () async {
    final result = await client.getAccountNFTs(ownerAddress: address);
    print(result);
  });

  test('test getTokenActivities', () async {
    final result = await client.getTokenActivities(idHash: "");
    print(result);
  });

  test('test getAccountCoinsData', () async {
    final coinBalances = await client.getAccountCoinsData(ownerAddress: address);
    coinBalances.forEach((element) { 
      debugPrint(element.toString());
    });
  });

  test('test getAccountTokensCount', () async {
    final result = await client.getAccountTokensCount(address);
    print(result);
  });

  test('test getAccountTransactionsCount', () async {
    final result = await client.getAccountTransactionsCount(address);
    print(result);
  });

  test('test getDelegatedStakingActivities', () async {
    final result = await client.getDelegatedStakingActivities(delegatorAddress: "", poolAddress: "");
    print(result);
  });

  test('test getTokenActivitiesCount', () async {
    final result = await client.getTokenActivitiesCount("");
    print(result);
  });

  test('test getAccountCoinActivity', () async {
    final result = await client.getAccountCoinActivity(accountAddress: address);
    result.forEach((element) { 
      debugPrint(element.toJson().toString());
    });
  });

  test('test getTokenData', () async {
    final accountNFTs = await client.getAccountNFTs(ownerAddress: address);
    final tokenId = accountNFTs.first.currentTokenData.tokenDataIdHash;
    final result = await client.getTokenData(tokenId);
    print(result);
  });

  test('test getCurrentTokenPendingClaims', () async {
    final data = await client.getCurrentTokenPendingClaims(ownerAddress: address);
    print(data);
  });
}