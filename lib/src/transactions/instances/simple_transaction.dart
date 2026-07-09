import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import 'raw_transaction.dart';

/// Represents a simple transaction type that can be submitted to the Aptos
/// chain for execution.
///
/// This transaction type is designed for a single signer and includes
/// metadata such as the Raw Transaction and an optional sponsor Account
/// Address to cover gas fees.
class SimpleTransaction extends Serializable implements AnyRawTransaction {
  @override
  RawTransaction rawTransaction;

  /// The optional sponsor Account Address to pay the gas fees. Mutable
  /// because the SDK sets it at signing time.
  @override
  AccountAddress? feePayerAddress;

  /// Always `null` for a SimpleTransaction. It exists to satisfy the
  /// [AnyRawTransaction] interface used for type checking throughout the SDK.
  @override
  List<AccountAddress>? get secondarySignerAddresses => null;

  /// SimpleTransaction represents a transaction signed by a single account
  /// that can be submitted to the Aptos chain for execution.
  ///
  /// [rawTransaction] - The Raw Transaction.
  /// [feePayerAddress] - The optional sponsor Account Address to pay the gas
  /// fees.
  SimpleTransaction(this.rawTransaction, [this.feePayerAddress]);

  /// Serializes the transaction data using the provided serializer.
  /// This function ensures that the raw transaction and fee payer address are
  /// properly serialized for further processing.
  @override
  void serialize(Serializer serializer) {
    rawTransaction.serialize(serializer);

    if (feePayerAddress == null) {
      serializer.serializeBool(false);
    } else {
      serializer.serializeBool(true);
      feePayerAddress!.serialize(serializer);
    }
  }

  /// Deserializes a SimpleTransaction from the given deserializer.
  /// This function helps in reconstructing a SimpleTransaction object from
  /// its serialized form.
  static SimpleTransaction deserialize(Deserializer deserializer) {
    final rawTransaction = RawTransaction.deserialize(deserializer);
    final feePayerPresent = deserializer.deserializeBool();
    AccountAddress? feePayerAddress;
    if (feePayerPresent) {
      feePayerAddress = AccountAddress.deserialize(deserializer);
    }

    return SimpleTransaction(rawTransaction, feePayerAddress);
  }
}
