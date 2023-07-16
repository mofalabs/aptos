
abstract class Constants {
  static const String mainnetAPI = "https://fullnode.mainnet.aptoslabs.com/v1";
  static const String testnetAPI = "https://fullnode.testnet.aptoslabs.com/v1";
  static const String devnetAPI = "https://fullnode.devnet.aptoslabs.com/v1";
  
  static const String faucetDevAPI = "https://faucet.devnet.aptoslabs.com";

  static const String mainnetIndexer = "https://indexer.mainnet.aptoslabs.com/v1/graphql";
  static const String testnetIndexer = "https://indexer-testnet.staging.gcp.aptosdev.com/v1/graphql";
  static const String devnetIndexer = "https://indexer-devnet.staging.gcp.aptosdev.com/v1/graphql";

  static bool enableDebugLog = false;
}

enum Network {
  mainnet, testnet, devnet
}