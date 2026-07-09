/// This file handles the transaction creation lifecycle.
/// It holds different operations to generate a transaction payload, a raw
/// transaction, and a signed transaction that can be simulated, signed and
/// submitted to chain.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../../api/aptos_config.dart';
import '../../bcs/consts.dart';
import '../../core/account_address.dart';
import '../../core/crypto/ed25519.dart';
import '../../core/crypto/federated_keyless.dart';
import '../../core/crypto/keyless.dart';
import '../../core/crypto/multi_key.dart';
import '../../core/crypto/public_key.dart';
import '../../core/crypto/secp256k1.dart';
import '../../core/crypto/signature.dart';
import '../../core/crypto/single_key.dart';
import '../../core/hex.dart';
import '../../internal/account.dart';
import '../../internal/general.dart';
import '../../types/types.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/const.dart';
import '../../utils/helpers.dart';
import '../../utils/memoize.dart';
import '../authenticator/account.dart';
import '../authenticator/transaction.dart';
import '../instances/chain_id.dart';
import '../instances/multi_agent_transaction.dart';
import '../instances/raw_transaction.dart';
import '../instances/signed_transaction.dart';
import '../instances/simple_transaction.dart';
import '../instances/transaction_payload.dart';
import '../types.dart';
import 'remote_abi.dart';

/// Builds a transaction payload based on the provided input data and returns
/// a transaction payload: a `TransactionPayloadScript`,
/// `TransactionPayloadMultiSig`, or `TransactionPayloadEntryFunction`.
///
/// This uses the Remote ABI by default (requiring [aptosConfig]); the remote
/// ABI fetch is skipped when an ABI is provided on the input data or by
/// using [generateTransactionPayloadWithABI].
Future<AnyTransactionPayloadInstance> generateTransactionPayload(
  InputGenerateTransactionPayloadData data, [
  AptosConfig? aptosConfig,
]) async {
  if (isScriptDataInput(data)) {
    final scriptData = data as InputScriptData;
    final scriptPayload = _generateTransactionPayloadScript(scriptData);
    // If a multisig address is present, wrap the script in a multisig
    // payload.
    if (scriptData is InputMultiSigScriptData) {
      final multisigAddress = AccountAddress.from(scriptData.multisigAddress);
      return TransactionPayloadMultiSig(
        MultiSig(
          multisigAddress,
          MultiSigTransactionPayload(scriptPayload.script),
        ),
      );
    }
    return scriptPayload;
  }

  final entryData = data as InputEntryFunctionData;
  final parts = getFunctionParts(entryData.function);

  EntryFunctionABI functionAbi;
  if (entryData.abi != null) {
    functionAbi = entryData.abi!;
  } else {
    if (aptosConfig == null) {
      throw ArgumentError(
        'aptosConfig is required to fetch the remote ABI for '
        "'${entryData.function}'. Either provide it or supply the ABI on "
        'the input data.',
      );
    }
    functionAbi = await _fetchAbi<EntryFunctionABI>(
      key: 'entry-function',
      moduleAddress: parts.moduleAddress,
      moduleName: parts.moduleName,
      functionName: parts.functionName,
      aptosConfig: aptosConfig,
      abi: entryData.abi,
      fetch: fetchEntryFunctionAbi,
    );
  }

  // Fill in the ABI.
  return generateTransactionPayloadWithABI(_withEntryFunctionAbi(
    entryData,
    functionAbi,
  ));
}

/// Returns a copy of [data] with [abi] filled in, preserving the multisig
/// variant.
InputEntryFunctionData _withEntryFunctionAbi(
  InputEntryFunctionData data,
  EntryFunctionABI abi,
) {
  if (data is InputMultiSigData) {
    return InputMultiSigData(
      multisigAddress: data.multisigAddress,
      function: data.function,
      typeArguments: data.typeArguments,
      functionArguments: data.functionArguments,
      abi: abi,
    );
  }
  return InputEntryFunctionData(
    function: data.function,
    typeArguments: data.typeArguments,
    functionArguments: data.functionArguments,
    abi: abi,
  );
}

