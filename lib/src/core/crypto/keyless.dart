import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../../api/aptos_config.dart';
import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../internal/keyless.dart' as keyless_api;
import '../../types/keyless.dart';
import '../../types/types.dart';
import '../../utils/helpers.dart';
import '../authentication_key.dart';
import '../hex.dart';
import 'bn254.dart';
import 'ed25519.dart';
import 'ephemeral.dart';
import 'federated_keyless.dart';
import 'poseidon.dart';
import 'proof.dart';
import 'public_key.dart';
import 'signature.dart';
import 'single_key.dart' show VerifySignatureAsyncOptions;

// NOTE: registration of the keyless variants into the
// AnyPublicKey/AnySignature registry is intentionally NOT done in this
// file — it is handled where the AnyPublicKey registry is defined.

const int epkHorizonSecs = 10000000;
const int maxAudValBytes = 120;
const int maxUidKeyBytes = 30;
const int maxUidValBytes = 330;
const int maxIssValBytes = 120;
const int maxExtraFieldBytes = 350;
const int maxJwtHeaderB64Bytes = 300;
const int maxCommitedEpkBytes = 93;

// Private aliases so constructor parameters of the same name don't shadow the
// library constants inside initializer lists.
const int _defaultMaxExtraFieldBytes = maxExtraFieldBytes;
const int _defaultMaxJwtHeaderB64Bytes = maxJwtHeaderB64Bytes;
const int _defaultMaxIssValBytes = maxIssValBytes;
const int _defaultMaxCommitedEpkBytes = maxCommitedEpkBytes;

/// Represents a Keyless Public Key used for authentication.
///
/// This class encapsulates the public key functionality for keyless
/// authentication, including methods for generating and verifying signatures,
/// as well as serialization and deserialization of the key. The
/// KeylessPublicKey is represented in the SDK as `AnyPublicKey`.
class KeylessPublicKey extends AccountPublicKey {
  /// The number of bytes that [idCommitment] should be.
  static const int idCommitmentLength = 32;

  /// The value of the 'iss' claim on the JWT which identifies the OIDC
  /// provider.
  final String iss;

  /// A value representing a cryptographic commitment to a user identity.
  ///
  /// It is calculated from the aud, uidKey, uidVal, pepper.
  final Uint8List idCommitment;

  /// Constructs an instance with the specified iss and idCommitment.
  ///
  /// Throws an [ArgumentError] if the idCommitment length is not
  /// [KeylessPublicKey.idCommitmentLength].
  KeylessPublicKey(this.iss, HexInput idCommitment)
      : idCommitment = Hex.fromHexInput(idCommitment).toUint8List() {
    if (this.idCommitment.length != KeylessPublicKey.idCommitmentLength) {
      throw ArgumentError(
        'Id Commitment length in bytes should be '
        '${KeylessPublicKey.idCommitmentLength}',
      );
    }
  }

  /// Get the authentication key for the keyless public key.
  @override
  AuthenticationKey authKey() {
    final serializer = Serializer();
    serializer.serializeU32AsUleb128(AnyPublicKeyVariant.keyless.value);
    serializer.serializeFixedBytes(bcsToBytes());
    return AuthenticationKey.fromSchemeAndBytes(
      scheme: SigningScheme.singleKey,
      input: serializer.toUint8List(),
    );
  }

  /// Verifies the validity of a signature for a given message.
  ///
  /// [jwk] is the JWK to use for verification and [keylessConfig] the keyless
  /// configuration to use for verification. Both are required; they are
  /// optional named parameters only to satisfy the base [PublicKey]
  /// interface.
  ///
  /// The Groth16 proof itself is verified via
  /// [Groth16VerificationKey.verifyProof] (BN254 pairings).
  @override
  bool verifySignature({
    required HexInput message,
    required Signature signature,
    MoveJWK? jwk,
    KeylessConfiguration? keylessConfig,
  }) {
    if (jwk == null || keylessConfig == null) {
      throw ArgumentError(
        'KeylessPublicKey.verifySignature requires jwk and keylessConfig',
      );
    }
    try {
      verifyKeylessSignatureWithJwkAndConfig(
        publicKey: this,
        message: message,
        signature: signature,
        jwk: jwk,
        keylessConfig: keylessConfig,
      );
      return true;
    } catch (_) {
      // Any failure to verify (malformed proof, off-curve or off-subgroup
      // point, decode error) means the signature is invalid — not that the
      // caller made a usage error. Mirrors FederatedKeylessPublicKey.
      return false;
    }
  }

  /// Verifies a keyless [signature], fetching the on-chain keyless
  /// configuration and the relevant JWK from the network.
  ///
  /// [aptosConfig] must be an [AptosConfig]; it identifies the network to
  /// query. See [verifyKeylessSignature] for the full behavior.
  @override
  Future<bool> verifySignatureAsync({
    Object? aptosConfig,
    required HexInput message,
    required Signature signature,
    Object? options,
  }) {
    return verifyKeylessSignature(
      publicKey: this,
      aptosConfig: aptosConfig as AptosConfig?,
      message: message,
      signature: signature,
      options: options,
    );
  }

