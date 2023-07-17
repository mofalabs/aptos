
import 'package:aptos/aptos.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/indexer_client.dart';
import 'package:aptos/models/table_item.dart';

const ansContractsMap = (
  testnet: "0x5f8fd2347449685cf41d4db97926ec3a096eaf381332be4f1318ad4d16a8497c",
  mainnet: "0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c",
);

// Each name component can only have lowercase letters, number or hyphens, and cannot start or end with a hyphen.
final nameComponentPattern = RegExp(r'^[a-z\d][a-z\d-]{1,61}[a-z\d]$');

final namePattern = RegExp(
    // Optional subdomain (cannot be followed by .apt)
    r"^(?:(?<subdomain>[^.]+)\.(?!apt$))?" +
    // Domain
    r"(?<domain>[^.]+)" +
    // Optional .apt suffix
    r"(?:\.apt)?$"
);

class AnsClient {

  final Network network;
  late final String contractAddress;
  late final AptosClient aptosClient;
  late final IndexerClient indexerClient;

  AnsClient(this.network,{String? fullNodeEndpoint, String? indexerEndpoint}) {
    switch (network) {
      case Network.mainnet:
        contractAddress = ansContractsMap.mainnet;
        aptosClient = AptosClient(fullNodeEndpoint ?? Constants.mainnetAPI);
        indexerClient = IndexerClient(indexerEndpoint ?? Constants.mainnetIndexer);
        break;
      case Network.testnet:
        contractAddress = ansContractsMap.testnet;
        aptosClient = AptosClient(fullNodeEndpoint ?? Constants.testnetAPI);
        indexerClient = IndexerClient(indexerEndpoint ?? Constants.testnetIndexer);
        break;
      case Network.devnet:
        contractAddress = ansContractsMap.testnet;
        aptosClient = AptosClient(fullNodeEndpoint ?? Constants.devnetAPI);
        indexerClient = IndexerClient(indexerEndpoint ?? Constants.devnetIndexer);
        break;
      default:
        throw ArgumentError("Undefined network type $network");
    }
  }

