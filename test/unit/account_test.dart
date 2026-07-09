import 'dart:typed_data';

import 'package:aptos/src/account/abstract_keyless_account.dart';
import 'package:aptos/src/account/abstracted_account.dart';
import 'package:aptos/src/account/account.dart';
import 'package:aptos/src/account/derivable_abstracted_account.dart';
import 'package:aptos/src/account/ed25519_account.dart';
import 'package:aptos/src/account/ephemeral_key_pair.dart';
import 'package:aptos/src/account/keyless_account.dart';
import 'package:aptos/src/account/multi_ed25519_account.dart';
import 'package:aptos/src/account/multi_key_account.dart';
import 'package:aptos/src/account/single_key_account.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/core/account_address.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/keyless.dart';
import 'package:aptos/src/core/crypto/multi_ed25519.dart';
import 'package:aptos/src/core/crypto/multi_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/crypto/secp256r1.dart';
import 'package:aptos/src/core/crypto/single_key.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:aptos/src/transactions/authenticator/account.dart';
import 'package:aptos/src/transactions/instances/chain_id.dart';
import 'package:aptos/src/transactions/instances/identifier.dart';
import 'package:aptos/src/transactions/instances/module_id.dart';
import 'package:aptos/src/transactions/instances/raw_transaction.dart';
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/transactions/transaction_builder/signing_message.dart';
import 'package:aptos/src/types/types.dart';
import 'package:aptos/src/utils/const.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:test/test.dart';

// Known-answer test fixtures.

const ed25519 = (
  privateKey:
      'ed25519-priv-0xc5338cd251c22daa8c9c9cc94f498cc8a5c7e1d2e75287a5dda91096fe64efa5',
  publicKey:
      '0xde19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c',
  authKey:
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa',
  address:
      '0x978c213990c4833df71548df7ce49d54c759d6b6d932de22b24d56060b7af2aa',
  messageEncoded: '68656c6c6f20776f726c64',
  stringMessage: 'hello world',
  signatureHex:
      '0x9e653d56a09247570bb174a389e85b9226abd5c403ea6c504b386626a145158cd4efd66fc5e071c0e19538a96a05ddbda24d3c51e1e6a9dacc6bb1ce775cce07',
);

const secp256k1TestObject = (
  privateKey:
      'secp256k1-priv-0xd107155adf816a0a94c6db3c9489c13ad8a1eda7ada2e558ba3bfa47c020347e',
  publicKey:
      '0x04acdd16651b839c24665b7e2033b55225f384554949fef46c397b5275f37f6ee95554d70fb5d9f93c5831ebf695c7206e7477ce708f03ae9bb2862dc6c9e033ea',
  address:
      '0x5792c985bc96f436270bd2a3c692210b09c7febb8889345ceefdbae4bacfe498',
  authKey:
      '0x5792c985bc96f436270bd2a3c692210b09c7febb8889345ceefdbae4bacfe498',
  messageEncoded: '68656c6c6f20776f726c64',
  stringMessage: 'hello world',
  signatureHex:
      '0xd0d634e843b61339473b028105930ace022980708b2855954b977da09df84a770c0b68c29c8ca1b5409a5085b0ec263be80e433c83fcf6debb82f3447e71edca',
);

const singleSignerED25519 = (
  publicKey:
      '0xe425451a5dc888ac871976c3c724dec6118910e7d11d344b4b07a22cd94e8c2e',
  privateKey:
      'ed25519-priv-0xf508cbef4e0fe463204aab724a90791c9a9dbe60a53b4978bbddbc712b55f2fd',
  address:
      '0x5bdf77d5bf826c8c04273d4e7323f7bc4a85ee7ee34b37bd7458b7aed3639dd3',
  authKey:
      '0x5bdf77d5bf826c8c04273d4e7323f7bc4a85ee7ee34b37bd7458b7aed3639dd3',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0xc6f50f4e0cb1961f6f7b28be1a1d80e3ece240dfbb7bd8a8b03cc26bfd144fc176295d7c322c5bf3d9669d2ad49d8bdbfe77254b4a6393d8c49da04b40cee600',
);

const singleSignerSecp256r1 = (
  publicKey:
      '0x046c761075b12769e9d0cc9995706275352e1bfb8e0085420625aa9cf849e6d62c2c140f0b3b7c53faf78c16648343966d769ccbc8f2fd14bb2c38f6befb91c77b',
  privateKey:
      'secp256r1-priv-0xa814fde3edc91aedf78c0e75bacbcf5e479cd4b27746961cfa1dc8e9b0e4481c',
  address:
      '0x9a5f9a9614e34f77295791db551e7072ff48d9801b19be97b38db1c05dfde817',
  authKey:
      '0x9a5f9a9614e34f77295791db551e7072ff48d9801b19be97b38db1c05dfde817',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0x4fc4bc5f8ed851aec68c64499fa56360b11ea0c8b73fe3f93279e97b700582e55cb9e2ada7ae38951c2bc33d7755529fffc6201504180405c7960715ae0d4ff5',
);

const wallet = (
  address: '0x07968dab936c1bad187c60ce4082f307d030d780e91e694ae03aef16aba73f30',
  mnemonic:
      'shoot island position soft burden budget tooth cruel issue economy destroy above',
  path: "m/44'/637'/0'/0'/0'",
);

const ed25519WalletTestObject = (
  address: '0x28b829b524d7c24aa7fd8916573c814df766dae542f724e1cf8914536232c346',
  mnemonic:
      'shoot island position soft burden budget tooth cruel issue economy destroy above',
  path: "m/44'/637'/0'/0'/0'",
);

