import '../../api/aptos_config.dart';
import '../../core/account_address.dart';
import '../../core/authentication_key.dart';
import '../../core/crypto/encryption/symmetric.dart' show randomBytes;
import '../../internal/account.dart';
import '../../internal/encryption_key.dart';
import '../instances/encrypted_payload.dart';
import '../instances/identifier.dart';
import '../instances/module_id.dart';
import '../instances/transaction_payload.dart';
import '../types.dart';
import 'transaction_builder.dart';

typedef _Executable = ({
  TransactionExecutable executable,
  TransactionExtraConfig extraConfig,
});

_Executable _payloadToExecutable(AnyTransactionPayloadInstance payload) {
  if (payload is TransactionInnerPayloadV1) {
    return (executable: payload.executable, extraConfig: payload.extraConfig);
  }
  final inner =
      convertPayloadToInnerPayload(payload) as TransactionInnerPayloadV1;
  return (executable: inner.executable, extraConfig: inner.extraConfig);
}

ClaimedEntryFunction _toClaimedEntryFunction(Object input) {
  if (input is ClaimedEntryFunction) {
    return input;
  }
  if (input is InputClaimedEntryFunction) {
    return ClaimedEntryFunction(
      ModuleId.fromStr(input.module),
      input.functionName != null ? Identifier(input.functionName!) : null,
    );
  }
  throw ArgumentError(
    'claimedEntryFunction must be a ClaimedEntryFunction or '
    'InputClaimedEntryFunction',
  );
}

void _assertClaimMatchesExecutable(
  AnyTransactionPayloadInstance payload,
  ClaimedEntryFunction claim,
) {
  final executable = _payloadToExecutable(payload).executable;
  if (executable is! TransactionExecutableEntryFunction) {
    throw ArgumentError(
      'claimedEntryFunction is only valid when the plaintext executable is an '
      'entry function.',
    );
  }
  final entry = executable.entryFunction;
  if (!entry.moduleName.address.equals(claim.moduleId.address) ||
      entry.moduleName.name.identifier != claim.moduleId.name.identifier) {
    throw ArgumentError(
      'claimedEntryFunction.module must match the entry function module.',
    );
  }
  if (claim.functionName != null &&
      entry.functionName.identifier != claim.functionName!.identifier) {
    throw ArgumentError(
      'claimedEntryFunction.functionName must match the entry function name '
      'when provided.',
    );
  }
}

bool _payloadHasMultisigAddress(AnyTransactionPayloadInstance payload) {
  if (payload is TransactionPayloadMultiSig) {
    return true;
  }
  if (payload is TransactionInnerPayloadV1) {
    final ec = payload.extraConfig;
    return ec is TransactionExtraConfigV1 && ec.multisigAddress != null;
  }
  return false;
}

ClaimedEntryFunction? _resolveClaimedEntryFun({
  required AnyTransactionPayloadInstance payload,
  required AccountAddressInput? feePayerAddress,
  required InputGenerateTransactionOptions options,
}) {
  // Unlike the associated-data auth keys, a zero fee-payer address (a deferred
  // gas-station sponsor) still means a fee payer will sign, so we include the
  // claimed entry function so they can inspect the payload without decrypting.
  final hasFeePayer = feePayerAddress != null;
  if (!hasFeePayer && !_payloadHasMultisigAddress(payload)) {
    return null;
  }
  final claimInput = options.claimedEntryFunction;
  if (claimInput != null) {
    final claim = _toClaimedEntryFunction(claimInput);
    _assertClaimMatchesExecutable(payload, claim);
    return claim;
  }
  final executable = _payloadToExecutable(payload).executable;
  if (executable is TransactionExecutableEntryFunction) {
    return ClaimedEntryFunction.fromEntryFunction(executable.entryFunction);
  }
  return null;
}

AuthenticationKey _resolveAuthKey(Object input) {
  if (input is AuthenticationKey) {
    return input;
  }
  return AuthenticationKey(data: input);
}

