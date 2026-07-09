/// A hex input, which can be a hex [String] (with or without the `0x` prefix)
/// or a [Uint8List] of raw bytes.
///
/// Dart has no union types, so this is an alias of [Object]; values of any
/// other type are rejected at runtime by `Hex.fromHexInput` and friends.
typedef HexInput = Object;

/// MIME types used by the Aptos REST API.
enum MimeType {
  /// JSON representation, used for transaction submission and accept type JSON
  /// output.
  json('application/json'),

  /// BCS representation, used for transaction submission in BCS input.
  bcs('application/x-bcs'),

  /// BCS representation of a signed transaction.
  bcsSignedTransaction('application/x.aptos.signed_transaction+bcs'),

  /// BCS representation of a view function.
  bcsViewFunction('application/x.aptos.view_function+bcs');

  const MimeType(this.value);

  final String value;
}

/// Variants of type tags used in the Rust implementation.
enum TypeTagVariants {
  boolean(0),
  u8(1),
  u64(2),
  u128(3),
  address(4),
  signer(5),
  vector(6),
  struct(7),
  u16(8),
  u32(9),
  u256(10),
  i8(11),
  i16(12),
  i32(13),
  i64(14),
  i128(15),
  i256(16),

  /// This is specifically a placeholder and does not represent a real type.
  reference(254),

  /// This is specifically a placeholder and does not represent a real type.
  generic(255);

  const TypeTagVariants(this.value);

  final int value;
}

/// Variants of script transaction arguments used in Rust.
/// See https://github.com/aptos-labs/aptos-core/blob/main/third_party/move/move-core/types/src/transaction_argument.rs
enum ScriptTransactionArgumentVariants {
  u8(0),
  u64(1),
  u128(2),
  address(3),
  u8Vector(4),
  boolean(5),
  u16(6),
  u32(7),
  u256(8),
  serialized(9),
  // NOTE: Added in bytecode version v9, do not reorder!
  i8(10),
  i16(11),
  i32(12),
  i64(13),
  i128(14),
  i256(15);

  const ScriptTransactionArgumentVariants(this.value);

  final int value;
}

/// The payload for various transaction types in the system.
/// See https://github.com/aptos-labs/aptos-core/blob/main/types/src/transaction/mod.rs
enum TransactionPayloadVariants {
  script(0),
  entryFunction(2),
  multisig(3),
  payload(4),
  encryptedPayload(5);

  const TransactionPayloadVariants(this.value);

  final int value;
}

/// Variants of multisig transaction payloads used in the system.
enum MultiSigTransactionPayloadVariants {
  entryFunction(0),
  script(1);

  const MultiSigTransactionPayloadVariants(this.value);

  final int value;
}

/// Variants of the transaction inner payload (used by orderless
/// transactions).
enum TransactionInnerPayloadVariants {
  v1(0);

  const TransactionInnerPayloadVariants(this.value);

  final int value;
}

/// Variants of transaction executables.
enum TransactionExecutableVariants {
  script(0),
  entryFunction(1),
  empty(2),
  encrypted(3);

  const TransactionExecutableVariants(this.value);

  final int value;
}

/// Variants of transaction extra configuration.
enum TransactionExtraConfigVariants {
  v1(0);

  const TransactionExtraConfigVariants(this.value);

  final int value;
}

/// Variants of raw transactions with data used in the system.
enum TransactionVariants {
  multiAgentTransaction(0),
  feePayerTransaction(1);

  const TransactionVariants(this.value);

  final int value;
}

/// Variants of transaction authenticators used in the system.
/// See https://github.com/aptos-labs/aptos-core/blob/main/types/src/transaction/authenticator.rs
enum TransactionAuthenticatorVariant {
  ed25519(0),
  multiEd25519(1),
  multiAgent(2),
  feePayer(3),
  singleSender(4);

  const TransactionAuthenticatorVariant(this.value);

  final int value;
}

/// Variants of account authenticators used in transactions.
enum AccountAuthenticatorVariant {
  ed25519(0),
  multiEd25519(1),
  singleKey(2),
  multiKey(3),
  noAccountAuthenticator(4),
  abstraction(5);