  /// Serializes the current instance into BCS.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(iss);
    serializer.serializeBytes(idCommitment);
  }

  /// Deserializes a KeylessPublicKey from the provided deserializer.
  static KeylessPublicKey deserialize(Deserializer deserializer) {
    final iss = deserializer.deserializeStr();
    final addressSeed = deserializer.deserializeBytes();
    return KeylessPublicKey(iss, addressSeed);
  }

  /// Loads a KeylessPublicKey instance from the provided deserializer.
  static KeylessPublicKey load(Deserializer deserializer) {
    final iss = deserializer.deserializeStr();
    final addressSeed = deserializer.deserializeBytes();
    return KeylessPublicKey(iss, addressSeed);
  }

  /// Determines if the provided public key is an instance of
  /// KeylessPublicKey.
  static bool isPublicKey(PublicKey publicKey) => publicKey is KeylessPublicKey;

  /// Creates a KeylessPublicKey from the JWT components plus pepper.
  ///
  /// [iss] is the iss of the identity, [uidKey] the key used to get the
  /// uidVal in the JWT token, [uidVal] the value of the uidKey in the JWT
  /// token, [aud] the client ID of the application, and [pepper] the pepper
  /// used to maintain privacy of the account.
  static KeylessPublicKey create({
    required String iss,
    required String uidKey,
    required String uidVal,
    required String aud,
    required HexInput pepper,
  }) {
    return KeylessPublicKey(
      iss,
      _computeIdCommitment(
        uidKey: uidKey,
        uidVal: uidVal,
        aud: aud,
        pepper: pepper,
      ),
    );
  }

  /// Creates a KeylessPublicKey instance from a JWT and a pepper value.
  ///
  /// SECURITY: the JWT is decoded WITHOUT verifying its signature. The
  /// cryptographic binding between the JWT and the user's identity is
  /// enforced on-chain by the keyless verifier. Callers MUST therefore obtain
  /// [jwt] directly from a trusted IdP redirect/OAuth flow; do not accept
  /// arbitrary user-supplied JWT strings here, since a tampered JWT will
  /// derive a different account address than the chain expects.
  ///
  /// [uidKey] is an optional key to retrieve the unique identifier from the
  /// JWT payload, defaults to "sub".
  static KeylessPublicKey fromJwtAndPepper({
    required String jwt,
    required HexInput pepper,
    String uidKey = 'sub',
  }) {
    // SECURITY: signature is not verified here — see method-level doc.
    final jwtPayload = _decodeJwtPayload(jwt);
    final iss = jwtPayload['iss'];
    if (iss is! String) {
      throw ArgumentError('iss was not found');
    }
    final aud = jwtPayload['aud'];
    if (aud is! String) {
      throw ArgumentError('aud was not found or an array of values');
    }
    final uidVal = jwtPayload[uidKey];
    return KeylessPublicKey.create(
      iss: iss,
      uidKey: uidKey,
      uidVal: '$uidVal',
      aud: aud,
      pepper: pepper,
    );
  }

  /// Checks if the provided public key is a valid instance by verifying its
  /// structure and types.
  static bool isInstance(PublicKey publicKey) => publicKey is KeylessPublicKey;
}

/// Verifies a keyless [signature] for [message], fetching the on-chain
/// keyless configuration and the relevant JWK from the network when they are
/// not supplied via [keylessConfig] / [jwk].
///
/// [publicKey] must be a [KeylessPublicKey] or [FederatedKeylessPublicKey].
/// [aptosConfig] identifies the network to query; it may be omitted only when
/// both [keylessConfig] and [jwk] are provided (no network lookup is needed).
///
/// This is the network-backed counterpart to
/// [verifyKeylessSignatureWithJwkAndConfig]. It returns false on any
/// verification failure, unless [options] is a [VerifySignatureAsyncOptions]
/// with `throwErrorWithReason` set, in which case the failure is rethrown.
Future<bool> verifyKeylessSignature({
  required PublicKey publicKey,
  required AptosConfig? aptosConfig,
  required HexInput message,
  required Signature signature,
  KeylessConfiguration? keylessConfig,
  MoveJWK? jwk,
  Object? options,
}) async {
  try {
    if (signature is! KeylessSignature) {
      throw ArgumentError('Not a keyless signature');
    }
    if ((keylessConfig == null || jwk == null) && aptosConfig == null) {
      throw ArgumentError(
        'verifyKeylessSignature requires an aptosConfig to fetch the keyless '
        'configuration and JWK from the network',
      );
    }
    final resolvedConfig = keylessConfig ??
        await keyless_api.getKeylessConfig(aptosConfig: aptosConfig!);
    final resolvedJwk = jwk ??
        await keyless_api.fetchJWK(
          aptosConfig: aptosConfig!,
          publicKey: publicKey,
          kid: signature.getJwkKid(),
        );
    verifyKeylessSignatureWithJwkAndConfig(
      publicKey: publicKey,
      message: message,
      signature: signature,
      jwk: resolvedJwk,
      keylessConfig: resolvedConfig,
    );
    return true;
  } catch (_) {
    if (options is VerifySignatureAsyncOptions &&
        options.throwErrorWithReason) {
      rethrow;
    }
    return false;
  }
}

