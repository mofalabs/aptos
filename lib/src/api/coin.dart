import '../core/account_address.dart';
import '../internal/coin.dart' as internal_coin;
import '../transactions/instances/simple_transaction.dart';
import '../transactions/types.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import 'aptos_config.dart';

/// A class to handle all `Coin` operations.
class Coin {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Coin` namespace with the specified
  /// configuration.
  const Coin(this.config);

  /// Generates a transfer coin transaction that can be simulated, signed,
  /// and submitted.
  ///
  /// [coinType] - Optional. The coin struct type to transfer. Defaults to
  /// `0x1::aptos_coin::AptosCoin`.
  Future<SimpleTransaction> transferCoinTransaction({
    required AccountAddressInput sender,
    required AccountAddressInput recipient,
    required AnyNumber amount,
    MoveStructId? coinType,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_coin.transferCoinTransaction(
      aptosConfig: config,
      sender: sender,
      recipient: recipient,
      amount: amount,
      coinType: coinType,
      options: options,
    );
  }
}
