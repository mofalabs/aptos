/// This file contains the underlying implementations for the exposed API
/// surface in `api/account.dart` (fullnode- and indexer-backed functions).
library;

import '../account/abstract_keyless_account.dart';
import '../account/account.dart';
import '../account/ed25519_account.dart';
import '../account/federated_keyless_account.dart';
import '../account/keyless_account.dart';
import '../account/multi_ed25519_account.dart';
import '../account/multi_key_account.dart';
import '../account/single_key_account.dart';
import '../api/aptos_config.dart';
import '../bcs/deserializer.dart';
import '../bcs/serializable/move_primitives.dart';
import '../bcs/serializable/move_structs.dart';
import '../client/get.dart';
import '../core/account/utils/address.dart';
import '../core/account_address.dart';
import '../core/authentication_key.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/federated_keyless.dart';
import '../core/crypto/multi_ed25519.dart';
import '../core/crypto/multi_key.dart';
import '../core/crypto/public_key.dart';
import '../core/crypto/secp256k1.dart';
import '../core/crypto/single_key.dart';
import '../core/crypto/utils.dart';
import '../core/hex.dart';
import '../errors/errors.dart';
import '../transactions/instances/rotation_proof_challenge.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/indexer.dart';
import '../types/ledger.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../types/types.dart';
import '../utils/const.dart';
import '../utils/memoize.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;
import 'table.dart';
import 'transaction_submission.dart';

/// Retrieves account information for a specified account address.
Future<AccountData> getInfo({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getInfo',
    path: 'accounts/${AccountAddress.from(accountAddress)}',
  );
  return AccountData.fromJson(Map<String, dynamic>.from(response.data as Map));
}

/// Retrieves the modules associated with a specified account address,
/// following the pagination cursor until [limit] modules (default 1000) have
/// been fetched.
Future<List<MoveModuleBytecode>> getModules({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  int? limit,
  LedgerVersionArg? options,
}) async {
  final data = await paginateWithObfuscatedCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getModules',
    path: 'accounts/${AccountAddress.from(accountAddress)}/modules',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
      'limit': limit ?? 1000,
    },
  );
  return data
      .map((e) =>
          MoveModuleBytecode.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves a single page of modules associated with a specified account
/// address. The returned cursor (if any) can be passed via
/// [CursorPaginationArgs.cursor] to fetch the next page.
Future<({List<MoveModuleBytecode> modules, String? cursor})> getModulesPage({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  CursorPaginationArgs? options,
  LedgerVersionArg? ledgerVersionArg,
}) async {
  final page = await getPageWithObfuscatedCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getModulesPage',
    path: 'accounts/${AccountAddress.from(accountAddress)}/modules',
    params: {
      if (ledgerVersionArg?.ledgerVersion != null)
        'ledger_version': ledgerVersionArg!.ledgerVersion,
      if (options?.cursor != null) 'cursor': options!.cursor,
      'limit': options?.limit ?? 100,
    },
  );

  final modules = (page.response.data as List)
      .map((e) =>
          MoveModuleBytecode.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return (modules: modules, cursor: page.cursor);
}

/// Queries for a move module given an account address and module name.
/// This function can help you retrieve the module's ABI and other relevant
/// information.
///
/// Results are cached for 5 minutes to reduce redundant network calls, unless
/// a specific ledger version is requested.
Future<MoveModuleBytecode> getModule({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required String moduleName,
  LedgerVersionArg? options,
}) {
  // We don't memoize the account module by ledger version, as it's not a
  // common use case; this would be handled by the developer directly.
  if (options?.ledgerVersion != null) {
    return _getModuleInner(
      aptosConfig: aptosConfig,
      accountAddress: accountAddress,
      moduleName: moduleName,
      options: options,
    );
  }

  return memoizeAsync(
    () => _getModuleInner(
      aptosConfig: aptosConfig,
      accountAddress: accountAddress,
      moduleName: moduleName,
      options: options,
    ),
    'module-$accountAddress-$moduleName',
    ttl: const Duration(minutes: 5),
  )();
}

/// Retrieves the bytecode of a specified module from a given account address.
Future<MoveModuleBytecode> _getModuleInner({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required String moduleName,
  LedgerVersionArg? options,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getModule',
    path: 'accounts/${AccountAddress.from(accountAddress)}/module/$moduleName',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
  );
  return MoveModuleBytecode.fromJson(
    Map<String, dynamic>.from(response.data as Map),
  );
}

/// Retrieves a list of committed transactions associated with a specific
/// account address, paginating through the results.
Future<List<CommittedTransactionResponse>> getTransactions({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  PaginationArgs? options,
}) async {
  final data = await paginateWithCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getTransactions',
    path: 'accounts/${AccountAddress.from(accountAddress)}/transactions',
    params: {
      if (options?.offset != null) 'start': options!.offset,
      if (options?.limit != null) 'limit': options!.limit,
    },
  );
  return data
      .map((e) =>
          TransactionResponse.fromJson(Map<String, dynamic>.from(e as Map))
              as CommittedTransactionResponse)
      .toList();
}

