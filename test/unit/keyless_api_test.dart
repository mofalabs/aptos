import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/src/account/ephemeral_key_pair.dart';
import 'package:aptos/src/account/federated_keyless_account.dart';
import 'package:aptos/src/account/keyless_account.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/api/keyless.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/keyless.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/internal/keyless.dart' as internal_keyless;
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:aptos/src/utils/memoize.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const keylessTestObject = (
  jwt:
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3QtcnNhIn0.eyJpc3MiOiJ0ZXN0Lm9pZGMucHJvdmlkZXIiLCJhdWQiOiJ0ZXN0LWtleWxlc3MtZGFwcCIsInN1YiI6InRlc3QtdXNlci0wIiwiZW1haWwiOiJ0ZXN0QGFwdG9zbGFicy5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaWF0Ijo5ODc2NTQzMjA5LCJleHAiOjk4NzY1NDMyMTAsIm5vbmNlIjoiMTk2NDM2OTg4NjEyNjU1Njc4MDQ5MDk5MTMxMzA1MDcyNDc4MTQ1MjY5MTM1NzAyMjgzMTY0MTczNzc5NjUxMDU2ODE3OTYxNzMwOTgifQ.C6QG9WyEIAqYEiLkY8-5yqTKYtCzmnu2RM4P7iqr17toRXhL2ZqCiQYgE2TpY60RlOqBI7_aiHOlxJRvF_iQghEQQSWkgWhkcjVkSvBJW0IHm0IrSRl9ZytQHi6x0vPa8bUff5L--9JfxMiH27wOTrGtTA1n8Fz3G8JKQfYNQF2VawzytJu3lywduRj6pZw9-FFTgPqPsZWQvwhiX75Tgud976CpDusKOrPAM3rA9fXgKo_aTKeOPiEIm11ezI1bsOJ3B4JhsxLT5vszZ11Ywytst8XXwqWHjnulkJWjM9QfVUJhsO-jEQ5T_dYDqMVnnkdzjJyMRbvgbyNPUkvx8Q',
  publicKey:
      '0x12746573742e6f6964632e70726f766964657220bdc98aab184dc40bbb5c483410ccac4c0b2ef20eeac8d568cf25125e9cdafc0f',
  iss: 'test.oidc.provider',
  pepper: '0x772714089792b0bc8c621843bd88599627c74564c47cb4dc7bc0196914a56c',
  proofHex:
      '0x00ac1c3add4fa703c66a940e9e947a71bcdb8f30258e72460c01f63d6236d9b2a835188c3ac199bea3905270b9660ddafacbf4f9addb93a3e235e9703ca72c40258362273f596f93594499527ca4802ef40cf0166ba3bd2d65d1a7f50562060127dcdcd995f9ae5e193582cce456f3ddfe8c0c935719ad8636a8e777369279d5a480969800000000000000010040d6433ea43090d25fc4f4a15c362a98a5343dcf4e29e3854f3b74d0d99a0b43abd9955c55a7d20f47372a5802a0e26cc4f860969109d48c9e989dab8287c41501',
  // The account address = auth key (no rotation recorded on chain).
  address: '0x3d255a4ea36dfedc32205a522f440064fab38fb2d8cf727642d113cb8d43045f',
  jwkHex:
      '0x08746573742d727361035253410552533235360441514142d6027935456673315a7a69734c4c4b4341525376547a7467576a354a465033373738645a57742d6f643738666d4f5a4678656d33615f6159624f58534a546f5270383632646f3050784a3450444d706d7177563566374b706c4649364e737751562d57507566514838496148585a74755064436a504f634879626344694c6b4f31326430644736695a51557a79706a414a6636334150636164696f2d344a444e576c4743355f4f775f5851396c495937316b544d6954396c6b434364305a787145696647746e4a653578536f5a6f614d524b72766c4f772d523669566a4c557450416b356879555839354c444b787741522d6f73686e6a37676d4154656a676132457648396f7a646e334d38476f31315053446130344f517850634132354f6f445466784c765432384c5270535872626d55575a2d4f5f6c4774446c335a41746a4967755947456f62546b344e3131655273734339354377',
);

/// The `EPHEMERAL_KEY_PAIR` fixture ephemeral key pair.
EphemeralKeyPair makeFixtureEphemeralKeyPair() => EphemeralKeyPair(
      privateKey: Ed25519PrivateKey(
        'ed25519-priv-'
        '0x1111111111111111111111111111111111111111111111111111111111111111',
      ),
      expiryDateSecs: 9876543210, // Friday, December 22, 2282
      blinder: Uint8List(31),
    );

ZeroKnowledgeSig fixtureProof() => ZeroKnowledgeSig.fromBytes(
      Hex.fromHexInput(keylessTestObject.proofHex).toUint8List(),
    );