/// Generates a transaction payload using the provided ABI and function
/// details. This function is synchronous and works offline with pre-fetched
/// ABIs (no network calls).
///
/// Does NOT support plain-object struct/enum arguments. For struct/enum
/// arguments, encode them first using
/// `StructEnumArgumentParser.encodeStructArgument()` or
/// `encodeEnumArgument()`, then pass the encoded `MoveStructArgument` or
/// `MoveEnumArgument` instances in the function arguments.
///
/// Returns a `TransactionPayloadMultiSig` when [data] is an
/// [InputMultiSigData], otherwise a `TransactionPayloadEntryFunction`.
///
/// Throws if the type argument count does not match the ABI or if the number
/// of function arguments is incorrect.
AnyTransactionPayloadInstance generateTransactionPayloadWithABI(
  InputEntryFunctionData data,
) {
  final functionAbi = data.abi;
  if (functionAbi == null) {
    throw ArgumentError(
      'generateTransactionPayloadWithABI requires an ABI on the input data',
    );
  }
  final parts = getFunctionParts(data.function);

  // Ensure that all type arguments are typed properly.
  final typeArguments = standardizeTypeTags(data.typeArguments);

  // Check the type argument count against the ABI.
  if (typeArguments.length != functionAbi.typeParameters.length) {
    throw ArgumentError(
      'Type argument count mismatch, expected '
      '${functionAbi.typeParameters.length}, received '
      '${typeArguments.length}',
    );
  }

  // Check all BCS types, and convert any non-BCS types.
  final functionArguments = data.functionArguments
      ?.asMap()
      .entries
      .map((entry) => convertArgument(
            data.function,
            functionAbi,
            entry.value,
            entry.key,
            typeArguments,
          ))
      .toList();

  // Check that all arguments are accounted for.
  if ((functionArguments?.length ?? 0) != functionAbi.parameters.length) {
    throw ArgumentError(
      "Too few arguments for '${parts.moduleAddress}::${parts.moduleName}::"
      "${parts.functionName}', expected ${functionAbi.parameters.length} "
      'but got ${functionArguments?.length ?? 0}',
    );
  }

  // Generate the entry function payload.
  final entryFunctionPayload = EntryFunction.build(
    '${parts.moduleAddress}::${parts.moduleName}',
    parts.functionName,
    typeArguments,
    functionArguments ?? [],
  );

  // Send it as multi sig if it's a multisig payload.
  if (data is InputMultiSigData) {
    final multisigAddress = AccountAddress.from(data.multisigAddress);
    return TransactionPayloadMultiSig(
      MultiSig(
        multisigAddress,
        MultiSigTransactionPayload(entryFunctionPayload),
      ),
    );
  }

  // Otherwise send as an entry function.
  return TransactionPayloadEntryFunction(entryFunctionPayload);
}

/// Generates the payload for a view function call using the provided input.
/// Uses the Remote ABI when [InputViewFunctionData.abi] is not provided.
Future<EntryFunction> generateViewFunctionPayload(
  InputViewFunctionData data,
  AptosConfig aptosConfig,
) async {
  final parts = getFunctionParts(data.function);

  final functionAbi = await _fetchAbi<ViewFunctionABI>(
    key: 'view-function',
    moduleAddress: parts.moduleAddress,
    moduleName: parts.moduleName,
    functionName: parts.functionName,
    aptosConfig: aptosConfig,
    abi: data.abi,
    fetch: fetchViewFunctionAbi,
  );

  // Fill in the ABI.
  return generateViewFunctionPayloadWithABI(InputViewFunctionData(
    function: data.function,
    typeArguments: data.typeArguments,
    functionArguments: data.functionArguments,
    abi: functionAbi,
  ));
}

