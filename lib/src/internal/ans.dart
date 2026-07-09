/// This file contains the underlying implementations for the exposed API
/// surface in `api/ans.dart`.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/ans.dart';
import '../types/indexer.dart';
import '../utils/api_endpoints.dart';
import 'general.dart' show queryIndexer;
import 'queries.dart' as queries;
import 'transaction_submission.dart';
import 'view.dart';

int? _gracePeriodInSeconds;

const int _renewalMonthsWindow = 6;

const String validationRulesDescription =
    'A name must be between 3 and 63 characters long, '
    'and can only contain lowercase a-z, 0-9, and hyphens. '
    'A name may not start or end with a hyphen.';

/// The result of an ANS transaction builder: the built transaction plus the
/// entry function input data it was built from.
typedef AnsTransactionResult = ({
  SimpleTransaction transaction,
  InputEntryFunctionData data,
});

/// Validate if a given fragment is a valid ANS segment.
/// This function checks the length and character constraints of the fragment
/// to ensure it meets the ANS standards.
bool isValidANSSegment(String fragment) {
  if (fragment.isEmpty) return false;
  if (fragment.length < 3) return false;
  if (fragment.length > 63) return false;
  // Only lowercase a-z and 0-9 are allowed, along with -. A domain may not
  // start or end with a hyphen.
  return RegExp(r'^[a-z\d][a-z\d-]{1,61}[a-z\d]$').hasMatch(fragment);
}

/// Checks if an ANS name is valid or not, returning its domain name and
/// optional subdomain name.
///
/// [name] - A string of the domain name, which can include or exclude the
/// `.apt` suffix.
({String domainName, String? subdomainName}) isValidANSName(String name) {
  final parts = name.replaceAll(RegExp(r'\.apt$'), '').split('.');
  final first = parts.isNotEmpty ? parts[0] : '';
  final second = parts.length > 1 ? parts[1] : null;

  if (parts.length > 2) {
    throw ArgumentError(
      '$name is invalid. A name can only have two parts, a domain and a '
      'subdomain separated by a "."',
    );
  }

  if (!isValidANSSegment(first)) {
    throw ArgumentError('$first is not valid. $validationRulesDescription');
  }

  if (second != null && !isValidANSSegment(second)) {
    throw ArgumentError('$second is not valid. $validationRulesDescription');
  }

  return (
    domainName: second ?? first,
    subdomainName: second != null ? first : null,
  );
}

int _parseTimestampMs(Object? timestamp) =>
    DateTime.parse(timestamp.toString()).millisecondsSinceEpoch;

/// Determines the status of an ANS name's expiration.
///
/// [name] - A raw ANS name returned from the indexer.
/// [gracePeriod] - The grace period after expiration, in seconds.
ExpirationStatus getANSExpirationStatus({
  required RawAnsName name,
  required int gracePeriod,
}) {
  final gracePeriodMs = gracePeriod * 1000; // Convert to milliseconds.

  final now = DateTime.now().millisecondsSinceEpoch;

  final tldExpirationTime = _parseTimestampMs(name.domainExpirationTimestamp);
  final nameExpirationTime = _parseTimestampMs(name.expirationTimestamp);

  final isTLDExpired = tldExpirationTime < now;
  final isNameExpired = nameExpirationTime < now;
  final isInGracePeriod =
      isNameExpired && now - nameExpirationTime < gracePeriodMs;
  final isTLDInGracePeriod =
      isTLDExpired && now - tldExpirationTime < gracePeriodMs;

  final hasSubdomain = name.subdomain != null && name.subdomain!.isNotEmpty;

  // If we are a subdomain, if our parent is expired we are always expired.
  if (hasSubdomain && isTLDExpired && !isTLDInGracePeriod) {
    return ExpirationStatus.expired;
  }

  // If we are a subdomain and our expiration policy is to follow the domain,
  // we follow the parent's status (since we know our parent is not fully
  // expired by this point).
  if (hasSubdomain &&
      SubdomainExpirationPolicy.fromValue(name.subdomainExpirationPolicy) ==
          SubdomainExpirationPolicy.followsDomain) {
    if (isTLDInGracePeriod) return ExpirationStatus.inGracePeriod;
    return ExpirationStatus.active;
  }

  // At this point, we are either a TLD or a subdomain with an independent
  // expiration policy, check the name's expiration status.
  if (isInGracePeriod) return ExpirationStatus.inGracePeriod;
  if (isNameExpired) return ExpirationStatus.expired;
  return ExpirationStatus.active;
}

