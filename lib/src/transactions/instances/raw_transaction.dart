import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../types/types.dart';
import 'chain_id.dart';
import 'transaction_payload.dart';

/// Represents a raw transaction that can be serialized and deserialized.
/// Raw transactions contain the metadata and payloads that can be submitted
/// to the Aptos chain for execution. They must be signed before the Aptos
/// chain can execute them.
class RawTransaction extends Serializable {
  /// The sender Account Address.
  final AccountAddress sender;

  /// Sequence number of this transaction. This must match the sequence number
  /// stored in the sender's account at the time the transaction executes.
  final BigInt sequenceNumber;

  /// Instructions for the Aptos Blockchain, including publishing a module,
  /// execute an entry function or execute a script payload.
  final TransactionPayload payload;

  /// Maximum total gas to spend for this transaction. The account must have
  /// more than this gas or the transaction will be discarded during
  /// validation.
  final BigInt maxGasAmount;

  /// Price to be paid per gas unit.
  final BigInt gasUnitPrice;

  /// The blockchain timestamp at which the blockchain would discard this
  /// transaction.
  final BigInt expirationTimestampSecs;

  /// The chain ID of the blockchain that this transaction is intended to be
  /// run on.
  final ChainId chainId;

  /// RawTransactions contain the metadata and payloads that can be submitted
  /// to the Aptos chain for execution. RawTransactions must be signed before
  /// the Aptos chain can execute them.
  RawTransaction(
    this.sender,
    this.sequenceNumber,
    this.payload,
    this.maxGasAmount,
    this.gasUnitPrice,
    this.expirationTimestampSecs,
    this.chainId,
  );

  /// Serializes the raw transaction fields in the canonical BCS order.
  @override
  void serialize(Serializer serializer) {
    sender.serialize(serializer);
    serializer.serializeU64(sequenceNumber);
    payload.serialize(serializer);
    serializer.serializeU64(maxGasAmount);
    serializer.serializeU64(gasUnitPrice);
    serializer.serializeU64(expirationTimestampSecs);
    chainId.serialize(serializer);
  }

  /// Deserializes a Raw Transaction from the provided deserializer.
  static RawTransaction deserialize(Deserializer deserializer) {
    final sender = AccountAddress.deserialize(deserializer);
    final sequenceNumber = deserializer.deserializeU64();
    final payload = TransactionPayload.deserialize(deserializer);
    final maxGasAmount = deserializer.deserializeU64();
    final gasUnitPrice = deserializer.deserializeU64();
    final expirationTimestampSecs = deserializer.deserializeU64();
    final chainId = ChainId.deserialize(deserializer);
    return RawTransaction(
      sender,
      sequenceNumber,
      payload,
      maxGasAmount,
      gasUnitPrice,
      expirationTimestampSecs,
      chainId,
    );
  }
}

/// Represents a raw transaction with associated data that can be serialized
/// and deserialized.
abstract class RawTransactionWithData extends Serializable {
  /// Serialize a Raw Transaction With Data.
  @override
  void serialize(Serializer serializer);

  /// Deserialize a Raw Transaction With Data.
  static RawTransactionWithData deserialize(Deserializer deserializer) {
    // index enum variant
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionVariants.multiAgentTransaction.value) {
      return MultiAgentRawTransaction.load(deserializer);
    } else if (index == TransactionVariants.feePayerTransaction.value) {
      return FeePayerRawTransaction.load(deserializer);
    }
    throw StateError('Unknown variant index for RawTransactionWithData: $index');
  }
}

/// Represents a multi-agent transaction that can be serialized and
/// deserialized.
class MultiAgentRawTransaction extends RawTransactionWithData {
  /// The raw transaction.
  final RawTransaction rawTxn;

  /// The secondary signers on this transaction.
  final List<AccountAddress> secondarySignerAddresses;

  MultiAgentRawTransaction(this.rawTxn, this.secondarySignerAddresses);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionVariants.multiAgentTransaction.value,
    );
    rawTxn.serialize(serializer);
    serializer.serializeVector(secondarySignerAddresses);
  }

  /// Deserializes a Multi Agent Raw Transaction from the provided
  /// deserializer. (The variant index must already have been read.)
  static MultiAgentRawTransaction load(Deserializer deserializer) {
    final rawTxn = RawTransaction.deserialize(deserializer);
    final secondarySignerAddresses =
        deserializer.deserializeVector(AccountAddress.deserialize);

    return MultiAgentRawTransaction(rawTxn, secondarySignerAddresses);
  }
}

/// Represents a Fee Payer Transaction that can be serialized and
/// deserialized.
class FeePayerRawTransaction extends RawTransactionWithData {
  /// The raw transaction.
  final RawTransaction rawTxn;

  /// The secondary signers on this transaction - optional and can be empty.
  final List<AccountAddress> secondarySignerAddresses;

  /// The fee payer account address.
  final AccountAddress feePayerAddress;

  FeePayerRawTransaction(
    this.rawTxn,
    this.secondarySignerAddresses,
    this.feePayerAddress,
  );

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionVariants.feePayerTransaction.value,
    );
    rawTxn.serialize(serializer);
    serializer.serializeVector(secondarySignerAddresses);
    feePayerAddress.serialize(serializer);
  }

  static FeePayerRawTransaction load(Deserializer deserializer) {
    final rawTxn = RawTransaction.deserialize(deserializer);
    final secondarySignerAddresses =
        deserializer.deserializeVector(AccountAddress.deserialize);
    final feePayerAddress = AccountAddress.deserialize(deserializer);

    return FeePayerRawTransaction(
      rawTxn,
      secondarySignerAddresses,
      feePayerAddress,
    );
  }
}

/// A unified type for the return types generated when building different
/// transaction types: a `SimpleTransaction` or a `MultiAgentTransaction`.
abstract class AnyRawTransaction {
  /// The raw transaction to be signed and submitted.
  RawTransaction get rawTransaction;

  /// The optional sponsor Account Address to pay the gas fees. Settable
  /// because it is mutated at signing time.
  AccountAddress? get feePayerAddress;
  set feePayerAddress(AccountAddress? value);

  /// The secondary signer addresses, or `null` for a `SimpleTransaction`.
  /// The union is discriminated by whether this is `null`.
  List<AccountAddress>? get secondarySignerAddresses;
}