const secp256k1WalletTestObject = (
  address: '0x4b4aa8759fcef40ba49e999409eb73a98252f44f6612a4de2b23bad5c37b15a6',
  mnemonic:
      'shoot island position soft burden budget tooth cruel issue economy destroy above',
  path: "m/44'/637'/0'/0/0",
);

const keylessTestObject = (
  jwt:
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3QtcnNhIn0.eyJpc3MiOiJ0ZXN0Lm9pZGMucHJvdmlkZXIiLCJhdWQiOiJ0ZXN0LWtleWxlc3MtZGFwcCIsInN1YiI6InRlc3QtdXNlci0wIiwiZW1haWwiOiJ0ZXN0QGFwdG9zbGFicy5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaWF0Ijo5ODc2NTQzMjA5LCJleHAiOjk4NzY1NDMyMTAsIm5vbmNlIjoiMTk2NDM2OTg4NjEyNjU1Njc4MDQ5MDk5MTMxMzA1MDcyNDc4MTQ1MjY5MTM1NzAyMjgzMTY0MTczNzc5NjUxMDU2ODE3OTYxNzMwOTgifQ.C6QG9WyEIAqYEiLkY8-5yqTKYtCzmnu2RM4P7iqr17toRXhL2ZqCiQYgE2TpY60RlOqBI7_aiHOlxJRvF_iQghEQQSWkgWhkcjVkSvBJW0IHm0IrSRl9ZytQHi6x0vPa8bUff5L--9JfxMiH27wOTrGtTA1n8Fz3G8JKQfYNQF2VawzytJu3lywduRj6pZw9-FFTgPqPsZWQvwhiX75Tgud976CpDusKOrPAM3rA9fXgKo_aTKeOPiEIm11ezI1bsOJ3B4JhsxLT5vszZ11Ywytst8XXwqWHjnulkJWjM9QfVUJhsO-jEQ5T_dYDqMVnnkdzjJyMRbvgbyNPUkvx8Q',
  publicKey:
      '0x12746573742e6f6964632e70726f766964657220bdc98aab184dc40bbb5c483410ccac4c0b2ef20eeac8d568cf25125e9cdafc0f',
  pepper: '0x772714089792b0bc8c621843bd88599627c74564c47cb4dc7bc0196914a56c',
  proofHex:
      '0x00ac1c3add4fa703c66a940e9e947a71bcdb8f30258e72460c01f63d6236d9b2a835188c3ac199bea3905270b9660ddafacbf4f9addb93a3e235e9703ca72c40258362273f596f93594499527ca4802ef40cf0166ba3bd2d65d1a7f50562060127dcdcd995f9ae5e193582cce456f3ddfe8c0c935719ad8636a8e777369279d5a480969800000000000000010040d6433ea43090d25fc4f4a15c362a98a5343dcf4e29e3854f3b74d0d99a0b43abd9955c55a7d20f47372a5802a0e26cc4f860969109d48c9e989dab8287c41501',
  address: '0x3d255a4ea36dfedc32205a522f440064fab38fb2d8cf727642d113cb8d43045f',
  authKey: '0x3d255a4ea36dfedc32205a522f440064fab38fb2d8cf727642d113cb8d43045f',
  messageEncoded: '68656c6c6f20776f726c64',
  signatureHex:
      '0x000028edb9b770bd33823ed3aa95d6a464ee61a6370f3662f9edb205e1fad45e3c943296fed377bcece279bd6f68649fdab2f81ca3e83b34fce490492574e2943f04e4f9bfda70c4325e4567bcb58c1a7ccbd67ff9ba618e03be794be0483141bc15a436433070367193c102fbad99c1fed866e34b1f624d64ecfd818a09aa62a41b80969800000000000000010040119893806295fa773fa806a1f5e0754055f773e8a2ca72a0442c23945c004f011c3a03ed218f246e0d758032f16de78b9c93b6868b0b81bea083c114e6d855052c7b22616c67223a225253323536222c22747970223a224a5754222c226b6964223a22746573742d727361227dea16b04c020000000020d04ab232742bb4ab3a1368bd4615e4e6d0224ab71a016baf8520a332c97787370040be6bc1c26488a31fdb030ccd1546e0dcb6dd4ffbada797040deba21231ce894470f1aef38272fe4c77725e77945c6c3b67c6c16d29e2d3ccf4f30bf4374b0f08',
);

/// The EPHEMERAL_KEY_PAIR fixture.
EphemeralKeyPair makeFixtureEphemeralKeyPair() => EphemeralKeyPair(
      privateKey: Ed25519PrivateKey(
        'ed25519-priv-0x1111111111111111111111111111111111111111111111111111111111111111',
      ),
      expiryDateSecs: 9876543210, // Friday, December 22, 2282
      blinder: Uint8List(31),
    );

ZeroKnowledgeSig fixtureProof() => ZeroKnowledgeSig.fromBytes(
      Hex.fromHexInput(keylessTestObject.proofHex).toUint8List(),
    );

KeylessAccount makeFixtureKeylessAccount() => KeylessAccount.create(
      jwt: keylessTestObject.jwt,
      pepper: keylessTestObject.pepper,
      ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
      proof: fixtureProof(),
    );

SimpleTransaction makeSimpleTransaction(AccountAddress sender) {
  final moduleId = ModuleId(AccountAddress.one, Identifier('aptos_account'));
  final entry = EntryFunction(moduleId, Identifier('transfer'), [], []);
  final payload = TransactionPayloadEntryFunction(entry);
  final raw = RawTransaction(
    sender,
    BigInt.zero,
    payload,
    BigInt.from(1000),
    BigInt.from(100),
    BigInt.from(999999),
    ChainId(4),
  );
  return SimpleTransaction(raw);
}

