/// This file contains the underlying implementations for the exposed account
/// abstraction API surface in `api/abstraction.dart`. By moving the methods
/// out into a separate file, other namespaces and processes can access these
/// methods without depending on the entire abstraction namespace and without
/// having a dependency cycle error.
library;

import '../api/aptos_config.dart';
import '../core/account_address.dart';
import '../transactions/instances/simple_transaction.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/move_types.dart';
import '../utils/helpers.dart';
import 'transaction_submission.dart';

/// Builds a transaction that adds a dispatchable authentication function to
/// the sender's account.
Future<SimpleTransaction> addAuthenticationFunctionTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required MoveFunctionId authenticationFunction,
  InputGenerateTransactionOptions? options,
}) async {
  final parts = getFunctionParts(authenticationFunction);
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    data: InputEntryFunctionData(
      function: '0x1::account_abstraction::add_authentication_function',
      typeArguments: const [],
      functionArguments: [
        parts.moduleAddress,
        parts.moduleName,
        parts.functionName,
      ],
      abi: EntryFunctionABI(
        typeParameters: const [],
        parameters: [
          TypeTagAddress(),
          TypeTagStruct(stringStructTag()),
          TypeTagStruct(stringStructTag()),
        ],
      ),
    ),
    options: options,
  ) as SimpleTransaction;
}

/// Builds a transaction that removes a dispatchable authentication function
/// from the sender's account.
Future<SimpleTransaction> removeAuthenticationFunctionTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required MoveFunctionId authenticationFunction,
  InputGenerateTransactionOptions? options,
}) async {
  final parts = getFunctionParts(authenticationFunction);
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    data: InputEntryFunctionData(
      function: '0x1::account_abstraction::remove_authentication_function',
      typeArguments: const [],
      functionArguments: [
        parts.moduleAddress,
        parts.moduleName,
        parts.functionName,
      ],
      abi: EntryFunctionABI(
        typeParameters: const [],
        parameters: [
          TypeTagAddress(),
          TypeTagStruct(stringStructTag()),
          TypeTagStruct(stringStructTag()),
        ],
      ),
    ),
    options: options,
  ) as SimpleTransaction;
}

/// Builds a transaction that removes the dispatchable authenticator from the
/// sender's account, disabling account abstraction entirely.
Future<SimpleTransaction> removeDispatchableAuthenticatorTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  InputGenerateTransactionOptions? options,
}) async {
  return await generateTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    data: const InputEntryFunctionData(
      function: '0x1::account_abstraction::remove_authenticator',
      typeArguments: [],
      functionArguments: [],
      abi: EntryFunctionABI(typeParameters: [], parameters: []),
    ),
    options: options,
  ) as SimpleTransaction;
}