/// Synchronously verifies a keyless signature for a given message. You need
/// to provide the keyless configuration and the JWK to use for verification.
///
/// This performs full local verification, including the BN254 Groth16 proof
/// check via [Groth16VerificationKey.verifyProof].
///
/// Throws an [ArgumentError] or [StateError] if the signature is invalid.
void verifyKeylessSignatureWithJwkAndConfig({
  required PublicKey publicKey,
  required HexInput message,
  required Signature signature,
  required KeylessConfiguration keylessConfig,
  required MoveJWK jwk,
}) {
  final verificationKey = keylessConfig.verificationKey;
  final maxExpHorizonSecs = keylessConfig.maxExpHorizonSecs;
  final trainingWheelsPubkey = keylessConfig.trainingWheelsPubkey;
  if (publicKey is! KeylessPublicKey &&
      publicKey is! FederatedKeylessPublicKey) {
    throw ArgumentError('Not a keyless public key');
  }
  if (signature is! KeylessSignature) {
    throw ArgumentError('Not a keyless signature');
  }
  final certSignature = signature.ephemeralCertificate.signature;
  if (certSignature is! ZeroKnowledgeSig) {
    throw ArgumentError('Unsupported ephemeral certificate variant');
  }
  final zkSig = certSignature;
  if (zkSig.proof.proof is! Groth16Zkp) {
    throw ArgumentError('Unsupported proof variant for ZeroKnowledgeSig');
  }
  final groth16Proof = zkSig.proof.proof as Groth16Zkp;
  if (signature.expiryDateSecs < nowInSeconds()) {
    throw ArgumentError('The expiryDateSecs is in the past');
  }
  if (zkSig.expHorizonSecs > maxExpHorizonSecs) {
    throw ArgumentError('The expHorizonSecs exceeds the maximum allowed');
  }
  if (!signature.ephemeralPublicKey.verifySignature(
    message: message,
    signature: signature.ephemeralSignature,
  )) {
    throw ArgumentError('Ephemeral signature verification failed');
  }
  final publicInputsHash = getPublicInputsHash(
    publicKey: publicKey,
    signature: signature,
    jwk: jwk,
    keylessConfig: keylessConfig,
  );
  if (!verificationKey.verifyProof(
    publicInputsHash: publicInputsHash,
    groth16Proof: groth16Proof,
  )) {
    throw ArgumentError('Proof verification failed');
  }
  if (trainingWheelsPubkey != null) {
    final trainingWheelsSignature = zkSig.trainingWheelsSignature;
    if (trainingWheelsSignature == null) {
      throw ArgumentError('Training wheels signature missing');
    }
    final proofAndStatement =
        Groth16ProofAndStatement(groth16Proof, publicInputsHash);
    if (!trainingWheelsPubkey.verifySignature(
      message: proofAndStatement.hash(),
      signature: trainingWheelsSignature,
    )) {
      throw ArgumentError('Training wheels signature verification failed');
    }
  }
}

/// Get the public inputs hash for the keyless signature.
///
/// [keylessConfig] defines the byte lengths to use when hashing fields.
BigInt getPublicInputsHash({
  required PublicKey publicKey,
  required KeylessSignature signature,
  required MoveJWK jwk,
  required KeylessConfiguration keylessConfig,
}) {
  final KeylessPublicKey innerKeylessPublicKey;
  if (publicKey is KeylessPublicKey) {
    innerKeylessPublicKey = publicKey;
  } else if (publicKey is FederatedKeylessPublicKey) {
    innerKeylessPublicKey = publicKey.keylessPublicKey;
  } else {
    throw ArgumentError('Not a keyless public key');
  }
  final certSignature = signature.ephemeralCertificate.signature;
  if (certSignature is! ZeroKnowledgeSig) {
    throw ArgumentError('Signature is not a ZeroKnowledgeSig');
  }
  final proof = certSignature;
  final fields = <Object>[];
  fields.addAll(padAndPackBytesWithLen(
    signature.ephemeralPublicKey.toUint8Array(),
    keylessConfig.maxCommitedEpkBytes,
  ));
  fields.add(bytesToBigIntLE(innerKeylessPublicKey.idCommitment));
  fields.add(signature.expiryDateSecs);
  fields.add(proof.expHorizonSecs);
  fields.add(hashStrToField(
    innerKeylessPublicKey.iss,
    keylessConfig.maxIssValBytes,
  ));
  final extraField = proof.extraField;
  if (extraField == null) {
    fields.add(BigInt.zero);
    fields.add(hashStrToField(' ', keylessConfig.maxExtraFieldBytes));
  } else {
    fields.add(BigInt.one);
    fields.add(hashStrToField(extraField, keylessConfig.maxExtraFieldBytes));
  }
  final jwtHeaderB64Url = base64UrlEncode(signature.jwtHeader);
  fields.add(hashStrToField(
    '$jwtHeaderB64Url.',
    keylessConfig.maxJwtHeaderB64Bytes,
  ));
  fields.add(jwk.toScalar());
  final overrideAudVal = proof.overrideAudVal;
  if (overrideAudVal == null) {
    fields.add(hashStrToField('', maxAudValBytes));
    fields.add(BigInt.zero);
  } else {
    fields.add(hashStrToField(overrideAudVal, maxAudValBytes));
    fields.add(BigInt.one);
  }
  return poseidonHash(fields);
}