/// Generates a payload for a view function call using the provided ABI and
/// arguments. This function is synchronous and works offline with
/// pre-fetched ABIs (no network calls). Does NOT support plain-object
/// struct/enum arguments.
///
/// Throws if the type argument count does not match the ABI or if the
/// function arguments do not match the expected parameters defined in the
/// ABI.
EntryFunction generateViewFunctionPayloadWithABI(InputViewFunctionData data) {
  final functionAbi = data.abi;
  if (functionAbi == null) {
    throw ArgumentError(
      'generateViewFunctionPayloadWithABI requires an ABI on the input data',
    );
  }
  final parts = getFunctionParts(data.function);

  // Ensure that all type arguments are typed properly.
  final typeArguments = standardizeTypeTags(data.typeArguments);

  // Check the type argument count against the ABI.
  if (typeArguments.length != functionAbi.typeParameters.length) {
    throw ArgumentError(
      'Type argument count mismatch, expected '
      '${functionAbi.typeParameters.length}, received '
      '${typeArguments.length}',
    );
  }

  // Check all BCS types, and convert any non-BCS types.
  final functionArguments = data.functionArguments
          ?.asMap()
          .entries
          .map((entry) => convertArgument(
                data.function,
                functionAbi,
                entry.value,
                entry.key,
                typeArguments,
              ))
          .toList() ??
      [];

  // Check that all arguments are accounted for.
  if (functionArguments.length != functionAbi.parameters.length) {
    throw ArgumentError(
      "Too few arguments for '${parts.moduleAddress}::${parts.moduleName}::"
      "${parts.functionName}', expected ${functionAbi.parameters.length} "
      'but got ${functionArguments.length}',
    );
  }

  // Generate the entry function payload.
  return EntryFunction.build(
    '${parts.moduleAddress}::${parts.moduleName}',
    parts.functionName,
    typeArguments,
    functionArguments,
  );
}

/// Generates a transaction payload script based on the provided input data.
TransactionPayloadScript _generateTransactionPayloadScript(
  InputScriptData data,
) {
  return TransactionPayloadScript(
    Script(
      Hex.fromHexInput(data.bytecode).toUint8List(),
      standardizeTypeTags(data.typeArguments),
      data.functionArguments,
    ),
  );
}

/// Generates a raw transaction that can be sent to the Aptos network.
///
/// [aptosConfig] - The configuration for the Aptos network.
/// [sender] - The transaction's sender account address as a hex input.
/// [payload] - The transaction payload, which can be created using
/// `generateTransactionPayload()`.
/// [options] - Optional parameters for transaction generation.
/// [feePayerAddress] - The address of the fee payer for sponsored
/// transactions.
/// [secondarySignerAddresses] - Reserved for encrypted multi-agent
/// transaction builds (not yet ported); currently unused.
Future<RawTransaction> generateRawTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required AnyTransactionPayloadInstance payload,
  InputGenerateTransactionOptions? options,
  AccountAddressInput? feePayerAddress,
  List<AccountAddressInput>? secondarySignerAddresses,
}) async {
  if (options?.replayProtectionNonce != null &&
      options?.accountSequenceNumber != null) {
    throw ArgumentError(
      'Cannot specify both replayProtectionNonce and accountSequenceNumber '
      'in options.',
    );
  }

  Future<int> getChainId() async {
    final knownChainId = networkToChainId[aptosConfig.network];
    if (knownChainId != null) {
      return knownChainId;
    }
    final info = await getLedgerInfo(aptosConfig: aptosConfig);
    return info.chainId;
  }

  Future<int> getGasUnitPrice() async {
    if (options?.gasUnitPrice != null) {
      return options!.gasUnitPrice!;
    }
    final estimation = await getGasPriceEstimation(aptosConfig: aptosConfig);
    return estimation.gasEstimate;
  }

  Future<BigInt> getSequenceNumberForAny() async {
    Future<BigInt> getSequenceNumber() async {
      if (options?.accountSequenceNumber != null) {
        return options!.accountSequenceNumber!;
      }
      if (options?.replayProtectionNonce != null) {
        // Orderless: the chain uses sequence_number = u64::MAX and replay
        // protection via extra_config.replay_protection_nonce (see
        // RawTransaction::replay_protector in aptos-core).
        return maxU64BigInt;
      }

      final info = await getInfo(
        aptosConfig: aptosConfig,
        accountAddress: sender,
      );
      return BigInt.parse(info.sequenceNumber);
    }

    // Check if this is a sponsored transaction, to honor AIP-52
    // (https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-52.md).
    if (feePayerAddress != null &&
        AccountAddress.from(feePayerAddress).equals(AccountAddress.zero)) {
      // Handle sponsored transaction generation with the option that the
      // main signer has not been created on chain.
      try {
        // Check if the main signer has been created on chain; if not,
        // assign sequence number 0.
        return await getSequenceNumber();
      } catch (_) {
        return BigInt.zero;
      }
    }
    return getSequenceNumber();
  }

  final results = await Future.wait<Object>([
    getChainId(),
    getGasUnitPrice(),
    getSequenceNumberForAny(),
  ]);
  final chainId = results[0] as int;
  final gasEstimate = results[1] as int;
  final sequenceNumber = results[2] as BigInt;

  final userMaxGas = BigInt.from(
    options?.maxGasAmount ?? aptosConfig.getDefaultMaxGasAmount(),
  );
  final maxGasAmount = userMaxGas < BigInt.from(minMaxGasAmount)
      ? BigInt.from(minMaxGasAmount)
      : userMaxGas;
  final gasUnitPrice = BigInt.from(options?.gasUnitPrice ?? gasEstimate);
  final expireTimestamp = BigInt.from(
    options?.expireTimestamp ??
        nowInSeconds() + aptosConfig.getDefaultTxnExpirySecFromNow(),
  );
  final replayProtectionNonce = options?.replayProtectionNonce;

  // The orderless flow wraps the payload in an inner V1 payload carrying the
  // replay nonce.
  // NOTE: the encrypted payload flow (`options.encrypted`) is not yet
  // implemented; it will be added together with the encrypted payload builder.
  var txnPayload = payload;
  if (replayProtectionNonce != null) {
    txnPayload = convertPayloadToInnerPayload(payload, replayProtectionNonce);
  }

  return RawTransaction(
    AccountAddress.from(sender),
    sequenceNumber,
    txnPayload,
    maxGasAmount,
    gasUnitPrice,
    expireTimestamp,
    ChainId(chainId),
  );
}