/// The private key of the local (localnet) ANS test account.
///
/// NOTE: this uses a fixed default constant and is not configurable.
const String localAnsAccountPk =
    'ed25519-priv-0x37368b46ce665362562c6d1d4ec01a08c8644c488690df5a17e13ba163e20221';

/// The address of the local (localnet) ANS test account.
///
/// NOTE: this uses a fixed default constant and is not configurable.
const String localAnsAccountAddress =
    '0x585fc9f0f0c54183b039ffc770ca282ebd87307916c215a3e692f2f8e4305e82';

/// The ANS router contract addresses per network. Networks where the ANS
/// contract is not deployed map to `null`.
const Map<Network, String?> networkToAnsContract = {
  Network.testnet:
      '0x5f8fd2347449685cf41d4db97926ec3a096eaf381332be4f1318ad4d16a8497c',
  Network.mainnet:
      '0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c',
  Network.local: localAnsAccountAddress,
  Network.custom: null,
  Network.devnet: null,
  Network.shelbynet: null,
  Network.netna: null,
};

/// Retrieves the address of the ANS contract based on the specified Aptos
/// network configuration.
///
/// Throws a [StateError] if the ANS contract is not deployed to the
/// specified network.
String getRouterAddress(AptosConfig aptosConfig) {
  final address = networkToAnsContract[aptosConfig.network];
  if (address == null) {
    throw StateError(
      'The ANS contract is not deployed to ${aptosConfig.network.value}',
    );
  }
  return address;
}

T? _unwrapOption<T>(Object? option) {
  if (option is Map && option.containsKey('vec') && option['vec'] is List) {
    final vec = option['vec'] as List;
    return vec.isNotEmpty ? vec.first as T : null;
  }
  return null;
}

/// Retrieve the owner address of a specified domain or subdomain.
///
/// Returns the account address of the owner, or null if not found.
Future<AccountAddress?> getOwnerAddress({
  required AptosConfig aptosConfig,
  required String name,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);

  final res = await view(
    aptosConfig: aptosConfig,
    payload: InputViewFunctionData(
      function: '$routerAddress::router::get_owner_addr',
      functionArguments: [parsed.domainName, parsed.subdomainName],
    ),
  );

  final owner = _unwrapOption<String>(res[0]);

  return owner != null ? AccountAddress.from(owner) : null;
}

/// The expiration policy for registering an ANS name.
class RegisterNameExpiration {
  final String policy;
  final int? years;

  /// An epoch number in milliseconds of the date when the subdomain will
  /// expire. Only applicable when the policy is `subdomain:independent`.
  final int? expirationDate;

  const RegisterNameExpiration._(this.policy, this.years, this.expirationDate);

  /// The name will expire after the given number of [years] (currently only
  /// 1 year registrations are supported).
  const RegisterNameExpiration.domain({int years = 1})
      : this._('domain', years, null);

  /// The subdomain will expire at the same time as the domain.
  const RegisterNameExpiration.subdomainFollowDomain()
      : this._('subdomain:follow-domain', null, null);

  /// The subdomain will expire at the given [expirationDate] (epoch
  /// milliseconds).
  const RegisterNameExpiration.subdomainIndependent({
    required int expirationDate,
  }) : this._('subdomain:independent', null, expirationDate);
}

