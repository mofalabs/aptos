## 1.0.0

Complete, ground-up rewrite with a new namespaced architecture.

* **Breaking**: the legacy `AptosClient` / `CoinClient` / `TokenClient` /
  `FaucetClient` / `IndexerClient` / `AptosAccount` API has been removed.
  See the README's migration table.
* **Breaking**: the package is now pure Dart — the Flutter dependency was
  removed (usable in server-side Dart, CLIs, and Flutter alike).
* New `Aptos` facade + `AptosConfig` with namespaces: account, coin, general,
  transaction (build/simulate/submit/batch), faucet, table, event,
  fungibleAsset, digitalAsset (Token v2), staking, object, ans, keyless,
  abstraction.
* New account hierarchy: `Account.generate()`, Ed25519 (legacy), AIP-55
  SingleKey (ed25519/secp256k1), secp256r1/WebAuthn keys, MultiKey,
  MultiEd25519, Keyless & FederatedKeyless (OIDC/ZK, pure-Dart poseidon),
  account abstraction (AA/DAA), `EphemeralKeyPair`.
* Full transaction pipeline: remote-ABI argument encoding, multi-agent and
  sponsored (fee payer) transactions, orderless transactions
  (replayProtectionNonce), simulation, batch submission worker, pluggable
  `TransactionSubmitter`.
* Keyless: full local signature verification, including the BN254 Groth16
  proof check (pure-Dart pairing), plus network-backed
  `verifySignatureAsync` (fetches the keyless configuration and JWKs from
  chain).
* Encrypted transactions: batch-encryption payloads via a pure-Dart
  BLS12-381 pairing implementation (BIBE identity-based encryption, RFC 9380
  hash-to-curve, AES-128-GCM), wired into the build flow through
  `options.encrypted`.
* BCS layer and all curve/pairing primitives validated byte-for-byte against
  the official SDK and independently generated reference vectors; 700+ unit
  tests.

## 0.0.1

* Initial version, created by 0xmovebuilder.


## 0.0.2

* Add optInTokenTransfer and multiSig

## 0.0.3

* Add typeTag and multiSig

## 0.0.4

* Add query pending tokens
* Add AnsClient

## 0.0.5

* Fix bcs simulate

## 0.0.6

* Fix dio Transformer type