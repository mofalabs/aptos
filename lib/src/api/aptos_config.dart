import '../client/dio_client.dart';
import '../client/types.dart';
import '../transactions/types.dart' show TransactionSubmitter;
import '../utils/api_endpoints.dart';
import '../utils/const.dart';

/// Settings for plugins. This can be used to override certain client
/// behavior.
class PluginSettings {
  /// If given, this will be used for submitting transactions instead of the
  /// default implementation (which submits transactions directly via a node).
  final TransactionSubmitter? transactionSubmitter;

  const PluginSettings({this.transactionSubmitter});
}

/// Optional transaction generation configurations.
class TransactionGenerationConfig {
  final int? defaultMaxGasAmountOverride;
  final int? defaultTxnExpirySecFromNowOverride;

  const TransactionGenerationConfig({
    this.defaultMaxGasAmountOverride,
    this.defaultTxnExpirySecFromNowOverride,
  });
}

/// Represents the configuration settings for an Aptos SDK client instance.
/// This class allows customization of various endpoints and client settings.
///
/// ```dart
/// // Create a configuration for connecting to the Aptos testnet
/// final config = AptosConfig(network: Network.testnet);
///
/// // Initialize the Aptos client with the configuration
/// final aptos = Aptos(config);
/// ```
class AptosConfig {
  /// The network that this SDK is associated with. Defaults to devnet.
  final Network network;

  /// The client instance the SDK uses. Defaults to [DioClient].
  final Client client;

  /// The optional hardcoded fullnode URL to send requests to instead of using
  /// the network.
  final String? fullnode;

  /// The optional hardcoded faucet URL to send requests to instead of using
  /// the network.
  final String? faucet;

  /// The optional hardcoded pepper service URL to send requests to instead of
  /// using the network.
  final String? pepper;

  /// The optional hardcoded prover service URL to send requests to instead of
  /// using the network.
  final String? prover;

  /// The optional hardcoded indexer URL to send requests to instead of using
  /// the network.
  final String? indexer;

  /// Optional client configurations.
  final ClientConfig clientConfig;

  /// Optional specific fullnode configurations.
  final FullNodeConfig fullnodeConfig;

  /// Optional specific indexer configurations.
  final IndexerConfig indexerConfig;

  /// Optional specific faucet configurations.
  final FaucetConfig faucetConfig;

  /// Optional specific transaction generation configurations.
  final TransactionGenerationConfig transactionGenerationConfig;

  /// Optional plugin settings to override client behavior.
  final PluginSettings? pluginSettings;

  /// Whether the configured transaction submitter (if any) is currently
  /// ignored. Initialized to `false` when plugin settings are provided.
  bool _ignoreTransactionSubmitter = false;

  /// Initializes an instance of the Aptos client configuration with the
  /// specified settings.
  ///
  /// Throws an [ArgumentError] when custom endpoints are provided without a
  /// network.
  AptosConfig({
    Network? network,
    this.fullnode,
    this.faucet,
    this.pepper,
    this.prover,
    this.indexer,
    Client? client,
    ClientConfig? clientConfig,
    FullNodeConfig? fullnodeConfig,
    IndexerConfig? indexerConfig,
    FaucetConfig? faucetConfig,
    TransactionGenerationConfig? transactionGenerationConfig,
    this.pluginSettings,
  })  : network = network ?? Network.devnet,
        client = client ?? DioClient(),
        clientConfig = clientConfig ?? const ClientConfig(),
        fullnodeConfig = fullnodeConfig ?? const FullNodeConfig(),
        indexerConfig = indexerConfig ?? const IndexerConfig(),
        faucetConfig = faucetConfig ?? const FaucetConfig(),
        transactionGenerationConfig =
            transactionGenerationConfig ?? const TransactionGenerationConfig() {
    // If there are any endpoint overrides, they are custom networks, keep
    // that in mind.
    final hasCustomEndpoints = fullnode != null ||
        indexer != null ||
        faucet != null ||
        pepper != null ||
        prover != null;
    if (hasCustomEndpoints && network == null) {
      throw ArgumentError('Custom endpoints require a network to be specified');
    }
  }

  /// Returns the URL endpoint to send the request to based on the specified
  /// API type. If a custom URL was provided in the configuration, that URL is
  /// returned. Otherwise, the URL endpoint is derived from the network.
  String getRequestUrl(AptosApiType apiType) {
    switch (apiType) {
      case AptosApiType.fullnode:
        if (fullnode != null) return fullnode!;
        if (network == Network.custom) {
          throw StateError('Please provide a custom full node url');
        }
        return networkToNodeApi[network]!;
      case AptosApiType.faucet:
        if (faucet != null) return faucet!;
        if (network == Network.testnet) {
          throw StateError(
            'There is no way to programmatically mint testnet APT, you must '
            'use the minting site at https://aptos.dev/network/faucet',
          );
        }
        if (network == Network.mainnet) {
          throw StateError('There is no mainnet faucet');
        }
        if (network == Network.custom) {
          throw StateError('Please provide a custom faucet url');
        }
        return networkToFaucetApi[network]!;
      case AptosApiType.indexer:
        if (indexer != null) return indexer!;
        if (network == Network.custom) {
          throw StateError('Please provide a custom indexer url');
        }
        return networkToIndexerApi[network]!;
      case AptosApiType.pepper:
        if (pepper != null) return pepper!;
        if (network == Network.custom) {
          throw StateError('Please provide a custom pepper service url');
        }
        return networkToPepperApi[network]!;
      case AptosApiType.prover:
        if (prover != null) return prover!;
        if (network == Network.custom) {
          throw StateError('Please provide a custom prover service url');
        }
        return networkToProverApi[network]!;
    }
  }

  /// Checks if the provided URL is a known pepper service endpoint.
  bool isPepperServiceRequest(String url) => networkToPepperApi[network] == url;

  /// Checks if the provided URL is a known prover service endpoint.
  bool isProverServiceRequest(String url) => networkToProverApi[network] == url;

  /// The default `max_gas_amount` used when a transaction does not specify one
  /// (the config override if set, otherwise the SDK default).
  int getDefaultMaxGasAmount() =>
      transactionGenerationConfig.defaultMaxGasAmountOverride ??
      defaultMaxGasAmount;

  /// The default expiration horizon in seconds from now, used when a
  /// transaction does not specify an expiration timestamp.
  int getDefaultTxnExpirySecFromNow() =>
      transactionGenerationConfig.defaultTxnExpirySecFromNowOverride ??
      defaultTxnExpSecFromNow;

  /// If you have set a custom transaction submitter, you can use this to
  /// determine whether to use it or not. For example, to stop using the
  /// transaction submitter:
  ///
  /// ```dart
  /// aptos.config.setIgnoreTransactionSubmitter(true);
  /// ```
  void setIgnoreTransactionSubmitter(bool ignore) {
    if (pluginSettings != null) {
      _ignoreTransactionSubmitter = ignore;
    }
  }

  /// If a custom transaction submitter has been specified in the
  /// [PluginSettings] and [setIgnoreTransactionSubmitter] has not been set to
  /// `true`, this returns a transaction submitter that should be used instead
  /// of the default transaction submission behavior.
  TransactionSubmitter? getTransactionSubmitter() {
    if (pluginSettings == null) return null;
    if (_ignoreTransactionSubmitter) return null;
    return pluginSettings!.transactionSubmitter;
  }
}
