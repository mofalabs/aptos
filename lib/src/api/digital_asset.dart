import '../account/account.dart' as signer;
import '../core/account_address.dart';
import '../internal/digital_asset.dart' as internal_digital_asset;
import '../internal/digital_asset.dart' show PropertyType, PropertyValue;
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/indexer.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

export '../internal/digital_asset.dart' show PropertyType, PropertyValue;

/// A class for managing digital assets (Token v2), providing methods for
/// querying, transferring, and mutating digital assets and collections.
class DigitalAsset {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `DigitalAsset` namespace with the
  /// specified configuration.
  const DigitalAsset(this.config);

  /// Queries data of a specific collection by the collection creator address
  /// and the collection name, or by a custom where-condition via [options].
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional token standard, pagination and where-condition
  /// parameters.
  Future<CollectionData> getCollectionData({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getCollectionData(
      aptosConfig: config,
      options: options,
    );
  }

  /// Queries data of a specific collection by the collection creator address
  /// and the collection name.
  Future<CollectionData> getCollectionDataByCreatorAddressAndCollectionName({
    required AccountAddressInput creatorAddress,
    required String collectionName,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset
        .getCollectionDataByCreatorAddressAndCollectionName(
      aptosConfig: config,
      creatorAddress: creatorAddress,
      collectionName: collectionName,
      options: options,
    );
  }

  /// Queries data of a specific collection by the collection creator
  /// address.
  Future<CollectionData> getCollectionDataByCreatorAddress({
    required AccountAddressInput creatorAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getCollectionDataByCreatorAddress(
      aptosConfig: config,
      creatorAddress: creatorAddress,
      options: options,
    );
  }

  /// Queries data of a specific collection by the collection ID (the
  /// collection object address).
  Future<CollectionData> getCollectionDataByCollectionId({
    required AccountAddressInput collectionId,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getCollectionDataByCollectionId(
      aptosConfig: config,
      collectionId: collectionId,
      options: options,
    );
  }

  /// Queries a collection's ID (the collection object address).
  Future<String> getCollectionId({
    required AccountAddressInput creatorAddress,
    required String collectionName,
    AnyNumber? minimumLedgerVersion,
    TokenStandard? tokenStandard,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getCollectionId(
      aptosConfig: config,
      creatorAddress: creatorAddress,
      collectionName: collectionName,
      tokenStandard: tokenStandard,
    );
  }

  /// Retrieves digital asset data for the specified digital asset address.
  Future<TokenData> getDigitalAssetData({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getDigitalAssetData(
      aptosConfig: config,
      digitalAssetAddress: digitalAssetAddress,
    );
  }

  /// Retrieves the current ownership data of a specified digital asset.
  Future<TokenOwnership> getCurrentDigitalAssetOwnership({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getCurrentDigitalAssetOwnership(
      aptosConfig: config,
      digitalAssetAddress: digitalAssetAddress,
    );
  }

  /// Retrieves the digital assets owned by a specified address.
  Future<List<TokenOwnership>> getOwnedDigitalAssets({
    required AccountAddressInput ownerAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getOwnedDigitalAssets(
      aptosConfig: config,
      ownerAddress: ownerAddress,
      options: options,
    );
  }

  /// Retrieves the activity data for a specified digital asset.
  Future<List<TokenActivity>> getDigitalAssetActivity({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_digital_asset.getDigitalAssetActivity(
      aptosConfig: config,
      digitalAssetAddress: digitalAssetAddress,
      options: options,
    );
  }

  /// Creates a new collection within the specified account.
  ///
  /// The optional named parameters configure the collection's supply, royalty
  /// and mutability settings.
  Future<SimpleTransaction> createCollectionTransaction({
    required signer.Account creator,
    required String description,
    required String name,
    required String uri,
    AnyNumber? maxSupply,
    bool? mutableDescription,
    bool? mutableRoyalty,
    bool? mutableURI,
    bool? mutableTokenDescription,
    bool? mutableTokenName,
    bool? mutableTokenProperties,
    bool? mutableTokenURI,
    bool? tokensBurnableByCreator,
    bool? tokensFreezableByCreator,
    int? royaltyNumerator,
    int? royaltyDenominator,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.createCollectionTransaction(
      aptosConfig: config,
      creator: creator,
      description: description,
      name: name,
      uri: uri,
      maxSupply: maxSupply,
      mutableDescription: mutableDescription,
      mutableRoyalty: mutableRoyalty,
      mutableURI: mutableURI,
      mutableTokenDescription: mutableTokenDescription,
      mutableTokenName: mutableTokenName,
      mutableTokenProperties: mutableTokenProperties,
      mutableTokenURI: mutableTokenURI,
      tokensBurnableByCreator: tokensBurnableByCreator,
      tokensFreezableByCreator: tokensFreezableByCreator,
      royaltyNumerator: royaltyNumerator,
      royaltyDenominator: royaltyDenominator,
      options: options,
    );
  }

  /// Creates a transaction to mint a digital asset into an existing
  /// collection.
  Future<SimpleTransaction> mintDigitalAssetTransaction({
    required signer.Account creator,
    required String collection,
    required String description,
    required String name,
    required String uri,
    List<String>? propertyKeys,
    List<PropertyType>? propertyTypes,
    List<PropertyValue>? propertyValues,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.mintDigitalAssetTransaction(
      aptosConfig: config,
      creator: creator,
      collection: collection,
      description: description,
      name: name,
      uri: uri,
      propertyKeys: propertyKeys,
      propertyTypes: propertyTypes,
      propertyValues: propertyValues,
      options: options,
    );
  }

  /// Transfers ownership of a non-fungible digital asset.
  Future<SimpleTransaction> transferDigitalAssetTransaction({
    required signer.Account sender,
    required AccountAddressInput digitalAssetAddress,
    required AccountAddressInput recipient,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.transferDigitalAssetTransaction(
      aptosConfig: config,
      sender: sender,
      digitalAssetAddress: digitalAssetAddress,
      recipient: recipient,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Mints a soul-bound digital asset into a recipient's account.
  Future<SimpleTransaction> mintSoulBoundTransaction({
    required signer.Account account,
    required String collection,
    required String description,
    required String name,
    required String uri,
    required AccountAddressInput recipient,
    List<String>? propertyKeys,
    List<PropertyType>? propertyTypes,
    List<PropertyValue>? propertyValues,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.mintSoulBoundTransaction(
      aptosConfig: config,
      account: account,
      collection: collection,
      description: description,
      name: name,
      uri: uri,
      recipient: recipient,
      propertyKeys: propertyKeys,
      propertyTypes: propertyTypes,
      propertyValues: propertyValues,
      options: options,
    );
  }

  /// Burns a digital asset by its creator.
  Future<SimpleTransaction> burnDigitalAssetTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.burnDigitalAssetTransaction(
      aptosConfig: config,
      creator: creator,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Freezes the ability to transfer a specified digital asset.
  Future<SimpleTransaction> freezeDigitalAssetTransferTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.freezeDigitalAssetTransferTransaction(
      aptosConfig: config,
      creator: creator,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Unfreezes the ability to transfer a specified digital asset.
  Future<SimpleTransaction> unfreezeDigitalAssetTransferTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.unfreezeDigitalAssetTransferTransaction(
      aptosConfig: config,
      creator: creator,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Sets the digital asset description.
  Future<SimpleTransaction> setDigitalAssetDescriptionTransaction({
    required signer.Account creator,
    required String description,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.setDigitalAssetDescriptionTransaction(
      aptosConfig: config,
      creator: creator,
      description: description,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Sets the digital asset name.
  Future<SimpleTransaction> setDigitalAssetNameTransaction({
    required signer.Account creator,
    required String name,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.setDigitalAssetNameTransaction(
      aptosConfig: config,
      creator: creator,
      name: name,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Sets the digital asset URI.
  Future<SimpleTransaction> setDigitalAssetURITransaction({
    required signer.Account creator,
    required String uri,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.setDigitalAssetURITransaction(
      aptosConfig: config,
      creator: creator,
      uri: uri,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Adds a digital asset property.
  Future<SimpleTransaction> addDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.addDigitalAssetPropertyTransaction(
      aptosConfig: config,
      creator: creator,
      propertyKey: propertyKey,
      propertyType: propertyType,
      propertyValue: propertyValue,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Removes a digital asset property.
  Future<SimpleTransaction> removeDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.removeDigitalAssetPropertyTransaction(
      aptosConfig: config,
      creator: creator,
      propertyKey: propertyKey,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Updates a digital asset property.
  Future<SimpleTransaction> updateDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.updateDigitalAssetPropertyTransaction(
      aptosConfig: config,
      creator: creator,
      propertyKey: propertyKey,
      propertyType: propertyType,
      propertyValue: propertyValue,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Adds a typed digital asset property.
  Future<SimpleTransaction> addDigitalAssetTypedPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.addDigitalAssetTypedPropertyTransaction(
      aptosConfig: config,
      creator: creator,
      propertyKey: propertyKey,
      propertyType: propertyType,
      propertyValue: propertyValue,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }

  /// Updates a typed digital asset property.
  Future<SimpleTransaction> updateDigitalAssetTypedPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_digital_asset.updateDigitalAssetTypedPropertyTransaction(
      aptosConfig: config,
      creator: creator,
      propertyKey: propertyKey,
      propertyType: propertyType,
      propertyValue: propertyValue,
      digitalAssetAddress: digitalAssetAddress,
      digitalAssetType: digitalAssetType,
      options: options,
    );
  }
}
