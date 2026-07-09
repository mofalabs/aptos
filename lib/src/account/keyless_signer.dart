/// Lightweight keyless signer detection utility.
///
/// This module has no dependency on the keyless crypto stack, making it safe
/// to import from anywhere without pulling in that dependency chain.
library;

import 'account.dart';

/// An interface which defines if an Account utilizes Keyless signing.
abstract class KeylessSigner implements Account {
  /// Validates that the Keyless Account can be used to sign transactions.
  // TODO: type [aptosConfig] as AptosConfig once the api module is available.
  Future<void> checkKeylessAccountValidity(Object? aptosConfig);

  /// Waits for any proofs on the KeylessAccount to be fetched. Present on
  /// `AbstractKeylessAccount` subclasses.
  Future<void> waitForProofFetch();
}

/// Determines whether the provided object is a [KeylessSigner].
///
/// Because Dart is nominally typed, this checks for the [KeylessSigner]
/// interface rather than doing a structural (duck-typed) check.
bool isKeylessSigner(Object? obj) => obj is KeylessSigner;
