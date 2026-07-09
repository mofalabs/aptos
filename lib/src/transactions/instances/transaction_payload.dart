import 'dart:typed_data';

import '../../bcs/deserializer.dart';
import '../../bcs/serializable/entry_function_bytes.dart';
import '../../bcs/serializable/move_primitives.dart';
import '../../bcs/serializable/move_structs.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../types/types.dart';
import '../type_tag/type_tag.dart';
import 'encrypted_payload.dart';
import 'identifier.dart';
import 'module_id.dart';
import 'transaction_argument.dart';

/// Deserializes a Script Transaction Argument.
///
/// This function retrieves and deserializes various types of script
/// transaction arguments based on the provided deserializer.
///
/// Throws a [StateError] if the variant index is unknown.
TransactionArgument deserializeFromScriptArgument(Deserializer deserializer) {
  // index enum variant
  final index = deserializer.deserializeUleb128AsU32();
  if (index == ScriptTransactionArgumentVariants.u8.value) {
    return U8.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u64.value) {
    return U64.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u128.value) {
    return U128.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.address.value) {
    return AccountAddress.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u8Vector.value) {
    return MoveVector.deserialize(deserializer, U8.deserialize);
  } else if (index == ScriptTransactionArgumentVariants.boolean.value) {
    return Bool.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u16.value) {
    return U16.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u32.value) {
    return U32.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.u256.value) {
    return U256.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.serialized.value) {
    return Serialized.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i8.value) {
    return I8.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i16.value) {
    return I16.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i32.value) {
    return I32.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i64.value) {
    return I64.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i128.value) {
    return I128.deserialize(deserializer);
  } else if (index == ScriptTransactionArgumentVariants.i256.value) {
    return I256.deserialize(deserializer);
  }
  throw StateError(
      'Unknown variant index for ScriptTransactionArgument: $index');
}

/// Represents a supported Transaction Payload that can be serialized and
/// deserialized.
///
/// This class serves as a base for different types of transaction payloads,
/// allowing for their serialization into a format suitable for transmission
/// and deserialization back into their original form.
abstract class TransactionPayload extends Serializable {
  /// Serialize a Transaction Payload.
  @override
  void serialize(Serializer serializer);

  /// Deserialize a Transaction Payload.
  static TransactionPayload deserialize(Deserializer deserializer) {
    // index enum variant
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionPayloadVariants.script.value) {
      return TransactionPayloadScript.load(deserializer);
    } else if (index == TransactionPayloadVariants.entryFunction.value) {
      return TransactionPayloadEntryFunction.load(deserializer);
    } else if (index == TransactionPayloadVariants.multisig.value) {
      return TransactionPayloadMultiSig.load(deserializer);
    } else if (index == TransactionPayloadVariants.payload.value) {
      return TransactionInnerPayload.deserialize(deserializer);
    } else if (index == TransactionPayloadVariants.encryptedPayload.value) {
      return TransactionPayloadEncryptedPayload.load(deserializer);
    }
    throw StateError('Unknown variant index for TransactionPayload: $index');
  }
}

/// Represents a transaction payload script that can be serialized and
/// deserialized.
///
/// This class encapsulates a script that defines the logic for a transaction
/// payload.
class TransactionPayloadScript extends TransactionPayload {
  final Script script;

  TransactionPayloadScript(this.script);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TransactionPayloadVariants.script.value);
    script.serialize(serializer);
  }

  /// Loads a TransactionPayloadScript from the provided deserializer.
  /// (The variant index must already have been read.)
  static TransactionPayloadScript load(Deserializer deserializer) {
    final script = Script.deserialize(deserializer);
    return TransactionPayloadScript(script);
  }
}

/// Represents a transaction payload entry function that can be serialized and
/// deserialized.
class TransactionPayloadEntryFunction extends TransactionPayload {
  final EntryFunction entryFunction;

  TransactionPayloadEntryFunction(this.entryFunction);

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(TransactionPayloadVariants.entryFunction.value);
    entryFunction.serialize(serializer);
  }

  static TransactionPayloadEntryFunction load(Deserializer deserializer) {
    final entryFunction = EntryFunction.deserialize(deserializer);
    return TransactionPayloadEntryFunction(entryFunction);
  }
}

