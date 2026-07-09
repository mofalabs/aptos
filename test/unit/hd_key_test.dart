import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/hd_key.dart';
import 'package:aptos/src/core/crypto/secp256k1.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

const walletPath = "m/44'/637'/0'/0'/0'";
const secp256k1WalletPath = "m/44'/637'/0'/0/0";

void main() {
  group('Hierarchical Deterministic Key (hdkey)', () {
    group('hardened path', () {
      test('Parsing a valid path should work', () {
        expect(isValidHardenedPath(walletPath), isTrue);
        expect(isValidHardenedPath("m/44'/637'/0'/0'/1'"), isTrue);
        expect(isValidHardenedPath("m/44'/637'/0'/0'/2'"), isTrue);
        expect(isValidHardenedPath("m/44'/637'/0'/2'/2'"), isTrue);
        expect(isValidHardenedPath("m/44'/637'/22'/22'/22'"), isTrue);
      });

      test('Parsing a invalid path should not work', () {
        // All beginning fields have to be hardened.
        expect(isValidHardenedPath('m/44/637/0/0/1'), isFalse);
        expect(isValidHardenedPath("m/44'/637/0/0/1"), isFalse);
        expect(isValidHardenedPath("m/44'/637'/0/0/1"), isFalse);
        expect(isValidHardenedPath("m/44'/637'/0'/0/1"), isFalse);
        // We don't accept `h`, only `'` is accepted.
        expect(isValidHardenedPath("m/44'/637'/0h/0/0"), isFalse);
        // No number.
        expect(isValidHardenedPath("m/44'/637'/a/0/0"), isFalse);
        // Invalid chain code.
        expect(isValidHardenedPath("m/44'/638'/0/0/0"), isFalse);
        // Not enough pieces.
        expect(isValidHardenedPath("m/44'/637'/"), isFalse);
        expect(isValidHardenedPath("m/44'/637'/0"), isFalse);
        expect(isValidHardenedPath("m/44'/637'/0/0"), isFalse);
        // Extra slash.
        expect(isValidHardenedPath("m/44'/637'/0/0/0/"), isFalse);
      });
    });

    group('BIP44 Path', () {
      test('Parsing a valid path should work', () {
        expect(isValidBIP44Path(secp256k1WalletPath), isTrue);
        expect(isValidBIP44Path("m/44'/637'/0'/0/1"), isTrue);
        expect(isValidBIP44Path("m/44'/637'/0'/2/2"), isTrue);
        expect(isValidBIP44Path("m/44'/637'/22'/2/22"), isTrue);
      });

      test('Parsing a invalid path should not work', () {
        expect(isValidBIP44Path("m/44'/637'/0'/0'/1"), isFalse);
        expect(isValidBIP44Path("m/44'/637'/0'/0'/1'"), isFalse);
        // All beginning fields have to be hardened.
        expect(isValidBIP44Path('m/44/637/0/0/1'), isFalse);
        expect(isValidBIP44Path("m/44'/637/0/0/1"), isFalse);
        expect(isValidBIP44Path("m/44'/637'/0/0/1"), isFalse);
        // We don't accept `h`, only `'` is accepted.
        expect(isValidBIP44Path("m/44'/637'/0h/0/0"), isFalse);
        // No number.
        expect(isValidBIP44Path("m/44'/637'/a/0/0"), isFalse);
        // Invalid chain code.
        expect(isValidBIP44Path("m/44'/638'/0/0/0"), isFalse);
        // Not enough pieces.
        expect(isValidBIP44Path("m/44'/637'/"), isFalse);
        expect(isValidBIP44Path("m/44'/637'/0"), isFalse);
        expect(isValidBIP44Path("m/44'/637'/0/0"), isFalse);
        // Extra slash.
        expect(isValidBIP44Path("m/44'/637'/0/0/0/"), isFalse);
      });
    });

    // Testing against
    // https://github.com/satoshilabs/slips/blob/master/slip-0010.md#test-vector-1-for-ed25519
    group('Ed25519', () {
      final seed = Hex.fromHexInput('000102030405060708090a0b0c0d0e0f');
      const vectors = [
        (
          chain: 'm',
          private:
              '2b4be7f19ee27bbf30c667b642d5f4aa69fd169872f8fc3059c08ebae2eb19e7',
        ),
        (
          chain: "m/0'",
          private:
              '68e0fe46dfb67e368c75379acec591dad19df3cde26e63b93a8e704f1dade7a3',
        ),
        (
          chain: "m/0'/1'",
          private:
              'b1d0bad404bf35da785a64ca1ac54b2617211d2777696fbffaf208f746ae84f2',
        ),
        (
          chain: "m/0'/1'/2'",
          private:
              '92a5b23c0b8a99e37d07df3fb9966917f5d06e02ddbd909c7e184371463e9fc9',
        ),
        (
          chain: "m/0'/1'/2'/2'",
          private:
              '30d1dc7e5fc04c31219ab25a27ae00b50f6fd66622f6e9c913253d6511d1e662',
        ),
        (
          chain: "m/0'/1'/2'/2'/1000000000'",
          private:
              '8f94d394a8e8fd6b1bc2f3f49f5c47e385281d5c17e65324b0f62483e37e8793',
        ),
      ];

      for (final vector in vectors) {
        test('should generate correct key pair for ${vector.chain}', () {
          final key = Ed25519PrivateKey.fromDerivationPathInner(
            vector.chain,
            seed.toUint8List(),
          );
          expect(key.toHexString(), equals('0x${vector.private}'));
        });
      }
    });

    // Testing against
    // https://github.com/satoshilabs/slips/blob/master/slip-0010.md#test-vector-1-for-secp256k1
    group('secp256k1', () {
      final seed = Hex.fromHexInput('000102030405060708090a0b0c0d0e0f');
      const vectors = [
        (
          chain: 'm',
          private:
              'e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35',
        ),
        (
          chain: "m/0'",
          private:
              'edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea',
        ),
        (
          chain: "m/0'/1",
          private:
              '3c6cb8d0f6a264c91ea8b5030fadaa8e538b020f0a387421a12de9319dc93368',
        ),
        (
          chain: "m/0'/1/2'",
          private:
              'cbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca',
        ),
        (
          chain: "m/0'/1/2'/2",
          private:
              '0f479245fb19a38a1954c5c7c0ebab2f9bdfd96a17563ef28a6a4b1a2a764ef4',
        ),
        (
          chain: "m/0'/1/2'/2/1000000000",
          private:
              '471b76e389e528d6de6d816857e012c5455051cad6660850e58372a6c3e6e7c8',
        ),
      ];

      for (final vector in vectors) {
        test('should generate correct key pair for ${vector.chain}', () {
          final key = Secp256k1PrivateKey.fromDerivationPathInner(
            vector.chain,
            seed.toUint8List(),
          );
          expect(key.toHexString(), equals('0x${vector.private}'));
        });
      }
    });
  });
}
