/// Keyless-related request/response DTOs mirrored from the pepper and prover
/// services and on-chain resources.
library;

/// The payload for a prover request, containing a Base64-encoded JWT.
class ProverRequest {
  ProverRequest({
    required this.jwtB64,
    required this.epk,
    required this.expDateSecs,
    required this.expHorizonSecs,
    required this.epkBlinder,
    required this.uidKey,
    required this.pepper,
  });

  final String jwtB64;
  final String epk;
  final int expDateSecs;
  final int expHorizonSecs;
  final String epkBlinder;
  final String uidKey;
  final String pepper;

  Map<String, dynamic> toJson() => {
        'jwt_b64': jwtB64,
        'epk': epk,
        'exp_date_secs': expDateSecs,
        'exp_horizon_secs': expHorizonSecs,
        'epk_blinder': epkBlinder,
        'uid_key': uidKey,
        'pepper': pepper,
      };
}

/// The response from the prover containing the proof data.
class ProverResponse {
  ProverResponse({
    required this.proof,
    required this.publicInputsHash,
    required this.trainingWheelsSignature,
  });

  factory ProverResponse.fromJson(Map<String, dynamic> json) {
    final proof = json['proof'] as Map<String, dynamic>;
    return ProverResponse(
      proof: (
        a: proof['a'] as String,
        b: proof['b'] as String,
        c: proof['c'] as String,
      ),
      publicInputsHash: json['public_inputs_hash'] as String,
      trainingWheelsSignature: json['training_wheels_signature'] as String,
    );
  }

  final ({String a, String b, String c}) proof;
  final String publicInputsHash;
  final String trainingWheelsSignature;
}

/// The request payload for fetching a pepper, containing a base64 encoded JWT.
class PepperFetchRequest {
  PepperFetchRequest({
    required this.jwtB64,
    required this.epk,
    required this.expDateSecs,
    required this.epkBlinder,
    required this.uidKey,
    required this.derivationPath,
  });

  final String jwtB64;
  final String epk;
  final int expDateSecs;
  final String epkBlinder;
  final String uidKey;
  final String derivationPath;

  Map<String, dynamic> toJson() => {
        'jwt_b64': jwtB64,
        'epk': epk,
        'exp_date_secs': expDateSecs,
        'epk_blinder': epkBlinder,
        'uid_key': uidKey,
        'derivation_path': derivationPath,
      };
}

/// The response object containing the fetched pepper string.
class PepperFetchResponse {
  PepperFetchResponse({required this.pepper, required this.address});

  factory PepperFetchResponse.fromJson(Map<String, dynamic> json) =>
      PepperFetchResponse(
        pepper: json['pepper'] as String,
        address: json['address'] as String,
      );

  final String pepper;
  final String address;
}

/// The response from the pepper service `signature` endpoint, containing the
/// VUF signature — i.e. the 48-byte `pepper_base` (compressed BLS12-381 G1
/// point) from which the final pepper is derived.
class SignatureFetchResponse {
  SignatureFetchResponse({required this.signature});

  factory SignatureFetchResponse.fromJson(Map<String, dynamic> json) =>
      SignatureFetchResponse(signature: json['signature'] as String);

  final String signature;
}

/// The response for the on-chain keyless configuration resource
/// (`0x1::keyless_account::Configuration`).
class KeylessConfigurationResponse {
  KeylessConfigurationResponse({
    required this.maxCommitedEpkBytes,
    required this.maxExpHorizonSecs,
    required this.maxExtraFieldBytes,
    required this.maxIssValBytes,
    required this.maxJwtHeaderB64Bytes,
    required this.maxSignaturesPerTxn,
    required this.overrideAudVals,
    required this.trainingWheelsPubkey,
  });

  factory KeylessConfigurationResponse.fromJson(Map<String, dynamic> json) {
    final trainingWheels =
        (json['training_wheels_pubkey'] as Map<String, dynamic>)['vec'] as List;
    return KeylessConfigurationResponse(
      maxCommitedEpkBytes: json['max_commited_epk_bytes'] as int,
      maxExpHorizonSecs: json['max_exp_horizon_secs'] as String,
      maxExtraFieldBytes: json['max_extra_field_bytes'] as int,
      maxIssValBytes: json['max_iss_val_bytes'] as int,
      maxJwtHeaderB64Bytes: json['max_jwt_header_b64_bytes'] as int,
      maxSignaturesPerTxn: json['max_signatures_per_txn'] as int,
      overrideAudVals:
          (json['override_aud_vals'] as List).cast<String>(),
      trainingWheelsPubkey:
          trainingWheels.isEmpty ? null : trainingWheels.first as String,
    );
  }

  final int maxCommitedEpkBytes;

  /// A u64 returned by the chain as a decimal string.
  final String maxExpHorizonSecs;
  final int maxExtraFieldBytes;
  final int maxIssValBytes;
  final int maxJwtHeaderB64Bytes;
  final int maxSignaturesPerTxn;
  final List<String> overrideAudVals;

  /// The training wheels public key, if set (`{ vec: [pubkey] }` on chain).
  final String? trainingWheelsPubkey;
}

/// The response containing the on-chain Groth16 verification key
/// (`0x1::keyless_account::Groth16VerificationKey`).
class Groth16VerificationKeyResponse {
  Groth16VerificationKeyResponse({
    required this.alphaG1,
    required this.betaG2,
    required this.deltaG2,
    required this.gammaAbcG1,
    required this.gammaG2,
  });

  factory Groth16VerificationKeyResponse.fromJson(Map<String, dynamic> json) =>
      Groth16VerificationKeyResponse(
        alphaG1: json['alpha_g1'] as String,
        betaG2: json['beta_g2'] as String,
        deltaG2: json['delta_g2'] as String,
        gammaAbcG1: (json['gamma_abc_g1'] as List).cast<String>(),
        gammaG2: json['gamma_g2'] as String,
      );

  final String alphaG1;
  final String betaG2;
  final String deltaG2;

  /// Exactly two G1 points.
  final List<String> gammaAbcG1;
  final String gammaG2;
}

/// The response containing the patched JWKs resource (`0x1::jwks::PatchedJWKs`
/// or `0x1::jwks::FederatedJWKs`).
class PatchedJWKsResponse {
  PatchedJWKsResponse({required this.jwks});

  factory PatchedJWKsResponse.fromJson(Map<String, dynamic> json) {
    final jwks = json['jwks'] as Map<String, dynamic>;
    return PatchedJWKsResponse(
      jwks: (
        entries: (jwks['entries'] as List)
            .map((e) => IssuerJWKS.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  final ({List<IssuerJWKS> entries}) jwks;
}

/// A set of JWKs belonging to a single issuer.
class IssuerJWKS {
  IssuerJWKS({required this.issuer, required this.jwks});

  factory IssuerJWKS.fromJson(Map<String, dynamic> json) => IssuerJWKS(
        issuer: json['issuer'] as String,
        jwks: (json['jwks'] as List)
            .map((e) => MoveAnyStruct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String issuer;
  final List<MoveAnyStruct> jwks;
}

/// A Move `any::Any` struct variant containing BCS-serialized data and the
/// Move type name of that data.
class MoveAnyStruct {
  MoveAnyStruct({required this.variant});

  factory MoveAnyStruct.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] as Map<String, dynamic>;
    return MoveAnyStruct(
      variant: (
        data: variant['data'] as String,
        typeName: variant['type_name'] as String,
      ),
    );
  }

  final ({String data, String typeName}) variant;
}