/// Represents a multi-signature transaction payload that can be serialized
/// and deserialized.
class TransactionPayloadMultiSig extends TransactionPayload {
  final MultiSig multiSig;

  TransactionPayloadMultiSig(this.multiSig);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TransactionPayloadVariants.multisig.value);
    multiSig.serialize(serializer);
  }

  static TransactionPayloadMultiSig load(Deserializer deserializer) {
    final value = MultiSig.deserialize(deserializer);
    return TransactionPayloadMultiSig(value);
  }
}

/// Represents an entry function that can be serialized and deserialized.
/// This class encapsulates the details required to invoke a function within a
/// module, including the module name, function name, type arguments, and
/// function arguments.
class EntryFunction extends Serializable {
  /// Fully qualified module name in the format
  /// "account_address::module_name", e.g. "0x1::coin".
  final ModuleId moduleName;

  /// The function name, e.g. "transfer".
  final Identifier functionName;

  /// Type arguments that the Move function requires.
  ///
  /// A coin transfer function has one type argument "CoinType":
  /// ```
  /// public entry fun transfer<CoinType>(from: &signer, to: address, amount: u64)
  /// ```
  final List<TypeTag> typeArgs;

  /// Arguments to the Move function.
  ///
  /// A coin transfer function has three arguments "from", "to" and "amount".
  final List<EntryFunctionArgument> args;

  /// Contains the payload to run a function within a module.
  EntryFunction(this.moduleName, this.functionName, this.typeArgs, this.args);

  /// Builds an EntryFunction payload from raw primitive values.
  ///
  /// [moduleId] - Fully qualified module name in the format
  /// "AccountAddress::module_id", e.g. "0x1::coin".
  /// [functionName] - The name of the function to be called.
  /// [typeArgs] - Type arguments that the Move function requires.
  /// [args] - Arguments to the Move function.
  static EntryFunction build(
    String moduleId,
    String functionName,
    List<TypeTag> typeArgs,
    List<EntryFunctionArgument> args,
  ) {
    return EntryFunction(
      ModuleId.fromStr(moduleId),
      Identifier(functionName),
      typeArgs,
      args,
    );
  }

  @override
  void serialize(Serializer serializer) {
    moduleName.serialize(serializer);
    functionName.serialize(serializer);
    serializer.serializeVector(typeArgs);
    serializer.serializeU32AsUleb128(args.length);
    for (final item in args) {
      item.serializeForEntryFunction(serializer);
    }
  }

  /// Deserializes an entry function payload with the arguments represented as
  /// [EntryFunctionBytes] instances.
  ///
  /// NOTE: When you deserialize an EntryFunction payload with this method,
  /// the entry function arguments are populated into the deserialized
  /// instance as type-agnostic, raw fixed bytes in the form of the
  /// [EntryFunctionBytes] class.
  ///
  /// In order to correctly deserialize these arguments as their actual type
  /// representations, you must know the types of the arguments beforehand and
  /// deserialize them yourself individually. One way you could achieve this
  /// is by using the ABIs for an entry function and deserializing each
  /// argument as its given, corresponding type.
  static EntryFunction deserialize(Deserializer deserializer) {
    final moduleName = ModuleId.deserialize(deserializer);
    final functionName = Identifier.deserialize(deserializer);
    final typeArgs = deserializer.deserializeVector(TypeTag.deserialize);

    final length = deserializer.deserializeUleb128AsU32();
    final args = <EntryFunctionArgument>[];

    for (var i = 0; i < length; i += 1) {
      final fixedBytesLength = deserializer.deserializeUleb128AsU32();
      final fixedBytes =
          EntryFunctionBytes.deserialize(deserializer, fixedBytesLength);
      args.add(fixedBytes);
    }

    return EntryFunction(moduleName, functionName, typeArgs, args);
  }
}

/// Discriminants of Rust `EncryptedPayload`. Only `Encrypted` is produced or
/// accepted client-side; `FailedDecryption` (1) and `Decrypted` (2) are
/// listed for wire-format reference.
const int _encryptedPayloadVariantEncrypted = 0;

