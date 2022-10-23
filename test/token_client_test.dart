
import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:aptos/token_client.dart';
import 'package:aptos/token_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    "full tutorial nft token flow",
    () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucetClient = FaucetClient(Constants.faucetDevAPI, client: client);
      final tokenClient = TokenClient(client);

      final alice = AptosAccount();
      final bob = AptosAccount();

      // Fund both Alice's and Bob's Account
      await faucetClient.fundAccount(alice.address, "10000000");
      await faucetClient.fundAccount(bob.address, "10000000");

      const collectionName = "AliceCollection";
      const tokenName = "Alice Token";

      // Create collection and token on Alice's account
      await Future.delayed(const Duration(seconds: 2));
      await client.waitForTransaction(
        await tokenClient.createCollection(alice, collectionName, "Alice's simple collection", "https://aptos.dev"),
        checkSuccess: true,
      );

      await client.waitForTransaction(
        await tokenClient.createToken(
          alice,
          collectionName,
          tokenName,
          "Alice's simple token",
          1,
          "https://aptos.dev/img/nyan.jpeg",
          BigInt.from(1000),
          royaltyPayeeAddress: alice.address,
          royaltyPointsDenominator: 0,
          royaltyPointsNumerator: 0,
          propertyKeys: ["key"],
          propertyValues: ["2"],
          propertyTypes: ["int"],
        ),
        checkSuccess: true,
      );

      final tokenDataId = TokenDataId(alice.address, collectionName, tokenName);
      final tokenId = TokenId(tokenDataId, "0");

      // Transfer Token from Alice's Account to Bob's Account
      await tokenClient.getCollectionData(alice.address, collectionName);
      var aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "1", true);
      final tokenData = await tokenClient.getTokenData(alice.address, collectionName, tokenName);
      expect(tokenData["name"] == tokenName, true);

      await client.waitForTransaction(
        await tokenClient.offerToken(alice, bob.address, alice.address, collectionName, tokenName, 1),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "0", true);

      await client.waitForTransaction(
        await tokenClient.cancelTokenOffer(alice, bob.address, alice.address, collectionName, tokenName),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "1", true);

      await Future.delayed(const Duration(seconds: 2));
      await client.waitForTransaction(
        await tokenClient.offerToken(alice, bob.address, alice.address, collectionName, tokenName, 1),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "0", true);

      await Future.delayed(const Duration(seconds: 2));
      await client.waitForTransaction(
        await tokenClient.claimToken(bob, alice.address, alice.address, collectionName, tokenName),
        checkSuccess: true,
      );

      await Future.delayed(const Duration(seconds: 2));
      final bobBalance = await tokenClient.getTokenForAccount(bob.address, tokenId);
      expect(bobBalance.amount == "1", true);
    },

    timeout: const Timeout(Duration(minutes: 2))
  );

}