/// Retrieves a list of resources associated with a specific account address,
/// following the pagination cursor until [limit] resources (default 999)
/// have been fetched.
Future<List<MoveResource>> getResources({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  int? limit,
  LedgerVersionArg? options,
}) async {
  final data = await paginateWithObfuscatedCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getResources',
    path: 'accounts/${AccountAddress.from(accountAddress)}/resources',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
      'limit': limit ?? 999,
    },
  );
  return data
      .map((e) => MoveResource.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves a single page of resources associated with a specific account
/// address. The returned cursor (if any) can be passed via
/// [CursorPaginationArgs.cursor] to fetch the next page.
Future<({List<MoveResource> resources, String? cursor})> getResourcesPage({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  CursorPaginationArgs? options,
  LedgerVersionArg? ledgerVersionArg,
}) async {
  final page = await getPageWithObfuscatedCursor(
    aptosConfig: aptosConfig,
    originMethod: 'getResourcesPage',
    path: 'accounts/${AccountAddress.from(accountAddress)}/resources',
    params: {
      if (ledgerVersionArg?.ledgerVersion != null)
        'ledger_version': ledgerVersionArg!.ledgerVersion,
      if (options?.cursor != null) 'cursor': options!.cursor,
      'limit': options?.limit ?? 100,
    },
  );

  final resources = (page.response.data as List)
      .map((e) => MoveResource.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return (resources: resources, cursor: page.cursor);
}

/// Retrieves a specific resource of a given type for the specified account
/// address, returning the resource's `data` field (typically a
/// `Map<String, dynamic>`).
Future<T> getResource<T>({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required MoveStructId resourceType,
  LedgerVersionArg? options,
}) async {
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getResource',
    path: 'accounts/${AccountAddress.from(accountAddress)}'
        '/resource/$resourceType',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
  );
  final resource =
      MoveResource.fromJson(Map<String, dynamic>.from(response.data as Map));
  return resource.data as T;
}

/// Like [getResource], but explicitly returns `null` when the resource does
/// not exist.
Future<T?> getResourceFallible<T>({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required MoveStructId resourceType,
  LedgerVersionArg? options,
}) async {
  try {
    return await getResource<T>(
      aptosConfig: aptosConfig,
      accountAddress: accountAddress,
      resourceType: resourceType,
      options: options,
    );
  } on AptosApiError catch (error) {
    // Explicitly return null if there is no resource.
    if (error.status == 404 &&
        (error.data is Map &&
            (error.data as Map)['error_code'] == 'resource_not_found')) {
      return null;
    }
    rethrow;
  }
}

/// Retrieves the original account address associated with a given
/// authentication key, which is useful for handling key rotations.
///
/// Returns the original account address or the provided authentication key
/// address if not found (which means the account has not been rotated).
Future<AccountAddress> lookupOriginalAccountAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput authenticationKey,
  LedgerVersionArg? options,
}) async {
  final resource = await getResource<Map<String, dynamic>>(
    aptosConfig: aptosConfig,
    accountAddress: '0x1',
    resourceType: '0x1::account::OriginatingAddress',
    options: options,
  );

  final handle = (resource['address_map'] as Map)['handle'] as String;

  final authKeyAddress = AccountAddress.from(authenticationKey);

  // If the address is not found in the address map, which means it's not
  // rotated, then return the address as is.
  try {
    final originalAddress = await getTableItem<String>(
      aptosConfig: aptosConfig,
      handle: handle,
      data: TableItemRequest(
        key: authKeyAddress.toString(),
        keyType: 'address',
        valueType: 'address',
      ),
      options: options,
    );

    return AccountAddress.from(originalAddress);
  } on AptosApiError catch (err) {
    if (err.data is Map &&
        (err.data as Map)['error_code'] == 'table_item_not_found') {
      return authKeyAddress;
    }
    rethrow;
  }
}

/// Fetches the on-chain `authentication_key` for an account address and
/// memoizes it for ~1 hour, keyed by `(network or fullnode URL, address)`.
///
/// If the address has no `0x1::account::Account` resource on chain (a
/// brand-new account, or a light account with balance/objects but no explicit
/// resource), returns the address bytes as the authentication key — matching
/// the chain's account-creation convention.
Future<AuthenticationKey> fetchAndCacheAuthKeyForAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) {
  final address = AccountAddress.from(accountAddress);
  final addr = address.toString();
  final cacheKey =
      'auth-key-${aptosConfig.fullnode ?? aptosConfig.network.value}-$addr';
  return memoizeAsync(
    () async {
      try {
        final info = await getInfo(
          aptosConfig: aptosConfig,
          accountAddress: addr,
        );
        return AuthenticationKey(data: info.authenticationKey);
      } on AptosApiError catch (err) {
        if (err.data is Map &&
            (err.data as Map)['error_code'] == 'account_not_found') {
          // Chain convention: with no Account resource the auth key is the
          // address itself.
          return AuthenticationKey(data: address.toUint8List());
        }
        rethrow;
      }
    },
    cacheKey,
    ttl: const Duration(hours: 1),
  )();
}

/// Retrieves an account's balance for the given asset via the fullnode REST
/// API.
///
/// [asset] may be a coin type (Move struct ID, e.g.
/// `0x1::aptos_coin::AptosCoin`) or an FA metadata address. Calls
/// `GET /accounts/{accountAddress}/balance/{asset}` and returns the numeric
/// balance.
Future<int> getBalance({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required Object asset,
}) async {
  final assetString =
      asset is String ? asset : AccountAddress.from(asset).toString();
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getBalance',
    path: 'accounts/${AccountAddress.from(accountAddress)}'
        '/balance/$assetString',
  );

  return int.parse(response.data.toString());
}