// TODO: `fetchJWK`, `getKeylessJWKs`, `fetchKeylessJWKsInternal`,
// `getKeylessConfig`, `getKeylessConfigurationResource`, and
// `getGroth16VerificationKeyResource` require the HTTP client and the
// api/aptosConfig module; add them together with the client.

Uint8List _computeIdCommitment({
  required String uidKey,
  required String uidVal,
  required String aud,
  required HexInput pepper,
}) {
  final fields = <Object>[
    bytesToBigIntLE(Hex.fromHexInput(pepper).toUint8List()),
    hashStrToField(aud, maxAudValBytes),
    hashStrToField(uidVal, maxUidValBytes),
    hashStrToField(uidKey, maxUidKeyBytes),
  ];

  return bigIntToBytesLE(
    poseidonHash(fields),
    KeylessPublicKey.idCommitmentLength,
  );
}

/// Represents a signature of a message signed via a Keyless Account,
/// utilizing proofs or a JWT token for authentication.
class KeylessSignature extends Signature {
  /// The inner signature ZeroKnowledgeSignature or OpenIdSignature.
  final EphemeralCertificate ephemeralCertificate;

  /// The jwt header in the token used to create the proof/signature. In json
  /// string representation.
  final String jwtHeader;

  /// The expiry timestamp in seconds of the EphemeralKeyPair used to sign.
  final int expiryDateSecs;

  /// The ephemeral public key used to verify the signature.
  final EphemeralPublicKey ephemeralPublicKey;

  /// The signature resulting from signing with the private key of the
  /// EphemeralKeyPair.
  final EphemeralSignature ephemeralSignature;

  KeylessSignature({
    required this.jwtHeader,
    required this.ephemeralCertificate,
    required this.expiryDateSecs,
    required this.ephemeralPublicKey,
    required this.ephemeralSignature,
  });

  /// Get the kid of the JWT used to derive the Keyless Account used to sign.
  String getJwkKid() => parseJwtHeader(jwtHeader).kid;

  @override
  void serialize(Serializer serializer) {
    ephemeralCertificate.serialize(serializer);
    serializer.serializeStr(jwtHeader);
    serializer.serializeU64(BigInt.from(expiryDateSecs));
    ephemeralPublicKey.serialize(serializer);
    ephemeralSignature.serialize(serializer);
  }

  static KeylessSignature deserialize(Deserializer deserializer) {
    final ephemeralCertificate = EphemeralCertificate.deserialize(deserializer);
    final jwtHeader = deserializer.deserializeStr();
    final expiryDateSecs = deserializer.deserializeU64();
    final ephemeralPublicKey = EphemeralPublicKey.deserialize(deserializer);
    final ephemeralSignature = EphemeralSignature.deserialize(deserializer);
    return KeylessSignature(
      jwtHeader: jwtHeader,
      expiryDateSecs:
          u64ToIntSafe(expiryDateSecs, 'KeylessSignature.expiryDateSecs'),
      ephemeralCertificate: ephemeralCertificate,
      ephemeralPublicKey: ephemeralPublicKey,
      ephemeralSignature: ephemeralSignature,
    );
  }

  static KeylessSignature getSimulationSignature() {
    return KeylessSignature(
      jwtHeader: '{}',
      ephemeralCertificate: EphemeralCertificate(
        ZeroKnowledgeSig(
          proof: ZkProof(
            Groth16Zkp(
              a: Uint8List(32),
              b: Uint8List(64),
              c: Uint8List(32),
            ),
            ZkpVariant.groth16,
          ),
          expHorizonSecs: 0,
        ),
        EphemeralCertificateVariant.zkProof,
      ),
      expiryDateSecs: 0,
      ephemeralPublicKey: EphemeralPublicKey(Ed25519PublicKey(Uint8List(32))),
      ephemeralSignature: EphemeralSignature(Ed25519Signature(Uint8List(64))),
    );
  }

  static bool isSignature(Signature signature) => signature is KeylessSignature;
}

/// Represents an ephemeral certificate containing a signature, specifically a
/// ZeroKnowledgeSig. This class can be extended to support additional
/// signature types, such as OpenIdSignature.
class EphemeralCertificate extends Signature {
  final Signature signature;

  /// Index of the underlying enum variant.
  final EphemeralCertificateVariant variant;

  EphemeralCertificate(this.signature, this.variant);

  /// Get the signature in bytes.
  @override
  Uint8List toUint8Array() => signature.toUint8Array();

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(variant.value);
    signature.serialize(serializer);
  }

  static EphemeralCertificate deserialize(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant == EphemeralCertificateVariant.zkProof.value) {
      return EphemeralCertificate(
        ZeroKnowledgeSig.deserialize(deserializer),
        EphemeralCertificateVariant.zkProof,
      );
    }
    throw ArgumentError(
      'Unknown variant index for EphemeralCertificate: $variant',
    );
  }
}

/// Represents a fixed-size byte array of 32 bytes, extending the Serializable
/// class. This class is used for handling and serializing G1 bytes in
/// cryptographic operations.
class G1Bytes extends Serializable {
  final Uint8List data;

  /// Throws an [ArgumentError] if the input is not 32 bytes.
  G1Bytes(HexInput data) : data = Hex.fromHexInput(data).toUint8List() {
    if (this.data.length != 32) {
      throw ArgumentError('Input needs to be 32 bytes');
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(data);
  }

  static G1Bytes deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeFixedBytes(32);
    return G1Bytes(bytes);
  }

