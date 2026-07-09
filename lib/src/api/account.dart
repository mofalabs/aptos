import '../account/account.dart' as signer;
import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/single_key.dart';
import '../internal/account.dart' as internal_account;
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class to query all `Account` related queries on Aptos.
///
/// NOTE: named `AccountApi` to avoid clashing with the signer `Account` class
/// from `lib/src/account/account.dart` under a single-namespace import.
class AccountApi {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Account` namespace with the specified
  /// configuration.
  const AccountApi(this.config);

  /// Queries the current state for an Aptos account given its account
  /// address.
  Future<AccountData> getAccountInfo({
    required AccountAddressInput accountAddress,
  }) {
    return internal_account.getInfo(
      aptosConfig: config,
      accountAddress: accountAddress,
    );
  }

  /// Queries for all modules in an account given an account address.
  ///
  /// Note: In order to get all account modules, this function may call the
  /// API multiple times as it paginates.
  Future<List<MoveModuleBytecode>> getAccountModules({
    required AccountAddressInput accountAddress,
    int? limit,
    LedgerVersionArg? options,
  }) {
    return internal_account.getModules(
      aptosConfig: config,
      accountAddress: accountAddress,
      limit: limit,
      options: options,
    );
  }

  /// Queries for a page of modules in an account given an account address.
  Future<({List<MoveModuleBytecode> modules, String? cursor})>
      getAccountModulesPage({
    required AccountAddressInput accountAddress,
    CursorPaginationArgs? options,
    LedgerVersionArg? ledgerVersionArg,
  }) {
    return internal_account.getModulesPage(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
      ledgerVersionArg: ledgerVersionArg,
    );
  }

  /// Queries for a specific account module given an account address and
  /// module name.
  Future<MoveModuleBytecode> getAccountModule({
    required AccountAddressInput accountAddress,
    required String moduleName,
    LedgerVersionArg? options,
  }) {
    return internal_account.getModule(
      aptosConfig: config,
      accountAddress: accountAddress,
      moduleName: moduleName,
      options: options,
    );
  }

  /// Queries account transactions given an account address.
  ///
  /// Note: In order to get all account transactions, this function may call
  /// the API multiple times as it paginates.
  Future<List<CommittedTransactionResponse>> getAccountTransactions({
    required AccountAddressInput accountAddress,
    PaginationArgs? options,
  }) {
    return internal_account.getTransactions(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Queries all account resources given an account address.
  ///
  /// Note: In order to get all account resources, this function may call the
  /// API multiple times as it paginates.
  Future<List<MoveResource>> getAccountResources({
    required AccountAddressInput accountAddress,
    int? limit,
    LedgerVersionArg? options,
  }) {
    return internal_account.getResources(
      aptosConfig: config,
      accountAddress: accountAddress,
      limit: limit,
      options: options,
    );
  }

  /// Queries a page of account resources given an account address.
  Future<({List<MoveResource> resources, String? cursor})>
      getAccountResourcesPage({
    required AccountAddressInput accountAddress,
    CursorPaginationArgs? options,
    LedgerVersionArg? ledgerVersionArg,
  }) {
    return internal_account.getResourcesPage(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
      ledgerVersionArg: ledgerVersionArg,
    );
  }

  /// Queries a specific account resource given an account address and
  /// resource type, returning the resource's `data` field.
  Future<T> getAccountResource<T>({
    required AccountAddressInput accountAddress,
    required MoveStructId resourceType,
    LedgerVersionArg? options,
  }) {
    return internal_account.getResource<T>(
      aptosConfig: config,
      accountAddress: accountAddress,
      resourceType: resourceType,
      options: options,
    );
  }

  /// Looks up the account address for a given authentication key, handling
  /// key rotations.
  Future<AccountAddress> lookupOriginalAccountAddress({
    required AccountAddressInput authenticationKey,
    LedgerVersionArg? options,
  }) {
    return internal_account.lookupOriginalAccountAddress(
      aptosConfig: config,
      authenticationKey: authenticationKey,
      options: options,
    );
  }

  /// Retrieves an account's balance for the given asset (a coin type such as
  /// `0x1::aptos_coin::AptosCoin` or an FA metadata address) via the fullnode
  /// REST API.
  Future<int> getBalance({
    required AccountAddressInput accountAddress,
    required Object asset,
  }) {
    return internal_account.getBalance(
      aptosConfig: config,
      accountAddress: accountAddress,
      asset: asset,
    );
  }

  /// Queries the current count of tokens owned by a specified account.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  Future<int> getAccountTokensCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.accountTransactionProcessor,
    );
    return internal_account.getAccountTokensCount(
      aptosConfig: config,
      accountAddress: accountAddress,
    );
  }

  /// Queries the tokens currently owned by a specified account, including
  /// NFTs and fungible tokens. If desired, you can filter the results by a
  /// specific token standard.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional token standard, pagination and ordering parameters.
  Future<List<TokenOwnership>> getAccountOwnedTokens({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_account.getAccountOwnedTokens(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Queries all current tokens of a specific collection that an account
  /// owns by the collection address.
  ///
  /// This query returns all tokens (v1 and v2 standards) an account owns,
  /// including NFTs, fungible, soulbound, etc. If you want to get only the
  /// token from a specific standard, you can pass an optional tokenStandard
  /// parameter via [options].
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional token standard, pagination and ordering parameters.
  Future<List<TokenOwnership>> getAccountOwnedTokensFromCollectionAddress({
    required AccountAddressInput accountAddress,
    required AccountAddressInput collectionAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_account.getAccountOwnedTokensFromCollectionAddress(
      aptosConfig: config,
      accountAddress: accountAddress,
      collectionAddress: collectionAddress,
      options: options,
    );
  }

  /// Queries for all collections that an account currently has tokens for,
  /// including NFTs, fungible tokens, and soulbound tokens.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional token standard, pagination and ordering parameters.
  Future<List<AccountCollectionWithOwnedTokens>>
      getAccountCollectionsWithOwnedTokens({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.tokenV2Processor,
    );
    return internal_account.getAccountCollectionsWithOwnedTokens(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Queries the current count of transactions submitted by an account.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  Future<int> getAccountTransactionsCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.accountTransactionProcessor,
    );
    return internal_account.getAccountTransactionsCount(
      aptosConfig: config,
      accountAddress: accountAddress,
    );
  }

  /// Retrieves the coins data for a specified account.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination, ordering and where-condition
  /// parameters.
  Future<List<CurrentFungibleAssetBalance>> getAccountCoinsData({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_account.getAccountCoinsData(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Retrieves the current count of an account's coins aggregated across all
  /// types.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  Future<int> getAccountCoinsCount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.fungibleAssetProcessor,
    );
    return internal_account.getAccountCoinsCount(
      aptosConfig: config,
      accountAddress: accountAddress,
    );
  }

  /// Retrieves the current amount of APT for a specified account. If the
  /// account does not exist, it will return 0.
  Future<int> getAccountAPTAmount({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
  }) {
    return getAccountCoinAmount(
      accountAddress: accountAddress,
      coinType: aptosCoin,
      faMetadataAddress: aptosFa,
    );
  }

  /// Queries the current amount of a specified coin held by an account.
  ///
  /// Deprecated: prefer `getBalance(accountAddress: ..., asset: ...)`; this
  /// method may be removed in a future release.
  ///
  /// [coinType] - Optional. The coin type to query. Note: If not provided,
  /// it may be automatically populated if [faMetadataAddress] is specified.
  /// [faMetadataAddress] - Optional. The fungible asset metadata address to
  /// query. Note: If not provided, it may be automatically populated if
  /// [coinType] is specified.
  Future<int> getAccountCoinAmount({
    required AccountAddressInput accountAddress,
    MoveStructId? coinType,
    AccountAddressInput? faMetadataAddress,
  }) {
    return internal_account.getAccountCoinAmount(
      aptosConfig: config,
      accountAddress: accountAddress,
      coinType: coinType,
      faMetadataAddress: faMetadataAddress,
    );
  }

  /// Queries an account's owned objects.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and ordering parameters.
  Future<List<ObjectData>> getAccountOwnedObjects({
    required AccountAddressInput accountAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.defaultProcessor,
    );
    return internal_account.getAccountOwnedObjects(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Derives an account by providing a private key. This function resolves
  /// the provided private key type and derives the public key from it.
  ///
  /// If the [privateKey] is a Secp256k1 type, it derives the account using
  /// the derived public key and auth key using the SingleKey scheme locally.
  /// If the [privateKey] is an ED25519 type, it looks up the authentication
  /// key on chain to determine whether it is a Legacy ED25519 key or a
  /// Unified ED25519 key, and then derives the account based on that.
  ///
  /// Note that more inspection is needed by the user to determine which
  /// account exists on-chain.
  ///
  /// Deprecated: this heuristic derivation is unreliable and may be removed in
  /// a future release.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [throwIfNoAccountFound] - Whether to throw when no existing account is
  /// found for the private key. Default is false.
  Future<signer.Account> deriveAccountFromPrivateKey({
    required PrivateKeyInput privateKey,
    AnyNumber? minimumLedgerVersion,
    bool throwIfNoAccountFound = false,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.accountRestorationProcessor,
    );
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.objectProcessor,
    );
    return internal_account.deriveAccountFromPrivateKey(
      aptosConfig: config,
      privateKey: privateKey,
      throwIfNoAccountFound: throwIfNoAccountFound,
    );
  }

  /// Gets all account info (address, account public key, last transaction
  /// version) associated with a public key and **related public keys**.
  ///
  /// For a given public key, it will query all multikeys that the public key
  /// is part of. Then, for the provided public key and any multikeys found
  /// in the previous step, it will query for any accounts that have an auth
  /// key that matches any of the public keys.
  ///
  /// Note: If an Ed25519PublicKey or an AnyPublicKey that wraps an
  /// Ed25519PublicKey is passed in, both the legacy and single signer cases
  /// are queried.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [includeUnverified] - Whether to include unverified accounts in the
  /// results (accounts that can be authenticated with the signer, but have
  /// no history of the signer using them). Default is false.
  /// [noMultiKey] - Whether to exclude multi-key accounts in the results.
  /// Default is false.
  Future<List<AccountInfo>> getAccountsForPublicKey({
    required AccountPublicKey publicKey,
    AnyNumber? minimumLedgerVersion,
    bool includeUnverified = false,
    bool noMultiKey = false,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.accountRestorationProcessor,
    );
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.objectProcessor,
    );
    return internal_account.getAccountsForPublicKey(
      aptosConfig: config,
      publicKey: publicKey,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }

  /// Derives all accounts owned by a signer. This function takes a signer
  /// (either an `Account` or a private key) and returns all accounts that
  /// can be derived from it, ordered by the most recently used account
  /// first.
  ///
  /// Note: this function will not return accounts that require more than one
  /// signer to be used.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [includeUnverified] - Whether to include unverified accounts in the
  /// results. Default is false.
  /// [noMultiKey] - If true, do not include multi-key accounts in the
  /// results. Default is false.
  Future<List<signer.Account>> deriveOwnedAccountsFromSigner({
    required Object signer,
    AnyNumber? minimumLedgerVersion,
    bool includeUnverified = false,
    bool noMultiKey = false,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.accountRestorationProcessor,
    );
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.objectProcessor,
    );
    return internal_account.deriveOwnedAccountsFromSigner(
      aptosConfig: config,
      signer: signer,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }

  /// Checks if an account exists by verifying its information against the
  /// Aptos blockchain.
  ///
  /// [authKey] - The authentication key used to derive the account address.
  Future<bool> isAccountExist({required AuthenticationKey authKey}) {
    return internal_account.isAccountExist(
      aptosConfig: config,
      authKey: authKey,
    );
  }
}