// Lazy-initialized to avoid circular dependency issues at module load time.
EntryFunctionABI? _rotateAuthKeyAbi;
EntryFunctionABI _getRotateAuthKeyAbi() {
  return _rotateAuthKeyAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [
      TypeTagU8(),
      TypeTagVector.u8(),
      TypeTagU8(),
      TypeTagVector.u8(),
      TypeTagVector.u8(),
      TypeTagVector.u8(),
    ],
  );
}

/// Rotates the authentication key for a given account.
///
/// This function supports two modes of rotation: using a target account
/// object ([toAccount], an `Ed25519Account` or `MultiEd25519Account`) or
/// using a new private key ([toNewPrivateKey]). Exactly one must be provided.
///
/// Returns a [SimpleTransaction] that can be submitted to the network.
Future<SimpleTransaction> rotateAuthKey({
  required AptosConfig aptosConfig,
  required Account fromAccount,
  Account? toAccount,
  Ed25519PrivateKey? toNewPrivateKey,
  InputGenerateTransactionOptions? options,
}) {
  if (toNewPrivateKey != null) {
    return _rotateAuthKeyWithChallenge(
      aptosConfig: aptosConfig,
      fromAccount: fromAccount,
      toNewPrivateKey: toNewPrivateKey,
      options: options,
    );
  }
  if (toAccount != null) {
    if (toAccount is Ed25519Account) {
      return _rotateAuthKeyWithChallenge(
        aptosConfig: aptosConfig,
        fromAccount: fromAccount,
        toNewPrivateKey: toAccount.privateKey,
        options: options,
      );
    }
    if (toAccount is MultiEd25519Account) {
      return _rotateAuthKeyWithChallenge(
        aptosConfig: aptosConfig,
        fromAccount: fromAccount,
        toAccount: toAccount,
        options: options,
      );
    }
    throw ArgumentError(
      'toAccount must be an Ed25519Account or MultiEd25519Account',
    );
  }
  throw ArgumentError('Invalid arguments');
}

Future<SimpleTransaction> _rotateAuthKeyWithChallenge({
  required AptosConfig aptosConfig,
  required Account fromAccount,
  MultiEd25519Account? toAccount,
  Ed25519PrivateKey? toNewPrivateKey,
  InputGenerateTransactionOptions? options,
}) async {
  final accountInfo = await getInfo(
    aptosConfig: aptosConfig,
    accountAddress: fromAccount.accountAddress,
  );

  final Account newAccount;
  if (toNewPrivateKey != null) {
    newAccount = Account.fromPrivateKey(
      privateKey: toNewPrivateKey,
      legacy: true,
    );
  } else {
    newAccount = toAccount!;
  }

  final challenge = RotationProofChallenge(
    sequenceNumber: BigInt.parse(accountInfo.sequenceNumber),
    originator: fromAccount.accountAddress,
    currentAuthKey: AccountAddress.from(accountInfo.authenticationKey),
    newPublicKey: newAccount.publicKey,
  );

  // Sign the challenge.
  final challengeHex = challenge.bcsToBytes();
  final proofSignedByCurrentKey = fromAccount.sign(challengeHex);
  final proofSignedByNewKey = newAccount.sign(challengeHex);

  // Generate transaction.
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: fromAccount.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::account::rotate_authentication_key',
      functionArguments: [
        U8(fromAccount.signingScheme.value), // from scheme
        MoveVector.u8(fromAccount.publicKey.toUint8Array()),
        U8(newAccount.signingScheme.value), // to scheme
        MoveVector.u8(newAccount.publicKey.toUint8Array()),
        MoveVector.u8(proofSignedByCurrentKey.toUint8Array()),
        MoveVector.u8(proofSignedByNewKey.toUint8Array()),
      ],
      abi: _getRotateAuthKeyAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

// Lazy-initialized to avoid circular dependency issues at module load time.
EntryFunctionABI? _rotateAuthKeyUnverifiedAbi;
EntryFunctionABI _getRotateAuthKeyUnverifiedAbi() {
  return _rotateAuthKeyUnverifiedAbi ??= EntryFunctionABI(
    typeParameters: const [],
    parameters: [TypeTagU8(), TypeTagVector.u8()],
  );
}

/// Rotates the authentication key for a given account without verifying the
/// new key (no proof-of-ownership challenge signed by the new key).
///
/// Returns a [SimpleTransaction] that can be submitted to the network.
Future<SimpleTransaction> rotateAuthKeyUnverified({
  required AptosConfig aptosConfig,
  required Account fromAccount,
  required AccountPublicKey toNewPublicKey,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: fromAccount.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::account::rotate_authentication_key_from_public_key',
      functionArguments: [
        U8(accountPublicKeyToSigningScheme(toNewPublicKey).value), // to scheme
        MoveVector.u8(
          accountPublicKeyToBaseAccountPublicKey(toNewPublicKey).toUint8Array(),
        ),
      ],
      abi: _getRotateAuthKeyUnverifiedAbi(),
    ),
    options: options,
  ) as SimpleTransaction;
}

// ===
// Indexer-backed functions
// ===

