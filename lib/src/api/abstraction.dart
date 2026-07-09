import '../core/account_address.dart';
import '../internal/abstraction.dart' as internal_abstraction;
import '../internal/view.dart' as internal_view;
import '../transactions/instances/simple_transaction.dart';
import '../transactions/type_tag/type_tag.dart';
import '../transactions/types.dart';
import '../types/move_types.dart';
import '../utils/helpers.dart';
import 'aptos_config.dart';

/// A dispatchable authentication function registered for an account,
/// identified by module address, module name, and function name.
class AuthenticationFunctionInfo {
  /// The address of the module containing the authentication function.
  final AccountAddress moduleAddress;

  /// The name of the module containing the authentication function.
  final String moduleName;

  /// The name of the authentication function.
  final String functionName;

  const AuthenticationFunctionInfo({
    required this.moduleAddress,
    required this.moduleName,
    required this.functionName,
  });
}

/// A class to handle all account abstraction (AA) operations on Aptos.
class AccountAbstraction {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  const AccountAbstraction(this.config);

  /// Adds a dispatchable authentication function to the account.
  ///
  /// [accountAddress] - The account to add the authentication function to.
  /// [authenticationFunction] - The authentication function info to add, in
  /// the form `moduleAddress::moduleName::functionName`.
  /// [options] - The options for the transaction.
  ///
  /// Returns a transaction to add the authentication function to the account.
  Future<SimpleTransaction> addAuthenticationFunctionTransaction({
    required AccountAddressInput accountAddress,
    required MoveFunctionId authenticationFunction,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_abstraction.addAuthenticationFunctionTransaction(
      aptosConfig: config,
      sender: accountAddress,
      authenticationFunction: authenticationFunction,
      options: options,
    );
  }

  /// Removes a dispatchable authentication function from the account.
  ///
  /// [accountAddress] - The account to remove the authentication function
  /// from. [authenticationFunction] - The authentication function info to
  /// remove. [options] - The options for the transaction.
  ///
  /// Returns a transaction to remove the authentication function from the
  /// account.
  Future<SimpleTransaction> removeAuthenticationFunctionTransaction({
    required AccountAddressInput accountAddress,
    required MoveFunctionId authenticationFunction,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_abstraction.removeAuthenticationFunctionTransaction(
      aptosConfig: config,
      sender: accountAddress,
      authenticationFunction: authenticationFunction,
      options: options,
    );
  }

  /// Removes the dispatchable authenticator from the account, disabling
  /// account abstraction entirely.
  ///
  /// [accountAddress] - The account to remove the authenticator from.
  /// [options] - The options for the transaction.
  ///
  /// Returns a transaction to remove the authenticator from the account.
  Future<SimpleTransaction> removeDispatchableAuthenticatorTransaction({
    required AccountAddressInput accountAddress,
    InputGenerateTransactionOptions? options,
  }) {
    return internal_abstraction.removeDispatchableAuthenticatorTransaction(
      aptosConfig: config,
      sender: accountAddress,
      options: options,
    );
  }

  /// Gets the dispatchable authentication functions for the account, or
  /// `null` if the account does not use account abstraction.
  Future<List<AuthenticationFunctionInfo>?> getAuthenticationFunction({
    required AccountAddressInput accountAddress,
  }) async {
    final result = await internal_view.view(
      aptosConfig: config,
      payload: InputViewFunctionData(
        function: '0x1::account_abstraction::dispatchable_authenticator',
        functionArguments: [AccountAddress.from(accountAddress)],
        abi: ViewFunctionABI(
          typeParameters: const [],
          parameters: [TypeTagAddress()],
          returnTypes: const [],
        ),
      ),
    );

    final functionInfoOption =
        ((result[0] as Map)['vec'] as List).cast<List<dynamic>>();

    if (functionInfoOption.isEmpty) return null;

    return functionInfoOption[0].map((functionInfo) {
      final info = functionInfo as Map;
      return AuthenticationFunctionInfo(
        moduleAddress:
            AccountAddress.fromString(info['module_address'] as String),
        moduleName: info['module_name'] as String,
        functionName: info['function_name'] as String,
      );
    }).toList();
  }

  /// Will return true if the account is abstracted with the given
  /// authentication function, otherwise false.
  ///
  /// [accountAddress] - The account to check.
  /// [authenticationFunction] - The authentication function to check for.
  Future<bool> isAccountAbstractionEnabled({
    required AccountAddressInput accountAddress,
    required MoveFunctionId authenticationFunction,
  }) async {
    final functionInfos =
        await getAuthenticationFunction(accountAddress: accountAddress);
    final parts = getFunctionParts(authenticationFunction);
    return functionInfos?.any(
          (functionInfo) =>
              AccountAddress.fromString(parts.moduleAddress)
                  .equals(functionInfo.moduleAddress) &&
              parts.moduleName == functionInfo.moduleName &&
              parts.functionName == functionInfo.functionName,
        ) ??
        false;
  }

  /// Creates a transaction to enable account abstraction with the given
  /// authentication function.
  ///
  /// This is an alias for [addAuthenticationFunctionTransaction].
  Future<SimpleTransaction> enableAccountAbstractionTransaction({
    required AccountAddressInput accountAddress,
    required MoveFunctionId authenticationFunction,
    InputGenerateTransactionOptions? options,
  }) {
    return addAuthenticationFunctionTransaction(
      accountAddress: accountAddress,
      authenticationFunction: authenticationFunction,
      options: options,
    );
  }

  /// Creates a transaction to disable account abstraction. If an
  /// authentication function is provided, it will specify to remove the
  /// authentication function; otherwise the dispatchable authenticator is
  /// removed entirely.
  Future<SimpleTransaction> disableAccountAbstractionTransaction({
    required AccountAddressInput accountAddress,
    MoveFunctionId? authenticationFunction,
    InputGenerateTransactionOptions? options,
  }) {
    if (authenticationFunction != null) {
      return removeAuthenticationFunctionTransaction(
        accountAddress: accountAddress,
        authenticationFunction: authenticationFunction,
        options: options,
      );
    }
    return removeDispatchableAuthenticatorTransaction(
      accountAddress: accountAddress,
      options: options,
    );
  }
}
