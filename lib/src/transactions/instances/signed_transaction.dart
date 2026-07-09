import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../authenticator/transaction.dart';
import 'raw_transaction.dart';

/// Represents a signed transaction that includes a raw transaction and an
/// authenticator.
///
/// The authenticator contains a client's public key and the signature of the
/// raw transaction, which can be of three types: single signature,
/// multi-signature, and multi-agent.
///
/// See https://github.com/aptos-labs/aptos-core/blob/main/types/src/transaction/authenticator.rs
/// for details.
class SignedTransaction extends Serializable {
  /// The raw transaction that was signed.
  final RawTransaction rawTxn;

  /// Contains a client's public key and the signature of the raw
  /// transaction.
  final TransactionAuthenticator authenticator;

  SignedTransaction(this.rawTxn, this.authenticator);

  /// Serializes the raw transaction and its authenticator using the provided
  /// serializer.
  ///
  /// This function is essential for preparing the transaction data for
  /// transmission or storage.
  @override
  void serialize(Serializer serializer) {
    rawTxn.serialize(serializer);
    authenticator.serialize(serializer);
  }

  /// Deserializes a signed transaction from the provided deserializer.
  ///
  /// This function allows you to reconstruct a SignedTransaction object from
  /// its serialized form, enabling further processing or validation.
  static SignedTransaction deserialize(Deserializer deserializer) {
    final rawTxn = RawTransaction.deserialize(deserializer);
    final authenticator = TransactionAuthenticator.deserialize(deserializer);
    return SignedTransaction(rawTxn, authenticator);
  }
}