/// Retrieves the count of tokens owned by a specific account address.
Future<int> getAccountTokensCount({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountTokensCount,
      variables: {
        'where_condition': {
          'owner_address': {'_eq': address},
          'amount': {'_gt': 0},
        },
      },
    ),
    originMethod: 'getAccountTokensCount',
  );

  final aggregate =
      (data['current_token_ownerships_v2_aggregate'] as Map)['aggregate'];
  return aggregate is Map ? (aggregate['count'] as int? ?? 0) : 0;
}

/// Retrieves the tokens owned by a specified account address.
///
/// [options] - Optional token standard, pagination and ordering parameters.
Future<List<TokenOwnership>> getAccountOwnedTokens({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final whereCondition = <String, dynamic>{
    'owner_address': {'_eq': address},
    'amount': {'_gt': 0},
  };

  if (options?.tokenStandard != null) {
    whereCondition['token_standard'] = {'_eq': options!.tokenStandard!.value};
  }

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountOwnedTokens,
      variables: {
        'where_condition': whereCondition,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getAccountOwnedTokens',
  );

  return (data['current_token_ownerships_v2'] as List)
      .map((e) => TokenOwnership.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the tokens owned by a specific account from a particular
/// collection address.
///
/// [options] - Optional token standard, pagination and ordering parameters.
Future<List<TokenOwnership>> getAccountOwnedTokensFromCollectionAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required AccountAddressInput collectionAddress,
  IndexerQueryArgs? options,
}) async {
  final ownerAddress = AccountAddress.from(accountAddress).toStringLong();
  final collAddress = AccountAddress.from(collectionAddress).toStringLong();

  final whereCondition = <String, dynamic>{
    'owner_address': {'_eq': ownerAddress},
    'current_token_data': {
      'collection_id': {'_eq': collAddress},
    },
    'amount': {'_gt': 0},
  };

  if (options?.tokenStandard != null) {
    whereCondition['token_standard'] = {'_eq': options!.tokenStandard!.value};
  }

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountOwnedTokensFromCollection,
      variables: {
        'where_condition': whereCondition,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getAccountOwnedTokensFromCollectionAddress',
  );

  return (data['current_token_ownerships_v2'] as List)
      .map((e) => TokenOwnership.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the collections owned by a specified account along with the
/// tokens in those collections.
///
/// [options] - Optional token standard, pagination and ordering parameters.
Future<List<AccountCollectionWithOwnedTokens>>
    getAccountCollectionsWithOwnedTokens({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final whereCondition = <String, dynamic>{
    'owner_address': {'_eq': address},
  };

  if (options?.tokenStandard != null) {
    whereCondition['current_collection'] = {
      'token_standard': {'_eq': options!.tokenStandard!.value},
    };
  }

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountCollectionsWithOwnedTokens,
      variables: {
        'where_condition': whereCondition,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getAccountCollectionsWithOwnedTokens',
  );

  return (data['current_collection_ownership_v2_view'] as List)
      .map((e) => AccountCollectionWithOwnedTokens.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the count of transactions associated with a specified account.
Future<int> getAccountTransactionsCount({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountTransactionsCount,
      variables: {'address': address},
    ),
    originMethod: 'getAccountTransactionsCount',
  );

  final aggregate =
      (data['account_transactions_aggregate'] as Map)['aggregate'];
  return aggregate is Map ? (aggregate['count'] as int? ?? 0) : 0;
}

/// Retrieves the amount of a specific coin (or paired fungible asset) held
/// by an account.
///
/// [coinType] - Optional. The type of coin to check the amount for.
/// [faMetadataAddress] - Optional. The address of the fungible asset
/// metadata.
///
/// Returns the amount held by the account, or 0 if none is found.
///
/// Throws an [ArgumentError] if neither [coinType] nor [faMetadataAddress]
/// is provided.
Future<int> getAccountCoinAmount({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  MoveStructId? coinType,
  AccountAddressInput? faMetadataAddress,
}) async {
  String? coinAssetType = coinType;
  final String faAddress;

  if (coinType != null && faMetadataAddress != null) {
    faAddress = AccountAddress.from(faMetadataAddress).toStringLong();
  } else if (coinType != null && faMetadataAddress == null) {
    if (coinType == aptosCoin) {
      faAddress = AccountAddress.a.toStringLong();
    } else {
      faAddress =
          createObjectAddress(AccountAddress.a, coinType).toStringLong();
    }
  } else if (coinType == null && faMetadataAddress != null) {
    final addr = AccountAddress.from(faMetadataAddress);
    faAddress = addr.toStringLong();
    if (addr.equals(AccountAddress.a)) {
      coinAssetType = aptosCoin;
    }
    // The paired CoinType should be populated outside of this function in
    // another async call. We cannot do this internally due to dependency
    // cycles issue.
  } else {
    throw ArgumentError(
      'Either coinType, fungibleAssetAddress, or both must be provided',
    );
  }
  final address = AccountAddress.from(accountAddress).toStringLong();

  // Search by fungible asset address, unless it has a coin it migrated from.
  Map<String, dynamic> where = {
    'asset_type': {'_eq': faAddress},
  };
  if (coinAssetType != null) {
    where = {
      'asset_type': {
        '_in': [coinAssetType, faAddress],
      },
    };
  }

  final data = await getAccountCoinsData(
    aptosConfig: aptosConfig,
    accountAddress: address,
    options: IndexerQueryArgs(where: where),
  );

  if (data.isEmpty || data.first.amount == null) return 0;
  final amount = data.first.amount;
  return amount is int ? amount : int.parse(amount.toString());
}

/// Retrieves the current fungible asset balances (including metadata) for a
/// specified account.
///
/// [options] - Optional pagination, ordering and filtering parameters.
Future<List<CurrentFungibleAssetBalance>> getAccountCoinsData({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final whereCondition = <String, dynamic>{
    ...?options?.where,
    'owner_address': {'_eq': address},
  };

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountCoinsData,
      variables: {
        'where_condition': whereCondition,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getAccountCoinsData',
  );

  return (data['current_fungible_asset_balances'] as List)
      .map((e) => CurrentFungibleAssetBalance.fromJson(
          Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Retrieves the count of fungible asset coins held by a specified account.
///
/// Throws a [StateError] if the count of account coins cannot be retrieved.
Future<int> getAccountCoinsCount({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountCoinsCount,
      variables: {'address': address},
    ),
    originMethod: 'getAccountCoinsCount',
  );

  final aggregate =
      (data['current_fungible_asset_balances_aggregate'] as Map)['aggregate'];
  if (aggregate is! Map) {
    throw StateError('Failed to get the count of account coins');
  }

  return aggregate['count'] as int;
}

/// Retrieves the objects owned by a specified account.
///
/// [options] - Optional pagination and ordering parameters.
Future<List<ObjectData>> getAccountOwnedObjects({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final address = AccountAddress.from(accountAddress).toStringLong();

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getObjectData,
      variables: {
        'where_condition': {
          'owner_address': {'_eq': address},
        },
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
      },
    ),
    originMethod: 'getAccountOwnedObjects',
  );

  return (data['current_objects'] as List)
      .map((e) => ObjectData.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Derives an account from the provided private key.
///
/// This function queries all owned accounts for the provided private key and
/// returns the most recently used account. If no account is found, it will
/// throw an error when [throwIfNoAccountFound] is true; otherwise it returns
/// the default account for the private key via `Account.fromPrivateKey`.
///
/// Note that more inspection is needed by the user to determine which
/// account exists on-chain.
///
/// Deprecated: this heuristic derivation is unreliable and may be removed in
/// a future release.
Future<Account> deriveAccountFromPrivateKey({
  required AptosConfig aptosConfig,
  required PrivateKeyInput privateKey,
  bool throwIfNoAccountFound = false,
}) async {
  final accounts = await _deriveOwnedAccountsFromPrivateKey(
    aptosConfig: aptosConfig,
    privateKey: privateKey,
  );
  if (accounts.isEmpty) {
    if (throwIfNoAccountFound) {
      throw StateError('No existing account found for private key.');
    }
    // If no account is found, return the default account. This is a legacy
    // account for Ed25519 private keys.
    return Account.fromPrivateKey(privateKey: privateKey);
  }
  return accounts.first;
}

/// Checks if an account exists by verifying its information against the
/// Aptos blockchain.
///
/// [authKey] - The authentication key used to derive the account address.
Future<bool> isAccountExist({
  required AptosConfig aptosConfig,
  required AuthenticationKey authKey,
}) async {
  final accountAddress = await lookupOriginalAccountAddress(
    aptosConfig: aptosConfig,
    authenticationKey: authKey.derivedAddress(),
  );

  return _doesAccountExistAtAddress(
    aptosConfig: aptosConfig,
    accountAddress: accountAddress,
  );
}

/// Checks if an account exists at a given address, optionally also matching
/// the provided authentication key.
Future<bool> _doesAccountExistAtAddress({
  required AptosConfig aptosConfig,
  required AccountAddress accountAddress,
  AuthenticationKey? withAuthKey,
}) async {
  try {
    // Get the account resource and the owned objects of the account. We need
    // to check both because an account resource can exist with 0 balance and
    // a balance can exist without an account resource (light accounts).
    final results = await Future.wait<Object?>([
      getResourceFallible<Map<String, dynamic>>(
        aptosConfig: aptosConfig,
        accountAddress: accountAddress,
        resourceType: '0x1::account::Account',
      ),
      getAccountOwnedObjects(
        aptosConfig: aptosConfig,
        accountAddress: accountAddress,
        options: const IndexerQueryArgs(limit: 1),
      ),
    ]);
    final accountResource = results[0] as Map<String, dynamic>?;
    final ownedObjects = results[1] as List<ObjectData>? ?? const [];

    // If the account resource is not found and the balance is 0, then the
    // account does not exist.
    if (accountResource == null && ownedObjects.isEmpty) {
      return false;
    }

    // If no auth key is provided as an argument, return true.
    if (withAuthKey == null) {
      return true;
    }

    // Get the auth key from the account resource if it exists. If the
    // account resource does not exist, then the auth key is the account
    // address by default.
    final String authKey;
    if (accountResource != null) {
      authKey = accountResource['authentication_key'] as String;
    } else {
      authKey = accountAddress.toStringLong();
    }

    if (authKey != withAuthKey.toString()) {
      return false;
    }

    // Else the account exists and the auth key matches.
    return true;
  } catch (error) {
    throw StateError(
      'Error while checking if account exists at $accountAddress: $error',
    );
  }
}

/// Gets all account info (address, account public key, last transaction
/// version) associated with a public key and **related public keys**.
///
/// For a given public key, it will query all multikeys that the public key
/// is part of. Then, for the provided public key and any multikeys found in
/// the previous step, it will query for any accounts that have an auth key
/// that matches any of the public keys.
///
/// Note: If an Ed25519PublicKey or an AnyPublicKey that wraps an
/// Ed25519PublicKey is passed in, both the legacy and single signer cases
/// are queried.
///
/// [includeUnverified] - Whether to include unverified accounts in the
/// results (accounts that can be authenticated with the signer, but have no
/// history of the signer using them). Default is false.
/// [noMultiKey] - If true, do not include multi-key accounts in the results.
Future<List<AccountInfo>> getAccountsForPublicKey({
  required AptosConfig aptosConfig,
  required AccountPublicKey publicKey,
  bool includeUnverified = false,
  bool noMultiKey = false,
}) async {
  if (noMultiKey && publicKey is AbstractMultiKey) {
    throw ArgumentError(
      'Multi-key accounts are not supported when noMultiKey is true.',
    );
  }
  final allPublicKeys = <AccountPublicKey>[publicKey];

  // For Ed25519, we add both the legacy Ed25519PublicKey and the new
  // AnyPublicKey form.
  if (publicKey is AnyPublicKey && publicKey.publicKey is Ed25519PublicKey) {
    allPublicKeys.add(publicKey.publicKey as Ed25519PublicKey);
  } else if (publicKey is Ed25519PublicKey) {
    allPublicKeys.add(AnyPublicKey(publicKey));
  }

  // Run both operations in parallel.
  // Check the provided public keys for default accounts, and get multi-keys
  // for the provided public key if not already a multi-key.
  final defaultAccountData = await Future.wait(
    allPublicKeys.map((key) async {
      final addressAndLastTxnVersion = await _getDefaultAccountInfoForPublicKey(
        aptosConfig: aptosConfig,
        publicKey: key,
      );
      if (addressAndLastTxnVersion != null) {
        return AccountInfo(
          accountAddress: addressAndLastTxnVersion.accountAddress,
          publicKey: key,
          lastTransactionVersion:
              addressAndLastTxnVersion.lastTransactionVersion,
        );
      }
      return null;
    }),
  );
  final multiPublicKeys = publicKey is! AbstractMultiKey && !noMultiKey
      ? await _getMultiKeysForPublicKey(
          aptosConfig: aptosConfig,
          publicKey: publicKey,
          includeUnverified: includeUnverified,
        )
      : <AbstractMultiKey>[];

  final result = <AccountInfo>[];

  // Add any default accounts that exist to the result.
  for (final data in defaultAccountData) {
    if (data != null) {
      result.add(data);
    }
  }

  // Add any multi-keys to allPublicKeys.
  allPublicKeys.addAll(multiPublicKeys);

  // Get a map of the auth key to the public key for all public keys.
  final authKeyToPublicKey = <String, AccountPublicKey>{
    for (final key in allPublicKeys) key.authKey().toString(): key,
  };

  // Get the account addresses for the auth keys.
  final authKeyAccountAddressPairs = await _getAccountAddressesForAuthKeys(
    aptosConfig: aptosConfig,
    authKeys: allPublicKeys.map((key) => key.authKey()).toList(),
    includeUnverified: includeUnverified,
  );

  for (final pair in authKeyAccountAddressPairs) {
    // Skip if the account address is already in the result. This can happen
    // in the rare edge case where the default account has been rotated but
    // has been rotated back to the original auth key.
    if (result.any((r) => r.accountAddress.equals(pair.accountAddress))) {
      continue;
    }
    // Get the public key for the auth key using the map we created earlier.
    final pairPublicKey = authKeyToPublicKey[pair.authKey.toString()];
    if (pairPublicKey == null) {
      throw StateError(
        'No publicKey found for authentication key ${pair.authKey}. This '
        'should never happen.',
      );
    }
    result.add(AccountInfo(
      accountAddress: pair.accountAddress,
      publicKey: pairPublicKey,
      lastTransactionVersion: pair.lastTransactionVersion,
    ));
  }
  // Sort the result by the last transaction version in descending order
  // (most recent first).
  result.sort(
    (a, b) => b.lastTransactionVersion.compareTo(a.lastTransactionVersion),
  );
  return result;
}

/// Derives all accounts owned by a signer. This function takes a signer
/// (either an [Account] or a private key) and returns all accounts that can
/// be derived from it, ordered by the most recently used account first.
///
/// Note: this function will not return accounts that require more than one
/// signer to be used.
Future<List<Account>> deriveOwnedAccountsFromSigner({
  required AptosConfig aptosConfig,
  required Object signer,
  bool includeUnverified = false,
  bool noMultiKey = false,
}) async {
  if (signer is Ed25519PrivateKey || signer is Secp256k1PrivateKey) {
    return _deriveOwnedAccountsFromPrivateKey(
      aptosConfig: aptosConfig,
      privateKey: signer,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }

  if (signer is Ed25519Account) {
    return _deriveOwnedAccountsFromPrivateKey(
      aptosConfig: aptosConfig,
      privateKey: signer.privateKey,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }
  if (signer is AbstractKeylessAccount) {
    return _deriveOwnedAccountsFromKeylessSigner(
      aptosConfig: aptosConfig,
      keylessAccount: signer,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }
  if (signer is SingleKeyAccount) {
    return _deriveOwnedAccountsFromPrivateKey(
      aptosConfig: aptosConfig,
      privateKey: signer.privateKey,
      includeUnverified: includeUnverified,
      noMultiKey: noMultiKey,
    );
  }

  if (signer is MultiKeyAccount) {
    if (signer.signers.length == 1) {
      return deriveOwnedAccountsFromSigner(
        aptosConfig: aptosConfig,
        signer: signer.signers.first,
        includeUnverified: includeUnverified,
        noMultiKey: noMultiKey,
      );
    }
  }

  if (signer is MultiEd25519Account) {
    if (signer.signers.length == 1) {
      return _deriveOwnedAccountsFromPrivateKey(
        aptosConfig: aptosConfig,
        privateKey: signer.signers.first,
        includeUnverified: includeUnverified,
        noMultiKey: noMultiKey,
      );
    }
  }

  throw ArgumentError('Unknown signer type');
}

Future<List<Account>> _deriveOwnedAccountsFromKeylessSigner({
  required AptosConfig aptosConfig,
  required AbstractKeylessAccount keylessAccount,
  bool includeUnverified = false,
  bool noMultiKey = false,
}) async {
  final addressesAndPublicKeys = await getAccountsForPublicKey(
    aptosConfig: aptosConfig,
    publicKey: keylessAccount.getAnyPublicKey(),
    includeUnverified: includeUnverified,
    noMultiKey: noMultiKey,
  );

  final isFederated = keylessAccount.publicKey is FederatedKeylessPublicKey;

  final accounts = <Account>[];
  for (final info in addressesAndPublicKeys) {
    final publicKey = info.publicKey;
    if (publicKey is AbstractMultiKey) {
      if (publicKey.getSignaturesRequired() > 1) {
        continue;
      }
      if (publicKey is MultiEd25519PublicKey) {
        throw StateError(
          'Keyless authentication cannot be used for multi-ed25519 accounts. '
          'This should never happen.',
        );
      } else if (publicKey is MultiKey) {
        accounts.add(MultiKeyAccount(
          multiKey: publicKey,
          signers: [keylessAccount],
          address: info.accountAddress,
        ));
      }
    } else if (isFederated) {
      accounts.add(FederatedKeylessAccount.create(
        address: info.accountAddress,
        proof: keylessAccount.proofOrPromise,
        jwt: keylessAccount.jwt,
        ephemeralKeyPair: keylessAccount.ephemeralKeyPair,
        pepper: keylessAccount.pepper,
        verificationKeyHash: keylessAccount.verificationKeyHash,
        jwkAddress:
            (keylessAccount.publicKey as FederatedKeylessPublicKey).jwkAddress,
      ));
    } else {
      accounts.add(KeylessAccount.create(
        address: info.accountAddress,
        proof: keylessAccount.proofOrPromise,
        jwt: keylessAccount.jwt,
        ephemeralKeyPair: keylessAccount.ephemeralKeyPair,
        pepper: keylessAccount.pepper,
        verificationKeyHash: keylessAccount.verificationKeyHash,
      ));
    }
  }
  return accounts;
}

Future<List<Account>> _deriveOwnedAccountsFromPrivateKey({
  required AptosConfig aptosConfig,
  required PrivateKeyInput privateKey,
  bool includeUnverified = false,
  bool noMultiKey = false,
}) async {
  final PublicKey basePublicKey;
  if (privateKey is Ed25519PrivateKey) {
    basePublicKey = privateKey.publicKey();
  } else if (privateKey is Secp256k1PrivateKey) {
    basePublicKey = privateKey.publicKey();
  } else {
    throw ArgumentError(
      'privateKey must be an Ed25519PrivateKey or Secp256k1PrivateKey',
    );
  }

  final singleKeyAccount =
      Account.fromPrivateKey(privateKey: privateKey, legacy: false);
  final addressesAndPublicKeys = await getAccountsForPublicKey(
    aptosConfig: aptosConfig,
    publicKey: AnyPublicKey(basePublicKey),
    includeUnverified: includeUnverified,
    noMultiKey: noMultiKey,
  );

  final accounts = <Account>[];

  // Iterate through the addressesAndPublicKeys and construct the accounts.
  for (final info in addressesAndPublicKeys) {
    final publicKey = info.publicKey;
    if (publicKey is AbstractMultiKey) {
      // Skip multi-key accounts with more than 1 signature required as the
      // user does not have full ownership with just 1 private key.
      if (publicKey.getSignaturesRequired() > 1) {
        continue;
      }
      // Construct the appropriate multi-key type.
      if (publicKey is MultiEd25519PublicKey) {
        if (privateKey is! Ed25519PrivateKey) {
          throw ArgumentError(
            'Private key not Ed25519 for MultiEd25519 signature',
          );
        }
        accounts.add(MultiEd25519Account(
          publicKey: publicKey,
          signers: [privateKey],
          address: info.accountAddress,
        ));
      } else if (publicKey is MultiKey) {
        accounts.add(MultiKeyAccount(
          multiKey: publicKey,
          signers: [singleKeyAccount],
          address: info.accountAddress,
        ));
      }
    } else {
      // Check if the public key is a legacy Ed25519PublicKey; if so, we need
      // to use the legacy account constructor.
      final isLegacy = publicKey is Ed25519PublicKey;
      accounts.add(Account.fromPrivateKey(
        privateKey: privateKey,
        address: info.accountAddress,
        legacy: isLegacy,
      ));
    }
  }
  return accounts;
}

String _anyPublicKeyVariantToString(AnyPublicKeyVariant variant) {
  switch (variant) {
    case AnyPublicKeyVariant.ed25519:
      return 'ed25519';
    case AnyPublicKeyVariant.secp256k1:
      return 'secp256k1';
    case AnyPublicKeyVariant.secp256r1:
      return 'secp256r1';
    case AnyPublicKeyVariant.keyless:
      return 'keyless';
    case AnyPublicKeyVariant.federatedKeyless:
      return 'federated_keyless';
    case AnyPublicKeyVariant.slhDsaSha2_128s:
      return 'slh_dsa_sha2_128s';
  }
}

/// Gets the multi-keys (MultiKey or MultiEd25519PublicKey) that contain the
/// provided public key. The provided public key cannot itself be a
/// multi-key.
Future<List<AbstractMultiKey>> _getMultiKeysForPublicKey({
  required AptosConfig aptosConfig,
  required AccountPublicKey publicKey,
  bool includeUnverified = false,
}) async {
  if (publicKey is AbstractMultiKey) {
    throw ArgumentError('Public key is a multi-key.');
  }
  final anyPublicKey =
      publicKey is AnyPublicKey ? publicKey : AnyPublicKey(publicKey);
  final baseKey = anyPublicKey.publicKey;
  final variant = _anyPublicKeyVariantToString(anyPublicKey.variant);

  final whereCondition = <String, dynamic>{
    'public_key': {'_eq': baseKey.toString()},
    'public_key_type': {'_eq': variant},
    'account_public_key': {'_is_null': false},
    if (!includeUnverified) 'is_public_key_used': {'_eq': true},
  };

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAuthKeysForPublicKey,
      variables: {'where_condition': whereCondition},
    ),
    originMethod: 'getMultiKeysForPublicKey',
  );

  return (data['public_key_auth_keys'] as List)
      .map(
          (e) => PublicKeyAuthKey.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((entry) => entry.accountPublicKey != null)
      .map<AbstractMultiKey>((entry) {
    switch (entry.signatureType) {
      case 'multi_ed25519_signature':
        return MultiEd25519PublicKey.deserializeWithoutLength(
          Deserializer.fromHex(entry.accountPublicKey!),
        );
      case 'multi_key_signature':
        return MultiKey.deserialize(
          Deserializer.fromHex(entry.accountPublicKey!),
        );
      default:
        throw StateError(
          'Unknown multi-signature type: ${entry.signatureType}',
        );
    }
  }).toList();
}

/// Gets the account addresses associated with the provided authentication
/// keys, ordered by the last transaction version (most recent first).
Future<List<AuthKeyAddressPair>> _getAccountAddressesForAuthKeys({
  required AptosConfig aptosConfig,
  required List<AuthenticationKey> authKeys,
  bool includeUnverified = false,
}) async {
  if (authKeys.isEmpty) {
    throw ArgumentError('No authentication keys provided');
  }
  final whereCondition = <String, dynamic>{
    'auth_key': {
      '_in': authKeys.map((authKey) => authKey.toString()).toList(),
    },
    if (!includeUnverified) 'is_auth_key_used': {'_eq': true},
  };

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getAccountAddressesForAuthKey,
      variables: {
        'where_condition': whereCondition,
        'order_by': [
          {'last_transaction_version': 'desc'},
        ],
      },
    ),
    originMethod: 'getAccountAddressesForAuthKeys',
  );

  return (data['auth_key_account_addresses'] as List)
      .map((e) =>
          AuthKeyAccountAddress.fromJson(Map<String, dynamic>.from(e as Map)))
      .map((entry) => AuthKeyAddressPair(
            authKey: AuthenticationKey(data: entry.authKey),
            accountAddress:
                AccountAddress(Hex.hexInputToUint8List(entry.accountAddress)),
            lastTransactionVersion:
                int.parse(entry.lastTransactionVersion.toString()),
          ))
      .toList();
}

/// Returns the last transaction version that was signed by an account, or 0
/// if the account has not signed any transactions.
Future<int> _getLatestTransactionVersionForAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
}) async {
  final transactions = await getTransactions(
    aptosConfig: aptosConfig,
    accountAddress: accountAddress,
    options: const PaginationArgs(limit: 1),
  );
  if (transactions.isEmpty) {
    return 0;
  }
  return int.parse(transactions.first.version);
}

/// Gets the default account info for a given public key. 'Default account'
/// means the account address is the same as the auth key derived from the
/// public key and the account auth key has not been rotated.
Future<({AccountAddress accountAddress, int lastTransactionVersion})?>
    _getDefaultAccountInfoForPublicKey({
  required AptosConfig aptosConfig,
  required AccountPublicKey publicKey,
}) async {
  final derivedAddress = publicKey.authKey().derivedAddress();

  final results = await Future.wait<Object>([
    _getLatestTransactionVersionForAddress(
      aptosConfig: aptosConfig,
      accountAddress: derivedAddress,
    ),
    _doesAccountExistAtAddress(
      aptosConfig: aptosConfig,
      accountAddress: derivedAddress,
      withAuthKey: publicKey.authKey(),
    ),
  ]);
  final lastTransactionVersion = results[0] as int;
  final exists = results[1] as bool;
  if (exists) {
    return (
      accountAddress: derivedAddress,
      lastTransactionVersion: lastTransactionVersion,
    );
  }
  return null;
}
