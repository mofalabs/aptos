import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/core/crypto/federated_keyless.dart';
import 'package:aptos/src/core/crypto/keyless.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

// Known-answer test vectors.
const keylessTestObject = (
  jwt:
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3QtcnNhIn0.eyJpc3MiOiJ0ZXN0Lm9pZGMucHJvdmlkZXIiLCJhdWQiOiJ0ZXN0LWtleWxlc3MtZGFwcCIsInN1YiI6InRlc3QtdXNlci0wIiwiZW1haWwiOiJ0ZXN0QGFwdG9zbGFicy5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaWF0Ijo5ODc2NTQzMjA5LCJleHAiOjk4NzY1NDMyMTAsIm5vbmNlIjoiMTk2NDM2OTg4NjEyNjU1Njc4MDQ5MDk5MTMxMzA1MDcyNDc4MTQ1MjY5MTM1NzAyMjgzMTY0MTczNzc5NjUxMDU2ODE3OTYxNzMwOTgifQ.C6QG9WyEIAqYEiLkY8-5yqTKYtCzmnu2RM4P7iqr17toRXhL2ZqCiQYgE2TpY60RlOqBI7_aiHOlxJRvF_iQghEQQSWkgWhkcjVkSvBJW0IHm0IrSRl9ZytQHi6x0vPa8bUff5L--9JfxMiH27wOTrGtTA1n8Fz3G8JKQfYNQF2VawzytJu3lywduRj6pZw9-FFTgPqPsZWQvwhiX75Tgud976CpDusKOrPAM3rA9fXgKo_aTKeOPiEIm11ezI1bsOJ3B4JhsxLT5vszZ11Ywytst8XXwqWHjnulkJWjM9QfVUJhsO-jEQ5T_dYDqMVnnkdzjJyMRbvgbyNPUkvx8Q',
  publicKey:
      '0x12746573742e6f6964632e70726f766964657220bdc98aab184dc40bbb5c483410ccac4c0b2ef20eeac8d568cf25125e9cdafc0f',
  iss: 'test.oidc.provider',
  idCommitment:
      '0xbdc98aab184dc40bbb5c483410ccac4c0b2ef20eeac8d568cf25125e9cdafc0f',
  pepper: '0x772714089792b0bc8c621843bd88599627c74564c47cb4dc7bc0196914a56c',
  proofHex:
      '0x00ac1c3add4fa703c66a940e9e947a71bcdb8f30258e72460c01f63d6236d9b2a835188c3ac199bea3905270b9660ddafacbf4f9addb93a3e235e9703ca72c40258362273f596f93594499527ca4802ef40cf0166ba3bd2d65d1a7f50562060127dcdcd995f9ae5e193582cce456f3ddfe8c0c935719ad8636a8e777369279d5a480969800000000000000010040d6433ea43090d25fc4f4a15c362a98a5343dcf4e29e3854f3b74d0d99a0b43abd9955c55a7d20f47372a5802a0e26cc4f860969109d48c9e989dab8287c41501',
  authKey: '0x3d255a4ea36dfedc32205a522f440064fab38fb2d8cf727642d113cb8d43045f',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0x000028edb9b770bd33823ed3aa95d6a464ee61a6370f3662f9edb205e1fad45e3c943296fed377bcece279bd6f68649fdab2f81ca3e83b34fce490492574e2943f04e4f9bfda70c4325e4567bcb58c1a7ccbd67ff9ba618e03be794be0483141bc15a436433070367193c102fbad99c1fed866e34b1f624d64ecfd818a09aa62a41b80969800000000000000010040119893806295fa773fa806a1f5e0754055f773e8a2ca72a0442c23945c004f011c3a03ed218f246e0d758032f16de78b9c93b6868b0b81bea083c114e6d855052c7b22616c67223a225253323536222c22747970223a224a5754222c226b6964223a22746573742d727361227dea16b04c020000000020d04ab232742bb4ab3a1368bd4615e4e6d0224ab71a016baf8520a332c97787370040be6bc1c26488a31fdb030ccd1546e0dcb6dd4ffbada797040deba21231ce894470f1aef38272fe4c77725e77945c6c3b67c6c16d29e2d3ccf4f30bf4374b0f08',
  jwkHex:
      '0x08746573742d727361035253410552533235360441514142d6027935456673315a7a69734c4c4b4341525376547a7467576a354a465033373738645a57742d6f643738666d4f5a4678656d33615f6159624f58534a546f5270383632646f3050784a3450444d706d7177563566374b706c4649364e737751562d57507566514838496148585a74755064436a504f634879626344694c6b4f31326430644736695a51557a79706a414a6636334150636164696f2d344a444e576c4743355f4f775f5851396c495937316b544d6954396c6b434364305a787145696647746e4a653578536f5a6f614d524b72766c4f772d523669566a4c557450416b356879555839354c444b787741522d6f73686e6a37676d4154656a676132457648396f7a646e334d38476f31315053446130344f517850634132354f6f445466784c765432384c5270535872626d55575a2d4f5f6c4774446c335a41746a4967755947456f62546b344e3131655273734339354377',
);

