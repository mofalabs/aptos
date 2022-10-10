
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';

class TransactionRequest {
  TransactionRequest({
    required this.sender, 
    this.sequenceNumber, 
    this.maxGasAmount, 
    this.gasUnitPrice, 
    this.expirationTimestampSecs,
    required this.payload,
    required this.signature});

  final String sender;
  final String? sequenceNumber;
  final String? maxGasAmount;
  final String? gasUnitPrice;
  final String? expirationTimestampSecs;
  final Payload payload;
  Signature signature;

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
    this.sequenceNumber, 
    this.maxGasAmount, 
    this.gasUnitPrice, 
    this.expirationTimestampSecs,
    this.secondarySigners});

  final String sender;
  final String? sequenceNumber;
  final String? maxGasAmount;
  final String? gasUnitPrice;
  final String? expirationTimestampSecs;
  final Payload payload;
  final List<String>? secondarySigners;

  factory TransactionEncodeSubmissionRequest.fromTransactionRequest(
      TransactionRequest tx,
      List<String> signers) {

    final tser = TransactionEncodeSubmissionRequest(
      sender: tx.sender,
      sequenceNumber: tx.sequenceNumber,
      maxGasAmount: tx.maxGasAmount,
      gasUnitPrice: tx.gasUnitPrice,
      expirationTimestampSecs: tx.expirationTimestampSecs,
      payload: tx.payload,
      secondarySigners: signers
    );

    return tser;
  }

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
      data["secondary_signers"] = secondarySigners.toString();
    }
    return data;
  }
}