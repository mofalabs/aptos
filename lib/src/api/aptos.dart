import 'dart:typed_data';

import '../account/abstract_keyless_account.dart';
import '../account/account.dart' as signer;
import '../account/ephemeral_key_pair.dart';
import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/keyless.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/single_key.dart';
import '../transactions/authenticator/account.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/ans.dart';
import '../types/api_extras.dart';
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../types/types.dart';
import '../utils/const.dart';
import 'abstraction.dart';
import 'account.dart';
import 'ans.dart';
import 'aptos_config.dart';
import 'coin.dart';
import 'digital_asset.dart';
import 'event.dart';
import 'faucet.dart';
import 'fungible_asset.dart';
import 'general.dart';
import 'keyless.dart';
import 'object.dart';
import 'staking.dart';
import 'table.dart';
import 'transaction.dart';

/// The main entry point for interacting with the Aptos APIs, providing
/// access to various functionalities organized into distinct namespaces.
///
/// ```dart
/// final config = AptosConfig(network: Network.testnet);
/// final aptos = Aptos(config);
/// final ledgerInfo = await aptos.getLedgerInfo();
/// ```
///
/// Every namespace method is also available on the `Aptos` instance directly
/// (except `transaction.build/simulate/submit/batch`) via the delegating
/// convenience methods written out below.
class Aptos {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  // Lazily-initialized sub-namespace backing fields.
  AccountApi? _account;
  AccountAbstraction? _abstraction;
  Ans? _ans;
  Coin? _coin;
  DigitalAsset? _digitalAsset;
  EventApi? _event;
  Faucet? _faucet;
  FungibleAsset? _fungibleAsset;
  General? _general;
  Keyless? _keyless;
  AptosObject? _object;
  Staking? _staking;
  Table? _table;
  Transaction? _transaction;

  /// Initializes a new instance of the Aptos client with the provided
  /// configuration settings (defaults to `AptosConfig()`, i.e. devnet).
  Aptos([AptosConfig? config]) : config = config ?? AptosConfig();

  /// The `Account` namespace (named `AccountApi` to avoid clashing with the
  /// signer `Account` class).
  AccountApi get account => _account ??= AccountApi(config);

  /// The `Coin` namespace.
  Coin get coin => _coin ??= Coin(config);

  /// The `Faucet` namespace.
  Faucet get faucet => _faucet ??= Faucet(config);

  /// The `General` namespace.
  General get general => _general ??= General(config);

  /// The `Table` namespace.
  Table get table => _table ??= Table(config);

  /// The `Transaction` namespace, including `transaction.build`,
  /// `transaction.simulate` and `transaction.submit`.
  Transaction get transaction => _transaction ??= Transaction(config);

  /// The `Keyless` namespace (pepper/prover services, keyless account
  /// derivation, federated JWK updates).
  Keyless get keyless => _keyless ??= Keyless(config);

  /// The `AccountAbstraction` namespace (AA enable/disable/query). Accessed
  /// as `aptos.abstraction`.
  AccountAbstraction get abstraction =>
      _abstraction ??= AccountAbstraction(config);

  /// The `ANS` (Aptos Name Service) namespace.
  Ans get ans => _ans ??= Ans(config);

  /// The `DigitalAsset` namespace (Token v2 collections and tokens).
  DigitalAsset get digitalAsset => _digitalAsset ??= DigitalAsset(config);

  /// The `Event` namespace (named `EventApi` to avoid clashing with the
  /// fullnode transaction `Event` type).
  EventApi get event => _event ??= EventApi(config);

  /// The `FungibleAsset` namespace.
  FungibleAsset get fungibleAsset => _fungibleAsset ??= FungibleAsset(config);

  /// The `Object` namespace (named `AptosObject` to avoid clashing with
  /// `dart:core`'s `Object`).
  AptosObject get object => _object ??= AptosObject(config);

  /// The `Staking` namespace.
  Staking get staking => _staking ??= Staking(config);

  /// If you have set a custom transaction submitter, you can use this to
  /// stop (or resume) using it.
  void setIgnoreTransactionSubmitter(bool ignore) {
    config.setIgnoreTransactionSubmitter(ignore);
  }

  // ===
  // ACCOUNT namespace convenience methods
  // ===

  /// See [AccountApi.getAccountInfo].
  Future<AccountData> getAccountInfo({
    required AccountAddressInput accountAddress,
  }) =>
      account.getAccountInfo(accountAddress: accountAddress);