KeylessConfiguration keylessTestConfig() => KeylessConfiguration(
      verificationKey: Groth16VerificationKey(
        alphaG1:
            '0xe2f26dbea299f5223b646cb1fb33eadb059d9407559d7441dfd902e3a79a4d2d',
        betaG2:
            '0xabb73dc17fbc13021e2471e0c08bd67d8401f52b73d6d07483794cad4778180e0c06f33bbc4c79a9cadef253a68084d382f17788f885c9afd176f7cb2f036789',
        deltaG2:
            '0xb106619932d0ef372c46909a2492e246d5de739aa140e27f2c71c0470662f125219049cfe15e4d140d7e4bb911284aad1cad19880efb86f2d9dd4b1bb344ef8f',
        gammaAbcG1: [
          '0x6123b6fea40de2a7e3595f9c35210da8a45a7e8c2f7da9eb4548e9210cfea81a',
          '0x32a9b8347c512483812ee922dc75952842f8f3083edb6fe8d5c3c07e1340b683',
        ],
        gammaG2:
            '0xedf692d95cbdde46ddda5ef7d422436779445c5e66006a42761e1f12efde0018c212f3aeb785e49712e7a9353349aaf1255dfb31b7bf60723a480d9293938e19',
      ),
      trainingWheelsPubkey:
          '0x1388de358cf4701696bd58ed4b96e9d670cbbb914b888be1ceda6374a3098ed4',
    );

