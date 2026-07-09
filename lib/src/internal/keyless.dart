/// This file contains the underlying implementations for the exposed API
/// surface in `api/keyless.dart`. By moving the methods out into a separate
/// file, other namespaces and processes can access these methods without
/// depending on the entire keyless namespace and without having a dependency
/// cycle error.
///
/// This file also hosts the network-backed keyless lookups (`getKeylessConfig`,
/// `fetchJWK`, `getKeylessJWKs` and the resource fetchers), because the core
/// crypto module has no dependency on the HTTP client.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../account/abstract_keyless_account.dart';
import '../account/account.dart';
import '../account/ephemeral_key_pair.dart';
import '../account/federated_keyless_account.dart';
import '../account/keyless_account.dart';
import '../api/aptos_config.dart';
import '../bcs/deserializer.dart';
import '../bcs/serializable/move_structs.dart';
import '../client/get.dart';
import '../client/post.dart';
import '../client/types.dart';
import '../core/account_address.dart';
import '../core/crypto/ephemeral.dart';
import '../core/crypto/federated_keyless.dart';
import '../core/crypto/keyless.dart';
import '../core/crypto/public_key.dart';
import '../core/hex.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/keyless.dart';
import '../types/pagination.dart';
import '../types/types.dart';
import '../utils/const.dart';
import '../utils/helpers.dart';
import '../utils/memoize.dart';
import 'account.dart';
import 'transaction_submission.dart';

/// Retrieves a pepper value based on the provided configuration and
/// authentication details.
///
/// [jwt] - The JSON Web Token used for authentication.
/// [ephemeralKeyPair] - The ephemeral key pair used for the operation.
/// [uidKey] - An optional unique identifier key (defaults to "sub").
/// [derivationPath] - An optional derivation path for the key.
///
/// Returns a [Uint8List] containing the fetched pepper value.
Future<Uint8List> getPepper({
  required AptosConfig aptosConfig,
  required String jwt,
  required EphemeralKeyPair ephemeralKeyPair,
  String uidKey = 'sub',
  String? derivationPath,
}) async {
  final response = await postAptosPepperService(
    aptosConfig: aptosConfig,
    path: 'fetch',
    body: _pepperServiceBody(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
      derivationPath: derivationPath,
    ),
    originMethod: 'getPepper',
    overrides: const AptosRequestOverrides(withCredentials: false),
  );
  final pepper = (response.data as Map)['pepper'] as String;
  return Hex.fromHexInput(pepper).toUint8List();
}

/// Retrieves the `pepper_base` for an account — the VUF signature from which
/// the final pepper is derived.
///
/// Unlike [getPepper] (which hits the pepper service `fetch` endpoint and
/// returns the 31-byte derived pepper), this hits the `signature` endpoint
/// and returns the raw 48-byte `pepper_base` (a compressed BLS12-381 G1
/// point). `pepper_base` is deterministic for a given OIDC identity,
/// independent of the ephemeral key and of the derivation path, which makes
/// it a stable seed for deriving a confidential-asset decryption key.
/// Deriving secrets from `pepper_base` rather than the final pepper also
/// ensures a leaked pepper does not compromise them.
///
/// Returns a [Uint8List] containing the 48-byte `pepper_base`.
Future<Uint8List> getPepperBase({
  required AptosConfig aptosConfig,
  required String jwt,
  required EphemeralKeyPair ephemeralKeyPair,
  String uidKey = 'sub',
  String? derivationPath,
}) async {
  final response = await postAptosPepperService(
    aptosConfig: aptosConfig,
    path: 'signature',
    body: _pepperServiceBody(
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      uidKey: uidKey,
      derivationPath: derivationPath,
    ),
    originMethod: 'getPepperBase',
    overrides: const AptosRequestOverrides(withCredentials: false),
  );
  final signature = (response.data as Map)['signature'] as String;
  return Hex.fromHexInput(signature).toUint8List();
}

/// Builds the shared pepper-service request body (`PepperFetchRequest`).
/// The `derivation_path` key is omitted from the JSON body when not provided.
Map<String, Object?> _pepperServiceBody({
  required String jwt,
  required EphemeralKeyPair ephemeralKeyPair,
  required String uidKey,
  String? derivationPath,
}) {
  return <String, Object?>{
    'jwt_b64': jwt,
    'epk': ephemeralKeyPair.getPublicKey().bcsToHex().toStringWithoutPrefix(),
    'exp_date_secs': ephemeralKeyPair.expiryDateSecs,
    'epk_blinder':
        Hex.fromHexInput(ephemeralKeyPair.blinder).toStringWithoutPrefix(),
    'uid_key': uidKey,
    if (derivationPath != null) 'derivation_path': derivationPath,
  };
}