/// Registers a domain or subdomain with the specified parameters. This
/// function ensures that the provided names and expiration policies are
/// valid before proceeding with the registration process.
///
/// [sender] - The account address initiating the name registration.
/// [name] - The name to be registered (domain or subdomain).
/// [expiration] - The expiration policy for the name registration.
/// [transferable] - Whether the name can be transferred to another owner
/// (subdomains only).
/// [toAddress] - The address that will be set as the owner_address of the
/// name; defaults to the sender if not provided.
/// [targetAddress] - The address that this name will resolve to.
Future<AnsTransactionResult> registerName({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required String name,
  required RegisterNameExpiration expiration,
  bool? transferable,
  AccountAddressInput? toAddress,
  AccountAddressInput? targetAddress,
  InputGenerateTransactionOptions? options,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);
  final domainName = parsed.domainName;
  final subdomainName = parsed.subdomainName;

  final hasSubdomainPolicy = expiration.policy == 'subdomain:independent' ||
      expiration.policy == 'subdomain:follow-domain';

  if (subdomainName != null && !hasSubdomainPolicy) {
    throw ArgumentError(
      'Subdomains must have an expiration policy of either '
      "'subdomain:independent' or 'subdomain:follow-domain'",
    );
  }

  if (hasSubdomainPolicy && subdomainName == null) {
    throw ArgumentError(
      'Policy is set to ${expiration.policy} but no subdomain was provided',
    );
  }

  if (expiration.policy == 'domain') {
    final years = expiration.years ?? 1;
    if (years != 1) {
      throw ArgumentError(
        'For now, names can only be registered for 1 year at a time',
      );
    }

    const secondsInYear = 31536000;
    final registrationDuration = years * secondsInYear;

    final data = InputEntryFunctionData(
      function: '$routerAddress::router::register_domain',
      functionArguments: [
        domainName,
        registrationDuration,
        targetAddress,
        toAddress,
      ],
    );

    final transaction = await generateTransaction(
      aptosConfig: aptosConfig,
      sender: AccountAddress.from(sender).toString(),
      data: data,
      options: options,
    ) as SimpleTransaction;

    return (transaction: transaction, data: data);
  }

  // We are a subdomain.
  if (subdomainName == null) {
    throw ArgumentError(
      '${expiration.policy} requires a subdomain to be provided.',
    );
  }

  final tldExpiration =
      await getExpiration(aptosConfig: aptosConfig, name: domainName);
  if (tldExpiration == null) {
    throw StateError('The domain does not exist');
  }

  final expirationDateInMillisecondsSinceEpoch =
      expiration.policy == 'subdomain:independent'
          ? expiration.expirationDate!
          : tldExpiration;

  if (expirationDateInMillisecondsSinceEpoch > tldExpiration) {
    throw ArgumentError(
      'The subdomain expiration time cannot be greater than the domain '
      'expiration time',
    );
  }

  final data = InputEntryFunctionData(
    function: '$routerAddress::router::register_subdomain',
    functionArguments: [
      domainName,
      subdomainName,
      (expirationDateInMillisecondsSinceEpoch / 1000).round(),
      expiration.policy == 'subdomain:follow-domain' ? 1 : 0,
      transferable ?? false,
      targetAddress,
      toAddress,
    ],
  );

  final transaction = await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(sender).toString(),
    data: data,
    options: options,
  ) as SimpleTransaction;

  return (transaction: transaction, data: data);
}

/// Retrieves the expiration time of a specified domain or subdomain in epoch
/// milliseconds, or null if an error occurs.
Future<int?> getExpiration({
  required AptosConfig aptosConfig,
  required String name,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);

  try {
    final res = await view(
      aptosConfig: aptosConfig,
      payload: InputViewFunctionData(
        function: '$routerAddress::router::get_expiration',
        functionArguments: [parsed.domainName, parsed.subdomainName],
      ),
    );

    // Normalize expiration time from epoch seconds to epoch milliseconds.
    return int.parse(res[0].toString()) * 1000;
  } catch (_) {
    return null;
  }
}

/// Retrieves the primary name associated with a given account address,
/// combining the subdomain and domain names when present.
Future<String?> getPrimaryName({
  required AptosConfig aptosConfig,
  required AccountAddressInput address,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);

  final res = await view(
    aptosConfig: aptosConfig,
    payload: InputViewFunctionData(
      function: '$routerAddress::router::get_primary_name',
      functionArguments: [AccountAddress.from(address).toString()],
    ),
  );

  final domainName = _unwrapOption<String>(res[1]);
  final subdomainName = _unwrapOption<String>(res[0]);

  if (domainName == null) return null;

  return [subdomainName, domainName].whereType<String>().join('.');
}

