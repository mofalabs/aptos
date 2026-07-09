/// Different network environments for connecting to services, ranging from
/// production to development setups.
enum Network {
  mainnet('mainnet'),
  testnet('testnet'),
  devnet('devnet'),
  shelbynet('shelbynet'),
  netna('netna'),
  local('local'),
  custom('custom');

  const Network(this.value);

  final String value;

  /// Returns the [Network] matching the given string name, or null if there
  /// is no match.
  static Network? fromName(String name) {
    for (final network in Network.values) {
      if (network.value == name) return network;
    }
    return null;
  }
}

const Map<Network, String> networkToIndexerApi = {
  Network.mainnet: 'https://api.mainnet.aptoslabs.com/v1/graphql',
  Network.testnet: 'https://api.testnet.aptoslabs.com/v1/graphql',
  Network.devnet: 'https://api.devnet.aptoslabs.com/v1/graphql',
  Network.shelbynet: 'https://api.shelbynet.shelby.xyz/v1/graphql',
  Network.netna: 'https://api.netna.staging.aptoslabs.com/v1/graphql',
  Network.local: 'http://127.0.0.1:8090/v1/graphql',
};

const Map<Network, String> networkToNodeApi = {
  Network.mainnet: 'https://api.mainnet.aptoslabs.com/v1',
  Network.testnet: 'https://api.testnet.aptoslabs.com/v1',
  Network.devnet: 'https://api.devnet.aptoslabs.com/v1',
  Network.shelbynet: 'https://api.shelbynet.shelby.xyz/v1',
  Network.netna: 'https://api.netna.staging.aptoslabs.com/v1',
  Network.local: 'http://127.0.0.1:8080/v1',
};

const Map<Network, String> networkToFaucetApi = {
  Network.devnet: 'https://faucet.devnet.aptoslabs.com',
  Network.shelbynet: 'https://faucet.shelbynet.shelby.xyz',
  Network.netna:
      'https://faucet-dev-netna-us-central1-410192433417.us-central1.run.app',
  Network.local: 'http://127.0.0.1:8081',
};

const Map<Network, String> networkToPepperApi = {
  Network.mainnet: 'https://api.mainnet.aptoslabs.com/keyless/pepper/v0',
  Network.testnet: 'https://api.testnet.aptoslabs.com/keyless/pepper/v0',
  Network.devnet: 'https://api.devnet.aptoslabs.com/keyless/pepper/v0',
  Network.shelbynet: 'https://api.shelbynet.aptoslabs.com/keyless/pepper/v0',
  Network.netna: 'https://api.devnet.aptoslabs.com/keyless/pepper/v0',
  // Use the devnet service for local environment
  Network.local: 'https://api.devnet.aptoslabs.com/keyless/pepper/v0',
};

const Map<Network, String> networkToProverApi = {
  Network.mainnet: 'https://api.mainnet.aptoslabs.com/keyless/prover/v0',
  Network.testnet: 'https://api.testnet.aptoslabs.com/keyless/prover/v0',
  Network.devnet: 'https://api.devnet.aptoslabs.com/keyless/prover/v0',
  Network.shelbynet: 'https://api.shelbynet.aptoslabs.com/keyless/prover/v0',
  Network.netna: 'https://api.devnet.aptoslabs.com/keyless/prover/v0',
  // Use the devnet service for local environment
  Network.local: 'https://api.devnet.aptoslabs.com/keyless/prover/v0',
};

const Map<Network, int> networkToChainId = {
  Network.mainnet: 1,
  Network.testnet: 2,
  Network.local: 4,
};