/// The on-chain keyless configuration resource (canned), matching the
/// fixture proof's `expHorizonSecs` of 10000000.
Map<String, dynamic> keylessConfigResource() => {
      'max_commited_epk_bytes': 93,
      'max_exp_horizon_secs': '10000000',
      'max_extra_field_bytes': 350,
      'max_iss_val_bytes': 120,
      'max_jwt_header_b64_bytes': 300,
      'max_signatures_per_txn': 3,
      'override_aud_vals': <String>[],
      'training_wheels_pubkey': {
        'vec': [
          '0x1388de358cf4701696bd58ed4b96e9d670cbbb914b888be1ceda6374a3098ed4',
        ],
      },
    };

/// The on-chain Groth16 verification key resource (canned).
Map<String, dynamic> vkResource() => {
      'alpha_g1':
          '0xe2f26dbea299f5223b646cb1fb33eadb059d9407559d7441dfd902e3a79a4d2d',
      'beta_g2':
          '0xabb73dc17fbc13021e2471e0c08bd67d8401f52b73d6d07483794cad4778180e0c06f33bbc4c79a9cadef253a68084d382f17788f885c9afd176f7cb2f036789',
      'delta_g2':
          '0xb106619932d0ef372c46909a2492e246d5de739aa140e27f2c71c0470662f125219049cfe15e4d140d7e4bb911284aad1cad19880efb86f2d9dd4b1bb344ef8f',
      'gamma_abc_g1': [
        '0x6123b6fea40de2a7e3595f9c35210da8a45a7e8c2f7da9eb4548e9210cfea81a',
        '0x32a9b8347c512483812ee922dc75952842f8f3083edb6fe8d5c3c07e1340b683',
      ],
      'gamma_g2':
          '0xedf692d95cbdde46ddda5ef7d422436779445c5e66006a42761e1f12efde0018c212f3aeb785e49712e7a9353349aaf1255dfb31b7bf60723a480d9293938e19',
    };

/// The prover service response (canned), constructed from the fixture proof so
/// that `getProof` reassembles a byte-identical `ZeroKnowledgeSig`.
Map<String, dynamic> proverResponse() {
  final zkSig = fixtureProof();
  final groth16 = zkSig.proof.proof as Groth16Zkp;
  return {
    'proof': {
      'a': Hex(groth16.a.data).toString(),
      'b': Hex(groth16.b.data).toString(),
      'c': Hex(groth16.c.data).toString(),
    },
    'public_inputs_hash': '0x00',
    'training_wheels_signature':
        zkSig.trainingWheelsSignature!.bcsToHex().toString(),
  };
}

/// The 0x1::jwks::PatchedJWKs resource (canned) containing the fixture JWK
/// for the fixture issuer.
Map<String, dynamic> patchedJwksResource() => {
      'type': '0x1::jwks::PatchedJWKs',
      'data': {
        'jwks': {
          'entries': [
            {
              'issuer': Hex.fromHexInput(
                Uint8List.fromList(utf8.encode(keylessTestObject.iss)),
              ).toString(),
              'jwks': [
                {
                  'variant': {
                    'data': keylessTestObject.jwkHex,
                    'type_name': '0x1::jwks::RSA_JWK',
                  },
                },
              ],
            },
          ],
        },
      },
    };

/// A fake client that dispatches canned responses by URL.
class ResponderClient implements Client {
  final List<ClientRequest> requests = [];

  ResponderClient();

  @override
  Future<ClientResponse<dynamic>> provider(ClientRequest request) async {
    requests.add(request);
    final url = request.url;
    if (url.contains('keyless_account::Configuration')) {
      return ClientResponse(status: 200, data: {
        'type': '0x1::keyless_account::Configuration',
        'data': keylessConfigResource(),
      });
    }
    if (url.contains('Groth16VerificationKey')) {
      return ClientResponse(status: 200, data: {
        'type': '0x1::keyless_account::Groth16VerificationKey',
        'data': vkResource(),
      });
    }
    if (url.contains('PatchedJWKs')) {
      return ClientResponse(status: 200, data: patchedJwksResource());
    }
    if (url.contains('FederatedJWKs')) {
      return ClientResponse(status: 200, data: {
        'type': '0x1::jwks::FederatedJWKs',
        'data': patchedJwksResource()['data'],
      });
    }
    if (url == 'https://pepper.example/v0/fetch') {
      return ClientResponse(status: 200, data: {
        'pepper': keylessTestObject.pepper,
        'address': keylessTestObject.address,
      });
    }
    if (url == 'https://pepper.example/v0/signature') {
      return ClientResponse(status: 200, data: {
        'signature': '0x${'ab' * 48}',
      });
    }
    if (url == 'https://prover.example/v0/prove') {
      return ClientResponse(status: 200, data: proverResponse());
    }
    if (url.contains('OriginatingAddress')) {
      return const ClientResponse(status: 200, data: {
        'type': '0x1::account::OriginatingAddress',
        'data': {
          'address_map': {'handle': '0x1'},
        },
      });
    }
    if (url.contains('/tables/') && url.contains('/item')) {
      return const ClientResponse(
        status: 404,
        statusText: 'Not Found',
        data: {
          'message': 'table item not found',
          'error_code': 'table_item_not_found',
        },
      );
    }
    return const ClientResponse(status: 200, data: {});
  }