/// Sets the primary name for the specified account. If no [name] is
/// provided, the existing primary name is cleared.
Future<AnsTransactionResult> setPrimaryName({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  String? name,
  InputGenerateTransactionOptions? options,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);

  if (name == null || name.isEmpty) {
    final data = InputEntryFunctionData(
      function: '$routerAddress::router::clear_primary_name',
      functionArguments: const [],
    );

    final transaction = await generateTransaction(
      aptosConfig: aptosConfig,
      sender: AccountAddress.from(sender).toString(),
      data: data,
      options: options,
    ) as SimpleTransaction;

    return (transaction: transaction, data: data);
  }

  final parsed = isValidANSName(name);

  final data = InputEntryFunctionData(
    function: '$routerAddress::router::set_primary_name',
    functionArguments: [parsed.domainName, parsed.subdomainName],
  );

  final transaction = await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(sender).toString(),
    data: data,
    options: options,
  ) as SimpleTransaction;

  return (transaction: transaction, data: data);
}

/// Retrieves the target address associated with a given domain name and
/// subdomain name. The target address is the address this name resolves to,
/// which may be different from who owns the name.
Future<AccountAddress?> getTargetAddress({
  required AptosConfig aptosConfig,
  required String name,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);

  final res = await view(
    aptosConfig: aptosConfig,
    payload: InputViewFunctionData(
      function: '$routerAddress::router::get_target_addr',
      functionArguments: [parsed.domainName, parsed.subdomainName],
    ),
  );

  final target = _unwrapOption<String>(res[0]);
  return target != null ? AccountAddress.from(target) : null;
}

/// Sets the target address for a specified domain or subdomain, associating
/// the given address with the name.
Future<AnsTransactionResult> setTargetAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required String name,
  required AccountAddressInput address,
  InputGenerateTransactionOptions? options,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);

  final data = InputEntryFunctionData(
    function: '$routerAddress::router::set_target_addr',
    functionArguments: [parsed.domainName, parsed.subdomainName, address],
  );

  final transaction = await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(sender).toString(),
    data: data,
    options: options,
  ) as SimpleTransaction;

  return (transaction: transaction, data: data);
}

/// Clears the target address for a specified domain or subdomain, removing
/// the address association.
Future<AnsTransactionResult> clearTargetAddress({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required String name,
  InputGenerateTransactionOptions? options,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final parsed = isValidANSName(name);

  final data = InputEntryFunctionData(
    function: '$routerAddress::router::clear_target_addr',
    functionArguments: [parsed.domainName, parsed.subdomainName],
  );

  final transaction = await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(sender).toString(),
    data: data,
    options: options,
  ) as SimpleTransaction;

  return (transaction: transaction, data: data);
}

/// Retrieves the active Aptos name associated with the specified domain and
/// subdomain, or null if the name is not active.
Future<AnsName?> getName({
  required AptosConfig aptosConfig,
  required String name,
}) async {
  final gracePeriod = await getANSGracePeriod(aptosConfig: aptosConfig);

  final parsed = isValidANSName(name);
  final subdomainName = parsed.subdomainName ?? '';

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    query: GraphqlQuery(
      query: queries.getNames,
      variables: {
        'where_condition': {
          'domain': {'_eq': parsed.domainName},
          'subdomain': {'_eq': subdomainName},
        },
        'limit': 1,
      },
    ),
    originMethod: 'getName',
  );

  final rows = data['current_aptos_names'] as List;
  if (rows.isEmpty) return null;

  final raw = RawAnsName.fromJson(Map<String, dynamic>.from(rows.first as Map));
  return _sanitizeANSName(name: raw, gracePeriod: gracePeriod);
}

/// The result of an ANS names query: the sanitized names plus the total
/// count of matching names.
typedef AnsNamesResult = ({List<AnsName> names, int total});

AnsNamesResult _parseNamesResult({
  required Map<String, dynamic> data,
  required int gracePeriod,
}) {
  final names = (data['current_aptos_names'] as List)
      .map((e) => _sanitizeANSName(
            name: RawAnsName.fromJson(Map<String, dynamic>.from(e as Map)),
            gracePeriod: gracePeriod,
          ))
      .toList();
  final aggregate =
      (data['current_aptos_names_aggregate'] as Map)['aggregate'];
  final total = aggregate is Map ? (aggregate['count'] as int? ?? 0) : 0;
  return (names: names, total: total);
}