const authFn = '0x1::permissioned_delegation::authenticate';

void main() {
  group('Account', () {
    group('generate', () {
      test(
          'should create an instance of Account with a legacy ED25519 when '
          'nothing is specified', () {
        final edAccount = Account.generate();
        expect(edAccount, isA<Ed25519Account>());
        expect(edAccount.publicKey, isA<Ed25519PublicKey>());
        expect(edAccount.signingScheme, SigningScheme.ed25519);
      });

      test(
          'should create an instance of Account with a Single Sender ED25519 '
          'when scheme and legacy specified', () {
        final edAccount = Account.generate(
          scheme: SigningSchemeInput.ed25519,
          legacy: false,
        );
        expect(edAccount, isA<SingleKeyAccount>());
        expect(edAccount.publicKey, isA<AnyPublicKey>());
        expect(edAccount.signingScheme, SigningScheme.singleKey);
      });

      test(
          'should create an instance of Account when Secp256k1 scheme is '
          'specified', () {
        final secpAccount = Account.generate(
          scheme: SigningSchemeInput.secp256k1Ecdsa,
        );
        expect(secpAccount, isA<SingleKeyAccount>());
        expect(secpAccount.publicKey, isA<AnyPublicKey>());
        expect(secpAccount.signingScheme, SigningScheme.singleKey);
      });
    });

    group('fromPrivateKeyAndAddress', () {
      test('delegates to fromPrivateKey', () {
        final privateKey = Ed25519PrivateKey(ed25519.privateKey);
        final accountAddress = AccountAddress.from(ed25519.address);
        // ignore: deprecated_member_use_from_same_package
        final viaAlias = Account.fromPrivateKeyAndAddress(
          privateKey: privateKey,
          address: accountAddress,
          legacy: true,
        );
        final direct = Account.fromPrivateKey(
          privateKey: privateKey,
          address: accountAddress,
          legacy: true,
        );
        expect(
          viaAlias.accountAddress.toString(),
          direct.accountAddress.toString(),
        );
        expect(viaAlias.publicKey.toString(), direct.publicKey.toString());
      });
    });

    group('fromPrivateKey', () {
      test('derives the correct account from a legacy ed25519 private key',
          () {
        final privateKey = Ed25519PrivateKey(ed25519.privateKey);
        final newAccount = Account.fromPrivateKey(privateKey: privateKey);
        expect(newAccount, isA<Ed25519Account>());
        newAccount as Ed25519Account;
        expect(newAccount.publicKey, isA<Ed25519PublicKey>());
        expect(newAccount.privateKey, isA<Ed25519PrivateKey>());
        expect(newAccount.privateKey.toString(), privateKey.toString());
        expect(
          newAccount.publicKey.toString(),
          Ed25519PublicKey(ed25519.publicKey).toString(),
        );
        expect(newAccount.accountAddress.toString(), ed25519.address);
      });

      test(
          'derives the correct account from a single signer ed25519 private '
          'key', () {
        final privateKey = Ed25519PrivateKey(singleSignerED25519.privateKey);
        final newAccount = Account.fromPrivateKey(
          privateKey: privateKey,
          legacy: false,
        );
        expect(newAccount, isA<SingleKeyAccount>());
        newAccount as SingleKeyAccount;
        expect(newAccount.publicKey, isA<AnyPublicKey>());
        expect(newAccount.publicKey.publicKey, isA<Ed25519PublicKey>());
        expect(newAccount.privateKey, isA<Ed25519PrivateKey>());
        expect(
          (newAccount.privateKey as Ed25519PrivateKey).toString(),
          privateKey.toString(),
        );
        expect(
          newAccount.publicKey.publicKey.toString(),
          singleSignerED25519.publicKey,
        );
        expect(
          newAccount.accountAddress.toString(),
          singleSignerED25519.address,
        );
      });

      test(
          'derives the correct account from a single signer secp256k1 '
          'private key', () {
        final privateKey = Secp256k1PrivateKey(secp256k1TestObject.privateKey);
        final newAccount = Account.fromPrivateKey(privateKey: privateKey);
        expect(newAccount, isA<SingleKeyAccount>());
        newAccount as SingleKeyAccount;
        expect(newAccount.publicKey, isA<AnyPublicKey>());
        expect(newAccount.publicKey.publicKey, isA<Secp256k1PublicKey>());
        expect(newAccount.privateKey, isA<Secp256k1PrivateKey>());
        expect(
          (newAccount.privateKey as Secp256k1PrivateKey).toString(),
          privateKey.toString(),
        );
        expect(
          newAccount.publicKey.publicKey.toString(),
          Secp256k1PublicKey(secp256k1TestObject.publicKey).toString(),
        );
        expect(
          newAccount.accountAddress.toString(),
          secp256k1TestObject.address,
        );
      });

      test('respects an explicitly provided address', () {
        final privateKey = Ed25519PrivateKey(ed25519.privateKey);
        final newAccount = Account.fromPrivateKey(
          privateKey: privateKey,
          address: AccountAddress.from('0x1'),
        );
        expect(newAccount.accountAddress.toString(), '0x1');
      });
    });

    group('fromDerivationPath', () {
      test(
          'should create a new account from bip44 path and mnemonics with '
          'legacy Ed25519', () {
        final newAccount = Account.fromDerivationPath(
          path: wallet.path,
          mnemonic: wallet.mnemonic,
          scheme: SigningSchemeInput.ed25519,
        );
        expect(newAccount.accountAddress.toString(), wallet.address);
        expect(newAccount, isA<Ed25519Account>());
      });

      test(
          'should create a new account from bip44 path and mnemonics with '
          'single signer Ed25519', () {
        final newAccount = Account.fromDerivationPath(
          path: ed25519WalletTestObject.path,
          mnemonic: ed25519WalletTestObject.mnemonic,
          scheme: SigningSchemeInput.ed25519,
          legacy: false,
        );
        expect(
          newAccount.accountAddress.toString(),
          ed25519WalletTestObject.address,
        );
        expect(newAccount, isA<SingleKeyAccount>());
      });

      test(
          'should create a new account from bip44 path and mnemonics with '
          'single signer secp256k1', () {
        final newAccount = Account.fromDerivationPath(
          path: secp256k1WalletTestObject.path,
          mnemonic: secp256k1WalletTestObject.mnemonic,
          scheme: SigningSchemeInput.secp256k1Ecdsa,
        );
        expect(
          newAccount.accountAddress.toString(),
          secp256k1WalletTestObject.address,
        );
        expect(newAccount, isA<SingleKeyAccount>());
      });
    });

    group('sign and verify', () {
      test(
          'signs a message with single signer Secp256k1 scheme and verifies '
          'successfully', () {
        final privateKey = Secp256k1PrivateKey(secp256k1TestObject.privateKey);
        final accountAddress =
            AccountAddress.from(secp256k1TestObject.address);
        final secpAccount = Account.fromPrivateKey(
          privateKey: privateKey,
          address: accountAddress,
        );
        // Verifies an encoded message.
        final signature1 =
            secpAccount.sign(secp256k1TestObject.messageEncoded);
        signature1 as AnySignature;
        expect(
          signature1.signature.toString(),
          secp256k1TestObject.signatureHex,
        );
        expect(
          secpAccount.verifySignature(
            message: secp256k1TestObject.messageEncoded,
            signature: signature1,
          ),
          true,
        );
        // Verifies a string message.
        final signature2 = secpAccount.sign(secp256k1TestObject.stringMessage);
        signature2 as AnySignature;
        expect(
          signature2.signature.toString(),
          secp256k1TestObject.signatureHex,
        );
        expect(
          secpAccount.verifySignature(
            message: secp256k1TestObject.stringMessage,
            signature: signature2,
          ),
          true,
        );
      });

      test(
          'signs a message with single signer ed25519 scheme and verifies '
          'successfully', () {
        final privateKey = Ed25519PrivateKey(singleSignerED25519.privateKey);
        final accountAddress =
            AccountAddress.from(singleSignerED25519.address);
        final edAccount = Account.fromPrivateKey(
          privateKey: privateKey,
          address: accountAddress,
          legacy: false,
        );
        final signature =
            edAccount.sign(singleSignerED25519.messageEncoded);
        signature as AnySignature;
        expect(
          signature.signature.toString(),
          singleSignerED25519.signatureHex,
        );
        expect(
          edAccount.verifySignature(
            message: singleSignerED25519.messageEncoded,
            signature: signature,
          ),
          true,
        );
      });

      test(
          'signs a message with single signer Secp256r1 scheme and verifies '
          'successfully', () {
        final privateKey =
            Secp256r1PrivateKey(singleSignerSecp256r1.privateKey);
        final publicKey = privateKey.publicKey();
        // NOTE: Secp256r1PublicKey does not expose authKey() directly;
        // AnyPublicKey derives the SingleKey scheme auth key for it.
        final authKey = AnyPublicKey(publicKey).authKey();
        expect(
          authKey.derivedAddress().toString(),
          singleSignerSecp256r1.address,
        );
        expect(authKey.toString(), singleSignerSecp256r1.authKey);
        expect(publicKey.toString(), singleSignerSecp256r1.publicKey);
        final signature =
            privateKey.sign(singleSignerSecp256r1.messageEncoded);
        expect(signature.toString(), singleSignerSecp256r1.signatureHex);
        expect(
          publicKey.verifySignature(
            message: singleSignerSecp256r1.messageEncoded,
            signature: signature,
          ),
          true,
        );
      });

      test(
          'signs a message with a legacy ed25519 scheme and verifies '
          'successfully', () {
        final privateKey = Ed25519PrivateKey(ed25519.privateKey);
        final accountAddress = AccountAddress.from(ed25519.address);
        final legacyEdAccount = Account.fromPrivateKey(
          privateKey: privateKey,
          address: accountAddress,
          legacy: true,
        );
        // Verifies an encoded message.
        final signature1 = legacyEdAccount.sign(ed25519.messageEncoded);
        expect(signature1.toString(), ed25519.signatureHex);
        expect(
          legacyEdAccount.verifySignature(
            message: ed25519.messageEncoded,
            signature: signature1,
          ),
          true,
        );
        // Verifies a string message.
        final signature2 = legacyEdAccount.sign(ed25519.stringMessage);
        expect(signature2.toString(), ed25519.signatureHex);
        expect(
          legacyEdAccount.verifySignature(
            message: ed25519.stringMessage,
            signature: signature2,
          ),
          true,
        );
      });

      group('multikey', () {
        final singleSignerED25519SenderAccount = Account.generate(
          scheme: SigningSchemeInput.ed25519,
          legacy: false,
        );
        final legacyED25519SenderAccount = Account.generate();
        final singleSignerSecp256k1Account = Account.generate(
          scheme: SigningSchemeInput.secp256k1Ecdsa,
        );
        final keylessAccount = makeFixtureKeylessAccount();
        final multiKey = MultiKey(
          publicKeys: [
            singleSignerED25519SenderAccount.publicKey,
            legacyED25519SenderAccount.publicKey,
            singleSignerSecp256k1Account.publicKey,
            keylessAccount.publicKey,
          ],
          signaturesRequired: 2,
        );

        test(
            'signs a message with a 2 of 4 multikey scheme and verifies '
            'successfully', () {
          final account = MultiKeyAccount(
            multiKey: multiKey,
            signers: [
              singleSignerSecp256k1Account,
              singleSignerED25519SenderAccount,
            ],
          );
          const message = 'test message';
          final multiKeySig = account.sign(message);
          expect(
            account.verifySignature(message: message, signature: multiKeySig),
            true,
          );
        });

        test(
            'signs a message with a 2 of 4 multikey scheme with keyless '
            'account and throws an error indicating that verifySignatureAsync '
            'should be used', () {
          final account = MultiKeyAccount(
            multiKey: multiKey,
            signers: [singleSignerSecp256k1Account, keylessAccount],
          );
          const message = 'test message';
          final multiKeySig = account.sign(message);
          expect(
            () => account.verifySignature(
              message: message,
              signature: multiKeySig,
            ),
            throwsA(isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Use verifySignatureAsync'),
            )),
          );
        });

        test(
            'signs a message with a 2 of 4 multikey scheme and verifies '
            'successfully with misordered signers', () {
          final account = MultiKeyAccount(
            multiKey: multiKey,
            signers: [
              singleSignerSecp256k1Account,
              singleSignerED25519SenderAccount,
            ],
          );
          const message = 'test message';
          final multiKeySig = account.sign(message);
          expect(
            account.verifySignature(message: message, signature: multiKeySig),
            true,
          );
        });

        test('constructing a multi key account with insufficient signers '
            'fails', () {
          expect(
            () => MultiKeyAccount(
              multiKey: multiKey,
              signers: [singleSignerED25519SenderAccount],
            ),
            throwsStateError,
          );
        });

        test('2-of-3 multikey account signs and verifies (mixed signers)',
            () {
          final edAccount = Account.generate();
          final singleKeyEd = Account.generate(
            scheme: SigningSchemeInput.ed25519,
            legacy: false,
          );
          final secpAccount = Account.generate(
            scheme: SigningSchemeInput.secp256k1Ecdsa,
          );
          final account = MultiKeyAccount.fromPublicKeysAndSigners(
            publicKeys: [
              // A legacy Ed25519 account key must be wrapped as AnyPublicKey.
              AnyPublicKey(edAccount.publicKey),
              singleKeyEd.publicKey,
              secpAccount.publicKey,
            ],
            signaturesRequired: 2,
            signers: [edAccount, secpAccount],
          );
          // The legacy Ed25519 signer is converted to a single-key signer.
          expect(account.signers, everyElement(isA<SingleKeyAccount>()));
          expect(account.signerIndicies, [0, 2]);
          const message = '0xdeadbeef';
          final signature = account.sign(message);
          expect(signature.signatures.length, 2);
          expect(
            account.verifySignature(message: message, signature: signature),
            true,
          );
        });
      });

      group('multiEd25519', () {
        final ed25519PrivateKey1 = Ed25519PrivateKey.generate();
        final ed25519PrivateKey2 = Ed25519PrivateKey.generate();
        final ed25519PrivateKey3 = Ed25519PrivateKey.generate();
        final multiKey = MultiEd25519PublicKey(
          publicKeys: [
            ed25519PrivateKey1.publicKey(),
            ed25519PrivateKey2.publicKey(),
            ed25519PrivateKey3.publicKey(),
          ],
          threshold: 2,
        );
        const message = 'test message';

        test(
            'signs a message with a 2 of 3 multiEd25519 scheme and verifies '
            'successfully', () {
          final account = MultiEd25519Account(
            publicKey: multiKey,
            signers: [ed25519PrivateKey1, ed25519PrivateKey3],
          );
          final multiKeySig = account.sign(message);
          expect(
            account.verifySignature(message: message, signature: multiKeySig),
            true,
          );
        });

        test(
            'signs a message with a 2 of 3 multiEd25519 scheme and verifies '
            'successfully with misordered signers', () {
          final account = MultiEd25519Account(
            publicKey: multiKey,
            signers: [ed25519PrivateKey3, ed25519PrivateKey2],
          );
          final multiKeySig = account.sign(message);
          expect(
            account.verifySignature(message: message, signature: multiKeySig),
            true,
          );
        });

        test(
            'constructing a multi ed25519 account with insufficient signers '
            'fails', () {
          expect(
            () => MultiEd25519Account(
              publicKey: multiKey,
              signers: [ed25519PrivateKey1],
            ),
            throwsStateError,
          );
        });
      });
    });

    group('transaction signing', () {
      test('Ed25519Account signs a transaction and verifies successfully',
          () {
        final account = Ed25519Account.generate();
        final transaction = makeSimpleTransaction(account.accountAddress);
        final signature = account.signTransaction(transaction);
        expect(
          account.verifySignature(
            message: generateSigningMessageForTransaction(transaction),
            signature: signature,
          ),
          true,
        );
        final authenticator =
            account.signTransactionWithAuthenticator(transaction);
        expect(authenticator, isA<AccountAuthenticatorEd25519>());
        expect(authenticator.publicKey.toString(), account.publicKey.toString());
        expect(authenticator.signature.toString(), signature.toString());
      });

      test('SingleKeyAccount signs a transaction and verifies successfully',
          () {
        final account =
            SingleKeyAccount.generate(scheme: SigningSchemeInput.secp256k1Ecdsa);
        final transaction = makeSimpleTransaction(account.accountAddress);
        final signature = account.signTransaction(transaction);
        expect(
          account.verifySignature(
            message: generateSigningMessageForTransaction(transaction),
            signature: signature,
          ),
          true,
        );
        final authenticator =
            account.signTransactionWithAuthenticator(transaction);
        expect(authenticator, isA<AccountAuthenticatorSingleKey>());
      });

      test('MultiEd25519Account signs a transaction and verifies successfully',
          () {
        final key1 = Ed25519PrivateKey.generate();
        final key2 = Ed25519PrivateKey.generate();
        final publicKey = MultiEd25519PublicKey(
          publicKeys: [key1.publicKey(), key2.publicKey()],
          threshold: 1,
        );
        final account =
            MultiEd25519Account(publicKey: publicKey, signers: [key2]);
        final transaction = makeSimpleTransaction(account.accountAddress);
        final signature = account.signTransaction(transaction);
        expect(
          account.verifySignature(
            message: generateSigningMessageForTransaction(transaction),
            signature: signature,
          ),
          true,
        );
        final authenticator =
            account.signTransactionWithAuthenticator(transaction);
        expect(authenticator, isA<AccountAuthenticatorMultiEd25519>());
      });

      test('MultiKeyAccount signs a transaction and verifies successfully',
          () {
        final signer1 = Account.generate(
          scheme: SigningSchemeInput.ed25519,
          legacy: false,
        );
        final signer2 = Account.generate(
          scheme: SigningSchemeInput.secp256k1Ecdsa,
        );
        final account = MultiKeyAccount.fromPublicKeysAndSigners(
          publicKeys: [
            signer1.publicKey,
            signer2.publicKey,
            AnyPublicKey(Account.generate().publicKey),
          ],
          signaturesRequired: 2,
          signers: [signer1, signer2],
        );
        final transaction = makeSimpleTransaction(account.accountAddress);
        final signature = account.signTransaction(transaction);
        expect(
          account.verifySignature(
            message: generateSigningMessageForTransaction(transaction),
            signature: signature,
          ),
          true,
        );
        final authenticator =
            account.signTransactionWithAuthenticator(transaction);
        expect(authenticator, isA<AccountAuthenticatorMultiKey>());
      });

      test('signWithAuthenticator returns the expected authenticator types',
          () {
        const message = '0xabcd';
        expect(
          Ed25519Account.generate().signWithAuthenticator(message),
          isA<AccountAuthenticatorEd25519>(),
        );
        expect(
          SingleKeyAccount.generate().signWithAuthenticator(message),
          isA<AccountAuthenticatorSingleKey>(),
        );
        final keylessAccount = makeFixtureKeylessAccount();
        expect(
          keylessAccount.signWithAuthenticator(message),
          isA<AccountAuthenticatorSingleKey>(),
        );
      });
    });

    group('keyless', () {
      test('creates the account from JWT, pepper and proof correctly', () {
        final account = makeFixtureKeylessAccount();
        expect(account.publicKey, isA<KeylessPublicKey>());
        expect(account.publicKey.toString(), keylessTestObject.publicKey);
        expect(
          account.accountAddress.toString(),
          keylessTestObject.address,
        );
        expect(
          account.publicKey.authKey().toString(),
          keylessTestObject.authKey,
        );
        expect(account.signingScheme, SigningScheme.singleKey);
        expect(account.uidKey, 'sub');
        expect(account.uidVal, 'test-user-0');
        expect(account.aud, 'test-keyless-dapp');
        expect(account.isExpired(), false);
      });

      test('signs a message with a well-formed KeylessSignature', () {
        final account = makeFixtureKeylessAccount();
        final signature = account.sign(keylessTestObject.messageEncoded);
        expect(signature, isA<KeylessSignature>());
        // The ephemeral certificate carries the account's ZK proof.
        expect(
          signature.ephemeralCertificate.signature.bcsToBytes(),
          fixtureProof().bcsToBytes(),
        );
        // The expiry matches the ephemeral key pair.
        expect(signature.expiryDateSecs, 9876543210);
        // The JWT header is the decoded first segment of the JWT.
        expect(signature.getJwkKid(), 'test-rsa');
        // The ephemeral signature verifies against the ephemeral public key.
        expect(
          signature.ephemeralPublicKey.verifySignature(
            message: keylessTestObject.messageEncoded,
            signature: signature.ephemeralSignature,
          ),
          true,
        );
        // Signing is deterministic (ed25519), so the BCS bytes round-trip.
        final again = account.sign(keylessTestObject.messageEncoded);
        expect(again.bcsToBytes(), signature.bcsToBytes());
        expect(
          KeylessSignature.deserialize(Deserializer(signature.bcsToBytes()))
              .bcsToBytes(),
          signature.bcsToBytes(),
        );
      });

      test('deserializes the official signature fixture', () {
        final signature = KeylessSignature.deserialize(
          Deserializer(
            Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List(),
          ),
        );
        expect(signature.getJwkKid(), 'test-rsa');
        expect(signature.expiryDateSecs, 9876543210);
        // The ephemeral signature in the fixture verifies over the fixture
        // message with the fixture ephemeral public key.
        expect(
          signature.ephemeralPublicKey.verifySignature(
            message: keylessTestObject.messageEncoded,
            signature: signature.ephemeralSignature,
          ),
          true,
        );
        expect(
          signature.ephemeralPublicKey.bcsToBytes(),
          makeFixtureEphemeralKeyPair().getPublicKey().bcsToBytes(),
        );
        expect(signature.bcsToBytes(),
            Hex.fromHexInput(keylessTestObject.signatureHex).toUint8List());
      });

      test('signs a transaction over the TransactionAndProof hash', () {
        final account = makeFixtureKeylessAccount();
        final transaction = makeSimpleTransaction(account.accountAddress);
        final signature = account.signTransaction(transaction);
        // The transaction signature must be a signature over the hash of the
        // transaction and proof (proof malleability guard).
        final expected = account.sign(account.getSigningMessage(transaction));
        expect(signature.bcsToBytes(), expected.bcsToBytes());
        // And the signing message itself is the TransactionAndProof hash.
        final txnAndProof = TransactionAndProof(
          deriveTransactionType(transaction),
          fixtureProof().proof,
        );
        expect(account.getSigningMessage(transaction), txnAndProof.hash());
      });

      test('sign throws when the ephemeral key pair is expired', () {
        final expiredKeyPair = EphemeralKeyPair(
          privateKey: Ed25519PrivateKey(
            'ed25519-priv-0x1111111111111111111111111111111111111111111111111111111111111111',
          ),
          expiryDateSecs: 10,
          blinder: Uint8List(31),
        );
        final account = KeylessAccount.create(
          jwt: keylessTestObject.jwt,
          pepper: keylessTestObject.pepper,
          ephemeralKeyPair: expiredKeyPair,
          proof: fixtureProof(),
        );
        expect(account.isExpired(), true);
        expect(
          () => account.sign('0x00'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          )),
        );
      });

      test('supports async proof fetching with a callback', () async {
        var callbackStatus = '';
        final account = KeylessAccount.create(
          jwt: keylessTestObject.jwt,
          pepper: keylessTestObject.pepper,
          ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
          proof: Future<ZeroKnowledgeSig>.value(fixtureProof()),
          proofFetchCallback: (status) async {
            callbackStatus = status.status;
          },
        );
        await account.waitForProofFetch();
        // Let the callback microtask run.
        await Future<void>.delayed(Duration.zero);
        expect(account.proof, isNotNull);
        expect(callbackStatus, 'Success');
        // The account can sign once the proof has been fetched, and the
        // result matches signing with a synchronously provided proof.
        final signature = account.sign(keylessTestObject.messageEncoded);
        expect(
          signature.bcsToBytes(),
          makeFixtureKeylessAccount()
              .sign(keylessTestObject.messageEncoded)
              .bcsToBytes(),
        );
      });

      test('async proof requires a callback', () {
        expect(
          () => KeylessAccount.create(
            jwt: keylessTestObject.jwt,
            pepper: keylessTestObject.pepper,
            ephemeralKeyPair: makeFixtureEphemeralKeyPair(),
            proof: Future<ZeroKnowledgeSig>.value(fixtureProof()),
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Must provide callback for async proof fetch'),
          )),
        );
      });

      test('checkKeylessAccountValidity fails locally on an expired keypair',
          () {
        // The ephemeral key pair is expired, so validation fails before any
        // network request is attempted (no canned client needed).
        final expiredKeyPair = EphemeralKeyPair(
          privateKey: Ed25519PrivateKey(
            'ed25519-priv-'
            '0x1111111111111111111111111111111111111111111111111111111111111111',
          ),
          expiryDateSecs: 10,
          blinder: Uint8List(31),
        );
        final account = KeylessAccount.create(
          jwt: keylessTestObject.jwt,
          pepper: keylessTestObject.pepper,
          ephemeralKeyPair: expiredKeyPair,
          proof: fixtureProof(),
        );
        expect(
          account.checkKeylessAccountValidity(AptosConfig()),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          )),
        );
      });

      test('isKeylessSigner and isSingleKeySigner classify accounts', () {
        final keylessAccount = makeFixtureKeylessAccount();
        expect(isKeylessSigner(keylessAccount), true);
        expect(isSingleKeySigner(keylessAccount), true);
        expect(isKeylessSigner(Account.generate()), false);
        expect(isKeylessSigner(null), false);
        expect(isSingleKeySigner(SingleKeyAccount.generate()), true);
        expect(isSingleKeySigner(Ed25519Account.generate()), false);
        // MultiKeyAccount implements KeylessSigner so that keyless validity
        // checks can be aggregated.
        final signer = Account.generate(
          scheme: SigningSchemeInput.ed25519,
          legacy: false,
        );
        final multiKeyAccount = MultiKeyAccount.fromPublicKeysAndSigners(
          publicKeys: [signer.publicKey, Account.generate().publicKey],
          signaturesRequired: 1,
          signers: [signer],
        );
        expect(isKeylessSigner(multiKeyAccount), true);
        // With no keyless signers these resolve without errors.
        expect(multiKeyAccount.waitForProofFetch(), completes);
        expect(multiKeyAccount.checkKeylessAccountValidity(null), completes);
      });
    });

    group('AbstractedAccount', () {
      test('rejects an invalid authentication function at construction', () {
        expect(
          () => AbstractedAccount(
            accountAddress: AccountAddress.one,
            authenticationFunction: 'not-a-move-function-id',
            signer: (_) => Uint8List(0),
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Invalid authentication function not-a-move-function-id '
              'passed into AbstractedAccount',
            ),
          )),
        );
      });

      test(
          'fromPermissionedSigner wraps an Ed25519 signer with the built-in '
          'auth function', () {
        final ed25519Account = Ed25519Account.generate();
        final abstracted =
            AbstractedAccount.fromPermissionedSigner(signer: ed25519Account);
        expect(abstracted.authenticationFunction, authFn);
        expect(
          abstracted.accountAddress.toString(),
          ed25519Account.accountAddress.toString(),
        );
        expect(
          abstracted.publicKey.accountAddress.toString(),
          ed25519Account.accountAddress.toString(),
        );
      });

      test('sign returns an AbstractSignature produced by the signer closure',
          () {
        final digest = Uint8List.fromList([9, 9, 9]);
        final account = AbstractedAccount(
          accountAddress: AccountAddress.one,
          authenticationFunction: authFn,
          signer: (_) => digest,
        );
        final signature = account.sign(digest);
        expect(signature, isA<AbstractSignature>());
        expect(signature.value, digest);
      });

      test('setSigner replaces the signing closure', () {
        final account = AbstractedAccount(
          accountAddress: AccountAddress.one,
          authenticationFunction: authFn,
          signer: (_) => Uint8List.fromList([1]),
        );
        account.setSigner((_) => '0x02');
        expect(account.sign(Uint8List(0)).value, [2]);
      });

      test(
          'signTransactionWithAuthenticator returns an abstraction '
          'authenticator with the correct digest', () {
        final ed25519Account = Ed25519Account.generate();
        final abstracted =
            AbstractedAccount.fromPermissionedSigner(signer: ed25519Account);
        final transaction =
            makeSimpleTransaction(abstracted.accountAddress);

        final authenticator =
            abstracted.signTransactionWithAuthenticator(transaction);

        expect(authenticator, isA<AccountAuthenticatorAbstraction>());
        expect(authenticator.functionInfo, authFn);
        expect(authenticator.abstractionSignature, isNotEmpty);

        // The signing message digest must be the SHA3-256 of the
        // AASigningData-domain-separated AccountAbstractionMessage.
        final expectedMessage = generateSigningMessage(
          AccountAbstractionMessage(
            generateSigningMessageForTransaction(transaction),
            authFn,
          ).bcsToBytes(),
          accountAbstractionSigningDataSalt,
        );
        final expectedDigest = SHA3Digest(256).process(expectedMessage);
        expect(
          authenticator.signingMessageDigest.toUint8List(),
          expectedDigest,
        );

        // The abstraction signature is the BCS bytes of the
        // AbstractSignature (length-prefixed), wrapping (public key, ed25519
        // signature over the digest) as produced by the permissioned signer
        // closure.
        final outer = Deserializer(authenticator.abstractionSignature);
        final deserializer = Deserializer(outer.deserializeBytes());
        final publicKey = Ed25519PublicKey.deserialize(deserializer);
        final signature = Ed25519Signature.deserialize(deserializer);
        expect(publicKey.toString(), ed25519Account.publicKey.toString());
        expect(
          publicKey.verifySignature(
            message: expectedDigest,
            signature: signature,
          ),
          true,
        );
      });

      test('AbstractedAccount publicKey serialization is unsupported', () {
        final account = AbstractedAccount(
          accountAddress: AccountAddress.one,
          authenticationFunction: authFn,
          signer: (_) => Uint8List(0),
        );
        expect(account.publicKey.bcsToBytes, throwsUnsupportedError);
        expect(
          account.publicKey.authKey().derivedAddress().toString(),
          AccountAddress.one.toString(),
        );
      });
    });

    group('DerivableAbstractedAccount', () {
      final abstractPublicKey = Uint8List.fromList(List.generate(32, (i) => i));
      const daaAuthFn = '0x7::test_functions::authenticate';

      test('computes a deterministic DAA account address', () {
        final address1 = DerivableAbstractedAccount.computeAccountAddress(
          daaAuthFn,
          abstractPublicKey,
        );
        final address2 = DerivableAbstractedAccount.computeAccountAddress(
          daaAuthFn,
          abstractPublicKey,
        );
        expect(address1.length, 32);
        expect(address1, address2);
        // A different abstract public key must give a different address.
        final other = DerivableAbstractedAccount.computeAccountAddress(
          daaAuthFn,
          Uint8List(32),
        );
        expect(address1, isNot(equals(other)));
        final account = DerivableAbstractedAccount(
          signer: (_) => Uint8List.fromList([1, 2, 3]),
          authenticationFunction: daaAuthFn,
          abstractPublicKey: abstractPublicKey,
        );
        expect(account.accountAddress.toUint8List(), address1);
      });

      test('rejects an invalid authentication function', () {
        expect(
          () => DerivableAbstractedAccount.computeAccountAddress(
            'invalid',
            abstractPublicKey,
          ),
          throwsStateError,
        );
      });

      test(
          'signWithAuthenticator produces a derivable authenticator with the '
          'account identity and raw signature bytes', () {
        final signerOutput = Uint8List.fromList([1, 2, 3]);
        final account = DerivableAbstractedAccount(
          signer: (_) => signerOutput,
          authenticationFunction: daaAuthFn,
          abstractPublicKey: abstractPublicKey,
        );
        const message = '0xcafe';
        final authenticator = account.signWithAuthenticator(message);
        expect(authenticator, isA<AccountAuthenticatorAbstraction>());
        expect(authenticator.accountIdentity, abstractPublicKey);
        // DAA uses the raw signature value (not BCS-encoded bytes).
        expect(authenticator.abstractionSignature, signerOutput);
        final expectedDigest = SHA3Digest(256)
            .process(Hex.fromHexInput(message).toUint8List());
        expect(
          authenticator.signingMessageDigest.toUint8List(),
          expectedDigest,
        );
      });
    });

    test('should return the authentication key for a public key', () {
      final publicKey = Ed25519PublicKey(ed25519.publicKey);
      final authKey = publicKey.authKey();
      expect(authKey.derivedAddress().toString(), ed25519.address);
      expect(
        Account.authKey(publicKey: publicKey).toString(),
        authKey.toString(),
      );
    });

    test(
        'verifySignature and verifySignatureAsync delegate to the account '
        'public key', () async {
      final account = Account.generate();
      const message = '0xabcd';
      final signature = account.sign(message);
      expect(
        account.verifySignature(message: message, signature: signature),
        true,
      );
      expect(
        await account.verifySignatureAsync(
          aptosConfig: null,
          message: message,
          signature: signature,
        ),
        true,
      );
    });
  });
}