/// Converts a standard transaction payload into an inner payload
/// (`TransactionInnerPayloadV1`), optionally carrying a replay protection
/// nonce for orderless transactions.
TransactionInnerPayload convertPayloadToInnerPayload(
  AnyTransactionPayloadInstance payload, [
  BigInt? replayProtectionNonce,
]) {
  if (payload is TransactionPayloadScript) {
    return TransactionInnerPayloadV1(
      TransactionExecutableScript(payload.script),
      TransactionExtraConfigV1(replayProtectionNonce: replayProtectionNonce),
    );
  }
  if (payload is TransactionPayloadEntryFunction) {
    return TransactionInnerPayloadV1(
      TransactionExecutableEntryFunction(payload.entryFunction),
      TransactionExtraConfigV1(replayProtectionNonce: replayProtectionNonce),
    );
  }
  if (payload is TransactionPayloadMultiSig) {
    final innerPayload = payload.multiSig.transactionPayload;
    TransactionExecutable executable;
    if (innerPayload == null) {
      executable = TransactionExecutableEmpty();
    } else if (innerPayload.transactionPayload is EntryFunction) {
      executable = TransactionExecutableEntryFunction(
        innerPayload.transactionPayload as EntryFunction,
      );
    } else if (innerPayload.transactionPayload is Script) {
      executable = TransactionExecutableScript(
        innerPayload.transactionPayload as Script,
      );
    } else {
      throw ArgumentError('Unsupported multisig transaction payload type');
    }

    return TransactionInnerPayloadV1(
      executable,
      TransactionExtraConfigV1(
        multisigAddress: payload.multiSig.multisigAddress,
        replayProtectionNonce: replayProtectionNonce,
      ),
    );
  }
  throw ArgumentError('Unsupported payload type: $payload');
}