/// `EncryptedPayload::Encrypted` as a `TransactionPayload`. BCS:
/// variant tag (5) | inner tag (0) | Ciphertext | TransactionExtraConfig |
/// 32-byte payload_hash | u64 epoch | Option&lt;ClaimedEntryFunction&gt;.
class TransactionPayloadEncryptedPayload extends TransactionPayload {
  final Ciphertext ciphertext;

  final TransactionExtraConfig extraConfig;

  final Uint8List payloadHash;

  /// Epoch hint matching the node's per-epoch encryption key (see aptos-core
  /// `EncryptedInner`).
  final BigInt encryptionEpoch;

  final ClaimedEntryFunction? claimedEntryFunction;

  TransactionPayloadEncryptedPayload(
    this.ciphertext,
    this.extraConfig,
    this.payloadHash,
    this.encryptionEpoch, [
    this.claimedEntryFunction,
  ]) {
    if (payloadHash.length != 32) {
      throw ArgumentError('payloadHash must be 32 bytes');
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionPayloadVariants.encryptedPayload.value,
    );
    serializer.serializeU32AsUleb128(_encryptedPayloadVariantEncrypted);
    ciphertext.serialize(serializer);
    extraConfig.serialize(serializer);
    serializer.serializeFixedBytes(payloadHash);
    serializer.serializeU64(encryptionEpoch);
    serializer.serializeOption(claimedEntryFunction);
  }

  static TransactionPayloadEncryptedPayload load(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant != _encryptedPayloadVariantEncrypted) {
      throw StateError(
        'Only EncryptedPayload::Encrypted (variant 0) is supported on the client, got $variant',
      );
    }
    final ciphertext = Ciphertext.deserialize(deserializer);
    final extraConfig = TransactionExtraConfig.deserialize(deserializer);
    final payloadHash = deserializer.deserializeFixedBytes(32);
    final encryptionEpoch = deserializer.deserializeU64();
    final claimedEntryFunction =
        deserializer.deserializeOption(ClaimedEntryFunction.deserialize);
    return TransactionPayloadEncryptedPayload(
      ciphertext,
      extraConfig,
      payloadHash,
      encryptionEpoch,
      claimedEntryFunction,
    );
  }
}

/// Represents a Script that can be serialized and deserialized.
/// Scripts contain the Move bytecode payload that can be submitted to the
/// Aptos chain for execution.
class Script extends Serializable {
  /// The move module bytecode.
  final Uint8List bytecode;

  /// The type arguments that the bytecode function requires.
  final List<TypeTag> typeArgs;

  /// The arguments that the bytecode function requires.
  final List<ScriptFunctionArgument> args;

  Script(this.bytecode, this.typeArgs, this.args);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(bytecode);
    serializer.serializeVector(typeArgs);
    serializer.serializeU32AsUleb128(args.length);
    for (final item in args) {
      item.serializeForScriptFunction(serializer);
    }
  }

  static Script deserialize(Deserializer deserializer) {
    final bytecode = deserializer.deserializeBytes();
    final typeArgs = deserializer.deserializeVector(TypeTag.deserialize);
    final length = deserializer.deserializeUleb128AsU32();
    final args = <ScriptFunctionArgument>[];
    for (var i = 0; i < length; i += 1) {
      // Note that we deserialize directly to the Move value, not its Script
      // argument representation. We are abstracting away the Script argument
      // representation because knowing about it is functionally useless.
      final scriptArgument = deserializeFromScriptArgument(deserializer);
      args.add(scriptArgument);
    }
    return Script(bytecode, typeArgs, args);
  }
}

/// Represents a MultiSig account that can be serialized and deserialized.
///
/// This class encapsulates the functionality to manage multi-signature
/// transactions, including the address of the multi-sig account and the
/// associated transaction payload.
class MultiSig extends Serializable {
  /// The multi-sig account address the transaction will be executed as.
  final AccountAddress multisigAddress;

  /// The payload of the multi-sig transaction. This is optional when
  /// executing a multi-sig transaction whose payload is already stored on
  /// chain.
  final MultiSigTransactionPayload? transactionPayload;