/// Generates a zero-knowledge proof based on the provided parameters. This
/// function is essential for creating a signed proof that can be used in
/// various cryptographic operations.
///
/// [jwt] - The JSON Web Token used for authentication.
/// [ephemeralKeyPair] - The ephemeral key pair used for generating the proof.
/// [pepper] - An optional hex input used to enhance security (fetched from
/// the pepper service if not provided).
/// [uidKey] - An optional string that specifies the unique identifier key
/// (defaults to "sub").
/// [maxExpHorizonSecs] - The maximum allowed lifespan of the ephemeral key
/// pair (fetched from the on-chain keyless configuration if not provided).
///
/// Throws an [ArgumentError] if the pepper length is not valid or if the
/// ephemeral key pair's lifespan exceeds the maximum allowed.
Future<ZeroKnowledgeSig> getProof({
  required AptosConfig aptosConfig,
  required String jwt,
  required EphemeralKeyPair ephemeralKeyPair,
  HexInput? pepper,
  String uidKey = 'sub',
  int? maxExpHorizonSecs,
}) async {
  final resolvedPepper = pepper ??
      await getPepper(
        aptosConfig: aptosConfig,
        jwt: jwt,
        ephemeralKeyPair: ephemeralKeyPair,
        uidKey: uidKey,
      );
  final resolvedMaxExpHorizonSecs = maxExpHorizonSecs ??
      (await getKeylessConfig(aptosConfig: aptosConfig)).maxExpHorizonSecs;
  if (Hex.fromHexInput(resolvedPepper).toUint8List().length !=
      AbstractKeylessAccount.pepperLength) {
    throw ArgumentError(
      'Pepper needs to be ${AbstractKeylessAccount.pepperLength} bytes',
    );
  }
  // SECURITY: the JWT signature is NOT verified here. The prover service is
  // the next hop and will reject a tampered JWT, and the on-chain keyless
  // verifier validates the signature against the JWK set published on-chain.
  // Callers must still source `jwt` from a trusted IdP redirect flow —
  // accepting a user-supplied JWT here will produce a useless proof, not a
  // forged one, but it also leaks the (unverified) claims to the prover.
  final decodedJwt = _decodeJwtPayload(jwt);
  final iat = decodedJwt['iat'];
  if (iat is! num) {
    throw ArgumentError('iat was not found');
  }
  if (resolvedMaxExpHorizonSecs <
      ephemeralKeyPair.expiryDateSecs - iat.toInt()) {
    throw ArgumentError(
      'The EphemeralKeyPair is too long lived.  Its lifespan must be less '
      'than $resolvedMaxExpHorizonSecs',
    );
  }
  final json = ProverRequest(
    jwtB64: jwt,
    epk: ephemeralKeyPair.getPublicKey().bcsToHex().toStringWithoutPrefix(),
    epkBlinder:
        Hex.fromHexInput(ephemeralKeyPair.blinder).toStringWithoutPrefix(),
    expDateSecs: ephemeralKeyPair.expiryDateSecs,
    expHorizonSecs: resolvedMaxExpHorizonSecs,
    pepper: Hex.fromHexInput(resolvedPepper).toStringWithoutPrefix(),
    uidKey: uidKey,
  ).toJson();

  final response = await postAptosProvingService(
    aptosConfig: aptosConfig,
    path: 'prove',
    body: json,
    originMethod: 'getProof',
    overrides: const AptosRequestOverrides(withCredentials: false),
  );

  // NOTE: the proof points may be hex strings or byte arrays; both are valid
  // HexInput for Groth16Zkp.
  final data = response.data as Map;
  final proofPoints = data['proof'] as Map;
  final groth16Zkp = Groth16Zkp(
    a: proofPoints['a'] as Object,
    b: proofPoints['b'] as Object,
    c: proofPoints['c'] as Object,
  );

  final signedProof = ZeroKnowledgeSig(
    proof: ZkProof(groth16Zkp, ZkpVariant.groth16),
    trainingWheelsSignature: EphemeralSignature.fromHex(
      data['training_wheels_signature'] as Object,
    ),
    expHorizonSecs: resolvedMaxExpHorizonSecs,
  );
  return signedProof;
}