  /// Decodes the compressed bytes into an affine BN254 G1 point.
  G1Point toProjectivePoint() => G1Point.fromAptosCompressed(data);

  /// The point as snarkjs-style projective coordinate strings `[x, y, z]`.
  List<String> toArray() {
    final p = toProjectivePoint();
    final (x, y) = p.toAffine();
    return [x.toString(), y.toString(), p.isInfinity ? '0' : '1'];
  }
}

/// Represents a 64-byte G2 element in a cryptographic context.
/// This class provides methods for serialization and deserialization of G2
/// bytes.
class G2Bytes extends Serializable {
  final Uint8List data;

  /// Throws an [ArgumentError] if the input is not 64 bytes.
  G2Bytes(HexInput data) : data = Hex.fromHexInput(data).toUint8List() {
    if (this.data.length != 64) {
      throw ArgumentError('Input needs to be 64 bytes');
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(data);
  }

  static G2Bytes deserialize(Deserializer deserializer) {
    final bytes = deserializer.deserializeFixedBytes(64);
    return G2Bytes(bytes);
  }

  /// Decodes the compressed bytes into an affine BN254 G2 point.
  G2Point toProjectivePoint() => G2Point.fromAptosCompressed(data);

  /// The point as snarkjs-style projective coordinate string pairs
  /// `[[x.c0, x.c1], [y.c0, y.c1], [z.c0, z.c1]]`.
  List<List<String>> toArray() {
    final p = toProjectivePoint();
    final (x, y) = p.toAffine();
    return [
      [x.c0.toString(), x.c1.toString()],
      [y.c0.toString(), y.c1.toString()],
      p.isInfinity ? ['0', '0'] : ['1', '0'],
    ];
  }
}

/// Represents a Groth16 zero-knowledge proof, consisting of three proof points
/// in compressed serialization format. The points are the compressed
/// serialization of affine representation of the proof.
class Groth16Zkp extends Proof {
  /// The bytes of G1 proof point a.
  final G1Bytes a;

  /// The bytes of G2 proof point b.
  final G2Bytes b;

  /// The bytes of G1 proof point c.
  final G1Bytes c;

  Groth16Zkp({
    required HexInput a,
    required HexInput b,
    required HexInput c,
  })  : a = G1Bytes(a),
        b = G2Bytes(b),
        c = G1Bytes(c);

  @override
  void serialize(Serializer serializer) {
    a.serialize(serializer);
    b.serialize(serializer);
    c.serialize(serializer);
  }

  static Groth16Zkp deserialize(Deserializer deserializer) {
    final a = G1Bytes.deserialize(deserializer).bcsToBytes();
    final b = G2Bytes.deserialize(deserializer).bcsToBytes();
    final c = G1Bytes.deserialize(deserializer).bcsToBytes();
    return Groth16Zkp(a: a, b: b, c: c);
  }

  /// The proof as a snarkjs-compatible JSON map.
  Map<String, dynamic> toSnarkJsJson() => {
        'protocol': 'groth16',
        'curve': 'bn128',
        'pi_a': a.toArray(),
        'pi_b': b.toArray(),
        'pi_c': c.toArray(),
      };
}

/// Represents a Groth16 proof and statement, consisting of a Groth16 proof and
/// a public inputs hash. This is used to generate the signing message for the
/// training wheels signature.
class Groth16ProofAndStatement extends Serializable {
  /// The Groth16 proof.
  final Groth16Zkp proof;

  /// The public inputs hash as a 32 byte Uint8List.
  final Uint8List publicInputsHash;

  /// The domain separator prefix used when hashing.
  static const String domainSeparator = 'APTOS::Groth16ProofAndStatement';

  /// [publicInputsHash] may be a [BigInt] (converted to 32 little-endian
  /// bytes) or a [HexInput].
  ///
  /// Throws an [ArgumentError] if the resulting hash is not 32 bytes.
  Groth16ProofAndStatement(this.proof, Object publicInputsHash)
      : publicInputsHash = publicInputsHash is BigInt
            ? bigIntToBytesLE(publicInputsHash, 32)
            : Hex.fromHexInput(publicInputsHash).toUint8List() {
    if (this.publicInputsHash.length != 32) {
      throw ArgumentError('Invalid public inputs hash');
    }
  }

  @override
  void serialize(Serializer serializer) {
    proof.serialize(serializer);
    serializer.serializeFixedBytes(publicInputsHash);
  }

  static Groth16ProofAndStatement deserialize(Deserializer deserializer) {
    return Groth16ProofAndStatement(
      Groth16Zkp.deserialize(deserializer),
      deserializer.deserializeFixedBytes(32),
    );
  }

  /// Generates the 'signing message' form of this struct: the SHA3-256 hash
  /// of the domain separator followed by the BCS bytes.
  Uint8List hash() {
    final prefix = SHA3Digest(256)
        .process(Uint8List.fromList(utf8.encode(domainSeparator)));
    final body = bcsToBytes();
    final merged = Uint8List(prefix.length + body.length);
    merged.setRange(0, prefix.length, prefix);
    merged.setRange(prefix.length, merged.length, body);
    return merged;
  }
}

/// Represents a container for different types of zero-knowledge proofs.
class ZkProof extends Serializable {
  final Proof proof;