  Iterable<ClientRequest> requestsTo(String fragment) =>
      requests.where((r) => r.url.contains(fragment));
}

(AptosConfig, ResponderClient) makeConfig() {
  final client = ResponderClient();
  final config = AptosConfig(
    network: Network.devnet,
    client: client,
    pepper: 'https://pepper.example/v0',
    prover: 'https://prover.example/v0',
  );
  return (config, client);
}

void main() {
  setUp(clearMemoizeCache);

  group('getPepper', () {
    test('POSTs the JWT and ephemeral key material to the fetch endpoint',
        () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);
      final ephemeralKeyPair = makeFixtureEphemeralKeyPair();

      final pepper = await keyless.getPepper(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: ephemeralKeyPair,
      );

      expect(Hex.fromHexInput(pepper).toString(), keylessTestObject.pepper);

      final request = client.requests.single;
      expect(request.method, 'POST');
      expect(request.url, 'https://pepper.example/v0/fetch');
      final body = request.body as Map;
      expect(body['jwt_b64'], keylessTestObject.jwt);
      expect(body['uid_key'], 'sub');
      expect(body['exp_date_secs'], 9876543210);
      expect(
        body['epk'],
        ephemeralKeyPair.getPublicKey().bcsToHex().toStringWithoutPrefix(),
      );
      expect(body['epk_blinder'], '00' * 31);
      // A missing derivation path is omitted from the body (undefined in TS).
      expect(body.containsKey('derivation_path'), isFalse);
    });

    test('passes the derivation path through when provided', () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      await keyless.getPepper(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        derivationPath: "m/44'/637'/0'/0'/0",
      );

      final body = client.requests.single.body as Map;
      expect(body['derivation_path'], "m/44'/637'/0'/0'/0");
    });
  });

  group('getPepperBase', () {
    test('POSTs to the signature endpoint and returns the 48-byte base',
        () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      final pepperBase = await keyless.getPepperBase(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        uidKey: 'email',
      );

      expect(pepperBase, hasLength(48));
      expect(Hex.fromHexInput(pepperBase).toString(), '0x${'ab' * 48}');

      final request = client.requests.single;
      expect(request.method, 'POST');
      expect(request.url, 'https://pepper.example/v0/signature');
      expect((request.body as Map)['uid_key'], 'email');
    });
  });

  group('getProof', () {
    test(
        'fetches the on-chain config, POSTs to the prover, and parses the '
        'response into the fixture ZeroKnowledgeSig', () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      final proof = await keyless.getProof(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        pepper: keylessTestObject.pepper,
      );

      // The keyless configuration was fetched from the fullnode.
      expect(
        client.requestsTo('keyless_account::Configuration'),
        hasLength(1),
      );
      expect(client.requestsTo('Groth16VerificationKey'), hasLength(1));

      // The prover request carries the pepper and horizon.
      final proverRequest = client.requestsTo('prove').single;
      expect(proverRequest.method, 'POST');
      final body = proverRequest.body as Map;
      expect(body['jwt_b64'], keylessTestObject.jwt);
      expect(
        body['pepper'],
        Hex.fromHexInput(keylessTestObject.pepper).toStringWithoutPrefix(),
      );
      expect(body['exp_horizon_secs'], 10000000);
      expect(body['uid_key'], 'sub');

      // The Groth16 proof deserialized from the prover JSON reassembles the
      // fixture proof byte for byte.
      expect(proof.expHorizonSecs, 10000000);
      expect(proof.trainingWheelsSignature, isNotNull);
      expect(
        Hex(proof.bcsToBytes()).toString(),
        keylessTestObject.proofHex,
      );
    });

    test('rejects peppers that are not exactly 31 bytes', () async {
      final (config, _) = makeConfig();

      await expectLater(
        internal_keyless.getProof(
          aptosConfig: config,
          jwt: keylessTestObject.jwt,
          ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
          pepper: '0x0102',
          maxExpHorizonSecs: 10000000,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Pepper needs to be 31 bytes'),
        )),
      );
    });

    test(
        'rejects ephemeral key pairs whose lifespan exceeds '
        'maxExpHorizonSecs', () async {
      final (config, _) = makeConfig();

      await expectLater(
        internal_keyless.getProof(
          aptosConfig: config,
          jwt: keylessTestObject.jwt,
          ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
          pepper: keylessTestObject.pepper,
          // The fixture JWT iat is 1 second before the keypair expiry.
          maxExpHorizonSecs: 0,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('too long lived'),
        )),
      );
    });
  });

  group('deriveKeylessAccount', () {
    test('derives the official fixture KeylessAccount with a given pepper',
        () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      final account = await keyless.deriveKeylessAccount(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        pepper: keylessTestObject.pepper,
      );

      expect(account, isA<KeylessAccount>());
      expect(account.accountAddress.toString(), keylessTestObject.address);
      expect(account.publicKey.toString(), keylessTestObject.publicKey);
      expect(account.proof, isNotNull);
      expect(
        Hex(account.proof!.bcsToBytes()).toString(),
        keylessTestObject.proofHex,
      );
      // The verification key hash was recorded from the on-chain config.
      expect(account.verificationKeyHash, isNotNull);

      // The pepper was provided, so the pepper service was never called.
      expect(client.requestsTo('pepper.example'), isEmpty);
      // The original address lookup fell back to the auth key (the table
      // item lookup 404s with table_item_not_found).
      expect(client.requestsTo('OriginatingAddress'), hasLength(1));
      expect(client.requestsTo('/item'), hasLength(1));
    });

    test('fetches the pepper from the pepper service when absent', () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      final account = await keyless.deriveKeylessAccount(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
      );

      expect(client.requestsTo('pepper.example').single.url,
          'https://pepper.example/v0/fetch');
      expect(account.accountAddress.toString(), keylessTestObject.address);
      expect(
        Hex.fromHexInput(account.pepper).toString(),
        keylessTestObject.pepper,
      );
    });

    test(
        'fetches the proof in the background and reports through the '
        'proofFetchCallback', () async {
      final (config, _) = makeConfig();
      final keyless = Keyless(config);
      final statuses = <String>[];

      final account = await keyless.deriveKeylessAccount(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        pepper: keylessTestObject.pepper,
        proofFetchCallback: (status) async => statuses.add(status.status),
      );

      expect(account, isA<KeylessAccount>());
      await account.waitForProofFetch();
      // Let the callback (scheduled by init) settle.
      await Future<void>.delayed(Duration.zero);
      expect(statuses, ['Success']);
      expect(account.proof, isNotNull);
    });

    test('derives a FederatedKeylessAccount when jwkAddress is provided',
        () async {
      final (config, _) = makeConfig();
      final keyless = Keyless(config);
      const jwkAddress =
          '0x000000000000000000000000000000000000000000000000000000000000face';

      final account = await keyless.deriveKeylessAccount(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        pepper: keylessTestObject.pepper,
        jwkAddress: jwkAddress,
      );

      expect(account, isA<FederatedKeylessAccount>());
      final federated = account as FederatedKeylessAccount;
      expect(federated.publicKey.jwkAddress.toString(), jwkAddress);
      expect(
        federated.publicKey.toString(),
        isNot(keylessTestObject.publicKey),
      );
      // No rotation was recorded, so the address is the derived auth key.
      expect(
        account.accountAddress.toString(),
        federated.publicKey.authKey().derivedAddress().toString(),
      );
    });

    test(
        'checkKeylessAccountValidity verifies the verification key and JWK '
        'over the network', () async {
      final (config, client) = makeConfig();
      final keyless = Keyless(config);

      final account = await keyless.deriveKeylessAccount(
        jwt: keylessTestObject.jwt,
        ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
        pepper: keylessTestObject.pepper,
      );

      await account.checkKeylessAccountValidity(config);

      // The JWK for the JWT's kid was looked up in the PatchedJWKs at 0x1.
      expect(client.requestsTo('PatchedJWKs'), hasLength(1));
    });
  });

  group('fetchJWK / getKeylessJWKs', () {
    test('finds the fixture JWK by issuer and kid', () async {
      final (config, _) = makeConfig();

      final jwk = await internal_keyless.fetchJWK(
        aptosConfig: config,
        publicKey: KeylessPublicKey.fromJwtAndPepper(
          jwt: keylessTestObject.jwt,
          pepper: keylessTestObject.pepper,
        ),
        kid: 'test-rsa',
      );

      expect(jwk.kid, 'test-rsa');
      expect(jwk.alg, 'RS256');
      expect(jwk.bcsToHex().toString(), keylessTestObject.jwkHex);
    });

    test('throws when no JWK matches the kid', () async {
      final (config, _) = makeConfig();

      await expectLater(
        internal_keyless.fetchJWK(
          aptosConfig: config,
          publicKey: KeylessPublicKey.fromJwtAndPepper(
            jwt: keylessTestObject.jwt,
            pepper: keylessTestObject.pepper,
          ),
          kid: 'unknown-kid',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains("JWK with kid 'unknown-kid'"),
        )),
      );
    });
  });
}
