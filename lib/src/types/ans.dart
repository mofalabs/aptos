/// Types for the Aptos Name Service (ANS), including the raw `GetNames` query
/// row shape.
library;

/// Policy for determining how subdomains expire in relation to their parent
/// domain.
enum SubdomainExpirationPolicy {
  /// The subdomain will expire independently of the domain. The owner of the
  /// domain can manually set when the subdomain expires.
  independent(0),

  /// The subdomain will expire at the same time as the domain.
  followsDomain(1);

  const SubdomainExpirationPolicy(this.value);

  final int value;

  /// Returns the policy matching the given numeric value, or null.
  static SubdomainExpirationPolicy? fromValue(Object? value) {
    if (value == null) return null;
    final numeric = value is int ? value : int.tryParse(value.toString());
    for (final policy in SubdomainExpirationPolicy.values) {
      if (policy.value == numeric) return policy;
    }
    return null;
  }
}

/// The status of an ANS name's expiration.
enum ExpirationStatus {
  /// The name no longer functions as a primary or target name. It is open to
  /// being claimed by the public.
  expired('expired'),

  /// The name is past its expiration date, but only claimable by the current
  /// owner of the name. It does not function as a primary or target name.
  inGracePeriod('in_grace_period'),

  /// The name is in good standing.
  active('active');

  const ExpirationStatus(this.value);

  final String value;
}

/// A raw ANS name row as returned by the indexer's `GetNames` query
/// (the `AnsTokenFragment` fragment of `current_aptos_names`).
class RawAnsName {
  /// The domain name. ie "aptos.apt" would have a domain of "aptos".
  final String? domain;

  /// The expiration timestamp (an ISO timestamp string from the indexer).
  final dynamic expirationTimestamp;

  /// The address that the name points to.
  final String? registeredAddress;

  /// The subdomain name, if the name is a subdomain.
  final String? subdomain;

  /// The token standard for the name (`v1` or `v2`).
  final String? tokenStandard;

  /// Whether the name is registered as a primary name for any account.
  final bool? isPrimary;

  /// The address of the wallet that owns the name.
  final String? ownerAddress;

  /// The expiration policy for the subdomain (0 = independent,
  /// 1 = follows domain).
  final dynamic subdomainExpirationPolicy;

  /// The expiration timestamp of the parent domain (an ISO timestamp string
  /// from the indexer).
  final dynamic domainExpirationTimestamp;

  const RawAnsName({
    this.domain,
    this.expirationTimestamp,
    this.registeredAddress,
    this.subdomain,
    this.tokenStandard,
    this.isPrimary,
    this.ownerAddress,
    this.subdomainExpirationPolicy,
    this.domainExpirationTimestamp,
  });

  factory RawAnsName.fromJson(Map<String, dynamic> json) => RawAnsName(
        domain: json['domain'] as String?,
        expirationTimestamp: json['expiration_timestamp'],
        registeredAddress: json['registered_address'] as String?,
        subdomain: json['subdomain'] as String?,
        tokenStandard: json['token_standard'] as String?,
        isPrimary: json['is_primary'] as bool?,
        ownerAddress: json['owner_address'] as String?,
        subdomainExpirationPolicy: json['subdomain_expiration_policy'],
        domainExpirationTimestamp: json['domain_expiration_timestamp'],
      );
}

/// A sanitized ANS name, with expiration timestamps normalized and derived
/// expiration status fields populated.
class AnsName {
  /// The domain name. ie "aptos.apt" would have a domain of "aptos".
  ///
  /// The indexer schema marks this field as nullable; callers should treat a
  /// missing `domain` as a bad row.
  final String? domain;

  /// The subdomain name, if the name is a subdomain. ie "name.aptos.apt"
  /// would have a subdomain of "name".
  final String? subdomain;

  /// The expiration timestamp of the name as a UTC ISO string. Note, if the
  /// name is not a subdomain, this will be the same as the domain expiration
  /// timestamp.
  final String expirationTimestamp;

  /// The expiration timestamp of the domain as a UTC ISO string.
  final String domainExpirationTimestamp;

  /// A derived date value. It takes into consideration if the name is a
  /// subdomain and its expiration policy.
  final DateTime expiration;

  /// The status of the name's expiration. See [ExpirationStatus].
  final ExpirationStatus expirationStatus;

  /// The address that the name points to.
  final String? registeredAddress;

  /// The token standard for the name (`v1` or `v2`).
  final String? tokenStandard;

  /// If the name is registered as a primary name for _any_ account.
  final bool? isPrimary;

  /// The address of the wallet that owns the name.
  final String? ownerAddress;

  /// The expiration policy for the subdomain. See
  /// [SubdomainExpirationPolicy].
  final SubdomainExpirationPolicy subdomainExpirationPolicy;

  /// Whether the name is in the renewable period. This incorporates leading
  /// time before the name expires and the grace period after the name
  /// expires.
  final bool isInRenewablePeriod;

  const AnsName({
    this.domain,
    this.subdomain,
    required this.expirationTimestamp,
    required this.domainExpirationTimestamp,
    required this.expiration,
    required this.expirationStatus,
    this.registeredAddress,
    this.tokenStandard,
    this.isPrimary,
    this.ownerAddress,
    required this.subdomainExpirationPolicy,
    required this.isInRenewablePeriod,
  });
}