  /// Index of the underlying enum variant.
  final ZkpVariant variant;

  ZkProof(this.proof, this.variant);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(variant.value);
    proof.serialize(serializer);
  }

  static ZkProof deserialize(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant == ZkpVariant.groth16.value) {
      return ZkProof(Groth16Zkp.deserialize(deserializer), ZkpVariant.groth16);
    }
    throw ArgumentError('Unknown variant index for ZkProof: $variant');
  }
}

/// Represents a zero-knowledge signature, encapsulating the proof and its
/// associated metadata.
class ZeroKnowledgeSig extends Signature {
  /// The proof.
  final ZkProof proof;

  /// The max lifespan of the proof.
  final int expHorizonSecs;

  /// A key value pair on the JWT token that can be specified on the signature
  /// which would reveal the value on chain. Can be used to assert identity or
  /// other attributes.
  final String? extraField;

  /// The 'aud' value of the recovery service which is set when recovering an
  /// account.
  final String? overrideAudVal;

  /// The training wheels signature.
  final EphemeralSignature? trainingWheelsSignature;

  ZeroKnowledgeSig({
    required this.proof,
    required this.expHorizonSecs,
    this.extraField,
    this.overrideAudVal,
    this.trainingWheelsSignature,
  });

  /// Deserialize a ZeroKnowledgeSig object from its BCS serialization in
  /// bytes.
  static ZeroKnowledgeSig fromBytes(Uint8List bytes) {
    return ZeroKnowledgeSig.deserialize(Deserializer(bytes));
  }

  @override
  void serialize(Serializer serializer) {
    proof.serialize(serializer);
    serializer.serializeU64(BigInt.from(expHorizonSecs));
    serializer.serializeOptionStr(extraField);
    serializer.serializeOptionStr(overrideAudVal);
    serializer.serializeOption(trainingWheelsSignature);
  }

  static ZeroKnowledgeSig deserialize(Deserializer deserializer) {
    final proof = ZkProof.deserialize(deserializer);
    final expHorizonSecs = u64ToIntSafe(
      deserializer.deserializeU64(),
      'ZeroKnowledgeSig.expHorizonSecs',
    );
    final extraField = deserializer.deserializeOptionStr();
    final overrideAudVal = deserializer.deserializeOptionStr();
    final trainingWheelsSignature =
        deserializer.deserializeOption(EphemeralSignature.deserialize);
    return ZeroKnowledgeSig(
      proof: proof,
      expHorizonSecs: expHorizonSecs,
      trainingWheelsSignature: trainingWheelsSignature,
      extraField: extraField,
      overrideAudVal: overrideAudVal,
    );
  }
}

/// Represents the on-chain configuration for how Keyless accounts operate.
///
/// This class encapsulates the verification key and the maximum lifespan of
/// ephemeral key pairs, which are essential for the functionality of Keyless
/// accounts.
class KeylessConfiguration {
  /// The verification key used to verify Groth16 proofs on chain.
  final Groth16VerificationKey verificationKey;

  /// The maximum lifespan of an ephemeral key pair. This is configured on
  /// chain.
  final int maxExpHorizonSecs;

  /// The public key of the training wheels account.
  final EphemeralPublicKey? trainingWheelsPubkey;

  /// The maximum number of bytes that can be used for the extra field.
  final int maxExtraFieldBytes;

  /// The maximum number of bytes that can be used for the JWT header.
  final int maxJwtHeaderB64Bytes;

  /// The maximum number of bytes that can be used for the issuer value.
  final int maxIssValBytes;

  /// The maximum number of bytes that can be used for the committed ephemeral
  /// public key.
  final int maxCommitedEpkBytes;

  KeylessConfiguration({
    required this.verificationKey,
    HexInput? trainingWheelsPubkey,
    int? maxExpHorizonSecs,
    int? maxExtraFieldBytes,
    int? maxJwtHeaderB64Bytes,
    int? maxIssValBytes,
    int? maxCommitedEpkBytes,
  })  : trainingWheelsPubkey = trainingWheelsPubkey != null
            ? EphemeralPublicKey(Ed25519PublicKey(trainingWheelsPubkey))
            : null,
        maxExpHorizonSecs = maxExpHorizonSecs ?? epkHorizonSecs,
        maxExtraFieldBytes = maxExtraFieldBytes ?? _defaultMaxExtraFieldBytes,
        maxJwtHeaderB64Bytes =
            maxJwtHeaderB64Bytes ?? _defaultMaxJwtHeaderB64Bytes,
        maxIssValBytes = maxIssValBytes ?? _defaultMaxIssValBytes,
        maxCommitedEpkBytes =
            maxCommitedEpkBytes ?? _defaultMaxCommitedEpkBytes;