/// Derives a keyless account by fetching the necessary proof and looking up
/// the original account address. This function helps in creating a keyless
/// account that can be used without managing private keys directly.
///
/// Returns a [KeylessAccount] or, when [jwkAddress] is provided, a
/// [FederatedKeylessAccount].
///
/// [jwt] - The JSON Web Token used for authentication.
/// [ephemeralKeyPair] - The ephemeral key pair used for cryptographic
/// operations.
/// [jwkAddress] - The address where the JWKs used to verify signatures are
/// found. Setting the value derives a [FederatedKeylessAccount].
/// [uidKey] - An optional unique identifier key for the user.
/// [pepper] - An optional hexadecimal input used for additional security.
/// [proofFetchCallback] - An optional callback function to handle the proof
/// fetch outcome; when provided the proof is fetched in the background.
Future<AbstractKeylessAccount> deriveKeylessAccount({
  required AptosConfig aptosConfig,
  required String jwt,
  required EphemeralKeyPair ephemeralKeyPair,
  AccountAddressInput? jwkAddress,
  String uidKey = 'sub',
  HexInput? pepper,
  ProofFetchCallback? proofFetchCallback,
}) async {
  final resolvedPepper = pepper ??
      await getPepper(
        aptosConfig: aptosConfig,
        jwt: jwt,
        ephemeralKeyPair: ephemeralKeyPair,
        uidKey: uidKey,
      );
  final keylessConfig = await getKeylessConfig(aptosConfig: aptosConfig);
  final verificationKey = keylessConfig.verificationKey;
  final maxExpHorizonSecs = keylessConfig.maxExpHorizonSecs;

  final proofPromise = getProof(
    aptosConfig: aptosConfig,
    jwt: jwt,
    ephemeralKeyPair: ephemeralKeyPair,
    pepper: resolvedPepper,
    uidKey: uidKey,
    maxExpHorizonSecs: maxExpHorizonSecs,
  );
  // If a callback is provided, pass in the proof as a future to
  // `KeylessAccount.create`. This will make the proof be fetched in the
  // background and the callback will handle the outcome of the fetch. This
  // allows the developer to not have to block on the proof fetch allowing
  // for faster rendering of UX.
  //
  // If no callback is provided, just await the proof fetch and continue
  // synchronously.
  if (proofFetchCallback != null) {
    // The proof future is awaited later by `AbstractKeylessAccount.init`; the
    // ignore() prevents an error completing during the address lookup below
    // from being reported as an unhandled asynchronous error.
    proofPromise.ignore();
  }
  final Object proof =
      proofFetchCallback != null ? proofPromise : await proofPromise;

  // Look up the original address to handle key rotations and then
  // instantiate the account.
  if (jwkAddress != null) {
    final publicKey = FederatedKeylessPublicKey.fromJwtAndPepper(
      jwt: jwt,
      pepper: resolvedPepper,
      jwkAddress: jwkAddress,
      uidKey: uidKey,
    );
    final address = await lookupOriginalAccountAddress(
      aptosConfig: aptosConfig,
      authenticationKey: publicKey.authKey().derivedAddress(),
    );

    return FederatedKeylessAccount.create(
      address: address,
      proof: proof,
      jwt: jwt,
      ephemeralKeyPair: ephemeralKeyPair,
      pepper: resolvedPepper,
      jwkAddress: jwkAddress,
      uidKey: uidKey,
      proofFetchCallback: proofFetchCallback,
      verificationKey: verificationKey,
    );
  }

  final publicKey = KeylessPublicKey.fromJwtAndPepper(
    jwt: jwt,
    pepper: resolvedPepper,
    uidKey: uidKey,
  );
  final address = await lookupOriginalAccountAddress(
    aptosConfig: aptosConfig,
    authenticationKey: publicKey.authKey().derivedAddress(),
  );
  return KeylessAccount.create(
    address: address,
    proof: proof,
    jwt: jwt,
    ephemeralKeyPair: ephemeralKeyPair,
    pepper: resolvedPepper,
    uidKey: uidKey,
    proofFetchCallback: proofFetchCallback,
    verificationKey: verificationKey,
  );
}

/// A JSON Web Key Set as fetched from an issuer's `jwks_uri`.
class JWKS {
  final List<MoveJWK> keys;

  const JWKS({required this.keys});
}

/// Caller can supply any IdP URL, so the JWKS response is untrusted. A
/// hostile/buggy IdP could return an unboundedly large `keys` array and we'd
/// pack the whole thing into the on-chain transaction. Validate the four
/// fields we actually use (kid, alg, e, n), cap the key count, and surface a
/// single descriptive error when anything is off.
const int _maxFederatedJwksKeys = 32;

