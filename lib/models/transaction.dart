
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';

class Transaction {
  Transaction(
    this.sender, 
    this.sequenceNumber, 
    this.maxGasAmount, 
    this.gasUnitPrice, 
    this.expirationTimestampSecs,
    this.payload,
    this.signature);

  final String sender;
  final String sequenceNumber;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final Payload payload;
  final Signature signature;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sender": sender,
      "sequence_number": sequenceNumber,
      "max_gas_amount": maxGasAmount,
      "gas_unit_price": gasUnitPrice,
      "expiration_timestamp_secs": expirationTimestampSecs,
      "payload": payload.toJson(),
      "signature": signature.toJson()
    };
  }
}

class TransactionEncodeSubmission {
  TransactionEncodeSubmission(
    this.sender, 
    this.sequenceNumber, 
    this.maxGasAmount, 
    this.gasUnitPrice, 
    this.expirationTimestampSecs,
    this.payload,
    this.secondarySigners);

  final String sender;
  final String sequenceNumber;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final Payload payload;
  final List<String> secondarySigners;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sender": sender,
      "sequence_number": sequenceNumber,
      "max_gas_amount": maxGasAmount,
      "gas_unit_price": gasUnitPrice,
      "expiration_timestamp_secs": expirationTimestampSecs,
      "payload": payload.toJson(),
      "secondary_signers": secondarySigners
    };
  }
}