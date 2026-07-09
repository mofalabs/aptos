import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import 'raw_transaction.dart';

/// Represents a multi-agent transaction that can be serialized and
/// deserialized.
///
/// This transaction includes a raw transaction, multiple secondary signer
/// addresses, and an optional fee payer address.
class MultiAgentTransaction extends Serializable implements AnyRawTransaction {
  @override
  RawTransaction rawTransaction;

  /// The optional sponsor Account Address to pay the gas fees. Mutable
  /// because the SDK sets it at signing time.
  @override
  AccountAddress? feePayerAddress;

  @override
  List<AccountAddress> secondarySignerAddresses;

  /// Represents a MultiAgentTransaction that can be submitted to the Aptos
  /// chain for execution.
  ///
  /// [rawTransaction] - The raw transaction data.
  /// [secondarySignerAddresses] - An array of secondary signer addresses.
  /// [feePayerAddress] - An optional account address that sponsors the gas
  /// fees.
  MultiAgentTransaction(
    this.rawTransaction,
    this.secondarySignerAddresses, [
    this.feePayerAddress,
  ]);

  /// Serializes the transaction data, including the raw transaction,
  /// secondary signer addresses, and fee payer address.
  @override
  void serialize(Serializer serializer) {
    rawTransaction.serialize(serializer);

    serializer.serializeVector(secondarySignerAddresses);

    if (feePayerAddress == null) {
      serializer.serializeBool(false);
    } else {
      serializer.serializeBool(true);
      feePayerAddress!.serialize(serializer);
    }
  }

  /// Deserializes a MultiAgentTransaction from the provided deserializer.
  /// This function allows you to reconstruct a MultiAgentTransaction object
  /// from its serialized form, including any secondary signer addresses and
  /// the fee payer address if present.
  static MultiAgentTransaction deserialize(Deserializer deserializer) {
    final rawTransaction = RawTransaction.deserialize(deserializer);

    final secondarySignerAddresses =
        deserializer.deserializeVector(AccountAddress.deserialize);

    final feePayerPresent = deserializer.deserializeBool();
    AccountAddress? feePayerAddress;
    if (feePayerPresent) {
      feePayerAddress = AccountAddress.deserialize(deserializer);
    }

    return MultiAgentTransaction(
      rawTransaction,
      secondarySignerAddresses,
      feePayerAddress,
    );
  }
}
