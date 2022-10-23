import 'dart:typed_data';

import 'package:aptos/abis.dart';
import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/authenticator.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/bcs/consts.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/models/table_item.dart';
import 'package:aptos/token_types.dart';
import 'package:aptos/transaction_builder/builder.dart';

/// Class for creating, minting and managing minting NFT collections and tokens.
class TokenClient {
  late final AptosClient aptosClient;
  late final TransactionBuilderABI transactionBuilder;

  TokenClient(AptosClient client) {
    aptosClient = client;
    transactionBuilder = TransactionBuilderABI(TOKEN_ABIS.map((abi) => HexString(abi).toUint8Array()).toList());
  }

  /// Creates a new NFT collection within the specified account and
  /// return the hash of the transaction submitted to the API.
  Future<String> createCollection(
    AptosAccount account,
    String name,
    String description,
    String uri,
    {BigInt? maxAmount}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::create_collection_script",
      [],
      [name, description, uri, maxAmount ?? MAX_U64_BIG_INT, [false, false, false]],
    );

    return aptosClient.generateSignSubmitTransaction(account, payload);
  }

  /// Creates a new NFT within the specified account and
  /// return the hash of the transaction submitted to the API.
  Future<String> createToken(
    AptosAccount account,
    String collectionName,
    String name,
    String description,
    int supply,
    String uri,
    BigInt max,
    {String? royaltyPayeeAddress,
    int? royaltyPointsDenominator,
    int? royaltyPointsNumerator,
    List<String>? propertyKeys,
    List<String>? propertyValues,
    List<String>? propertyTypes,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    royaltyPayeeAddress ??= account.address;
    royaltyPointsDenominator ??= 0;
    propertyKeys ??= [];
    propertyValues ??= [];
    propertyTypes ??= [];
    
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::create_token_script",
      [],
      [
        collectionName,
        name,
        description,
        supply,
        max,
        uri,
        royaltyPayeeAddress,
        royaltyPointsDenominator,
        royaltyPointsNumerator,
        [false, false, false, false, false],
        propertyKeys,
        propertyValues,
        propertyTypes,
      ],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// Transfers specified amount of tokens from account to receiver and
  /// return the hash of the transaction submitted to the API.
  Future<String> offerToken(
    AptosAccount account,
    String receiver,
    String creator,
    String collectionName,
    String name,
    int amount,
    {int? propertyVersion,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token_transfers::offer_script",
      [],
      [receiver, creator, collectionName, name, propertyVersion ?? 0, amount],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// Claims a token on specified account and return
  /// the hash of the transaction submitted to the API.
  Future<String> claimToken(
    AptosAccount account,
    String sender,
    String creator,
    String collectionName,
    String name,
    {int? propertyVersion,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token_transfers::claim_script",
      [],
      [sender, creator, collectionName, name, propertyVersion ?? 0],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// Removes a token from pending claims list and return
  /// the hash of the transaction submitted to the API.
  Future<String> cancelTokenOffer(
    AptosAccount account,
    String receiver,
    String creator,
    String collectionName,
    String name,
    {int? propertyVersion,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token_transfers::cancel_offer_script",
      [],
      [receiver, creator, collectionName, name, propertyVersion ?? 0],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// Directly transfer the specified amount of tokens from account to receiver
  /// using a single multi signature transaction. 
  /// And return the hash of the transaction submitted to the API.
  Future<String> directTransferToken(
    AptosAccount sender,
    AptosAccount receiver,
    String creator,
    String collectionName,
    String name,
    int amount,
    {int? propertyVersion,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::direct_transfer_script",
      [],
      [creator, collectionName, name, propertyVersion, amount],
    );

    final rawTxn = await aptosClient.generateRawTransaction(
      sender.address, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
    final multiAgentTxn = MultiAgentRawTransaction(rawTxn, [
      AccountAddress.fromHex(receiver.address),
    ]);

    final senderSignature = Ed25519Signature(
      sender.signBuffer(TransactionBuilder.getSigningMessage(multiAgentTxn)).toUint8Array(),
    );

    final senderAuthenticator = AccountAuthenticatorEd25519(
      Ed25519PublicKey(Uint8List.fromList(sender.signingKey.publicKey.bytes)),
      senderSignature,
    );

    final receiverSignature = Ed25519Signature(
      receiver.signBuffer(TransactionBuilder.getSigningMessage(multiAgentTxn)).toUint8Array(),
    );

    final receiverAuthenticator = AccountAuthenticatorEd25519(
      Ed25519PublicKey(Uint8List.fromList(receiver.signingKey.publicKey.bytes)),
      receiverSignature,
    );

    final multiAgentAuthenticator = TransactionAuthenticatorMultiAgent(
      senderAuthenticator,
      [AccountAddress.fromHex(receiver.address)], // Secondary signer addresses
      [receiverAuthenticator], // Secondary signer authenticators
    );

    final bcsTxn = bcsToBytes(SignedTransaction(rawTxn, multiAgentAuthenticator));

    final transactionRes = await aptosClient.submitSignedBCSTransaction(bcsTxn);

    return transactionRes["hash"];
  }

  /// Queries collection data.
  /// 
  /// Collection data in below format
  /// ```dart
  ///  Collection {
  ///    String description;
  ///    String name;
  ///    String uri;
  ///    int count;
  ///    int maximum;
  ///  }
  /// ```
  Future<dynamic> getCollectionData(String creator, String collectionName) async {
    final resources = await aptosClient.getAccountResources(creator);
    final accountResource = (resources as List).firstWhere((r) => r["type"] == "0x3::token::Collections");
    final handle = accountResource["data"]["collection_data"]["handle"];
    final tableItem = TableItem("0x1::string::String", "0x3::token::CollectionData", collectionName);
    final collectionTable = await aptosClient.queryTableItem(handle, tableItem);
    return collectionTable;
  }

  /// Queries token data from collection.
  ///
  /// Token data in below format
  /// ```dart
  /// TokenData {
  ///     String collection;
  ///     String description;
  ///     String name;
  ///     int maximum;
  ///     int supply;
  ///     int uri;
  ///   }
  /// ```
  Future<dynamic> getTokenData(
    String creator,
    String collectionName,
    String tokenName,
  ) async {
    final collection = await aptosClient.getAccountResource(
      creator,
      "0x3::token::Collections",
    );
    final handle = collection["data"]["token_data"]["handle"];
    final tokenDataId = {
      "creator": creator,
      "collection": collectionName,
      "name": tokenName,
    };

    final tableItem = TableItem("0x3::token::TokenDataId", "0x3::token::TokenData", tokenDataId);

    return aptosClient.queryTableItem(handle, tableItem);
  }

  /// Queries token balance for the token creator.
  Future<Token> getToken(
    String creator,
    String collectionName,
    String tokenName,
    {int? propertyVersion = 0}
  ) async {
    final tokenDataId = TokenDataId(creator, collectionName, tokenName);
    return await getTokenForAccount(creator, TokenId(tokenDataId, propertyVersion!.toString()));
  }

  /// Queries token balance for a token account.
  Future<Token> getTokenForAccount(String account, TokenId tokenId) async {
    final tokenStore = await aptosClient.getAccountResource(
      account,
      "0x3::token::TokenStore",
    );
    final handle = tokenStore["data"]["tokens"]["handle"];

    final tableItem = TableItem("0x3::token::TokenId", "0x3::token::Token", tokenId);

    try {
      final resp = await aptosClient.queryTableItem(handle, tableItem);
      return Token.fromJson(resp);
    } catch (e) {
      dynamic err = e;
      if (err.response.statusCode == 404) {
        return Token(tokenId, "0");
      }
      rethrow;
    }
  }
}