/// This installs a set of FederatedJWKs at an address for a given iss.
///
/// It will fetch the JSON Web Key Set (JWKS) from the well-known endpoint
/// (or [jwksUrl] when provided) and build a transaction updating the
/// FederatedJWKs at the sender's address to reflect it.
///
/// [sender] - The account that will install the JWKs.
/// [iss] - The iss claim of the federated OIDC provider.
/// [jwksUrl] - The URL to find the corresponding JWKs. For supported IDP
/// providers this parameter is not necessary.
///
/// Returns the [SimpleTransaction] that can be signed and submitted.
Future<SimpleTransaction> updateFederatedKeylessJwkSetTransaction({
  required AptosConfig aptosConfig,
  required Account sender,
  required String iss,
  String? jwksUrl,
  InputGenerateTransactionOptions? options,
}) async {
  var resolvedJwksUrl = jwksUrl;
  if (resolvedJwksUrl == null) {
    if (firebaseAuthIssPattern.hasMatch(iss)) {
      resolvedJwksUrl =
          'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
    } else {
      resolvedJwksUrl = iss.endsWith('/')
          ? '$iss.well-known/jwks.json'
          : '$iss/.well-known/jwks.json';
    }
  }

  // SSRF guard: require HTTPS. Without this check a caller-supplied `iss` or
  // `jwksUrl` could redirect the fetch to plaintext HTTP, cloud-metadata
  // endpoints (e.g., `http://169.254.169.254/...`), internal services, or
  // non-network schemes like `file:` / `data:`. The on-chain JWKS update is
  // a privileged operation, so we refuse to source key material over an
  // untrusted transport.
  final Uri parsedJwksUrl;
  try {
    parsedJwksUrl = Uri.parse(resolvedJwksUrl);
    if (!parsedJwksUrl.isAbsolute) {
      throw const FormatException('not an absolute URL');
    }
  } on FormatException {
    throw ArgumentError('JWKS URL is not a valid URL');
  }
  if (parsedJwksUrl.scheme != 'https') {
    throw ArgumentError(
      'JWKS URL must use https: (got ${parsedJwksUrl.scheme}:)',
    );
  }
  final origin = parsedJwksUrl.origin;

  // Plain HTTP GET via the configured client provider (this is not an Aptos
  // API request, so it bypasses the aptosRequest wrapper).
  final Object? rawJwks;
  try {
    final response = await aptosConfig.client.provider(
      ClientRequest(url: resolvedJwksUrl, method: 'GET'),
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('${response.status} ${response.statusText ?? ''}');
    }
    rawJwks = response.data;
  } catch (error) {
    // Surface only the origin (scheme + host + port) of the JWKS URL in the
    // user-facing error. The full URL, which may include `iss`-derived path
    // segments or tenant identifiers from enterprise IdPs, is intentionally
    // omitted to avoid leaking infrastructure details into logs / crash
    // reporters.
    throw StateError(
      'Failed to fetch JWKS from $origin: ${getErrorMessage(error)}',
    );
  }

  final jwks = _validateJwksResponse(rawJwks, origin);
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::jwks::update_federated_jwk_set',
      functionArguments: [
        iss,
        MoveVector.string(jwks.keys.map((key) => key.kid).toList()),
        MoveVector.string(jwks.keys.map((key) => key.alg).toList()),
        MoveVector.string(jwks.keys.map((key) => key.e).toList()),
        MoveVector.string(jwks.keys.map((key) => key.n).toList()),
      ],
    ),
    options: options,
  ) as SimpleTransaction;
}

JWKS _validateJwksResponse(Object? raw, String originForError) {
  if (raw is! Map || raw['keys'] is! List) {
    throw StateError(
      "JWKS response from $originForError is missing a 'keys' array",
    );
  }
  final keys = raw['keys'] as List;
  if (keys.isEmpty) {
    throw StateError(
      "JWKS response from $originForError has an empty 'keys' array",
    );
  }
  if (keys.length > _maxFederatedJwksKeys) {
    throw StateError(
      'JWKS response from $originForError has ${keys.length} keys '
      '(max $_maxFederatedJwksKeys)',
    );
  }
  final moveJwks = <MoveJWK>[];
  for (var i = 0; i < keys.length; i += 1) {
    final key = keys[i];
    if (key is! Map) {
      throw StateError(
        'JWKS response from $originForError: key at index $i is not an '
        'object',
      );
    }
    for (final field in const ['kid', 'alg', 'e', 'n']) {
      if (key[field] is! String) {
        throw StateError(
          'JWKS response from $originForError: key at index $i is missing '
          "string field '$field'",
        );
      }
    }
    moveJwks.add(MoveJWK(
      kid: key['kid'] as String,
      kty: (key['kty'] as String?) ?? 'RSA',
      alg: key['alg'] as String,
      e: key['e'] as String,
      n: key['n'] as String,
    ));
  }
  return JWKS(keys: moveJwks);
}

