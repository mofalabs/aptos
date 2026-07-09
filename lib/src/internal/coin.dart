/// Internal helpers for building coin transfer transactions.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'transaction_submission.dart';

final EntryFunctionABI _coinTransferAbi = EntryFunctionABI(
  typeParameters: const [MoveFunctionGenericTypeParam(constraints: [])],
  parameters: [TypeTagAddress(), TypeTagU64()],
);

/// Generates a transaction to transfer coins from one account to another.
/// This function allows you to specify the sender, recipient, amount, and
/// coin type for the transaction.
///
/// [coinType] - (Optional) The type of coin to transfer; defaults to the
/// Aptos Coin if not specified.
Future<SimpleTransaction> transferCoinTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required AccountAddressInput recipient,
  required AnyNumber amount,
  MoveStructId? coinType,
  InputGenerateTransactionOptions? options,
}) async {
  final coinStructType = coinType ?? aptosCoin;
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    data: InputEntryFunctionData(
      function: '0x1::aptos_account::transfer_coins',
      typeArguments: [coinStructType],
      functionArguments: [recipient, amount],
      abi: _coinTransferAbi,
    ),
    options: options,
  ) as SimpleTransaction;
}
