/// Types of API endpoints used for routing requests in the Aptos network.
enum AptosApiType {
  fullnode('Fullnode'),
  indexer('Indexer'),
  faucet('Faucet'),
  pepper('Pepper'),
  prover('Prover');

  const AptosApiType(this.value);

  final String value;
}

/// The default max gas amount when none is given.
///
/// This is the maximum number of gas units that will be used by a transaction
/// before being rejected.
///
/// Note that max gas amount varies based on the transaction. A larger
/// transaction will go over this default gas amount, and the value will need
/// to be changed for the specific transaction.
const int defaultMaxGasAmount = 2000000;

/// The minimum max gas amount that the SDK will allow for a transaction.
///
/// This value acts as a floor to prevent transactions from being built with a
/// max gas amount below the network's minimum transaction gas units, which
/// would cause MAX_GAS_UNITS_BELOW_MIN_TRANSACTION_GAS_UNITS errors.
const int minMaxGasAmount = 2000;

/// Minimum gas unit price (Octas per gas unit) for encrypted transactions.
/// Encrypted transactions require 2× the network base minimum (100) because
/// validators bear the decryption compute cost (aptos-core
/// `encrypted_txn_min_price_per_gas_unit`, RELEASE_V1_45+). The node rejects
/// encrypted submissions below this price.
const int minEncryptedTxnGasUnitPrice = 200;

/// The default transaction expiration seconds from now.
///
/// This time is how long until the blockchain nodes will reject the
/// transaction.
const int defaultTxnExpSecFromNow = 20;

/// The default number of seconds to wait for a transaction to be processed.
const int defaultTxnTimeoutSec = 20;

/// The default gas currency for the network.
const String aptosCoin = '0x1::aptos_coin::AptosCoin';

/// The address of the APT fungible asset metadata object.
const String aptosFa =
    '0x000000000000000000000000000000000000000000000000000000000000000a';

const String rawTransactionSalt = 'APTOS::RawTransaction';

const String rawTransactionWithDataSalt = 'APTOS::RawTransactionWithData';

const String accountAbstractionSigningDataSalt = 'APTOS::AASigningData';

/// Supported processor types for the indexer API, sourced from the
/// processor_status table in the indexer database.
enum ProcessorType {
  accountRestorationProcessor('account_restoration_processor'),
  accountTransactionProcessor('account_transactions_processor'),
  defaultProcessor('default_processor'),
  eventsProcessor('events_processor'),

  /// Fungible asset processor also handles coins.
  fungibleAssetProcessor('fungible_asset_processor'),
  stakeProcessor('stake_processor'),

  /// Token V2 processor replaces Token processor (not only for digital
  /// assets).
  tokenV2Processor('token_v2_processor'),
  userTransactionProcessor('user_transaction_processor'),
  objectProcessor('objects_processor');

  const ProcessorType(this.value);

  final String value;
}

/// Regular expression pattern for Firebase Auth issuer URLs.
/// Matches URLs in the format: https://securetoken.google.com/[project-id]
/// where project-id can contain letters, numbers, hyphens, and underscores.
final RegExp firebaseAuthIssPattern =
    RegExp(r'^https://securetoken\.google\.com/[a-zA-Z0-9-_]+$');