/// Generates a transaction based on the provided arguments.
/// This function can create both simple and multi-agent transactions,
/// allowing for flexible transaction handling.
///
/// Returns a [MultiAgentTransaction] when [secondarySignerAddresses] is
/// provided (even if empty), and a [SimpleTransaction] otherwise.
///
/// When [withFeePayer] is `true` and no [feePayerAddress] is given, the fee
/// payer address is set to the `AccountAddress.zero` sentinel, to be replaced
/// at signing time.
Future<AnyRawTransaction> buildTransaction({
  required AptosConfig aptosConfig,
  required AccountAddressInput sender,
  required AnyTransactionPayloadInstance payload,
  InputGenerateTransactionOptions? options,
  List<AccountAddressInput>? secondarySignerAddresses,
  AccountAddressInput? feePayerAddress,
  bool withFeePayer = false,
}) async {
  var feePayer = feePayerAddress;
  if (withFeePayer) {
    feePayer ??= AccountAddress.zero;
  }

  // Generate the raw transaction.
  final rawTxn = await generateRawTransaction(
    aptosConfig: aptosConfig,
    sender: sender,
    payload: payload,
    options: options,
    feePayerAddress: feePayer,
    secondarySignerAddresses: secondarySignerAddresses,
  );

  // If this is a multi-agent transaction.
  if (secondarySignerAddresses != null) {
    final signers = secondarySignerAddresses
        .map((signer) => AccountAddress.from(signer))
        .toList();

    return MultiAgentTransaction(
      rawTxn,
      signers,
      feePayer != null ? AccountAddress.from(feePayer) : null,
    );
  }

  // Return the simple transaction.
  return SimpleTransaction(
    rawTxn,
    feePayer != null ? AccountAddress.from(feePayer) : null,
  );
}

/// Generates a signed transaction for simulation before submitting it to the
/// chain. This function helps in preparing a transaction that can be
/// simulated, allowing users to verify its validity and expected behavior.
Future<Uint8List> generateSignedTransactionForSimulation(
  InputSimulateTransactionData args,
) async {
  final transaction = args.transaction;
  final signerPublicKey = args.signerPublicKey;
  final secondarySignersPublicKeys = args.secondarySignersPublicKeys;
  final feePayerPublicKey = args.feePayerPublicKey;

  final accountAuthenticator =
      await getAuthenticatorForSimulation(signerPublicKey);

  // Fee payer transaction.
  if (transaction.feePayerAddress != null) {
    final transactionToSign = FeePayerRawTransaction(
      transaction.rawTransaction,
      transaction.secondarySignerAddresses ?? [],
      transaction.feePayerAddress!,
    );
    var secondaryAccountAuthenticators = <AccountAuthenticator>[];
    if (transaction.secondarySignerAddresses != null) {
      if (secondarySignersPublicKeys != null) {
        secondaryAccountAuthenticators = await Future.wait(
          secondarySignersPublicKeys.map(getAuthenticatorForSimulation),
        );
      } else {
        secondaryAccountAuthenticators = await Future.wait(
          List.generate(
            transaction.secondarySignerAddresses!.length,
            (_) => getAuthenticatorForSimulation(null),
          ),
        );
      }
    }
    final feePayerAuthenticator =
        await getAuthenticatorForSimulation(feePayerPublicKey);

    final transactionAuthenticator = TransactionAuthenticatorFeePayer(
      accountAuthenticator,
      transaction.secondarySignerAddresses ?? [],
      secondaryAccountAuthenticators,
      (
        address: transaction.feePayerAddress!,
        authenticator: feePayerAuthenticator,
      ),
    );
    return SignedTransaction(
      transactionToSign.rawTxn,
      transactionAuthenticator,
    ).bcsToBytes();
  }

  // Multi-agent transaction.
  if (transaction.secondarySignerAddresses != null) {
    final transactionToSign = MultiAgentRawTransaction(
      transaction.rawTransaction,
      transaction.secondarySignerAddresses!,
    );

    List<AccountAuthenticator> secondaryAccountAuthenticators;
    if (secondarySignersPublicKeys != null) {
      secondaryAccountAuthenticators = await Future.wait(
        secondarySignersPublicKeys.map(getAuthenticatorForSimulation),
      );
    } else {
      secondaryAccountAuthenticators = await Future.wait(
        List.generate(
          transaction.secondarySignerAddresses!.length,
          (_) => getAuthenticatorForSimulation(null),
        ),
      );
    }

    final transactionAuthenticator = TransactionAuthenticatorMultiAgent(
      accountAuthenticator,
      transaction.secondarySignerAddresses!,
      secondaryAccountAuthenticators,
    );

    return SignedTransaction(
      transactionToSign.rawTxn,
      transactionAuthenticator,
    ).bcsToBytes();
  }

  // Single signer raw transaction.
  TransactionAuthenticator transactionAuthenticator;
  if (accountAuthenticator is AccountAuthenticatorEd25519) {
    transactionAuthenticator = TransactionAuthenticatorEd25519(
      accountAuthenticator.publicKey,
      accountAuthenticator.signature,
    );
  } else if (accountAuthenticator is AccountAuthenticatorSingleKey ||
      accountAuthenticator is AccountAuthenticatorMultiKey ||
      accountAuthenticator is AccountAuthenticatorNoAccountAuthenticator) {
    transactionAuthenticator =
        TransactionAuthenticatorSingleSender(accountAuthenticator);
  } else {
    throw ArgumentError('Invalid public key');
  }
  return SignedTransaction(
    transaction.rawTransaction,
    transactionAuthenticator,
  ).bcsToBytes();
}