  /// See [AccountApi.getAccountModules].
  Future<List<MoveModuleBytecode>> getAccountModules({
    required AccountAddressInput accountAddress,
    int? limit,
    LedgerVersionArg? options,
  }) =>
      account.getAccountModules(
        accountAddress: accountAddress,
        limit: limit,
        options: options,
      );

  /// See [AccountApi.getAccountModulesPage].
  Future<({List<MoveModuleBytecode> modules, String? cursor})>
      getAccountModulesPage({
    required AccountAddressInput accountAddress,
    CursorPaginationArgs? options,
    LedgerVersionArg? ledgerVersionArg,
  }) =>
          account.getAccountModulesPage(
            accountAddress: accountAddress,
            options: options,
            ledgerVersionArg: ledgerVersionArg,
          );

  /// See [AccountApi.getAccountModule].
  Future<MoveModuleBytecode> getAccountModule({
    required AccountAddressInput accountAddress,
    required String moduleName,
    LedgerVersionArg? options,
  }) =>
      account.getAccountModule(
        accountAddress: accountAddress,
        moduleName: moduleName,
        options: options,
      );

  /// See [AccountApi.getAccountTransactions].
  Future<List<CommittedTransactionResponse>> getAccountTransactions({
    required AccountAddressInput accountAddress,
    PaginationArgs? options,
  }) =>
      account.getAccountTransactions(
        accountAddress: accountAddress,
        options: options,
      );

  /// See [AccountApi.getAccountResources].
  Future<List<MoveResource>> getAccountResources({
    required AccountAddressInput accountAddress,
    int? limit,
    LedgerVersionArg? options,
  }) =>
      account.getAccountResources(
        accountAddress: accountAddress,
        limit: limit,
        options: options,
      );

  /// See [AccountApi.getAccountResourcesPage].
  Future<({List<MoveResource> resources, String? cursor})>
      getAccountResourcesPage({
    required AccountAddressInput accountAddress,
    CursorPaginationArgs? options,
    LedgerVersionArg? ledgerVersionArg,
  }) =>
          account.getAccountResourcesPage(
            accountAddress: accountAddress,
            options: options,
            ledgerVersionArg: ledgerVersionArg,
          );

  /// See [AccountApi.getAccountResource].
  Future<T> getAccountResource<T>({
    required AccountAddressInput accountAddress,
    required MoveStructId resourceType,
    LedgerVersionArg? options,
  }) =>
      account.getAccountResource<T>(
        accountAddress: accountAddress,
        resourceType: resourceType,
        options: options,
      );

  /// See [AccountApi.lookupOriginalAccountAddress].
  Future<AccountAddress> lookupOriginalAccountAddress({
    required AccountAddressInput authenticationKey,
    LedgerVersionArg? options,
  }) =>
      account.lookupOriginalAccountAddress(
        authenticationKey: authenticationKey,
        options: options,
      );

  /// See [AccountApi.getBalance].
  Future<int> getBalance({
    required AccountAddressInput accountAddress,
    required Object asset,
  }) =>
      account.getBalance(accountAddress: accountAddress, asset: asset);