/// Retrieves the configuration parameters for Keyless Accounts on the
/// blockchain, including the verifying key and the maximum expiry horizon.
///
/// The result is memoized for five minutes, keyed by network.
///
/// [options.ledgerVersion] - The ledger version to query; if not provided,
/// the latest version will be used.
Future<KeylessConfiguration> getKeylessConfig({
  required AptosConfig aptosConfig,
  LedgerVersionArg? options,
}) async {
  return await memoizeAsync(
    () async {
      final config = await _getKeylessConfigurationResource(
        aptosConfig: aptosConfig,
        options: options,
      );
      final vk = await _getGroth16VerificationKeyResource(
        aptosConfig: aptosConfig,
        options: options,
      );
      return KeylessConfiguration.create(vk, config);
    },
    'keyless-configuration-${aptosConfig.network.value}',
    ttl: const Duration(minutes: 5),
  )();
}

/// Retrieves the KeylessConfiguration resource
/// (`0x1::keyless_account::Configuration`) set on chain.
Future<KeylessConfigurationResponse> _getKeylessConfigurationResource({
  required AptosConfig aptosConfig,
  LedgerVersionArg? options,
}) async {
  const resourceType = '0x1::keyless_account::Configuration';
  try {
    final response = await getAptosFullNode(
      aptosConfig: aptosConfig,
      originMethod: 'getKeylessConfigurationResource',
      path: 'accounts/${AccountAddress.from('0x1')}/resource/$resourceType',
      params: {
        if (options?.ledgerVersion != null)
          'ledger_version': options!.ledgerVersion,
      },
    );
    final resource = response.data as Map;
    return KeylessConfigurationResponse.fromJson(
      Map<String, dynamic>.from(resource['data'] as Map),
    );
  } catch (error) {
    throw StateError(
      'Failed to look up the keyless configuration on the fullnode: '
      '${getErrorMessage(error)}',
    );
  }
}

/// Retrieves the Groth16VerificationKey resource
/// (`0x1::keyless_account::Groth16VerificationKey`) set on the blockchain.
Future<Groth16VerificationKeyResponse> _getGroth16VerificationKeyResource({
  required AptosConfig aptosConfig,
  LedgerVersionArg? options,
}) async {
  const resourceType = '0x1::keyless_account::Groth16VerificationKey';
  try {
    final response = await getAptosFullNode(
      aptosConfig: aptosConfig,
      originMethod: 'getGroth16VerificationKeyResource',
      path: 'accounts/${AccountAddress.from('0x1')}/resource/$resourceType',
      params: {
        if (options?.ledgerVersion != null)
          'ledger_version': options!.ledgerVersion,
      },
    );
    final resource = response.data as Map;
    return Groth16VerificationKeyResponse.fromJson(
      Map<String, dynamic>.from(resource['data'] as Map),
    );
  } catch (error) {
    throw StateError(
      'Failed to look up the Groth16 verification key on the fullnode: '
      '${getErrorMessage(error)}',
    );
  }
}