/// Derives an [AccountAuthenticator] to use for simulating a transaction
/// with the given public key (or a no-account authenticator when [publicKey]
/// is `null`, which skips the auth key check during simulation).
Future<AccountAuthenticator> getAuthenticatorForSimulation(
  PublicKey? publicKey,
) async {
  if (publicKey == null) {
    return AccountAuthenticatorNoAccountAuthenticator();
  }

  // Wrap the public key types below with AnyPublicKey as they are only
  // supported through single sender. Learn more about AnyPublicKey here -
  // https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-55.md
  AnyPublicKeyVariant? keylessVariant;
  if (publicKey is FederatedKeylessPublicKey) {
    keylessVariant = AnyPublicKeyVariant.federatedKeyless;
  } else if (publicKey is KeylessPublicKey) {
    keylessVariant = AnyPublicKeyVariant.keyless;
  }
  final convertToAnyPublicKey =
      keylessVariant != null || publicKey is Secp256k1PublicKey;
  // Pass the variant explicitly for keyless keys.
  final accountPublicKey = convertToAnyPublicKey
      ? AnyPublicKey(publicKey, keylessVariant)
      : publicKey;

  // No need for the signature to match in scheme. All that matters for
  // simulations is that it's not valid.
  final invalidSignature = Ed25519Signature(Uint8List(64));

  if (accountPublicKey is Ed25519PublicKey) {
    return AccountAuthenticatorEd25519(accountPublicKey, invalidSignature);
  }

  if (accountPublicKey is AnyPublicKey) {
    if (accountPublicKey.variant == AnyPublicKeyVariant.keyless ||
        accountPublicKey.variant == AnyPublicKeyVariant.federatedKeyless) {
      return AccountAuthenticatorSingleKey(
        accountPublicKey,
        AnySignature(KeylessSignature.getSimulationSignature()),
      );
    }
    return AccountAuthenticatorSingleKey(
      accountPublicKey,
      AnySignature(invalidSignature),
    );
  }

  if (accountPublicKey is MultiKey) {
    return AccountAuthenticatorMultiKey(
      accountPublicKey,
      MultiKeySignature(
        signatures: accountPublicKey.publicKeys.map<Signature>((pubKey) {
          if (pubKey.variant == AnyPublicKeyVariant.keyless ||
              pubKey.variant == AnyPublicKeyVariant.federatedKeyless) {
            return AnySignature(KeylessSignature.getSimulationSignature());
          }
          return AnySignature(invalidSignature);
        }).toList(),
        bitmap: List<int>.generate(
          accountPublicKey.publicKeys.length,
          (i) => i,
        ),
      ),
    );
  }

  throw ArgumentError('Unsupported PublicKey used for simulations');
}