  /// Creates a new KeylessConfiguration instance from a
  /// [Groth16VerificationKeyResponse] and a [KeylessConfigurationResponse].
  static KeylessConfiguration create(
    Groth16VerificationKeyResponse res,
    KeylessConfigurationResponse config,
  ) {
    return KeylessConfiguration(
      verificationKey: Groth16VerificationKey(
        alphaG1: res.alphaG1,
        betaG2: res.betaG2,
        deltaG2: res.deltaG2,
        gammaAbcG1: res.gammaAbcG1,
        gammaG2: res.gammaG2,
      ),
      // Chain config returns u64 as a decimal string; widen → safe-narrow so
      // a malformed/exotic value throws rather than silently truncates.
      maxExpHorizonSecs: u64ToIntSafe(
        BigInt.parse(config.maxExpHorizonSecs),
        'KeylessConfiguration.maxExpHorizonSecs',
      ),
      trainingWheelsPubkey: config.trainingWheelsPubkey,
      maxExtraFieldBytes: config.maxExtraFieldBytes,
      maxJwtHeaderB64Bytes: config.maxJwtHeaderB64Bytes,
      maxIssValBytes: config.maxIssValBytes,
      maxCommitedEpkBytes: config.maxCommitedEpkBytes,
    );
  }
}

/// Represents the verification key stored on-chain used to verify Groth16
/// proofs.
class Groth16VerificationKey {
  // The docstrings below are borrowed from ark-groth16.

  /// The `alpha * G`, where `G` is the generator of G1.
  final G1Bytes alphaG1;

  /// The `alpha * H`, where `H` is the generator of G2.
  final G2Bytes betaG2;

  /// The `delta * H`, where `H` is the generator of G2.
  final G2Bytes deltaG2;

  /// The `gamma^{-1} * (beta * a_i + alpha * b_i + c_i) * H`, where H is the
  /// generator of G1.
  final List<G1Bytes> gammaAbcG1;

  /// The `gamma * H`, where `H` is the generator of G2.
  final G2Bytes gammaG2;

  Groth16VerificationKey({
    required HexInput alphaG1,
    required HexInput betaG2,
    required HexInput deltaG2,
    required List<HexInput> gammaAbcG1,
    required HexInput gammaG2,
  })  : alphaG1 = G1Bytes(alphaG1),
        betaG2 = G2Bytes(betaG2),
        deltaG2 = G2Bytes(deltaG2),
        gammaAbcG1 = [G1Bytes(gammaAbcG1[0]), G1Bytes(gammaAbcG1[1])],
        gammaG2 = G2Bytes(gammaG2);

  /// Calculates the hash of the serialized form of the verification key.
  /// This is useful for comparing verification keys or using them as unique
  /// identifiers.
  Uint8List hash() {
    final serializer = Serializer();
    serialize(serializer);
    return SHA3Digest(256).process(serializer.toUint8List());
  }

  void serialize(Serializer serializer) {
    alphaG1.serialize(serializer);
    betaG2.serialize(serializer);
    deltaG2.serialize(serializer);
    gammaAbcG1[0].serialize(serializer);
    gammaAbcG1[1].serialize(serializer);
    gammaG2.serialize(serializer);
  }

  /// Converts a [Groth16VerificationKeyResponse] object into a
  /// Groth16VerificationKey instance.
  static Groth16VerificationKey fromGroth16VerificationKeyResponse(
    Groth16VerificationKeyResponse res,
  ) {
    return Groth16VerificationKey(
      alphaG1: res.alphaG1,
      betaG2: res.betaG2,
      deltaG2: res.deltaG2,
      gammaAbcG1: res.gammaAbcG1,
      gammaG2: res.gammaG2,
    );
  }

  /// Verifies a Groth16 proof using the verification key given the public
  /// inputs hash and the proof.
  ///
  /// Checks the pairing equation
  /// `e(A, B) = e(α, β) · e(ic₀ + h·ic₁, γ) · e(C, δ)`, where `A`, `B`, `C`
  /// are the proof points, `h` is [publicInputsHash], and the remaining
  /// points come from this verification key.
  bool verifyProof({
    required BigInt publicInputsHash,
    required Groth16Zkp groth16Proof,
  }) {
    final proofA = groth16Proof.a.toProjectivePoint();
    final proofB = groth16Proof.b.toProjectivePoint();
    final proofC = groth16Proof.c.toProjectivePoint();

    final vkAlpha1 = alphaG1.toProjectivePoint();
    final vkBeta2 = betaG2.toProjectivePoint();
    final vkGamma2 = gammaG2.toProjectivePoint();
    final vkDelta2 = deltaG2.toProjectivePoint();
    final vkIc = gammaAbcG1.map((g1) => g1.toProjectivePoint()).toList();

    // ic₀ + publicInputsHash · ic₁
    final accum = vkIc[0].add(vkIc[1].multiply(publicInputsHash));

    final pairingAccumGamma = bn254Pairing(accum, vkGamma2);
    final pairingAb = bn254Pairing(proofA, proofB);
    final pairingAlphaBeta = bn254Pairing(vkAlpha1, vkBeta2);
    final pairingCDelta = bn254Pairing(proofC, vkDelta2);

    final product = pairingAlphaBeta.mul(pairingAccumGamma.mul(pairingCDelta));
    return pairingAb.eql(product);
  }

  /// The verification key as a snarkjs-compatible JSON map.
  Map<String, dynamic> toSnarkJsJson() => {
        'protocol': 'groth16',
        'curve': 'bn128',
        'nPublic': 1,
        'vk_alpha_1': alphaG1.toArray(),
        'vk_beta_2': betaG2.toArray(),
        'vk_gamma_2': gammaG2.toArray(),
        'vk_delta_2': deltaG2.toArray(),
        'IC': gammaAbcG1.map((g1) => g1.toArray()).toList(),
      };
}