/// Fetches the JWK from the on-chain JWK sets given the issuer of the
/// provided keyless public key and the `kid` of the JWT used to derive it.
///
/// [publicKey] - The keyless public key which contains the issuer and, for a
/// [FederatedKeylessPublicKey], the address to fetch the JWKs from (0x1
/// otherwise).
/// [kid] - The kid of the JWK to fetch.
///
/// Returns a [MoveJWK] matching the `kid` in the JWT header.
///
/// Throws a [StateError] if the JWK cannot be fetched.
Future<MoveJWK> fetchJWK({
  required AptosConfig aptosConfig,
  required PublicKey publicKey,
  required String kid,
}) async {
  final KeylessPublicKey keylessPubKey;
  if (publicKey is KeylessPublicKey) {
    keylessPubKey = publicKey;
  } else if (publicKey is FederatedKeylessPublicKey) {
    keylessPubKey = publicKey.keylessPublicKey;
  } else {
    throw ArgumentError(
      'fetchJWK requires a KeylessPublicKey or FederatedKeylessPublicKey, '
      'got ${publicKey.runtimeType}',
    );
  }
  final iss = keylessPubKey.iss;

  final jwkAddr =
      publicKey is FederatedKeylessPublicKey ? publicKey.jwkAddress : null;
  Map<String, List<MoveJWK>> allJWKs;
  try {
    allJWKs = await getKeylessJWKs(aptosConfig: aptosConfig, jwkAddr: jwkAddr);
  } catch (error) {
    throw StateError(
      'Failed to fetch ${jwkAddr != null ? 'Federated' : 'Patched'}JWKs '
      '${jwkAddr != null ? 'for address $jwkAddr' : '0x1'}: '
      '${getErrorMessage(error)}',
    );
  }

  // Find the corresponding JWK set by `iss`.
  final jwksForIssuer = allJWKs[iss];

  if (jwksForIssuer == null) {
    throw StateError('JWKs for issuer $iss not found.');
  }

  // Find the corresponding JWK by `kid`.
  for (final jwk in jwksForIssuer) {
    if (jwk.kid == kid) {
      return jwk;
    }
  }

  throw StateError("JWK with kid '$kid' for issuer '$iss' not found.");
}

/// Fetches JWKs from the blockchain with optional caching.
///
/// [jwkAddr] - Optional. The address to fetch JWKs from (for federated
/// keyless). When absent, the patched JWKs at 0x1 are fetched.
/// [options] - Optional. Ledger version options.
/// [useCache] - Optional. Whether to use cached JWKs. Defaults to true.
///
/// Returns a map of issuer to JWK arrays.
Future<Map<String, List<MoveJWK>>> getKeylessJWKs({
  required AptosConfig aptosConfig,
  AccountAddressInput? jwkAddr,
  LedgerVersionArg? options,
  bool useCache = true,
}) async {
  // Generate a cache key based on network and address.
  final addrString =
      jwkAddr != null ? AccountAddress.from(jwkAddr).toString() : '0x1';
  final cacheKey = 'keyless-jwks-${aptosConfig.network.value}-$addrString';

  // If caching is enabled and we have a ledger version, don't use the cache
  // (specific ledger versions should always fetch fresh data).
  if (useCache && options?.ledgerVersion == null) {
    return memoizeAsync(
      () => _fetchKeylessJWKsInternal(
        aptosConfig: aptosConfig,
        jwkAddr: jwkAddr,
        options: options,
      ),
      cacheKey,
      ttl: const Duration(minutes: 5),
    )();
  }

  return _fetchKeylessJWKsInternal(
    aptosConfig: aptosConfig,
    jwkAddr: jwkAddr,
    options: options,
  );
}

/// Internal function to fetch JWKs from the blockchain.
Future<Map<String, List<MoveJWK>>> _fetchKeylessJWKsInternal({
  required AptosConfig aptosConfig,
  AccountAddressInput? jwkAddr,
  LedgerVersionArg? options,
}) async {
  final path = jwkAddr == null
      ? 'accounts/0x1/resource/0x1::jwks::PatchedJWKs'
      : 'accounts/${AccountAddress.from(jwkAddr)}/resource/'
          '0x1::jwks::FederatedJWKs';
  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'getKeylessJWKs',
    path: path,
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
  );
  final resource = PatchedJWKsResponse.fromJson(
    Map<String, dynamic>.from((response.data as Map)['data'] as Map),
  );

  // Create a map of issuer to JWK arrays.
  final jwkMap = <String, List<MoveJWK>>{};
  for (final entry in resource.jwks.entries) {
    final jwks = <MoveJWK>[];
    for (final jwkStruct in entry.jwks) {
      final jwkData = jwkStruct.variant.data;
      final deserializer =
          Deserializer(Hex.fromHexInput(jwkData).toUint8List());
      jwks.add(MoveJWK.deserialize(deserializer));
    }
    jwkMap[hexToAsciiString(entry.issuer)] = jwks;
  }

  return jwkMap;
}

/// Decodes the payload (claims) section of a JWT without verifying the
/// signature.
Map<String, dynamic> _decodeJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length < 2) {
    throw ArgumentError('Invalid JWT format');
  }
  final decoded = jsonDecode(base64UrlDecode(parts[1]));
  if (decoded is! Map<String, dynamic>) {
    throw ArgumentError('Invalid JWT format');
  }
  return decoded;
}
