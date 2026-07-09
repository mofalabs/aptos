import '../core/account_address.dart';
import '../internal/faucet.dart' as internal_faucet;
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import 'aptos_config.dart';

/// A class to query all `Faucet` related queries on Aptos.
///
/// Note that only devnet has a publicly accessible faucet. For testnet, you
/// must use the minting page at https://aptos.dev/network/faucet.
class Faucet {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Faucet` namespace with the specified
  /// configuration.
  const Faucet(this.config);

  /// This function creates an account if it does not exist and mints the
  /// specified amount of coins into that account.
  ///
  /// Returns the user transaction that funded the account.
  ///
  /// NOTE: waiting for the indexer to sync up to the funding transaction
  /// version (unless `options.waitForIndexer == false`) is deferred to the
  /// indexer task.
  Future<UserTransactionResponse> fundAccount({
    required AccountAddressInput accountAddress,
    required int amount,
    WaitForTransactionOptions? options,
  }) {
    return internal_faucet.fundAccount(
      aptosConfig: config,
      accountAddress: accountAddress,
      amount: amount,
      options: options,
    );
  }
}
