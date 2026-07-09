import '../core/account_address.dart';
import '../internal/ans.dart' as internal_ans;
import '../internal/ans.dart'
    show AnsTransactionResult, AnsNamesResult, RegisterNameExpiration;
import '../transactions/types.dart';
import '../types/ans.dart';
import '../types/indexer.dart';
import 'aptos_config.dart';

export '../internal/ans.dart'
    show AnsTransactionResult, AnsNamesResult, RegisterNameExpiration;

/// A class to handle all `ANS` (Aptos Name Service) operations.
///
/// NOTE: named `Ans` following Dart's UpperCamelCase acronym style.
class Ans {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Ans` namespace with the specified
  /// configuration.
  const Ans(this.config);

  /// Retrieve the owner address of a specified domain name or subdomain name
  /// from the contract.
  ///
  /// Returns the [AccountAddress] if the name is owned, null otherwise.
  Future<AccountAddress?> getOwnerAddress({required String name}) {
    return internal_ans.getOwnerAddress(aptosConfig: config, name: name);
  }

  /// Retrieve the expiration time of a domain name or subdomain name from
  /// the contract, in epoch milliseconds; null if the name is not registered.
  Future<int?> getExpiration({required String name}) {
    return internal_ans.getExpiration(aptosConfig: config, name: name);
  }

  /// Retrieve the target address of a domain or subdomain name (the address
  /// the name points to), or null if none is set.
  Future<AccountAddress?> getTargetAddress({required String name}) {
    return internal_ans.getTargetAddress(aptosConfig: config, name: name);
  }

  /// Sets the target address of a domain or subdomain name, pointing it to
  /// the specified address.
  ///
  /// Returns a record with the built transaction and its entry function
  /// input data.
  Future<AnsTransactionResult> setTargetAddress({
    required AccountAddressInput sender,
    required String name,
    required AccountAddressInput address,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_ans.setTargetAddress(
      aptosConfig: config,
      sender: sender,
      name: name,
      address: address,
      options: options,
    );
  }

  /// Clears the target address of a domain or subdomain name, removing the
  /// address association.
  Future<AnsTransactionResult> clearTargetAddress({
    required AccountAddressInput sender,
    required String name,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_ans.clearTargetAddress(
      aptosConfig: config,
      sender: sender,
      name: name,
      options: options,
    );
  }

  /// Retrieve the primary name for an account, or null when the account does
  /// not have one.
  Future<String?> getPrimaryName({required AccountAddressInput address}) {
    return internal_ans.getPrimaryName(aptosConfig: config, address: address);
  }

  /// Sets the primary name for the sender; when [name] is omitted, the
  /// primary name is cleared.
  Future<AnsTransactionResult> setPrimaryName({
    required AccountAddressInput sender,
    String? name,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_ans.setPrimaryName(
      aptosConfig: config,
      sender: sender,
      name: name,
      options: options,
    );
  }

  /// Registers a new name (domain or subdomain) with the specified
  /// expiration policy and options.
  Future<AnsTransactionResult> registerName({
    required AccountAddressInput sender,
    required String name,
    required RegisterNameExpiration expiration,
    bool? transferable,
    AccountAddressInput? toAddress,
    AccountAddressInput? targetAddress,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_ans.registerName(
      aptosConfig: config,
      sender: sender,
      name: name,
      expiration: expiration,
      transferable: transferable,
      toAddress: toAddress,
      targetAddress: targetAddress,
      options: options,
    );
  }

  /// Renews a domain name for one year. If a domain name was minted with V1
  /// of the contract, it will automatically be upgraded to V2 via this
  /// transaction.
  Future<AnsTransactionResult> renewDomain({
    required AccountAddressInput sender,
    required String name,
    int years = 1,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_ans.renewDomain(
      aptosConfig: config,
      sender: sender,
      name: name,
      years: years,
      options: options,
    );
  }

  /// Fetches a single name from the indexer, e.g. "test.aptos.apt",
  /// "test.apt" or "test" (inclusive or exclusive of the `.apt` suffix).
  ///
  /// Returns the [AnsName] or null if the name is not active.
  Future<AnsName?> getName({required String name}) {
    return internal_ans.getName(aptosConfig: config, name: name);
  }

  /// Fetches all names (domains and subdomains) for an account, using the
  /// `owner_address` field.
  Future<AnsNamesResult> getAccountNames({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) {
    return internal_ans.getAccountNames(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Fetches all top-level domain names for an account.
  Future<AnsNamesResult> getAccountDomains({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) {
    return internal_ans.getAccountDomains(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Fetches all subdomain names for an account.
  Future<AnsNamesResult> getAccountSubdomains({
    required AccountAddressInput accountAddress,
    IndexerQueryArgs? options,
  }) {
    return internal_ans.getAccountSubdomains(
      aptosConfig: config,
      accountAddress: accountAddress,
      options: options,
    );
  }

  /// Fetches all subdomain names for a given domain, regardless of who owns
  /// them.
  Future<AnsNamesResult> getDomainSubdomains({
    required String domain,
    IndexerQueryArgs? options,
  }) {
    return internal_ans.getDomainSubdomains(
      aptosConfig: config,
      domain: domain,
      options: options,
    );
  }
}