  MultiSig(this.multisigAddress, [this.transactionPayload]);

  @override
  void serialize(Serializer serializer) {
    multisigAddress.serialize(serializer);
    // Options are encoded with an extra u8 field before the value - 0x0 is
    // none and 0x1 is present. We use serializeBool below to create this
    // prefix value.
    if (transactionPayload == null) {
      serializer.serializeBool(false);
    } else {
      serializer.serializeBool(true);
      transactionPayload!.serialize(serializer);
    }
  }

  static MultiSig deserialize(Deserializer deserializer) {
    final multisigAddress = AccountAddress.deserialize(deserializer);
    final payloadPresent = deserializer.deserializeBool();
    MultiSigTransactionPayload? transactionPayload;
    if (payloadPresent) {
      transactionPayload = MultiSigTransactionPayload.deserialize(deserializer);
    }
    return MultiSig(multisigAddress, transactionPayload);
  }
}

/// Represents a multi-signature transaction payload that can be serialized
/// and deserialized.
///
/// This class is designed to encapsulate the transaction payload for
/// multi-sig account transactions as defined in the `multisig_account.move`
/// module. Future enhancements may allow support for script payloads as the
/// `multisig_account.move` module evolves.
class MultiSigTransactionPayload extends Serializable {
  /// The payload of the multi-sig transaction. This can be an [EntryFunction]
  /// or a [Script].
  final Serializable transactionPayload;

  /// Contains the payload to run a multi-sig account transaction.
  ///
  /// [transactionPayload] must be an [EntryFunction] or a [Script].
  MultiSigTransactionPayload(this.transactionPayload) {
    if (transactionPayload is! EntryFunction && transactionPayload is! Script) {
      throw ArgumentError('Unsupported multisig transaction payload type');
    }
  }

  @override
  void serialize(Serializer serializer) {
    if (transactionPayload is EntryFunction) {
      serializer.serializeU32AsUleb128(
        MultiSigTransactionPayloadVariants.entryFunction.value,
      );
    } else if (transactionPayload is Script) {
      serializer.serializeU32AsUleb128(
        MultiSigTransactionPayloadVariants.script.value,
      );
    } else {
      throw StateError('Unsupported multisig transaction payload type');
    }
    transactionPayload.serialize(serializer);
  }

  static MultiSigTransactionPayload deserialize(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant == MultiSigTransactionPayloadVariants.entryFunction.value) {
      return MultiSigTransactionPayload(
          EntryFunction.deserialize(deserializer));
    } else if (variant == MultiSigTransactionPayloadVariants.script.value) {
      return MultiSigTransactionPayload(Script.deserialize(deserializer));
    }
    throw StateError('Unknown MultisigTransactionPayload variant: $variant');
  }
}

/// Represents any transaction payload that can be submitted to the Aptos
/// chain for execution.
///
/// This is specifically required for orderless transactions, but can be used
/// for any transaction payload.
abstract class TransactionInnerPayload extends TransactionPayload {
  static TransactionInnerPayload deserialize(Deserializer deserializer) {
    // index enum variant
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionInnerPayloadVariants.v1.value) {
      return TransactionInnerPayloadV1.load(deserializer);
    }
    throw StateError(
        'Unknown variant index for TransactionInnerPayload: $index');
  }
}

/// The V1 variant of the transaction inner payload, holding an executable and
/// extra configuration.
class TransactionInnerPayloadV1 extends TransactionInnerPayload {
  final TransactionExecutable executable;
  final TransactionExtraConfig extraConfig;

  TransactionInnerPayloadV1(this.executable, this.extraConfig);

  @override
  void serialize(Serializer serializer) {
    // This payload must be serialized as a top level TransactionPayload, so
    // we add that here.
    serializer.serializeU32AsUleb128(TransactionPayloadVariants.payload.value);
    // V1 is serialized as 0
    serializer.serializeU32AsUleb128(TransactionInnerPayloadVariants.v1.value);
    executable.serialize(serializer);
    extraConfig.serialize(serializer);
  }