/// Parses a JWT and returns the 'iss', 'aud', and 'uid' values.
///
/// SECURITY: This function decodes claims without verifying the JWT
/// signature. The keyless on-chain verifier is the authority that binds a JWT
/// to its IdP; the SDK only uses these claims to derive the keyless account
/// address and package the JWT for the prover service. Callers must source
/// [jwt] from a trusted IdP redirect flow.
///
/// [uidKey] is the key to use for the 'uid' value; defaults to 'sub'.
({String iss, String aud, String uidVal}) getIssAudAndUidVal({
  required String jwt,
  String uidKey = 'sub',
}) {
  final Map<String, dynamic> jwtPayload;
  try {
    // SECURITY: signature is not verified here — see function-level doc.
    jwtPayload = _decodeJwtPayload(jwt);
  } on ArgumentError {
    rethrow;
  } catch (_) {
    // Sanitized error message - don't expose parsing details.
    throw ArgumentError('Invalid JWT format');
  }
  final iss = jwtPayload['iss'];
  if (iss is! String) {
    // Sanitized error message - don't expose internal structure.
    throw ArgumentError('Invalid JWT: missing required claim');
  }
  final aud = jwtPayload['aud'];
  if (aud is! String) {
    // Sanitized error message - don't expose internal structure.
    throw ArgumentError('Invalid JWT: missing or malformed required claim');
  }
  final uidVal = jwtPayload[uidKey];
  return (iss: iss, aud: aud, uidVal: '$uidVal');
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

/// A JSON Web Key (JWK) as represented on chain
/// (`0x1::jwks::RSA_JWK`), used to verify the OIDC provider signature over the
/// JWT during keyless verification. Serializes to and from the on-chain BCS
/// layout and exposes the RSA `kid`/`n`/`e` fields.
class MoveJWK extends Serializable {
  final String kid;
  final String kty;
  final String alg;
  final String e;
  final String n;

  MoveJWK({
    required this.kid,
    required this.kty,
    required this.alg,
    required this.e,
    required this.n,
  });

  @override
  void serialize(Serializer serializer) {
    serializer.serializeStr(kid);
    serializer.serializeStr(kty);
    serializer.serializeStr(alg);
    serializer.serializeStr(e);
    serializer.serializeStr(n);
  }

  static MoveJWK fromMoveStruct(MoveAnyStruct struct) {
    final data = struct.variant.data;
    final deserializer = Deserializer(Hex.fromHexInput(data).toUint8List());
    return MoveJWK.deserialize(deserializer);
  }

  /// Converts the JWK's RSA modulus into a scalar field element via Poseidon
  /// hashing, as used in the public inputs hash.
  ///
  /// Throws a [StateError] if the JWK algorithm is not RS256.
  BigInt toScalar() {
    if (alg != 'RS256') {
      throw StateError(
        'Failed to convert JWK to scalar when calculating the public inputs '
        'hash. Only RSA 256 is supported currently',
      );
    }
    final bytes = base64UrlToBytes(n);
    final reversed = Uint8List.fromList(bytes.reversed.toList());
    final chunks = _chunkInto24Bytes(reversed);
    final scalars = chunks.map<Object>(bytesToBigIntLE).toList();
    scalars.add(BigInt.from(256)); // Add the modulus size
    return poseidonHash(scalars);
  }

  static MoveJWK deserialize(Deserializer deserializer) {
    final kid = deserializer.deserializeStr();
    final kty = deserializer.deserializeStr();
    final alg = deserializer.deserializeStr();
    final e = deserializer.deserializeStr();
    final n = deserializer.deserializeStr();
    return MoveJWK(kid: kid, kty: kty, alg: alg, n: n, e: e);
  }
}

List<Uint8List> _chunkInto24Bytes(Uint8List data) {
  final chunks = <Uint8List>[];
  for (var i = 0; i < data.length; i += 24) {
    final end = i + 24 < data.length ? i + 24 : data.length;
    final chunk = data.sublist(i, end);
    // Pad last chunk with zeros if needed.
    if (chunk.length < 24) {
      final paddedChunk = Uint8List(24);
      paddedChunk.setRange(0, chunk.length, chunk);
      chunks.add(paddedChunk);
    } else {
      chunks.add(chunk);
    }
  }
  return chunks;
}

/// A parsed JWT header.
class JwtHeader {
  /// Key ID.
  final String kid;

  JwtHeader({required this.kid});
}

/// Safely parses the JWT header.
///
/// Throws an [ArgumentError] if the header is invalid or missing required
/// fields.
JwtHeader parseJwtHeader(String jwtHeader) {
  final Object? header;
  try {
    header = jsonDecode(jwtHeader);
  } catch (_) {
    // Sanitized error message - don't expose parsing details.
    throw ArgumentError('Invalid JWT header format');
  }
  if (header is! Map<String, dynamic> || header['kid'] == null) {
    // Sanitized error message - don't expose internal structure.
    throw ArgumentError('Invalid JWT header: missing required field');
  }
  return JwtHeader(kid: '${header['kid']}');
}
