# Aptos Dart SDK

A pure-Dart SDK for the [Aptos](https://aptos.dev) blockchain. Works in Dart
VM, Flutter (all platforms), and dart2js.

## Features

- **`Aptos` facade + `AptosConfig`** — a high-level, namespaced API:
  `account`, `coin`, `general`,
  `transaction` (`build` / `simulate` / `submit` / `batch`), `faucet`,
  `table`, `event`, `fungibleAsset`, `digitalAsset` (Token v2), `staking`,
  `object`, `ans`, `keyless`, `abstraction`.
- **Full account & key support** — legacy Ed25519, AIP-55 unified single key
  (Ed25519 / secp256k1), secp256r1 (WebAuthn), MultiKey, MultiEd25519,
  Keyless (OIDC / zero-knowledge, incl. federated), account abstraction
  (AA / DAA), BIP-44 / SLIP-0010 derivation, AIP-80 private key formatting.
- **Complete transaction pipeline** — remote-ABI argument encoding, simple /
  multi-agent / sponsored (fee payer) transactions, orderless transactions
  (replay protection nonce), simulation, batched submission via a
  transaction worker.
- **Wire-exact BCS** — the serialization layer is validated byte-for-byte
  against known-answer vectors (700+ unit tests), including poseidon hashing
  for keyless accounts implemented in pure Dart.
- **Indexer GraphQL support** — token / coin / staking / object / ANS queries
  against the Aptos indexer.

## Installation

```yaml
dependencies:
  aptos: ^1.0.0
```

## Quickstart

```dart
import 'package:aptos/aptos.dart';

Future<void> main() async {
  final aptos = Aptos(AptosConfig(network: Network.devnet));

  // Generate accounts.
  final alice = Account.generate();
  final bob = Account.generate();

  // Fund Alice via the devnet faucet.
  await aptos.fundAccount(
    accountAddress: alice.accountAddress,
    amount: 100000000,
  );

  // Build a transfer (the entry function ABI is fetched remotely).
  final transaction = await aptos.transaction.build.simple(
    sender: alice.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::aptos_account::transfer',
      functionArguments: [bob.accountAddress, 1000000],
    ),
    options: InputGenerateTransactionOptions(maxGasAmount: 200000),
  );

  // Simulate (optional).
  final simulations = await aptos.transaction.simulate.simple(
    signerPublicKey: alice.publicKey,
    transaction: transaction,
  );

  // Sign, submit, and wait for the transaction to commit.
  final pending = await aptos.signAndSubmitTransaction(
    signer: alice,
    transaction: transaction,
  );
  final committed =
      await aptos.waitForTransaction(transactionHash: pending.hash);

  // Read a balance.
  final balance = await aptos.getBalance(
    accountAddress: bob.accountAddress,
    asset: aptosCoin,
  );
}
```

See [`example/main.dart`](example/main.dart) for the runnable version.

## Common recipes

### Accounts

```dart
// Legacy Ed25519 (default)
final account = Account.generate();

// AIP-55 single key with secp256k1
final secp = Account.generate(
  scheme: SigningSchemeInput.secp256k1Ecdsa,
  legacy: false,
);

// From private key / mnemonic
final fromKey = Account.fromPrivateKey(
  privateKey: Ed25519PrivateKey('0x...'),
);
final fromMnemonic = Account.fromDerivationPath(
  path: "m/44'/637'/0'/0'/0'",
  mnemonic: 'your mnemonic ...',
);
```

### Multi-agent & sponsored transactions

```dart
final transaction = await aptos.transaction.build.multiAgent(
  sender: alice.accountAddress,
  secondarySignerAddresses: [bob.accountAddress],
  data: InputEntryFunctionData(function: '...', functionArguments: [...]),
);
final aliceAuth = aptos.transaction.sign(signer: alice, transaction: transaction);
final bobAuth = aptos.transaction.sign(signer: bob, transaction: transaction);
await aptos.transaction.submit.multiAgent(
  transaction: transaction,
  senderAuthenticator: aliceAuth,
  additionalSignersAuthenticators: [bobAuth],
);
```

### Keyless (OIDC) accounts

```dart
final ephemeralKeyPair = EphemeralKeyPair.generate();
// Have the user sign in with the OIDC provider using
// ephemeralKeyPair.nonce, then:
final keylessAccount = await aptos.deriveKeylessAccount(
  jwt: jwt,
  ephemeralKeyPair: ephemeralKeyPair,
);
```

### Indexer queries

```dart
final tokens = await aptos.getAccountOwnedTokens(
  accountAddress: alice.accountAddress,
);
final coins = await aptos.getAccountCoinsData(
  accountAddress: alice.accountAddress,
);
```

## Migrating from 0.x

Version 1.0.0 is a complete, ground-up rewrite. The legacy `AptosClient` /
`CoinClient` / `TokenClient` / `FaucetClient` / `IndexerClient` / `AptosAccount`
API has been removed. Highlights:

| 0.x | 1.x |
|---|---|
| `AptosClient(endpoint)` | `Aptos(AptosConfig(network: Network.mainnet))` |
| `AptosAccount()` | `Account.generate()` |
| `client.generateSignSubmitTransaction(...)` | `aptos.signAndSubmitTransaction(...)` |
| `CoinClient.transfer(...)` | `aptos.transferCoinTransaction(...)` |
| `TokenClient` (Token v1) | `aptos.digitalAsset.*` (Token v2) |
| `FaucetClient.fundAccount(...)` | `aptos.fundAccount(...)` |
| `IndexerClient` | `aptos.queryIndexer(...)` + typed namespace queries |

The package is now pure Dart (no Flutter dependency) and can be used in
server-side Dart, CLIs, and Flutter apps alike.

## Notes

- Groth16 proof verification (`Groth16VerificationKey.verifyProof`) is not
  supported client-side: it requires BN254 pairings, which have no pure-Dart
  implementation. Everything else in the keyless flow (pepper/prover services,
  address derivation, signing) is fully supported — proof verification is done
  by the chain itself.
- `dart test` runs the full offline unit suite. `example/main.dart` performs a
  live devnet end-to-end check.

## License

MIT © Mofa Labs. See [LICENSE](LICENSE).
