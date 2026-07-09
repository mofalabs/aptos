/// This file handles the generation of the signing message.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../../bcs/serializer.dart';
import '../../utils/const.dart';
import '../instances/raw_transaction.dart';

/// Derives the appropriate raw transaction instance based on the provided
/// transaction details. This function helps in identifying whether the
/// transaction is a [FeePayerRawTransaction], [MultiAgentRawTransaction], or
/// a standard [RawTransaction].
///
/// Returns the BCS-serializable instance to be signed.
Serializable deriveTransactionType(AnyRawTransaction transaction) {
  if (transaction.feePayerAddress != null) {
    return FeePayerRawTransaction(
      transaction.rawTransaction,
      transaction.secondarySignerAddresses ?? [],
      transaction.feePayerAddress!,
    );
  }
  if (transaction.secondarySignerAddresses != null) {
    return MultiAgentRawTransaction(
      transaction.rawTransaction,
      transaction.secondarySignerAddresses!,
    );
  }

  return transaction.rawTransaction;
}

/// Generates the 'signing message' form of a message to be signed.
/// This function combines a domain separator with the byte representation of
/// the message to create a signing message.
///
/// [domainSeparator] must start with 'APTOS::'.
Uint8List generateSigningMessage(Uint8List bytes, String domainSeparator) {
  if (!domainSeparator.startsWith('APTOS::')) {
    throw ArgumentError(
      "Domain separator needs to start with 'APTOS::'.  Provided - $domainSeparator",
    );
  }

  final prefix =
      SHA3Digest(256).process(Uint8List.fromList(utf8.encode(domainSeparator)));

  final mergedArray = Uint8List(prefix.length + bytes.length);
  mergedArray.setAll(0, prefix);
  mergedArray.setAll(prefix.length, bytes);

  return mergedArray;
}

/// Generates the 'signing message' form of a serializable value by
/// serializing it and using the runtime type name as the domain separator.
Uint8List generateSigningMessageForSerializable(Serializable serializable) {
  return generateSigningMessage(
    serializable.bcsToBytes(),
    'APTOS::${serializable.runtimeType}',
  );
}

/// Generates the 'signing message' form of a transaction by deriving the type
/// of transaction and applying the appropriate domain separator based on the
/// presence of a fee payer or secondary signers.
Uint8List generateSigningMessageForTransaction(AnyRawTransaction transaction) {
  final rawTxn = deriveTransactionType(transaction);
  if (transaction.feePayerAddress != null ||
      transaction.secondarySignerAddresses != null) {
    return generateSigningMessage(
        rawTxn.bcsToBytes(), rawTransactionWithDataSalt);
  }
  return generateSigningMessage(rawTxn.bcsToBytes(), rawTransactionSalt);
}