  /// See [AccountApi.getAccountTokensCount].
  Future<int> getAccountTokensCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      account.getAccountTokensCount(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [AccountApi.getAccountOwnedTokens].
  Future<List<TokenOwnership>> getAccountOwnedTokens({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      account.getAccountOwnedTokens(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [AccountApi.getAccountOwnedTokensFromCollectionAddress].
  Future<List<TokenOwnership>> getAccountOwnedTokensFromCollectionAddress({
    required AccountAddressInput accountAddress,
    required AccountAddressInput collectionAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      account.getAccountOwnedTokensFromCollectionAddress(
        accountAddress: accountAddress,
        collectionAddress: collectionAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [AccountApi.getAccountCollectionsWithOwnedTokens].
  Future<List<AccountCollectionWithOwnedTokens>>
      getAccountCollectionsWithOwnedTokens({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
          account.getAccountCollectionsWithOwnedTokens(
            accountAddress: accountAddress,
            minimumLedgerVersion: minimumLedgerVersion,
            options: options,
          );

  /// See [AccountApi.getAccountTransactionsCount].
  Future<int> getAccountTransactionsCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      account.getAccountTransactionsCount(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [AccountApi.getAccountCoinsData].
  Future<List<CurrentFungibleAssetBalance>> getAccountCoinsData({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      account.getAccountCoinsData(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [AccountApi.getAccountCoinsCount].
  Future<int> getAccountCoinsCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      account.getAccountCoinsCount(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [AccountApi.getAccountAPTAmount].
  Future<int> getAccountAPTAmount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      account.getAccountAPTAmount(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [AccountApi.getAccountCoinAmount].
  Future<int> getAccountCoinAmount({
    required AccountAddressInput accountAddress,
    MoveStructId? coinType,
    AccountAddressInput? faMetadataAddress,
  }) =>
      account.getAccountCoinAmount(
        accountAddress: accountAddress,
        coinType: coinType,
        faMetadataAddress: faMetadataAddress,
      );

  /// See [AccountApi.getAccountOwnedObjects].
  Future<List<ObjectData>> getAccountOwnedObjects({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      account.getAccountOwnedObjects(
        accountAddress: accountAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [AccountApi.deriveAccountFromPrivateKey].
  Future<signer.Account> deriveAccountFromPrivateKey({
    required PrivateKeyInput privateKey,
    AnyNumber? minimumLedgerVersion,
    bool throwIfNoAccountFound = false,
  }) =>
      account.deriveAccountFromPrivateKey(
        privateKey: privateKey,
        minimumLedgerVersion: minimumLedgerVersion,
        throwIfNoAccountFound: throwIfNoAccountFound,
      );

  /// See [AccountApi.getAccountsForPublicKey].
  Future<List<AccountInfo>> getAccountsForPublicKey({
    required AccountPublicKey publicKey,
    AnyNumber? minimumLedgerVersion,
    bool includeUnverified = false,
    bool noMultiKey = false,
  }) =>
      account.getAccountsForPublicKey(
        publicKey: publicKey,
        minimumLedgerVersion: minimumLedgerVersion,
        includeUnverified: includeUnverified,
        noMultiKey: noMultiKey,
      );

  /// See [AccountApi.deriveOwnedAccountsFromSigner].
  Future<List<signer.Account>> deriveOwnedAccountsFromSigner({
    required Object signer,
    AnyNumber? minimumLedgerVersion,
    bool includeUnverified = false,
    bool noMultiKey = false,
  }) =>
      account.deriveOwnedAccountsFromSigner(
        signer: signer,
        minimumLedgerVersion: minimumLedgerVersion,
        includeUnverified: includeUnverified,
        noMultiKey: noMultiKey,
      );

  /// See [AccountApi.isAccountExist].
  Future<bool> isAccountExist({required AuthenticationKey authKey}) =>
      account.isAccountExist(authKey: authKey);

  // ===
  // ANS namespace convenience methods
  // ===

  /// See [Ans.getOwnerAddress].
  Future<AccountAddress?> getOwnerAddress({required String name}) =>
      ans.getOwnerAddress(name: name);

  /// See [Ans.getExpiration].
  Future<int?> getExpiration({required String name}) =>
      ans.getExpiration(name: name);

  /// See [Ans.getTargetAddress].
  Future<AccountAddress?> getTargetAddress({required String name}) =>
      ans.getTargetAddress(name: name);

  /// See [Ans.setTargetAddress].
  Future<AnsTransactionResult> setTargetAddress({
    required AccountAddressInput sender,
    required String name,
    required AccountAddressInput address,
    InputGenerateTransactionOptions? options,
  }) =>
      ans.setTargetAddress(
        sender: sender,
        name: name,
        address: address,
        options: options,
      );

  /// See [Ans.clearTargetAddress].
  Future<AnsTransactionResult> clearTargetAddress({
    required AccountAddressInput sender,
    required String name,
    InputGenerateTransactionOptions? options,
  }) =>
      ans.clearTargetAddress(sender: sender, name: name, options: options);

  /// See [Ans.getPrimaryName].
  Future<String?> getPrimaryName({required AccountAddressInput address}) =>
      ans.getPrimaryName(address: address);

  /// See [Ans.setPrimaryName].
  Future<AnsTransactionResult> setPrimaryName({
    required AccountAddressInput sender,
    String? name,
    InputGenerateTransactionOptions? options,
  }) =>
      ans.setPrimaryName(sender: sender, name: name, options: options);

  /// See [Ans.registerName].
  Future<AnsTransactionResult> registerName({
    required AccountAddressInput sender,
    required String name,
    required RegisterNameExpiration expiration,
    bool? transferable,
    AccountAddressInput? toAddress,
    AccountAddressInput? targetAddress,
    InputGenerateTransactionOptions? options,
  }) =>
      ans.registerName(
        sender: sender,
        name: name,
        expiration: expiration,
        transferable: transferable,
        toAddress: toAddress,
        targetAddress: targetAddress,
        options: options,
      );

  /// See [Ans.renewDomain].
  Future<AnsTransactionResult> renewDomain({
    required AccountAddressInput sender,
    required String name,
    int years = 1,
    InputGenerateTransactionOptions? options,
  }) =>
      ans.renewDomain(
        sender: sender,
        name: name,
        years: years,
        options: options,
      );

  /// See [Ans.getName].
  Future<AnsName?> getName({required String name}) => ans.getName(name: name);

  /// See [Ans.getAccountNames].
  Future<AnsNamesResult> getAccountNames({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) =>
      ans.getAccountNames(accountAddress: accountAddress, options: options);

  /// See [Ans.getAccountDomains].
  Future<AnsNamesResult> getAccountDomains({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) =>
      ans.getAccountDomains(accountAddress: accountAddress, options: options);

  /// See [Ans.getAccountSubdomains].
  Future<AnsNamesResult> getAccountSubdomains({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) =>
      ans.getAccountSubdomains(
        accountAddress: accountAddress,
        options: options,
      );

  /// See [Ans.getDomainSubdomains].
  Future<AnsNamesResult> getDomainSubdomains({
    required String domain,
    IndexerQueryArgs? options,
  }) =>
      ans.getDomainSubdomains(domain: domain, options: options);

  // ===
  // COIN namespace convenience methods
  // ===

  /// See [Coin.transferCoinTransaction].
  Future<SimpleTransaction> transferCoinTransaction({
    required AccountAddressInput sender,
    required AccountAddressInput recipient,
    required AnyNumber amount,
    MoveStructId? coinType,
    InputGenerateTransactionOptions? options,
  }) =>
      coin.transferCoinTransaction(
        sender: sender,
        recipient: recipient,
        amount: amount,
        coinType: coinType,
        options: options,
      );

  // ===
  // DIGITAL ASSET namespace convenience methods
  // ===

  /// See [DigitalAsset.getCollectionData].
  Future<CollectionData> getCollectionData({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getCollectionData(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.getCollectionDataByCreatorAddressAndCollectionName].
  Future<CollectionData> getCollectionDataByCreatorAddressAndCollectionName({
    required AccountAddressInput creatorAddress,
    required String collectionName,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getCollectionDataByCreatorAddressAndCollectionName(
        creatorAddress: creatorAddress,
        collectionName: collectionName,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.getCollectionDataByCreatorAddress].
  Future<CollectionData> getCollectionDataByCreatorAddress({
    required AccountAddressInput creatorAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getCollectionDataByCreatorAddress(
        creatorAddress: creatorAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.getCollectionDataByCollectionId].
  Future<CollectionData> getCollectionDataByCollectionId({
    required AccountAddressInput collectionId,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getCollectionDataByCollectionId(
        collectionId: collectionId,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.getCollectionId].
  Future<String> getCollectionId({
    required AccountAddressInput creatorAddress,
    required String collectionName,
    AnyNumber? minimumLedgerVersion,
    TokenStandard? tokenStandard,
  }) =>
      digitalAsset.getCollectionId(
        creatorAddress: creatorAddress,
        collectionName: collectionName,
        minimumLedgerVersion: minimumLedgerVersion,
        tokenStandard: tokenStandard,
      );

  /// See [DigitalAsset.getDigitalAssetData].
  Future<TokenData> getDigitalAssetData({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      digitalAsset.getDigitalAssetData(
        digitalAssetAddress: digitalAssetAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [DigitalAsset.getCurrentDigitalAssetOwnership].
  Future<TokenOwnership> getCurrentDigitalAssetOwnership({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      digitalAsset.getCurrentDigitalAssetOwnership(
        digitalAssetAddress: digitalAssetAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [DigitalAsset.getOwnedDigitalAssets].
  Future<List<TokenOwnership>> getOwnedDigitalAssets({
    required AccountAddressInput ownerAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getOwnedDigitalAssets(
        ownerAddress: ownerAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.getDigitalAssetActivity].
  Future<List<TokenActivity>> getDigitalAssetActivity({
    required AccountAddressInput digitalAssetAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      digitalAsset.getDigitalAssetActivity(
        digitalAssetAddress: digitalAssetAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [DigitalAsset.createCollectionTransaction].
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
  }) =>
      digitalAsset.createCollectionTransaction(
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

  /// See [DigitalAsset.mintDigitalAssetTransaction].
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
  }) =>
      digitalAsset.mintDigitalAssetTransaction(
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

  /// See [DigitalAsset.transferDigitalAssetTransaction].
  Future<SimpleTransaction> transferDigitalAssetTransaction({
    required signer.Account sender,
    required AccountAddressInput digitalAssetAddress,
    required AccountAddressInput recipient,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.transferDigitalAssetTransaction(
        sender: sender,
        digitalAssetAddress: digitalAssetAddress,
        recipient: recipient,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.mintSoulBoundTransaction].
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
  }) =>
      digitalAsset.mintSoulBoundTransaction(
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

  /// See [DigitalAsset.burnDigitalAssetTransaction].
  Future<SimpleTransaction> burnDigitalAssetTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.burnDigitalAssetTransaction(
        creator: creator,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.freezeDigitalAssetTransferTransaction].
  Future<SimpleTransaction> freezeDigitalAssetTransferTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.freezeDigitalAssetTransferTransaction(
        creator: creator,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.unfreezeDigitalAssetTransferTransaction].
  Future<SimpleTransaction> unfreezeDigitalAssetTransferTransaction({
    required signer.Account creator,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.unfreezeDigitalAssetTransferTransaction(
        creator: creator,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.setDigitalAssetDescriptionTransaction].
  Future<SimpleTransaction> setDigitalAssetDescriptionTransaction({
    required signer.Account creator,
    required String description,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.setDigitalAssetDescriptionTransaction(
        creator: creator,
        description: description,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.setDigitalAssetNameTransaction].
  Future<SimpleTransaction> setDigitalAssetNameTransaction({
    required signer.Account creator,
    required String name,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.setDigitalAssetNameTransaction(
        creator: creator,
        name: name,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.setDigitalAssetURITransaction].
  Future<SimpleTransaction> setDigitalAssetURITransaction({
    required signer.Account creator,
    required String uri,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.setDigitalAssetURITransaction(
        creator: creator,
        uri: uri,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.addDigitalAssetPropertyTransaction].
  Future<SimpleTransaction> addDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.addDigitalAssetPropertyTransaction(
        creator: creator,
        propertyKey: propertyKey,
        propertyType: propertyType,
        propertyValue: propertyValue,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.removeDigitalAssetPropertyTransaction].
  Future<SimpleTransaction> removeDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.removeDigitalAssetPropertyTransaction(
        creator: creator,
        propertyKey: propertyKey,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.updateDigitalAssetPropertyTransaction].
  Future<SimpleTransaction> updateDigitalAssetPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.updateDigitalAssetPropertyTransaction(
        creator: creator,
        propertyKey: propertyKey,
        propertyType: propertyType,
        propertyValue: propertyValue,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.addDigitalAssetTypedPropertyTransaction].
  Future<SimpleTransaction> addDigitalAssetTypedPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.addDigitalAssetTypedPropertyTransaction(
        creator: creator,
        propertyKey: propertyKey,
        propertyType: propertyType,
        propertyValue: propertyValue,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  /// See [DigitalAsset.updateDigitalAssetTypedPropertyTransaction].
  Future<SimpleTransaction> updateDigitalAssetTypedPropertyTransaction({
    required signer.Account creator,
    required String propertyKey,
    required PropertyType propertyType,
    required PropertyValue propertyValue,
    required AccountAddressInput digitalAssetAddress,
    MoveStructId? digitalAssetType,
    InputGenerateTransactionOptions? options,
  }) =>
      digitalAsset.updateDigitalAssetTypedPropertyTransaction(
        creator: creator,
        propertyKey: propertyKey,
        propertyType: propertyType,
        propertyValue: propertyValue,
        digitalAssetAddress: digitalAssetAddress,
        digitalAssetType: digitalAssetType,
        options: options,
      );

  // ===
  // EVENT namespace convenience methods
  // ===

  /// See [EventApi.getModuleEventsByEventType].
  Future<List<IndexerEvent>> getModuleEventsByEventType({
    required MoveStructId eventType,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      event.getModuleEventsByEventType(
        eventType: eventType,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [EventApi.getAccountEventsByCreationNumber].
  Future<List<IndexerEvent>> getAccountEventsByCreationNumber({
    required AccountAddressInput accountAddress,
    required AnyNumber creationNumber,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      event.getAccountEventsByCreationNumber(
        accountAddress: accountAddress,
        creationNumber: creationNumber,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [EventApi.getAccountEventsByEventType].
  Future<List<IndexerEvent>> getAccountEventsByEventType({
    required AccountAddressInput accountAddress,
    required MoveStructId eventType,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      event.getAccountEventsByEventType(
        accountAddress: accountAddress,
        eventType: eventType,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [EventApi.getEvents].
  Future<List<IndexerEvent>> getEvents({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      event.getEvents(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  // ===
  // GENERAL namespace convenience methods
  // ===

  /// See [General.getLedgerInfo].
  Future<LedgerInfo> getLedgerInfo() => general.getLedgerInfo();

  /// See [General.getChainId].
  Future<int> getChainId() => general.getChainId();

  /// See [General.getBlockByVersion].
  Future<Block> getBlockByVersion({
    required AnyNumber ledgerVersion,
    bool? withTransactions,
  }) =>
      general.getBlockByVersion(
        ledgerVersion: ledgerVersion,
        withTransactions: withTransactions,
      );

  /// See [General.getBlockByHeight].
  Future<Block> getBlockByHeight({
    required AnyNumber blockHeight,
    bool? withTransactions,
  }) =>
      general.getBlockByHeight(
        blockHeight: blockHeight,
        withTransactions: withTransactions,
      );

  /// See [General.view].
  Future<List<MoveValue>> view({
    required InputViewFunctionData payload,
    LedgerVersionArg? options,
  }) =>
      general.view(payload: payload, options: options);

  /// See [General.viewJson].
  Future<List<MoveValue>> viewJson({
    required InputViewFunctionJsonData payload,
    LedgerVersionArg? options,
  }) =>
      general.viewJson(payload: payload, options: options);

  /// See [General.getChainTopUserTransactions].
  Future<List<ChainTopUserTransaction>> getChainTopUserTransactions({
    required int limit,
  }) =>
      general.getChainTopUserTransactions(limit: limit);

  /// See [General.queryIndexer].
  Future<Map<String, dynamic>> queryIndexer({required GraphqlQuery query}) =>
      general.queryIndexer(query: query);

  /// See [General.getProcessorStatuses].
  Future<List<ProcessorStatus>> getProcessorStatuses() =>
      general.getProcessorStatuses();

  /// See [General.getProcessorStatus].
  Future<ProcessorStatus> getProcessorStatus({
    required ProcessorType processorType,
  }) =>
      general.getProcessorStatus(processorType: processorType);

  /// See [General.getIndexerLastSuccessVersion].
  Future<BigInt> getIndexerLastSuccessVersion() =>
      general.getIndexerLastSuccessVersion();

  // ===
  // FAUCET namespace convenience methods
  // ===

  /// See [Faucet.fundAccount].
  Future<UserTransactionResponse> fundAccount({
    required AccountAddressInput accountAddress,
    required int amount,
    WaitForTransactionOptions? options,
  }) =>
      faucet.fundAccount(
        accountAddress: accountAddress,
        amount: amount,
        options: options,
      );

  // ===
  // FUNGIBLE ASSET namespace convenience methods
  // ===

  /// See [FungibleAsset.getFungibleAssetMetadata].
  Future<List<FungibleAssetMetadata>> getFungibleAssetMetadata({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      fungibleAsset.getFungibleAssetMetadata(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [FungibleAsset.getFungibleAssetMetadataByAssetType].
  Future<FungibleAssetMetadata> getFungibleAssetMetadataByAssetType({
    required String assetType,
    AnyNumber? minimumLedgerVersion,
  }) =>
      fungibleAsset.getFungibleAssetMetadataByAssetType(
        assetType: assetType,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [FungibleAsset.getFungibleAssetMetadataByCreatorAddress].
  Future<List<FungibleAssetMetadata>> getFungibleAssetMetadataByCreatorAddress({
    required AccountAddressInput creatorAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      fungibleAsset.getFungibleAssetMetadataByCreatorAddress(
        creatorAddress: creatorAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [FungibleAsset.getFungibleAssetActivities].
  Future<List<FungibleAssetActivity>> getFungibleAssetActivities({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      fungibleAsset.getFungibleAssetActivities(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [FungibleAsset.getCurrentFungibleAssetBalances].
  Future<List<CurrentFungibleAssetBalance>> getCurrentFungibleAssetBalances({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      fungibleAsset.getCurrentFungibleAssetBalances(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [FungibleAsset.transferFungibleAsset].
  Future<SimpleTransaction> transferFungibleAsset({
    required signer.Account sender,
    required AccountAddressInput fungibleAssetMetadataAddress,
    required AccountAddressInput recipient,
    required AnyNumber amount,
    InputGenerateTransactionOptions? options,
  }) =>
      fungibleAsset.transferFungibleAsset(
        sender: sender,
        fungibleAssetMetadataAddress: fungibleAssetMetadataAddress,
        recipient: recipient,
        amount: amount,
        options: options,
      );

  /// See [FungibleAsset.transferFungibleAssetBetweenStores].
  Future<SimpleTransaction> transferFungibleAssetBetweenStores({
    required signer.Account sender,
    required AccountAddressInput fromStore,
    required AccountAddressInput toStore,
    required AnyNumber amount,
    InputGenerateTransactionOptions? options,
  }) =>
      fungibleAsset.transferFungibleAssetBetweenStores(
        sender: sender,
        fromStore: fromStore,
        toStore: toStore,
        amount: amount,
        options: options,
      );

  // ===
  // OBJECT namespace convenience methods
  // ===

  /// See [AptosObject.getObjectDataByObjectAddress].
  Future<ObjectData> getObjectDataByObjectAddress({
    required AccountAddressInput objectAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      object.getObjectDataByObjectAddress(
        objectAddress: objectAddress,
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  // ===
  // STAKING namespace convenience methods
  // ===

  /// See [Staking.getNumberOfDelegators].
  Future<int> getNumberOfDelegators({
    required AccountAddressInput poolAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      staking.getNumberOfDelegators(
        poolAddress: poolAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  /// See [Staking.getNumberOfDelegatorsForAllPools].
  Future<List<NumberOfDelegators>> getNumberOfDelegatorsForAllPools({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      staking.getNumberOfDelegatorsForAllPools(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [Staking.getDelegatedStakingActivities].
  Future<List<DelegatedStakingActivity>> getDelegatedStakingActivities({
    required AccountAddressInput delegatorAddress,
    required AccountAddressInput poolAddress,
    AnyNumber? minimumLedgerVersion,
  }) =>
      staking.getDelegatedStakingActivities(
        delegatorAddress: delegatorAddress,
        poolAddress: poolAddress,
        minimumLedgerVersion: minimumLedgerVersion,
      );

  // ===
  // TABLE namespace convenience methods
  // ===

  /// See [Table.getTableItem].
  Future<T> getTableItem<T>({
    required String handle,
    required TableItemRequest data,
    LedgerVersionArg? options,
  }) =>
      table.getTableItem<T>(handle: handle, data: data, options: options);

  /// See [Table.getTableItemsData].
  Future<List<TableItemData>> getTableItemsData({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      table.getTableItemsData(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  /// See [Table.getTableItemsMetadata].
  Future<List<TableMetadata>> getTableItemsMetadata({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) =>
      table.getTableItemsMetadata(
        minimumLedgerVersion: minimumLedgerVersion,
        options: options,
      );

  // ===
  // TRANSACTION namespace convenience methods
  //
  // Note: `build`, `simulate`, `submit` and `batch` intentionally stay only
  // on `aptos.transaction.build` etc., and are not surfaced as convenience
  // methods here.
  // ===

  /// See [Transaction.getTransactions].
  Future<List<TransactionResponse>> getTransactions({
    PaginationArgs? options,
  }) =>
      transaction.getTransactions(options: options);

  /// See [Transaction.getTransactionByVersion].
  Future<TransactionResponse> getTransactionByVersion({
    required AnyNumber ledgerVersion,
  }) =>
      transaction.getTransactionByVersion(ledgerVersion: ledgerVersion);

  /// See [Transaction.getTransactionByHash].
  Future<TransactionResponse> getTransactionByHash({
    required HexInput transactionHash,
  }) =>
      transaction.getTransactionByHash(transactionHash: transactionHash);

  /// See [Transaction.isPendingTransaction].
  Future<bool> isPendingTransaction({required HexInput transactionHash}) =>
      transaction.isPendingTransaction(transactionHash: transactionHash);

  /// See [Transaction.waitForTransaction].
  Future<CommittedTransactionResponse> waitForTransaction({
    required HexInput transactionHash,
    WaitForTransactionOptions? options,
  }) =>
      transaction.waitForTransaction(
        transactionHash: transactionHash,
        options: options,
      );

  /// See [Transaction.getGasPriceEstimation].
  Future<GasEstimation> getGasPriceEstimation() =>
      transaction.getGasPriceEstimation();

  /// See [Transaction.getSigningMessage].
  Uint8List getSigningMessage({required AnyRawTransaction transaction}) =>
      this.transaction.getSigningMessage(transaction: transaction);

  /// See [Transaction.publishPackageTransaction].
  Future<SimpleTransaction> publishPackageTransaction({
    required AccountAddressInput account,
    required HexInput metadataBytes,
    required List<HexInput> moduleBytecode,
    InputGenerateTransactionOptions? options,
  }) =>
      transaction.publishPackageTransaction(
        account: account,
        metadataBytes: metadataBytes,
        moduleBytecode: moduleBytecode,
        options: options,
      );

  /// See [Transaction.rotateAuthKey].
  Future<SimpleTransaction> rotateAuthKey({
    required signer.Account fromAccount,
    signer.Account? toAccount,
    Ed25519PrivateKey? toNewPrivateKey,
    InputGenerateTransactionOptions? options,
  }) =>
      transaction.rotateAuthKey(
        fromAccount: fromAccount,
        toAccount: toAccount,
        toNewPrivateKey: toNewPrivateKey,
        options: options,
      );

  /// See [Transaction.rotateAuthKeyUnverified].
  Future<SimpleTransaction> rotateAuthKeyUnverified({
    required signer.Account fromAccount,
    required AccountPublicKey toNewPublicKey,
    InputGenerateTransactionOptions? options,
  }) =>
      transaction.rotateAuthKeyUnverified(
        fromAccount: fromAccount,
        toNewPublicKey: toNewPublicKey,
        options: options,
      );

  /// See [Transaction.sign].
  AccountAuthenticator sign({
    required signer.Account signer,
    required AnyRawTransaction transaction,
  }) =>
      this.transaction.sign(signer: signer, transaction: transaction);

  /// See [Transaction.signAsFeePayer].
  AccountAuthenticator signAsFeePayer({
    required signer.Account signer,
    required AnyRawTransaction transaction,
  }) =>
      this.transaction.signAsFeePayer(
            signer: signer,
            transaction: transaction,
          );

  /// See [Transaction.generateUserTransactionHash].
  String generateUserTransactionHash(InputSubmitTransactionData args) =>
      transaction.generateUserTransactionHash(args);

  /// See [Transaction.signAndSubmitTransaction].
  Future<PendingTransactionResponse> signAndSubmitTransaction({
    required signer.Account signer,
    required AnyRawTransaction transaction,
    signer.Account? feePayer,
    AccountAuthenticator? feePayerAuthenticator,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) =>
      this.transaction.signAndSubmitTransaction(
            signer: signer,
            transaction: transaction,
            feePayer: feePayer,
            feePayerAuthenticator: feePayerAuthenticator,
            pluginParams: pluginParams,
            transactionSubmitter: transactionSubmitter,
          );

  /// See [Transaction.signAndSubmitAsFeePayer].
  Future<PendingTransactionResponse> signAndSubmitAsFeePayer({
    required signer.Account feePayer,
    required AccountAuthenticator senderAuthenticator,
    required AnyRawTransaction transaction,
    Map<String, Object?>? pluginParams,
    TransactionSubmitter? transactionSubmitter,
  }) =>
      this.transaction.signAndSubmitAsFeePayer(
            feePayer: feePayer,
            senderAuthenticator: senderAuthenticator,
            transaction: transaction,
            pluginParams: pluginParams,
            transactionSubmitter: transactionSubmitter,
          );

  // ===
  // KEYLESS namespace convenience methods
  // ===

  /// See [Keyless.getPepper].
  Future<Uint8List> getPepper({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    String uidKey = 'sub',
    String? derivationPath,
  }) {
    return keyless.getPepper(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
      derivationPath: derivationPath,
    );
  }

  /// See [Keyless.getPepperBase].
  Future<Uint8List> getPepperBase({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    String uidKey = 'sub',
  }) {
    return keyless.getPepperBase(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
    );
  }

  /// See [Keyless.getProof].
  Future<ZeroKnowledgeSig> getProof({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    HexInput? pepper,
    String uidKey = 'sub',
  }) {
    return keyless.getProof(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      pepper: pepper,
      uidKey: uidKey,
    );
  }

  /// See [Keyless.deriveKeylessAccount].
  Future<AbstractKeylessAccount> deriveKeylessAccount({
    required String jwt,
    required EphemeralKeyPair ephemeralKeyPair,
    AccountAddressInput? jwkAddress,
    String uidKey = 'sub',
    HexInput? pepper,
    ProofFetchCallback? proofFetchCallback,
  }) {
    return keyless.deriveKeylessAccount(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      jwkAddress: jwkAddress,
      uidKey: uidKey,
      pepper: pepper,
      proofFetchCallback: proofFetchCallback,
    );
  }

  /// See [Keyless.updateFederatedKeylessJwkSetTransaction].
  Future<SimpleTransaction> updateFederatedKeylessJwkSetTransaction({
    required signer.Account sender,
    required String iss,
    String? jwksUrl,
    InputGenerateTransactionOptions? options,
  }) {
    return keyless.updateFederatedKeylessJwkSetTransaction(
      sender: sender,
      iss: iss,
      jwksUrl: jwksUrl,
      options: options,
    );
  }
}