  /// Returns the primary name for the given account [address].
  Future<String?> getPrimaryNameByAddress(String address) async {
    final ansResource = await aptosClient.getAccountResource(
      contractAddress,
      "$contractAddress::domains::ReverseLookupRegistryV1",
    );
    final handle = ansResource["data"]["registry"]["handle"];
    final domainsTableItemRequest = TableItem(
      "address", 
      "$contractAddress::domains::NameRecordKeyV1", 
      address
    );

    try {
      final item = await aptosClient.queryTableItem(handle, domainsTableItemRequest);
      final vec = item["subdomain_name"]["vec"] as List;
      return vec.isNotEmpty ? "${vec.first}.${item["domain_name"]}" : item["domain_name"];
    } catch (e) {
      // response is 404 error - meaning item not found
      dynamic err = e;
      if (err.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

   /// Returns the target account address for the given [name]
  Future<String?> getAddressByName(String name) async {
    final match = namePattern.firstMatch(name);
    if (match == null || match.groupCount == 0) return null;
    final domain = match.namedGroup("domain");
    if (domain == null) return null;
    final subdomain = match.namedGroup("subdomain");
    final registration = subdomain != null
      ? await getRegistrationForSubdomainName(domain, subdomain)
      : await getRegistrationForDomainName(domain);
    return registration?.$1;
  }

  /// Mint a new Aptos name.
  ///
  /// [account] AptosAccount where collection will be created.
  /// [domainName] Aptos domain name to mint.
  /// [years] year duration of the domain name.
  /// Return the hash of the pending transaction submitted to the API.
  Future<String> mintAptosName(
    AptosAccount account,
    String domainName,{
    int years = 1,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    // check if the name is valid
    if (!nameComponentPattern.hasMatch(domainName)) {
      throw ArgumentError("Name $domainName is not valid");
    }
    // check if the name is available
    final registration = await getRegistrationForDomainName(domainName);
    if (registration != null) {
      final now = (DateTime.now().millisecondsSinceEpoch / 1000).ceil();
      if (now < registration.$2) {
        throw ArgumentError("Name $domainName is not available");
      }
    }

    final buildConfig = ABIBuilderConfig(
      sender: account.address,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp
    );
    final builder = TransactionBuilderRemoteABI(aptosClient, buildConfig);
    final rawTxn = await builder.build("$contractAddress::domains::register_domain", [], [domainName, years]);

    final bcsTxn = AptosClient.generateBCSTransaction(account, rawTxn);
    final pendingTransaction = await aptosClient.submitSignedBCSTransaction(bcsTxn);

    return pendingTransaction["hash"];
  }

  /// Mint a new Aptos Subdomain.
  ///
  /// [account] AptosAccount the owner of the domain name.
  /// [subdomainName] subdomain name to mint.
  /// [domainName] Aptos domain name to mint under.
  /// [expirationTimestampSeconds] must be set between the domains expiration and the current time.
  /// Return the hash of the pending transaction submitted to the API.
  Future<dynamic> mintAptosSubdomain(
    AptosAccount account,
    String subdomainName,
    String domainName,{
    int? expirationTimestampSeconds,
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    // check if the domainName is valid
    if (!nameComponentPattern.hasMatch(domainName)) {
      throw ArgumentError("Domain name $domainName is not valid");
    }
    // check if the subdomainName is valid
    if (!nameComponentPattern.hasMatch(subdomainName)) {
      throw ArgumentError("Subdomain name $subdomainName is not valid");
    }
    // check if the name is available
    final subdomainRegistration = await getRegistrationForSubdomainName(domainName, subdomainName);
    if (subdomainRegistration != null) {
      final now = (DateTime.now().millisecondsSinceEpoch / 1000).ceil();
      if (now < subdomainRegistration.$2) {
        throw ArgumentError("Name $subdomainName.$domainName is not available");
      }
    }

    final domainRegistration = await getRegistrationForDomainName(domainName);
    if (domainRegistration == null) {
      throw ArgumentError("Domain name $domainName does not exist");
    }
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).ceil();
    if (domainRegistration.$2 < now) {
      throw ArgumentError("Domain name $domainName expired");
    }

    final actualExpirationTimestampSeconds =
      expirationTimestampSeconds ?? domainRegistration.$2;
    if (actualExpirationTimestampSeconds < now) {
      throw ArgumentError("Expiration for $subdomainName.$domainName is before now");
    }

    final buildConfig = ABIBuilderConfig(
      sender: account.address,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp
    );
    final builder = TransactionBuilderRemoteABI(aptosClient, buildConfig);
    final rawTxn = await builder.build(
      "$contractAddress::domains::register_subdomain",
      [],
      [subdomainName, domainName, actualExpirationTimestampSeconds]
    );

    final bcsTxn = AptosClient.generateBCSTransaction(account, rawTxn);
    final pendingTransaction = await aptosClient.submitSignedBCSTransaction(bcsTxn);

    return pendingTransaction["hash"];
  }

  /// [account] AptosAccount the owner of the domain name.
  /// [subdomainName] subdomain name to mint.
  /// [domainName] Aptos domain name to mint.
  /// [target] the target address for the subdomain.
  /// Return the hash of the pending transaction submitted to the API.
  Future<String> setSubdomainAddress(
    AptosAccount account,
    String subdomainName,
    String domainName,
    String target,{
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    final standardizeAddress = AccountAddress.standardizeAddress(target);

    // check if the name is valid
    if (!nameComponentPattern.hasMatch(domainName)) {
      throw ArgumentError("Name $domainName is not valid");
    }
    // check if the name is valid
    if (!nameComponentPattern.hasMatch(subdomainName)) {
      throw ArgumentError("Name $subdomainName is not valid");
    }

    final buildConfig = ABIBuilderConfig(
      sender: account.address,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp
    );
    final builder = TransactionBuilderRemoteABI(aptosClient, buildConfig);
    final rawTxn = await builder.build(
      "$contractAddress::domains::set_subdomain_address",
      [],
      [subdomainName, domainName, standardizeAddress]
    );

    final bcsTxn = AptosClient.generateBCSTransaction(account, rawTxn);
    final pendingTransaction = await aptosClient.submitSignedBCSTransaction(bcsTxn);

    return pendingTransaction["hash"];
  }

  /// Initialize reverse lookup for contract owner.
  ///
  /// [owner] the `aptos_names` AptosAccount.
  /// Return the hash of the pending transaction submitted to the API.
  Future<String> initReverseLookupRegistry(
    AptosAccount owner,{
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp
  }) async {
    final buildConfig = ABIBuilderConfig(
      sender: owner.address,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp
    );
    final builder = TransactionBuilderRemoteABI(aptosClient, buildConfig);
    final rawTxn = await builder.build(
      "$contractAddress::domains::init_reverse_lookup_registry_v1",
      [],
      []
    );

    final bcsTxn = AptosClient.generateBCSTransaction(owner, rawTxn);
    final pendingTransaction = await aptosClient.submitSignedBCSTransaction(bcsTxn);

    return pendingTransaction["hash"];
  }

  /// e.g. if name is `aptos.apt`, domain = aptos
  Future<(String? target, int expirationTimestampSeconds)?> getRegistrationForDomainName(String domain) async {
    if (!nameComponentPattern.hasMatch(domain)) return null;
    final ansResource = await aptosClient.getAccountResource(
      contractAddress,
      "$contractAddress::domains::NameRegistryV1",
    );

    final handle = ansResource["data"]["registry"]["handle"];
    final domainsTableItemRequest = TableItem(
      "$contractAddress::domains::NameRecordKeyV1", 
      "$contractAddress::domains::NameRecordV1", 
      {
        "subdomain_name": { "vec": [] },
        "domain_name": domain,
      }
    );

    try {
      final item = await aptosClient.queryTableItem(handle, domainsTableItemRequest);
      final vec = item["target_address"]["vec"] as List;
      return (
        vec.isNotEmpty ? vec.first.toString() : null,
        int.parse(item["expiration_time_sec"].toString())
      );
    } catch (e) {
      // response is 404 error - meaning item not found
      dynamic err = e;
      if (err.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// e.g. if name is `dev.aptos.apt`, domain = aptos, subdomain = dev
  Future<(dynamic target, dynamic expirationTimestampSeconds)?> getRegistrationForSubdomainName(String domain, String subdomain) async {
    if (!nameComponentPattern.hasMatch(domain)) return null;
    if (!nameComponentPattern.hasMatch(subdomain)) return null;

    final ansResource = await aptosClient.getAccountResource(
      contractAddress,
      "$contractAddress::domains::NameRegistryV1",
    );

    final handle = ansResource["data"]["registry"]["handle"];
    final domainsTableItemRequest = TableItem(
      "$contractAddress::domains::NameRecordKeyV1", 
      "$contractAddress::domains::NameRecordV1", 
      {
        "subdomain_name": { "vec": [subdomain] },
        "domain_name": domain,
      }
    );

    try {
      final item = await aptosClient.queryTableItem(handle, domainsTableItemRequest);
      final vec = item["target_address"]["vec"] as List;
      return (
        vec.isNotEmpty ? vec.first.toString() : null,
        int.parse(item["expiration_time_sec"].toString())
      );
    } catch (e) {
      // response is 404 error - meaning item not found
      dynamic err = e;
      if (err.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
