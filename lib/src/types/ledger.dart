import 'move_types.dart';
import 'transaction_responses.dart';
import 'types.dart';

/// Information about the current blockchain ledger, including its chain ID.
class LedgerInfo {
  const LedgerInfo({
    required this.chainId,
    required this.epoch,
    required this.ledgerVersion,
    required this.oldestLedgerVersion,
    required this.ledgerTimestamp,
    required this.nodeRole,
    required this.oldestBlockHeight,
    required this.blockHeight,
    this.gitHash,
    this.encryptionKey,
  });

  factory LedgerInfo.fromJson(Map<String, dynamic> json) => LedgerInfo(
        chainId: json['chain_id'] as int,
        epoch: json['epoch'] as String,
        ledgerVersion: json['ledger_version'] as String,
        oldestLedgerVersion: json['oldest_ledger_version'] as String,
        ledgerTimestamp: json['ledger_timestamp'] as String,
        nodeRole: RoleType.values.firstWhere(
          (role) => role.value == json['node_role'],
          orElse: () =>
              throw ArgumentError('Unknown node role: ${json['node_role']}'),
        ),
        oldestBlockHeight: json['oldest_block_height'] as String,
        blockHeight: json['block_height'] as String,
        gitHash: json['git_hash'] as String?,
        encryptionKey: json['encryption_key'] as String?,
      );

  /// Chain ID of the current chain.
  final int chainId;
  final String epoch;
  final String ledgerVersion;
  final String oldestLedgerVersion;
  final String ledgerTimestamp;
  final RoleType nodeRole;
  final String oldestBlockHeight;
  final String blockHeight;

  /// Git hash of the build of the API endpoint. Can be used to determine the
  /// exact software version used by the API endpoint.
  final String? gitHash;

  /// Hex-encoded encryption key for encrypted transactions. Present when the
  /// node supports encrypted transaction submission.
  final String? encryptionKey;

  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        'epoch': epoch,
        'ledger_version': ledgerVersion,
        'oldest_ledger_version': oldestLedgerVersion,
        'ledger_timestamp': ledgerTimestamp,
        'node_role': nodeRole.value,
        'oldest_block_height': oldestBlockHeight,
        'block_height': blockHeight,
        if (gitHash != null) 'git_hash': gitHash,
        if (encryptionKey != null) 'encryption_key': encryptionKey,
      };
}

/// A block returned by the fullnode API.
class Block {
  const Block({
    required this.blockHeight,
    required this.blockHash,
    required this.blockTimestamp,
    required this.firstVersion,
    required this.lastVersion,
    this.transactions,
  });

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        blockHeight: json['block_height'] as String,
        blockHash: json['block_hash'] as String,
        blockTimestamp: json['block_timestamp'] as String,
        firstVersion: json['first_version'] as String,
        lastVersion: json['last_version'] as String,
        transactions: json['transactions'] == null
            ? null
            : (json['transactions'] as List)
                .map((e) =>
                    TransactionResponse.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  final String blockHeight;
  final String blockHash;
  final String blockTimestamp;
  final String firstVersion;
  final String lastVersion;

  /// The transactions in the block in sequential order.
  final List<TransactionResponse>? transactions;

  Map<String, dynamic> toJson() => {
        'block_height': blockHeight,
        'block_hash': blockHash,
        'block_timestamp': blockTimestamp,
        'first_version': firstVersion,
        'last_version': lastVersion,
        if (transactions != null)
          'transactions': transactions!.map((e) => e.toJson()).toList(),
      };
}

/// The data associated with an account, including its sequence number.
class AccountData {
  const AccountData({
    required this.sequenceNumber,
    required this.authenticationKey,
  });

  factory AccountData.fromJson(Map<String, dynamic> json) => AccountData(
        sequenceNumber: json['sequence_number'] as String,
        authenticationKey: json['authentication_key'] as String,
      );

  final String sequenceNumber;
  final String authenticationKey;

  Map<String, dynamic> toJson() => {
        'sequence_number': sequenceNumber,
        'authentication_key': authenticationKey,
      };
}

/// The output of the estimate gas API, including the deprioritized estimate
/// for the gas unit price.
class GasEstimation {
  const GasEstimation({
    this.deprioritizedGasEstimate,
    required this.gasEstimate,
    this.prioritizedGasEstimate,
  });

  factory GasEstimation.fromJson(Map<String, dynamic> json) => GasEstimation(
        deprioritizedGasEstimate: json['deprioritized_gas_estimate'] as int?,
        gasEstimate: json['gas_estimate'] as int,
        prioritizedGasEstimate: json['prioritized_gas_estimate'] as int?,
      );

  /// The deprioritized estimate for the gas unit price.
  final int? deprioritizedGasEstimate;

  /// The current estimate for the gas unit price.
  final int gasEstimate;

  /// The prioritized estimate for the gas unit price.
  final int? prioritizedGasEstimate;

  Map<String, dynamic> toJson() => {
        if (deprioritizedGasEstimate != null)
          'deprioritized_gas_estimate': deprioritizedGasEstimate,
        'gas_estimate': gasEstimate,
        if (prioritizedGasEstimate != null)
          'prioritized_gas_estimate': prioritizedGasEstimate,
      };
}

/// The request payload for the GetTableItem API.
class TableItemRequest {
  const TableItemRequest({
    required this.keyType,
    required this.valueType,
    required this.key,
  });

  factory TableItemRequest.fromJson(Map<String, dynamic> json) =>
      TableItemRequest(
        keyType: json['key_type'],
        valueType: json['value_type'],
        key: json['key'],
      );

  final MoveValue keyType;
  final MoveValue valueType;

  /// The value of the table item's key.
  final dynamic key;

  Map<String, dynamic> toJson() => {
        'key_type': keyType,
        'value_type': valueType,
        'key': key,
      };
}

/// The payload sent to the fullnode for a JSON view request.
class ViewFunctionJsonPayload {
  const ViewFunctionJsonPayload({
    required this.function,
    this.typeArguments = const [],
    this.functionArguments = const [],
  });

  factory ViewFunctionJsonPayload.fromJson(Map<String, dynamic> json) =>
      ViewFunctionJsonPayload(
        function: json['function'] as String,
        typeArguments: (json['type_arguments'] as List).cast<String>(),
        functionArguments: json['arguments'] as List,
      );

  final MoveFunctionId function;
  final List<MoveStructId> typeArguments;
  final List<MoveValue> functionArguments;

  Map<String, dynamic> toJson() => {
        'function': function,
        'type_arguments': typeArguments,
        'arguments': functionArguments,
      };
}
