
import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/faucet_client.dart';
import 'package:aptos/token_client.dart';
import 'package:aptos/aptos_types/token_types.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    "full tutorial nft token flow",
    () async {
      final client = AptosClient(Constants.devnetAPI, enableDebugLog: true);
      final faucetClient = FaucetClient.fromClient(Constants.faucetDevAPI, client);
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
        await tokenClient.createCollection(
          alice, 
          collectionName, 
          "Alice's simple collection", 
          "https://aptos.dev"
        ),
        checkSuccess: true,
      );

      await client.waitForTransaction(
        await tokenClient.createTokenWithMutabilityConfig(
          alice,
          collectionName,
          tokenName,
          "Alice's simple token",
          2,
          "https://aptos.dev/img/nyan.jpeg",
          max: BigInt.from(1000),
          royaltyPayeeAddress: alice.address,
          royaltyPointsDenominator: 1,
          royaltyPointsNumerator: 0,
          propertyKeys: ["TOKEN_BURNABLE_BY_OWNER"],
          propertyValues: [bcsSerializeBool(true)],
          propertyTypes: ["bool"],
          mutabilityConfig: [false, false, false, false, true],
        ),
        checkSuccess: true,
      );

      final tokenDataId = TokenDataId(alice.address, collectionName, tokenName);
      final tokenId = TokenId(tokenDataId, "0");

      // Transfer Token from Alice's Account to Bob's Account
      await tokenClient.getCollectionData(alice.address, collectionName);
      var aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "2", true);
      final tokenData = await tokenClient.getTokenData(alice.address, collectionName, tokenName);
      expect(tokenData.name == tokenName, true);

      await client.waitForTransaction(
        await tokenClient.offerToken(alice, bob.address, alice.address, collectionName, tokenName, 1),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "1", true);

      await client.waitForTransaction(
        await tokenClient.cancelTokenOffer(alice, bob.address, alice.address, collectionName, tokenName),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "2", true);

      await Future.delayed(const Duration(seconds: 2));
      await client.waitForTransaction(
        await tokenClient.offerToken(alice, bob.address, alice.address, collectionName, tokenName, 1),
        checkSuccess: true,
      );
      aliceBalance = await tokenClient.getTokenForAccount(alice.address, tokenId);
      expect(aliceBalance.amount == "1", true);

      await Future.delayed(const Duration(seconds: 2));
      await client.waitForTransaction(
        await tokenClient.claimToken(bob, alice.address, alice.address, collectionName, tokenName),
        checkSuccess: true,
      );

      await Future.delayed(const Duration(seconds: 2));
      final bobBalance = await tokenClient.getTokenForAccount(bob.address, tokenId);
      expect(bobBalance.amount == "1", true);

      // default token property is configured to be mutable and then alice can make bob burn token after token creation
      // test mutate Bob's token properties and allow owner to burn this token
      await client.waitForTransactionWithResult(
        await tokenClient.mutateTokenProperties(
          alice, 
          bob.address, 
          alice.address, 
          collectionName, 
          tokenName, 
          BigInt.zero, 
          BigInt.one, 
          ["test"], 
          [bcsSerializeBool(true)],
          ["bool"]
        )
      );

      final newTokenId = TokenId(tokenDataId, "1");
      final mutatedToken = await tokenClient.getTokenForAccount(bob.address, newTokenId);
      // expect property map deserialization works
      expect(mutatedToken.tokenProperties.data["test"]?.value, "true");
      expect(mutatedToken.tokenProperties.data["TOKEN_BURNABLE_BY_OWNER"]?.value, "true");

      // burn the token by owner
      var txnHash = await tokenClient.burnByOwner(bob, alice.address, collectionName, tokenName, BigInt.one, BigInt.one);
      await client.waitForTransactionWithResult(txnHash);
      final newbalance = await tokenClient.getTokenForAccount(bob.address, newTokenId);
      expect(newbalance.amount, "0");

      //bob opt_in directly transfer and alice transfer token to bob directly
      txnHash = await tokenClient.optInTokenTransfer(bob, true);
      await client.waitForTransactionWithResult(txnHash);

      // alice still have one token with property version 0.
      txnHash = await tokenClient.transferWithOptIn(
        alice,
        alice.address,
        collectionName,
        tokenName,
        BigInt.zero,
        bob.address,
        BigInt.one,
      );
      await client.waitForTransactionWithResult(txnHash);
      final balance = await tokenClient.getTokenForAccount(bob.address, tokenId);
      expect(balance.amount, "1");
    },

    timeout: const Timeout(Duration(minutes: 2))
  );

}