void main() {
  group('KeylessPublicKey', () {
    test('should create the instance correctly without error', () {
      // Create from inputs.
      final publicKey = KeylessPublicKey(
        keylessTestObject.iss,
        keylessTestObject.idCommitment,
      );
      expect(publicKey.toString(), keylessTestObject.publicKey);

      // Create from JWT and pepper (exercises the poseidon idCommitment
      // computation end to end).
      final publicKey2 = KeylessPublicKey.fromJwtAndPepper(
        jwt: keylessTestObject.jwt,
        pepper: keylessTestObject.pepper,
      );
      expect(publicKey2.toString(), keylessTestObject.publicKey);
    });

    test('rejects an idCommitment of the wrong length', () {
      expect(
        () => KeylessPublicKey(keylessTestObject.iss, '0x0011'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('derives the expected authentication key', () {
      final publicKey = KeylessPublicKey(
        keylessTestObject.iss,
        keylessTestObject.idCommitment,
      );
      expect(publicKey.authKey().toString(), keylessTestObject.authKey);
    });

    test('BCS round-trips', () {
      final publicKey = KeylessPublicKey(
        keylessTestObject.iss,
        keylessTestObject.idCommitment,
      );
      final bytes = publicKey.bcsToBytes();
      final restored = KeylessPublicKey.deserialize(Deserializer(bytes));
      expect(restored.iss, publicKey.iss);
      expect(restored.idCommitment, publicKey.idCommitment);
      expect(restored.bcsToBytes(), bytes);
    });
  });

  group('KeylessSignature', () {
    test('BCS round-trips the official signature fixture', () {
      final bytes =
          Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List();
      final signature = KeylessSignature.deserialize(Deserializer(bytes));
      expect(signature.expiryDateSecs, 9876543210);
      expect(signature.getJwkKid(), 'test-rsa');
      expect(signature.bcsToBytes(), bytes);
    });

    test('verifies the ephemeral signature within the fixture', () {
      final signature = KeylessSignature.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List(),
      ));
      final message =
          Hex.fromHexString(keylessTestObject.messageEncoded).toUint8List();
      expect(
        signature.ephemeralPublicKey.verifySignature(
          message: message,
          signature: signature.ephemeralSignature,
        ),
        true,
      );
    });

    test(
        'public inputs hash and training wheels signature match the fixture '
        '(cross-validates poseidon, jwk.toScalar, and the signing message)',
        () {
      final config = keylessTestConfig();
      final publicKey = KeylessPublicKey(
        keylessTestObject.iss,
        keylessTestObject.idCommitment,
      );
      final signature = KeylessSignature.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List(),
      ));
      final jwk = MoveJWK.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.jwkHex).toUint8List(),
      ));

      final publicInputsHash = getPublicInputsHash(
        publicKey: publicKey,
        signature: signature,
        jwk: jwk,
        keylessConfig: config,
      );

      final zkSig =
          signature.ephemeralCertificate.signature as ZeroKnowledgeSig;
      final groth16Proof = zkSig.proof.proof as Groth16Zkp;
      final proofAndStatement =
          Groth16ProofAndStatement(groth16Proof, publicInputsHash);
      // The training wheels key signed sha3(domain) || bcs(proof, hash); if
      // our poseidon public-inputs hash were wrong this verification would
      // fail.
      expect(
        config.trainingWheelsPubkey!.verifySignature(
          message: proofAndStatement.hash(),
          signature: zkSig.trainingWheelsSignature!,
        ),
        true,
      );
    });

    test('getSimulationSignature BCS round-trips', () {
      final signature = KeylessSignature.getSimulationSignature();
      final bytes = signature.bcsToBytes();
      final restored = KeylessSignature.deserialize(Deserializer(bytes));
      expect(restored.bcsToBytes(), bytes);
    });
  });

  group('ZeroKnowledgeSig', () {
    test('BCS round-trips the official proof fixture', () {
      final bytes = Hex.fromHexInput(keylessTestObject.proofHex).toUint8List();
      final zkSig = ZeroKnowledgeSig.fromBytes(bytes);
      expect(zkSig.expHorizonSecs, 10000000);
      expect(zkSig.extraField, isNull);
      expect(zkSig.overrideAudVal, isNull);
      expect(zkSig.trainingWheelsSignature, isNotNull);
      expect(zkSig.proof.variant.value, 0);
      expect(zkSig.bcsToBytes(), bytes);
    });
  });

  group('MoveJWK', () {
    test('BCS round-trips and exposes the JWK fields', () {
      final bytes = Hex.fromHexInput(keylessTestObject.jwkHex).toUint8List();
      final jwk = MoveJWK.deserialize(Deserializer(bytes));
      expect(jwk.kid, 'test-rsa');
      expect(jwk.kty, 'RSA');
      expect(jwk.alg, 'RS256');
      expect(jwk.e, 'AQAB');
      expect(jwk.bcsToBytes(), bytes);
    });

    test('toScalar matches the poseidon-lite reference value', () {
      final jwk = MoveJWK.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.jwkHex).toUint8List(),
      ));
      // Known-answer value for MoveJWK.toScalar over this fixture.
      expect(
        jwk.toScalar(),
        BigInt.parse(
            '20492805183146429738881682260735553594568833942159524362726888331422541660702'),
      );
    });

    test('toScalar rejects non-RS256 keys', () {
      final jwk = MoveJWK(
        kid: 'kid',
        kty: 'RSA',
        alg: 'RS512',
        e: 'AQAB',
        n: 'AQAB',
      );
      expect(jwk.toScalar, throwsA(isA<StateError>()));
    });
  });

  group('Groth16VerificationKey', () {
    test('hash is deterministic and 32 bytes', () {
      final config = keylessTestConfig();
      final hash = config.verificationKey.hash();
      expect(hash.length, 32);
      expect(config.verificationKey.hash(), hash);
    });

    test('verifyProof accepts the fixture proof and rejects a tampered hash',
        () {
      final config = keylessTestConfig();
      final publicKey = KeylessPublicKey(
        keylessTestObject.iss,
        keylessTestObject.idCommitment,
      );
      final signature = KeylessSignature.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List(),
      ));
      final jwk = MoveJWK.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.jwkHex).toUint8List(),
      ));
      final publicInputsHash = getPublicInputsHash(
        publicKey: publicKey,
        signature: signature,
        jwk: jwk,
        keylessConfig: config,
      );
      final groth16Proof =
          (signature.ephemeralCertificate.signature as ZeroKnowledgeSig)
              .proof
              .proof as Groth16Zkp;

      // The real fixture proof verifies against the real verification key
      // with the correct public inputs hash (exercises point decompression,
      // the BN254 pairing, and the Groth16 equation end to end).
      expect(
        config.verificationKey.verifyProof(
          publicInputsHash: publicInputsHash,
          groth16Proof: groth16Proof,
        ),
        true,
      );
      // Tampering the public inputs hash makes verification fail.
      expect(
        config.verificationKey.verifyProof(
          publicInputsHash: publicInputsHash + BigInt.one,
          groth16Proof: groth16Proof,
        ),
        false,
      );
    });

    test('toSnarkJsJson exposes the verification key in snarkjs format', () {
      final config = keylessTestConfig();
      final j = config.verificationKey.toSnarkJsJson();
      expect(j['protocol'], 'groth16');
      expect(j['curve'], 'bn128');
      expect(j['nPublic'], 1);
      // G1 point => [x, y, "1"]; G2 point => [[..],[..],["1","0"]].
      expect((j['vk_alpha_1'] as List).length, 3);
      expect((j['vk_alpha_1'] as List)[2], '1');
      expect((j['vk_gamma_2'] as List)[2], ['1', '0']);
      expect((j['IC'] as List).length, 2);
    });
  });

  group('Groth16Zkp', () {
    test('toSnarkJsJson exposes the proof in snarkjs format', () {
      final signature = KeylessSignature.deserialize(Deserializer(
        Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List(),
      ));
      final proof =
          (signature.ephemeralCertificate.signature as ZeroKnowledgeSig)
              .proof
              .proof as Groth16Zkp;
      final j = proof.toSnarkJsJson();
      expect(j['protocol'], 'groth16');
      expect((j['pi_a'] as List).length, 3); // G1: [x, y, z]
      expect((j['pi_b'] as List).length, 3); // G2: 3 Fp2 pairs
      expect((j['pi_b'] as List)[0], isA<List>());
      expect((j['pi_c'] as List).length, 3);
    });
  });

  group('G1Bytes/G2Bytes', () {
    test('enforce fixed lengths', () {
      expect(() => G1Bytes('0x00'), throwsA(isA<ArgumentError>()));
      expect(() => G2Bytes('0x00'), throwsA(isA<ArgumentError>()));
      final serializer = Serializer();
      G1Bytes(Hex.fromHexInput(keylessTestObject.idCommitment).toUint8List())
          .serialize(serializer);
      expect(serializer.toUint8List().length, 32);
    });
  });

  group('JWT helpers', () {
    test('getIssAudAndUidVal parses the fixture JWT', () {
      final parsed = getIssAudAndUidVal(jwt: keylessTestObject.jwt);
      expect(parsed.iss, keylessTestObject.iss);
      expect(parsed.aud, 'test-keyless-dapp');
      expect(parsed.uidVal, 'test-user-0');
    });

    test('getIssAudAndUidVal rejects malformed JWTs', () {
      expect(
        () => getIssAudAndUidVal(jwt: 'not-a-jwt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parseJwtHeader extracts the kid', () {
      expect(parseJwtHeader('{"kid":"test-rsa"}').kid, 'test-rsa');
      expect(
        () => parseJwtHeader('{"alg":"RS256"}'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => parseJwtHeader('not json'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FederatedKeylessPublicKey', () {
    test('creates from JWT and pepper and BCS round-trips', () {
      final publicKey = FederatedKeylessPublicKey.fromJwtAndPepper(
        jwt: keylessTestObject.jwt,
        pepper: keylessTestObject.pepper,
        jwkAddress: '0x1',
      );
      expect(
        publicKey.keylessPublicKey.toString(),
        keylessTestObject.publicKey,
      );
      final bytes = publicKey.bcsToBytes();
      final restored =
          FederatedKeylessPublicKey.deserialize(Deserializer(bytes));
      expect(restored.bcsToBytes(), bytes);
      expect(restored.jwkAddress.toString(), '0x1');
    });

    test('authKey differs from the non-federated variant', () {
      final federated = FederatedKeylessPublicKey.fromJwtAndPepper(
        jwt: keylessTestObject.jwt,
        pepper: keylessTestObject.pepper,
        jwkAddress: '0x1',
      );
      expect(
        federated.authKey().toString(),
        isNot(keylessTestObject.authKey),
      );
    });
  });
}