  const AccountAuthenticatorVariant(this.value);

  final int value;
}

/// Variants of private keys that can comply with the AIP-80 standard.
/// See https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-80.md
enum PrivateKeyVariants {
  ed25519('ed25519'),
  secp256k1('secp256k1'),
  secp256r1('secp256r1');

  const PrivateKeyVariants(this.value);

  final String value;
}

/// Variants of public keys used in cryptographic operations.
enum AnyPublicKeyVariant {
  ed25519(0),
  secp256k1(1),
  secp256r1(2),
  keyless(3),
  federatedKeyless(4),
  slhDsaSha2_128s(5);

  const AnyPublicKeyVariant(this.value);

  final int value;
}

/// Variants of signature types used for cryptographic operations.
enum AnySignatureVariant {
  ed25519(0),
  secp256k1(1),
  webAuthn(2),
  keyless(3),
  slhDsaSha2_128s(4);

  const AnySignatureVariant(this.value);

  final int value;
}

/// Variants of ephemeral public keys used in cryptographic operations.
enum EphemeralPublicKeyVariant {
  ed25519(0);

  const EphemeralPublicKeyVariant(this.value);

  final int value;
}

/// Variants of ephemeral signatures used for secure communication.
enum EphemeralSignatureVariant {
  ed25519(0);

  const EphemeralSignatureVariant(this.value);

  final int value;
}

/// Variants of ephemeral certificates used in secure transactions.
enum EphemeralCertificateVariant {
  zkProof(0);

  const EphemeralCertificateVariant(this.value);

  final int value;
}

/// Variants of zero-knowledge proofs used in cryptographic operations.
enum ZkpVariant {
  groth16(0);

  const ZkpVariant(this.value);

  final int value;
}

/// The type of a transaction response.
enum TransactionResponseType {
  pending('pending_transaction'),
  user('user_transaction'),
  genesis('genesis_transaction'),
  blockMetadata('block_metadata_transaction'),
  stateCheckpoint('state_checkpoint_transaction'),
  validator('validator_transaction'),
  blockEpilogue('block_epilogue_transaction');

  const TransactionResponseType(this.value);

  final String value;
}

/// Move function visibility.
enum MoveFunctionVisibility {
  private('private'),
  public('public'),
  friend('friend');

  const MoveFunctionVisibility(this.value);

  final String value;
}

/// Move abilities.
enum MoveAbility {
  store('store'),
  drop('drop'),
  key('key'),
  copy('copy');

  const MoveAbility(this.value);

  final String value;
}

/// The role of a node.
enum RoleType {
  validator('validator'),
  fullNode('full_node');

  const RoleType(this.value);

  final String value;
}

/// Different schemes for signing keys used in cryptographic operations.
enum SigningScheme {
  /// For Ed25519PublicKey.
  ed25519(0),

  /// For MultiEd25519PublicKey.
  multiEd25519(1),

  /// For SingleKey ecdsa.
  singleKey(2),

  multiKey(3);

  const SigningScheme(this.value);

  final int value;
}

/// Specifies the signing schemes available for cryptographic operations.
enum SigningSchemeInput {
  /// For Ed25519PublicKey.
  ed25519(0),

  /// For Secp256k1Ecdsa.
  secp256k1Ecdsa(2);

  const SigningSchemeInput(this.value);

  final int value;
}

/// Specifies the schemes for deriving account addresses from various data
/// sources.
enum DeriveScheme {
  /// Derives an address using an AUID, used for objects.
  deriveAuid(251),

  /// Derives an address from another object address.
  deriveObjectAddressFromObject(252),

  /// Derives an address from a GUID, used for objects.
  deriveObjectAddressFromGuid(253),

  /// Derives an address from seed bytes, used for named objects.
  deriveObjectAddressFromSeed(254),

  /// Derives an address from seed bytes, used for resource accounts.
  deriveResourceAccountAddress(255);

  const DeriveScheme(this.value);

  final int value;
}