/// Retrieves all the current Aptos names owned by an account (via the
/// `owner_address` field, not the `registered_address` field).
Future<AnsNamesResult> getAccountNames({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final gracePeriod = await getANSGracePeriod(aptosConfig: aptosConfig);

  final expirationDate = await _getANSExpirationDate(aptosConfig: aptosConfig);

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    originMethod: 'getAccountNames',
    query: GraphqlQuery(
      query: queries.getNames,
      variables: {
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
        'where_condition': {
          'owner_address': {'_eq': accountAddress.toString()},
          'expiration_timestamp': {'_gte': expirationDate},
          ...?options?.where,
        },
      },
    ),
  );

  return _parseNamesResult(data: data, gracePeriod: gracePeriod);
}

/// Retrieves the list of top-level domains owned by a specified account,
/// using the `owner_address` field.
Future<AnsNamesResult> getAccountDomains({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final gracePeriod = await getANSGracePeriod(aptosConfig: aptosConfig);

  final expirationDate = await _getANSExpirationDate(aptosConfig: aptosConfig);

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    originMethod: 'getAccountDomains',
    query: GraphqlQuery(
      query: queries.getNames,
      variables: {
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
        'where_condition': {
          'owner_address': {'_eq': accountAddress.toString()},
          'expiration_timestamp': {'_gte': expirationDate},
          'subdomain': {'_eq': ''},
          ...?options?.where,
        },
      },
    ),
  );

  return _parseNamesResult(data: data, gracePeriod: gracePeriod);
}

/// Retrieves a list of subdomains owned by a specified account address,
/// determined by the `owner_address` field.
Future<AnsNamesResult> getAccountSubdomains({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  IndexerQueryArgs? options,
}) async {
  final gracePeriod = await getANSGracePeriod(aptosConfig: aptosConfig);

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    originMethod: 'getAccountSubdomains',
    query: GraphqlQuery(
      query: queries.getNames,
      variables: {
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
        'where_condition': {
          'owner_address': {'_eq': accountAddress.toString()},
          'subdomain': {'_neq': ''},
          ...?options?.where,
        },
      },
    ),
  );

  return _parseNamesResult(data: data, gracePeriod: gracePeriod);
}

/// Retrieve the active subdomains associated with a specified domain,
/// regardless of who is in possession of the domain.
Future<AnsNamesResult> getDomainSubdomains({
  required AptosConfig aptosConfig,
  required String domain,
  IndexerQueryArgs? options,
}) async {
  final gracePeriod = await getANSGracePeriod(aptosConfig: aptosConfig);

  final data = await queryIndexer(
    aptosConfig: aptosConfig,
    originMethod: 'getDomainSubdomains',
    query: GraphqlQuery(
      query: queries.getNames,
      variables: {
        if (options?.limit != null) 'limit': options!.limit,
        if (options?.offset != null) 'offset': options!.offset,
        if (options?.orderBy != null)
          'order_by': orderByToJson(options!.orderBy),
        'where_condition': {
          'domain': {'_eq': domain},
          'subdomain': {'_neq': ''},
          ...?options?.where,
        },
      },
    ),
  );

  return _parseNamesResult(data: data, gracePeriod: gracePeriod);
}

/// Returns the expiration date (as a UTC ISO string) before which a name is
/// fully expired as defined by the contract. The grace period allows names
/// to be past expiration for a certain amount of time before they are
/// released to the public.
Future<String> _getANSExpirationDate({required AptosConfig aptosConfig}) async {
  final gracePeriodInSeconds =
      await getANSGracePeriod(aptosConfig: aptosConfig);
  return DateTime.now()
      .toUtc()
      .subtract(Duration(seconds: gracePeriodInSeconds))
      .toIso8601String();
}