/// Generates a signed transaction ready for submission to the blockchain.
/// This function prepares the transaction by authenticating the sender and
/// any additional signers based on the provided arguments.
///
/// Returns a [Uint8List] representing the BCS-serialized signed transaction.
///
/// Throws if the [InputSubmitTransactionData.feePayerAuthenticator] is not
/// provided for a fee payer transaction, or if
/// [InputSubmitTransactionData.additionalSignersAuthenticators] are not
/// provided for a multi-signer transaction.
Uint8List generateSignedTransaction(InputSubmitTransactionData args) {
  final transaction = args.transaction;
  final senderAuthenticator = args.senderAuthenticator;
  final feePayerAuthenticator = args.feePayerAuthenticator;
  final additionalSignersAuthenticators = args.additionalSignersAuthenticators;

  TransactionAuthenticator txnAuthenticator;
  if (transaction.feePayerAddress != null) {
    if (feePayerAuthenticator == null) {
      throw ArgumentError(
        'Must provide a feePayerAuthenticator argument to generate a signed '
        'fee payer transaction',
      );
    }
    txnAuthenticator = TransactionAuthenticatorFeePayer(
      senderAuthenticator,
      transaction.secondarySignerAddresses ?? [],
      additionalSignersAuthenticators ?? [],
      (
        address: transaction.feePayerAddress!,
        authenticator: feePayerAuthenticator,
      ),
    );
  } else if (transaction.secondarySignerAddresses != null) {
    if (additionalSignersAuthenticators == null) {
      throw ArgumentError(
        'Must provide a additionalSignersAuthenticators argument to '
        'generate a signed multi agent transaction',
      );
    }
    txnAuthenticator = TransactionAuthenticatorMultiAgent(
      senderAuthenticator,
      transaction.secondarySignerAddresses!,
      additionalSignersAuthenticators,
    );
  } else if (senderAuthenticator is AccountAuthenticatorEd25519) {
    txnAuthenticator = TransactionAuthenticatorEd25519(
      senderAuthenticator.publicKey,
      senderAuthenticator.signature,
    );
  } else if (senderAuthenticator is AccountAuthenticatorMultiEd25519) {
    txnAuthenticator = TransactionAuthenticatorMultiEd25519(
      senderAuthenticator.publicKey,
      senderAuthenticator.signature,
    );
  } else {
    txnAuthenticator =
        TransactionAuthenticatorSingleSender(senderAuthenticator);
  }

  return SignedTransaction(transaction.rawTransaction, txnAuthenticator)
      .bcsToBytes();
}

/// Hashes the set of values using a SHA3-256 hash algorithm.
///
/// [input] - A list of UTF-8 strings or `Uint8List` byte arrays to be
/// hashed.
Uint8List hashValues(List<Object> input) {
  final builder = BytesBuilder(copy: false);
  for (final item in input) {
    if (item is String) {
      builder.add(utf8.encode(item));
    } else if (item is Uint8List) {
      builder.add(item);
    } else {
      throw ArgumentError(
        'hashValues input must be a String or Uint8List, got '
        '${item.runtimeType}',
      );
    }
  }
  return SHA3Digest(256).process(builder.toBytes());
}

/// The domain separated prefix for hashing transactions.
final Uint8List _transactionPrefix = hashValues(['APTOS::Transaction']);

/// Generates a user transaction hash for the provided transaction payload,
/// which must already have an authenticator. This function helps ensure the
/// integrity and uniqueness of the transaction by producing a hash based on
/// the signed transaction data.
///
/// The hash is defined as the SHA3-256 of: the domain separated prefix based
/// on the `Transaction` struct, followed by the transaction enum variant
/// byte (UserTransaction is 0), followed by the BCS-encoded bytes of the
/// signed transaction.
String generateUserTransactionHash(InputSubmitTransactionData args) {
  final signedTransaction = generateSignedTransaction(args);

  return Hex(hashValues([
    _transactionPrefix,
    Uint8List.fromList([0]),
    signedTransaction,
  ])).toString();
}

/// Fetches and caches ABIs while allowing for pass-through on provided ABIs.
Future<T> _fetchAbi<T extends FunctionABI>({
  required String key,
  required String moduleAddress,
  required String moduleName,
  required String functionName,
  required AptosConfig aptosConfig,
  T? abi,
  required Future<T> Function(
    String moduleAddress,
    String moduleName,
    String functionName,
    AptosConfig aptosConfig,
  ) fetch,
}) {
  if (abi != null) {
    return Future.value(abi);
  }

  // We fetch the function ABI, and then pretend that we already had it.
  return memoizeAsync(
    () => fetch(moduleAddress, moduleName, functionName, aptosConfig),
    '$key-${aptosConfig.network.value}-$moduleAddress-$moduleName-'
    '$functionName',
    ttl: const Duration(minutes: 5),
  )();
}
