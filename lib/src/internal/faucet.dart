/// This file contains the underlying implementation for the exposed API
/// surface in `api/faucet.dart`.
library;

import '../api/aptos_config.dart';
import '../client/post.dart';
import '../core/account_address.dart';
import '../types/pagination.dart';
import '../types/transaction_responses.dart';
import '../utils/const.dart';
import 'transaction.dart';

/// Funds an account with a specified amount of tokens from the Aptos faucet.
/// This function is useful for quickly providing a new or existing account
/// with tokens to facilitate transactions.
///
/// Note that only devnet has a publicly accessible faucet. For testnet, you
/// must use the minting page at https://aptos.dev/network/faucet.
///
/// Throws an error if the transaction does not return a user transaction
/// type.
Future<UserTransactionResponse> fundAccount({
  required AptosConfig aptosConfig,
  required AccountAddressInput accountAddress,
  required int amount,
  WaitForTransactionOptions? options,
}) async {
  final timeout = options?.timeoutSecs ?? defaultTxnTimeoutSec;
  final response = await postAptosFaucet(
    aptosConfig: aptosConfig,
    path: 'fund',
    body: {
      'address': AccountAddress.from(accountAddress).toString(),
      'amount': amount,
    },
    originMethod: 'fundAccount',
  );

  final data = Map<String, dynamic>.from(response.data as Map);
  final txnHash = (data['txn_hashes'] as List).first as String;

  final res = await waitForTransaction(
    aptosConfig: aptosConfig,
    transactionHash: txnHash,
    options: WaitForTransactionOptions(
      timeoutSecs: timeout,
      checkSuccess: options?.checkSuccess,
    ),
  );

  // Response is always User transaction for a user submitted transaction.
  if (res is UserTransactionResponse) {
    return res;
  }

  throw StateError(
    'Unexpected transaction received for fund account: ${res.type}',
  );
}