/// Returns the grace period in seconds as defined by the contract. A name
/// that is past expiration but within the grace period is considered in
/// grace period and can't be claimed by others. The value is cached after
/// the first fetch.
Future<int> getANSGracePeriod({required AptosConfig aptosConfig}) async {
  if (_gracePeriodInSeconds != null) {
    return _gracePeriodInSeconds!;
  }

  final routerAddress = getRouterAddress(aptosConfig);

  final res = await view(
    aptosConfig: aptosConfig,
    payload: InputViewFunctionData(
      function: '$routerAddress::config::reregistration_grace_sec',
      functionArguments: const [],
    ),
  );

  final gracePeriodInSeconds = int.parse(res[0].toString());
  _gracePeriodInSeconds = gracePeriodInSeconds;
  return gracePeriodInSeconds;
}

/// Clears the cached ANS grace period (for tests).
void clearANSGracePeriodCache() {
  _gracePeriodInSeconds = null;
}

/// Renews a domain for one year. Subdomains cannot be renewed.
Future<AnsTransactionResult> renewDomain({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required String name,
  int years = 1,
  InputGenerateTransactionOptions? options,
}) async {
  final routerAddress = getRouterAddress(aptosConfig);
  final renewalDuration = years * 31536000;
  final parsed = isValidANSName(name);

  if (parsed.subdomainName != null) {
    throw ArgumentError('Subdomains cannot be renewed');
  }

  if (years != 1) {
    throw ArgumentError('Currently, only 1 year renewals are supported');
  }

  final data = InputEntryFunctionData(
    function: '$routerAddress::router::renew_domain',
    functionArguments: [parsed.domainName, renewalDuration],
  );

  final transaction = await generateTransaction(
    aptosConfig: aptosConfig,
    sender: AccountAddress.from(sender).toString(),
    data: data,
    options: options,
  ) as SimpleTransaction;

  return (transaction: transaction, data: data);
}

/// The indexer returns ISO strings for expiration, however the contract
/// works in epoch milliseconds. This function normalizes the raw name and
/// derives the expiration status fields.
AnsName _sanitizeANSName({
  required RawAnsName name,
  required int gracePeriod,
}) {
  final expirationTimestamp = '${name.expirationTimestamp}Z';
  final domainExpirationTimestamp = '${name.domainExpirationTimestamp}Z';

  final isSubdomain = name.subdomain != null && name.subdomain!.isNotEmpty;
  final expirationPolicy =
      SubdomainExpirationPolicy.fromValue(name.subdomainExpirationPolicy);
  final expiration =
      isSubdomain && expirationPolicy == SubdomainExpirationPolicy.followsDomain
          ? domainExpirationTimestamp
          : expirationTimestamp;

  final expirationStatus =
      getANSExpirationStatus(name: name, gracePeriod: gracePeriod);

  var isInRenewablePeriod = false;
  final expirationDate = DateTime.parse(expiration);
  if (expirationStatus == ExpirationStatus.inGracePeriod) {
    isInRenewablePeriod = true;
  } else if (expirationStatus == ExpirationStatus.active) {
    // Check if the name is within the renewal window (6 months before
    // expiration).
    final now = DateTime.now();
    final renewalWindowDate = DateTime(
      now.year,
      now.month + _renewalMonthsWindow,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );

    isInRenewablePeriod = expirationDate.isBefore(renewalWindowDate);
  }

  // Pass nullable indexer fields through as `null` rather than fabricating
  // placeholder values. `subdomainExpirationPolicy` keeps a default of
  // `followsDomain` because that is the contract's semantic fallback for
  // subdomains, not a fabrication.
  return AnsName(
    domain: name.domain,
    subdomain: isSubdomain ? name.subdomain : null,
    expirationTimestamp: expirationTimestamp,
    expirationStatus: expirationStatus,
    domainExpirationTimestamp: domainExpirationTimestamp,
    expiration: expirationDate,
    tokenStandard: name.tokenStandard,
    isPrimary: name.isPrimary,
    subdomainExpirationPolicy:
        expirationPolicy ?? SubdomainExpirationPolicy.followsDomain,
    ownerAddress: name.ownerAddress,
    registeredAddress: name.registeredAddress,
    isInRenewablePeriod: isInRenewablePeriod,
  );
}
