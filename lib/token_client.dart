import 'dart:convert';
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
import 'package:aptos/utils/property_map_serde.dart';

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
    {BigInt? maxAmount,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::create_collection_script",
      [],
      [name, description, uri, maxAmount ?? MAX_U64_BIG_INT, [false, false, false]],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
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
    {BigInt? max,
    String? royaltyPayeeAddress,
    int? royaltyPointsDenominator,
    int? royaltyPointsNumerator,
    List<String>? propertyKeys,
    List<String>? propertyValues,
    List<String>? propertyTypes,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) async {
    max ??= MAX_U64_BIG_INT;
    royaltyPayeeAddress ??= account.address;
    royaltyPointsDenominator ??= 0;
    royaltyPointsNumerator ??= 0;
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
        getPropertyValueRaw(propertyValues, propertyTypes),
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

  /// Creates a new NFT within the specified account and
  /// return the hash of the transaction submitted to the API.
  Future<String> createTokenWithMutabilityConfig(
    AptosAccount account,
    String collectionName,
    String name,
    String description,
    int supply,
    String uri,
    {BigInt? max,
    String? royaltyPayeeAddress,
    int? royaltyPointsDenominator,
    int? royaltyPointsNumerator,
    List<String>? propertyKeys,
    List<Uint8List>? propertyValues,
    List<String>? propertyTypes,
    List<bool>? mutabilityConfig,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp}
  ) {
    max ??= MAX_U64_BIG_INT;
    royaltyPayeeAddress ??= account.address;
    royaltyPointsDenominator ??= 0;
    royaltyPointsNumerator ??= 0;
    propertyKeys ??= [];
    propertyValues ??= [];
    propertyTypes ??= [];
    mutabilityConfig ??= [false, false, false, false, false];

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
        mutabilityConfig,
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

  /// User opt-in or out direct transfer through a boolean flag,
  /// return the hash of the transaction submitted to the API.
  Future<String> optInTokenTransfer(
    AptosAccount sender, 
    bool optIn, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) {
    final payload = transactionBuilder.buildTransactionPayload("0x3::token::opt_in_direct_transfer", [], [optIn]);
    return aptosClient.generateSignSubmitTransaction(
      sender, 
      payload, 
      maxGasAmount: maxGasAmount, 
      gasUnitPrice: gasUnitPrice, 
      expireTimestamp: expireTimestamp
    );
  }

  /// Directly transfer token from sender to a receiver.
  /// The receiver should have opted in to direct transfer.
  Future<String> transferWithOptIn(
    AptosAccount sender,
    String creator,
    String collectionName,
    String tokenName,
    BigInt propertyVersion,
    String receiver,
    BigInt amount, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) {
    // compile script to invoke public transfer function
    final payload = TransactionPayloadScript(
      Script(
        HexString(TOKEN_TRANSFER_OPT_IN).toUint8Array(),
        [],
        [
          TransactionArgumentAddress(AccountAddress.fromHex(creator)),
          TransactionArgumentU8Vector(Uint8List.fromList(utf8.encode(collectionName))),
          TransactionArgumentU8Vector(Uint8List.fromList(utf8.encode(tokenName))),
          TransactionArgumentU64(propertyVersion),
          TransactionArgumentAddress(AccountAddress.fromHex(receiver)),
          TransactionArgumentU64(amount),
        ],
      ),
    );

    return aptosClient.generateSignSubmitTransaction(
      sender, 
      payload, 
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// BurnToken by Creator
  Future<String> burnByCreator(
    AptosAccount creator,
    String ownerAddress,
    String collection,
    String name,
    BigInt propertyVersion,
    BigInt amount, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::burn_by_creator",
      [],
      [ownerAddress, collection, name, propertyVersion, amount],
    );

    return aptosClient.generateSignSubmitTransaction(
      creator,
      payload,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// BurnToken by Owner
  Future<String> burnByOwner(
    AptosAccount owner,
    String creatorAddress,
    String collection,
    String name,
    BigInt propertyVersion,
    BigInt amount, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::burn",
      [],
      [creatorAddress, collection, name, propertyVersion, amount],
    );

    return aptosClient.generateSignSubmitTransaction(
      owner, 
      payload, 
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
  }

  /// [account] creator mutates the properties of the tokens own by [tokenOwner]
  Future<String> mutateTokenProperties(
    AptosAccount account,
    String tokenOwner,
    String creator,
    String collectionName,
    String tokenName,
    BigInt propertyVersion,
    BigInt amount,
    List<String> keys,
    List<Uint8List> values,
    List<String> types, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) {
    final payload = transactionBuilder.buildTransactionPayload(
      "0x3::token::mutate_token_properties",
      [],
      [tokenOwner, creator, collectionName, tokenName, propertyVersion, amount, keys, values, types],
    );

    return aptosClient.generateSignSubmitTransaction(
      account, 
      payload, 
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expireTimestamp: expireTimestamp
    );
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
  ///     PropertyMap defaultProperties;
  ///     List<bool> mutabilityConfig;
  ///   }
  /// ```
  Future<TokenData> getTokenData(
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

    final rawTokenData = await aptosClient.queryTableItem(handle, tableItem);
    return TokenData(
      rawTokenData["collection"] ?? collectionName,
      rawTokenData["description"],
      rawTokenData["name"],
      int.tryParse(rawTokenData["maximum"]),
      int.parse(rawTokenData["supply"]),
      rawTokenData["uri"],
      rawTokenData["default_properties"],
      rawTokenData["mutability_config"],
    );
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
        return Token(tokenId, "0", PropertyMap());
      }
      rethrow;
    }
  }
}