  static TransactionInnerPayloadV1 load(Deserializer deserializer) {
    final executable = TransactionExecutable.deserialize(deserializer);
    final extraConfig = TransactionExtraConfig.deserialize(deserializer);
    return TransactionInnerPayloadV1(executable, extraConfig);
  }
}

/// Represents an executable inside an orderless transaction payload.
abstract class TransactionExecutable extends Serializable {
  static TransactionExecutable deserialize(Deserializer deserializer) {
    // index enum variant
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionExecutableVariants.script.value) {
      return TransactionExecutableScript.load(deserializer);
    } else if (index == TransactionExecutableVariants.entryFunction.value) {
      return TransactionExecutableEntryFunction.load(deserializer);
    } else if (index == TransactionExecutableVariants.empty.value) {
      return TransactionExecutableEmpty.load(deserializer);
    } else if (index == TransactionExecutableVariants.encrypted.value) {
      return TransactionExecutableEncrypted.load(deserializer);
    }
    throw StateError('Unknown variant index for TransactionExecutable: $index');
  }
}

/// A script executable for an orderless transaction payload.
class TransactionExecutableScript extends TransactionExecutable {
  final Script script;

  TransactionExecutableScript(this.script);

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(TransactionExecutableVariants.script.value);
    script.serialize(serializer);
  }

  static TransactionExecutableScript load(Deserializer deserializer) {
    final script = Script.deserialize(deserializer);
    return TransactionExecutableScript(script);
  }
}

/// An entry function executable for an orderless transaction payload.
class TransactionExecutableEntryFunction extends TransactionExecutable {
  final EntryFunction entryFunction;

  TransactionExecutableEntryFunction(this.entryFunction);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionExecutableVariants.entryFunction.value,
    );
    entryFunction.serialize(serializer);
  }

  static TransactionExecutableEntryFunction load(Deserializer deserializer) {
    final entryFunction = EntryFunction.deserialize(deserializer);
    return TransactionExecutableEntryFunction(entryFunction);
  }
}

/// An empty executable for an orderless transaction payload.
class TransactionExecutableEmpty extends TransactionExecutable {
  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TransactionExecutableVariants.empty.value);
  }

  static TransactionExecutableEmpty load(Deserializer deserializer) {
    return TransactionExecutableEmpty();
  }
}

/// Server-side sentinel variant the fullnode places in a decrypted
/// transaction. The SDK never constructs this; it exists only for
/// deserialization completeness.
class TransactionExecutableEncrypted extends TransactionExecutable {
  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(TransactionExecutableVariants.encrypted.value);
  }

  static TransactionExecutableEncrypted load(Deserializer deserializer) {
    return TransactionExecutableEncrypted();
  }
}

/// Represents the extra configuration of an orderless transaction payload.
abstract class TransactionExtraConfig extends Serializable {
  static TransactionExtraConfig deserialize(Deserializer deserializer) {
    // index enum variant
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionExtraConfigVariants.v1.value) {
      return TransactionExtraConfigV1.load(deserializer);
    }
    throw StateError(
        'Unknown variant index for TransactionExtraConfig: $index');
  }
}

/// The V1 variant of the transaction extra configuration, holding an optional
/// multisig address and an optional replay protection nonce.
class TransactionExtraConfigV1 extends TransactionExtraConfig {
  final AccountAddress? multisigAddress;
  final BigInt? replayProtectionNonce;

  TransactionExtraConfigV1({this.multisigAddress, this.replayProtectionNonce});

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(TransactionExtraConfigVariants.v1.value);
    serializer.serializeOption(multisigAddress);
    serializer.serializeOption(
      replayProtectionNonce != null ? U64(replayProtectionNonce!) : null,
    );
  }

  static TransactionExtraConfigV1 load(Deserializer deserializer) {
    final multisigAddress =
        deserializer.deserializeOption(AccountAddress.deserialize);
    final replayProtectionNonce =
        deserializer.deserializeOption(U64.deserialize);
    return TransactionExtraConfigV1(
      multisigAddress: multisigAddress,
      replayProtectionNonce: replayProtectionNonce?.value,
    );
  }
}