/// Assembles `(address, authenticationKey)` pairs in signer order (sender,
/// secondaries, fee payer last). Keys not supplied in [options] are fetched
/// from chain via [fetchAndCacheAuthKeyForAddress].
Future<({SignerAuthKeyPair sender, List<SignerAuthKeyPair>? additional})>
    _buildSignerAuthKeys({
  required AptosConfig aptosConfig,
  required AccountAddress sender,
  required InputGenerateTransactionOptions options,
  AccountAddressInput? feePayerAddress,
  List<AccountAddressInput>? secondarySignerAddresses,
}) async {
  final secondaryAddrs = secondarySignerAddresses ?? const [];
  final secondaryAuthInputs = options.secondarySignerAuthenticationKeys;
  if (secondaryAddrs.isEmpty &&
      secondaryAuthInputs != null &&
      secondaryAuthInputs.isNotEmpty) {
    throw ArgumentError(
      'options.secondarySignerAuthenticationKeys was set but no '
      'secondarySignerAddresses were provided.',
    );
  }
  if (secondaryAddrs.isNotEmpty &&
      secondaryAuthInputs != null &&
      secondaryAuthInputs.length != secondaryAddrs.length) {
    throw ArgumentError(
      'Encrypted multi-agent transactions require '
      'options.secondarySignerAuthenticationKeys (when provided) to have one '
      'entry per secondarySignerAddresses entry, in the same order. Leave '
      'individual entries null to fetch them from chain.',
    );
  }

  final feePayerAddr =
      feePayerAddress != null ? AccountAddress.from(feePayerAddress) : null;
  final hasNonZeroFeePayer =
      feePayerAddr != null && !feePayerAddr.equals(AccountAddress.zero);
  if (options.feePayerAuthenticationKey != null && !hasNonZeroFeePayer) {
    throw ArgumentError(
      'options.feePayerAuthenticationKey was set but feePayerAddress is '
      'missing or the zero address (no on-chain fee payer for the associated '
      'data).',
    );
  }

  Future<AuthenticationKey> resolveFor(
    AccountAddress address,
    Object? input,
  ) async {
    if (input != null) {
      return _resolveAuthKey(input);
    }
    return fetchAndCacheAuthKeyForAddress(
      aptosConfig: aptosConfig,
      accountAddress: address,
    );
  }

  final senderAuthKeyFuture =
      resolveFor(sender, options.senderAuthenticationKey);
  final secondaryPairsFuture = Future.wait(
    List.generate(secondaryAddrs.length, (i) async {
      final address = AccountAddress.from(secondaryAddrs[i]);
      final authKey = await resolveFor(address, secondaryAuthInputs?[i]);
      return SignerAuthKeyPair(address: address, authenticationKey: authKey);
    }),
  );
  final feePayerAuthKeyFuture = hasNonZeroFeePayer
      ? resolveFor(feePayerAddr, options.feePayerAuthenticationKey)
      : Future<AuthenticationKey?>.value(null);

  final senderAuthKey = await senderAuthKeyFuture;
  final secondaryPairs = await secondaryPairsFuture;
  final feePayerAuthKey = await feePayerAuthKeyFuture;

  final senderPair =
      SignerAuthKeyPair(address: sender, authenticationKey: senderAuthKey);
  final additional = <SignerAuthKeyPair>[...secondaryPairs];
  if (hasNonZeroFeePayer && feePayerAuthKey != null) {
    additional.add(SignerAuthKeyPair(
      address: feePayerAddr,
      authenticationKey: feePayerAuthKey,
    ));
  }
  return (
    sender: senderPair,
    additional: additional.isNotEmpty ? additional : null,
  );
}

/// Encrypts an entry-function/script/inner [payload] using the node's
/// per-epoch batch-encryption key, producing a
/// [TransactionPayloadEncryptedPayload].
///
/// Throws if the node does not advertise an encryption key.
Future<TransactionPayloadEncryptedPayload> buildEncryptedPayload({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required AnyTransactionPayloadInstance payload,
  required InputGenerateTransactionOptions options,
  AccountAddressInput? feePayerAddress,
  List<AccountAddressInput>? secondarySignerAddresses,
  BigInt? replayProtectionNonce,
}) async {
  final senderAddr = AccountAddress.from(sender);
  final authKeys = await _buildSignerAuthKeys(
    aptosConfig: aptosConfig,
    sender: senderAddr,
    options: options,
    feePayerAddress: feePayerAddress,
    secondarySignerAddresses: secondarySignerAddresses,
  );
  final claimedEntryFunction = _resolveClaimedEntryFun(
    payload: payload,
    feePayerAddress: feePayerAddress,
    options: options,
  );

  final encryption = await fetchAndCacheEncryptionKey(aptosConfig: aptosConfig);
  if (encryption == null) {
    throw StateError(
      'Encrypted transactions requested but the node does not provide an '
      'encryption key. Ensure the node supports encrypted transaction '
      'submission.',
    );
  }

  final base = _payloadToExecutable(payload);
  var extraConfig = base.extraConfig;
  if (replayProtectionNonce != null &&
      extraConfig is TransactionExtraConfigV1) {
    extraConfig = TransactionExtraConfigV1(
      multisigAddress: extraConfig.multisigAddress,
      replayProtectionNonce: replayProtectionNonce,
    );
  }

  final decryptionNonce = randomBytes(decryptionNonceLength);
  final decryptedPayload = DecryptedPlaintext(base.executable, decryptionNonce);
  final associatedData = PayloadAssociatedData(
    senderAddr,
    [authKeys.sender, ...?authKeys.additional],
  );
  final ciphertext = encryption.key.encrypt(decryptedPayload, associatedData);

  return TransactionPayloadEncryptedPayload(
    ciphertext,
    extraConfig,
    decryptedPayload.hash(),
    encryption.epoch,
    claimedEntryFunction,
  );
}
