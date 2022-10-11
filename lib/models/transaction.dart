import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';

class TransactionRequest {

  final String sender;
  final String sequenceNumber;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final Payload payload;
  final Signature signature;

  TransactionRequest({
    required this.sender,
    required this.sequenceNumber,
    required this.maxGasAmount,
    required this.gasUnitPrice, 
    required this.expirationTimestampSecs,
    required this.payload,
    required this.signature});

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

class TransactionEncodeSubmissionRequest {
  TransactionEncodeSubmissionRequest({
    required this.sender, 
    required this.payload,
    required this.sequenceNumber, 
    required this.maxGasAmount, 
    required this.gasUnitPrice, 
    required this.expirationTimestampSecs,
    this.secondarySigners});

  final String sender;
  final String sequenceNumber;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final Payload payload;
  final List<String>? secondarySigners;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      "sender": sender,
      "sequence_number": sequenceNumber,
      "max_gas_amount": maxGasAmount,
      "gas_unit_price": gasUnitPrice,
      "expiration_timestamp_secs": expirationTimestampSecs,
      "payload": payload.toJson()
    };
    if (secondarySigners != null) {
      data["secondary_signers"] = secondarySigners;
    }
    return data;
  }
}