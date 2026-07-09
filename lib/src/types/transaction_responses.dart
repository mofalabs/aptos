import 'move_types.dart';
import 'types.dart';

// ===
// EVENT TYPES
// ===

/// The structure for an event's unique identifier, including its creation
/// number.
class EventGuid {
  const EventGuid({
    required this.creationNumber,
    required this.accountAddress,
  });

  factory EventGuid.fromJson(Map<String, dynamic> json) => EventGuid(
        creationNumber: json['creation_number'] as String,
        accountAddress: json['account_address'] as String,
      );

  final String creationNumber;
  final String accountAddress;

  Map<String, dynamic> toJson() => {
        'creation_number': creationNumber,
        'account_address': accountAddress,
      };
}

/// An event emitted by a transaction, identified by a unique GUID.
class Event {
  const Event({
    required this.guid,
    required this.sequenceNumber,
    required this.type,
    required this.data,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        guid: EventGuid.fromJson(json['guid'] as Map<String, dynamic>),
        sequenceNumber: json['sequence_number'] as String,
        type: json['type'] as String,
        data: json['data'],
      );

  final EventGuid guid;
  final String sequenceNumber;
  final String type;

  /// The JSON representation of the event.
  final dynamic data;

  Map<String, dynamic> toJson() => {
        'guid': guid.toJson(),
        'sequence_number': sequenceNumber,
        'type': type,
        'data': data,
      };
}

// ===
// WRITESET CHANGE TYPES
// ===

/// The decoded data for a table, including its key in JSON format.
class DecodedTableData {
  const DecodedTableData({
    required this.key,
    required this.keyType,
    required this.value,
    required this.valueType,
  });

  factory DecodedTableData.fromJson(Map<String, dynamic> json) =>
      DecodedTableData(
        key: json['key'],
        keyType: json['key_type'] as String,
        value: json['value'],
        valueType: json['value_type'] as String,
      );

  /// Key of table in JSON.
  final dynamic key;

  /// Type of key.
  final String keyType;

  /// Value of table in JSON.
  final dynamic value;

  /// Type of value.
  final String valueType;

  Map<String, dynamic> toJson() => {
        'key': key,
        'key_type': keyType,
        'value': value,
        'value_type': valueType,
      };
}

/// Data for a deleted table entry.
class DeletedTableData {
  const DeletedTableData({required this.key, required this.keyType});

  factory DeletedTableData.fromJson(Map<String, dynamic> json) =>
      DeletedTableData(
        key: json['key'],
        keyType: json['key_type'] as String,
      );

  /// Deleted key.
  final dynamic key;

  /// Deleted key type.
  final String keyType;

  Map<String, dynamic> toJson() => {'key': key, 'key_type': keyType};
}

/// A change in a write set, which can be a module, resource, or table item
/// write or deletion.
abstract class WriteSetChange {
  const WriteSetChange();

  /// Creates the concrete [WriteSetChange] variant by dispatching on the
  /// `type` field of the JSON payload.
  factory WriteSetChange.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'delete_module':
        return WriteSetChangeDeleteModule.fromJson(json);
      case 'delete_resource':
        return WriteSetChangeDeleteResource.fromJson(json);
      case 'delete_table_item':
        return WriteSetChangeDeleteTableItem.fromJson(json);
      case 'write_module':
        return WriteSetChangeWriteModule.fromJson(json);
      case 'write_resource':
        return WriteSetChangeWriteResource.fromJson(json);
      case 'write_table_item':
        return WriteSetChangeWriteTableItem.fromJson(json);
      default:
        throw ArgumentError('Unknown write set change type: $type');
    }
  }

  String get type;

  Map<String, dynamic> toJson();
}

/// The structure for a module deletion change in a write set.
class WriteSetChangeDeleteModule extends WriteSetChange {
  const WriteSetChangeDeleteModule({
    this.type = 'delete_module',
    required this.address,
    required this.stateKeyHash,
    required this.module,
  });

  factory WriteSetChangeDeleteModule.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeDeleteModule(
        type: json['type'] as String,
        address: json['address'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        module: json['module'] as String,
      );

  @override
  final String type;
  final String address;

  /// State key hash.
  final String stateKeyHash;
  final MoveModuleId module;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'address': address,
        'state_key_hash': stateKeyHash,
        'module': module,
      };
}

/// The payload for a resource deletion in a write set change.
class WriteSetChangeDeleteResource extends WriteSetChange {
  const WriteSetChangeDeleteResource({
    this.type = 'delete_resource',
    required this.address,
    required this.stateKeyHash,
    required this.resource,
  });

  factory WriteSetChangeDeleteResource.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeDeleteResource(
        type: json['type'] as String,
        address: json['address'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        resource: json['resource'] as String,
      );

  @override
  final String type;
  final String address;
  final String stateKeyHash;
  final String resource;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'address': address,
        'state_key_hash': stateKeyHash,
        'resource': resource,
      };
}

/// The payload for a write set change that deletes a table item.
class WriteSetChangeDeleteTableItem extends WriteSetChange {
  const WriteSetChangeDeleteTableItem({
    this.type = 'delete_table_item',
    required this.stateKeyHash,
    required this.handle,
    required this.key,
    this.data,
  });

  factory WriteSetChangeDeleteTableItem.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeDeleteTableItem(
        type: json['type'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        handle: json['handle'] as String,
        key: json['key'] as String,
        data: json['data'] == null
            ? null
            : DeletedTableData.fromJson(json['data'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String stateKeyHash;
  final String handle;
  final String key;
  final DeletedTableData? data;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'state_key_hash': stateKeyHash,
        'handle': handle,
        'key': key,
        if (data != null) 'data': data!.toJson(),
      };
}

/// The structure for a write module change in a write set.
class WriteSetChangeWriteModule extends WriteSetChange {
  const WriteSetChangeWriteModule({
    this.type = 'write_module',
    required this.address,
    required this.stateKeyHash,
    required this.data,
  });

  factory WriteSetChangeWriteModule.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeWriteModule(
        type: json['type'] as String,
        address: json['address'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        data: MoveModuleBytecode.fromJson(json['data'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String address;
  final String stateKeyHash;
  final MoveModuleBytecode data;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'address': address,
        'state_key_hash': stateKeyHash,
        'data': data.toJson(),
      };
}

/// The resource associated with a write set change, identified by its type.
class WriteSetChangeWriteResource extends WriteSetChange {
  const WriteSetChangeWriteResource({
    this.type = 'write_resource',
    required this.address,
    required this.stateKeyHash,
    required this.data,
  });

  factory WriteSetChangeWriteResource.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeWriteResource(
        type: json['type'] as String,
        address: json['address'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        data: MoveResource.fromJson(json['data'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String address;
  final String stateKeyHash;
  final MoveResource data;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'address': address,
        'state_key_hash': stateKeyHash,
        'data': data.toJson(),
      };
}

/// The structure for a write operation on a table in a write set change.
class WriteSetChangeWriteTableItem extends WriteSetChange {
  const WriteSetChangeWriteTableItem({
    this.type = 'write_table_item',
    required this.stateKeyHash,
    required this.handle,
    required this.key,
    required this.value,
    this.data,
  });

  factory WriteSetChangeWriteTableItem.fromJson(Map<String, dynamic> json) =>
      WriteSetChangeWriteTableItem(
        type: json['type'] as String,
        stateKeyHash: json['state_key_hash'] as String,
        handle: json['handle'] as String,
        key: json['key'] as String,
        value: json['value'] as String,
        data: json['data'] == null
            ? null
            : DecodedTableData.fromJson(json['data'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String stateKeyHash;
  final String handle;
  final String key;
  final String value;
  final DecodedTableData? data;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'state_key_hash': stateKeyHash,
        'handle': handle,
        'key': key,
        'value': value,
        if (data != null) 'data': data!.toJson(),
      };
}

// ===
// TRANSACTION PAYLOAD RESPONSE TYPES
// ===

/// The payload for a transaction response, which can be an entry function,
/// script, multisig, or encrypted payload.
abstract class TransactionPayloadResponse {
  const TransactionPayloadResponse();

  /// Creates the concrete [TransactionPayloadResponse] variant by dispatching
  /// on the `type` field of the JSON payload.
  factory TransactionPayloadResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('encrypted_state')) {
      return EncryptedTransactionPayloadResponse.fromJson(json);
    }
    final type = json['type'] as String;
    switch (type) {
      case 'entry_function_payload':
        return EntryFunctionPayloadResponse.fromJson(json);
      case 'script_payload':
        return ScriptPayloadResponse.fromJson(json);
      case 'multisig_payload':
        return MultisigPayloadResponse.fromJson(json);
      default:
        throw ArgumentError('Unknown transaction payload type: $type');
    }
  }

  String get type;

  Map<String, dynamic> toJson();
}

/// The response payload for an entry function, containing the type of the
/// entry.
class EntryFunctionPayloadResponse extends TransactionPayloadResponse {
  const EntryFunctionPayloadResponse({
    this.type = 'entry_function_payload',
    required this.function,
    required this.typeArguments,
    required this.arguments,
  });

  factory EntryFunctionPayloadResponse.fromJson(Map<String, dynamic> json) =>
      EntryFunctionPayloadResponse(
        type: json['type'] as String,
        function: json['function'] as String,
        typeArguments: (json['type_arguments'] as List).cast<String>(),
        arguments: json['arguments'] as List,
      );

  @override
  final String type;
  final MoveFunctionId function;

  /// Type arguments of the function.
  final List<String> typeArguments;

  /// Arguments of the function.
  final List<dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'function': function,
        'type_arguments': typeArguments,
        'arguments': arguments,
      };
}

/// The payload for a script response, containing the type of the script.
class ScriptPayloadResponse extends TransactionPayloadResponse {
  const ScriptPayloadResponse({
    this.type = 'script_payload',
    required this.code,
    required this.typeArguments,
    required this.arguments,
  });

  factory ScriptPayloadResponse.fromJson(Map<String, dynamic> json) =>
      ScriptPayloadResponse(
        type: json['type'] as String,
        code: MoveScriptBytecode.fromJson(json['code'] as Map<String, dynamic>),
        typeArguments: (json['type_arguments'] as List).cast<String>(),
        arguments: json['arguments'] as List,
      );

  @override
  final String type;
  final MoveScriptBytecode code;

  /// Type arguments of the function.
  final List<String> typeArguments;

  /// Arguments of the function.
  final List<dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code.toJson(),
        'type_arguments': typeArguments,
        'arguments': arguments,
      };
}

/// The response payload for a multisig transaction, containing the type of
/// the transaction.
class MultisigPayloadResponse extends TransactionPayloadResponse {
  const MultisigPayloadResponse({
    this.type = 'multisig_payload',
    required this.multisigAddress,
    this.transactionPayload,
  });

  factory MultisigPayloadResponse.fromJson(Map<String, dynamic> json) =>
      MultisigPayloadResponse(
        type: json['type'] as String,
        multisigAddress: json['multisig_address'] as String,
        transactionPayload: json['transaction_payload'] == null
            ? null
            : EntryFunctionPayloadResponse.fromJson(
                json['transaction_payload'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String multisigAddress;
  final EntryFunctionPayloadResponse? transactionPayload;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'multisig_address': multisigAddress,
        if (transactionPayload != null)
          'transaction_payload': transactionPayload!.toJson(),
      };
}

/// Claimed entry function metadata on encrypted transaction payloads (the
/// REST API uses `name` for the optional function identifier).
class ClaimedEntryFunctionResponse {
  const ClaimedEntryFunctionResponse({required this.module, this.name});

  factory ClaimedEntryFunctionResponse.fromJson(Map<String, dynamic> json) =>
      ClaimedEntryFunctionResponse(
        module: json['module'] as String,
        name: json['name'] as String?,
      );

  final String module;
  final String? name;

  Map<String, dynamic> toJson() => {
        'module': module,
        if (name != null) 'name': name,
      };
}

/// Encrypted transaction payload as returned by the API. Discriminate on
/// `encrypted_state`:
/// - `encrypted` / `failed_decryption` →
///   [EncryptedEncryptedTransactionPayloadResponse]
/// - `decrypted` → [DecryptedEncryptedTransactionPayloadResponse]
abstract class EncryptedTransactionPayloadResponse
    extends TransactionPayloadResponse {
  const EncryptedTransactionPayloadResponse();

  factory EncryptedTransactionPayloadResponse.fromJson(
      Map<String, dynamic> json) {
    final encryptedState = json['encrypted_state'] as String;
    if (encryptedState == 'decrypted') {
      return DecryptedEncryptedTransactionPayloadResponse.fromJson(json);
    }
    return EncryptedEncryptedTransactionPayloadResponse.fromJson(json);
  }

  String get encryptedState;
  String get payloadHash;
  String get ciphertext;
  ClaimedEntryFunctionResponse? get claimedEntryFun;

  /// Ledger epoch hint for the encryption key used on the wire (aptos-core
  /// `EncryptedInner.encryption_epoch`).
  String? get encryptionEpoch;
}

/// Encrypted payload response when the node has not yet decrypted it, or
/// decryption failed. Narrow on [encryptedState] to distinguish from
/// [DecryptedEncryptedTransactionPayloadResponse].
class EncryptedEncryptedTransactionPayloadResponse
    extends EncryptedTransactionPayloadResponse {
  const EncryptedEncryptedTransactionPayloadResponse({
    this.type = 'encrypted_payload',
    required this.encryptedState,
    required this.payloadHash,
    required this.ciphertext,
    this.claimedEntryFun,
    this.encryptionEpoch,
    this.decryptionFailureReason,
  });

  factory EncryptedEncryptedTransactionPayloadResponse.fromJson(
          Map<String, dynamic> json) =>
      EncryptedEncryptedTransactionPayloadResponse(
        type: json['type'] as String,
        encryptedState: json['encrypted_state'] as String,
        payloadHash: json['payload_hash'] as String,
        ciphertext: json['ciphertext'] as String,
        claimedEntryFun: json['claimed_entry_fun'] == null
            ? null
            : ClaimedEntryFunctionResponse.fromJson(
                json['claimed_entry_fun'] as Map<String, dynamic>),
        encryptionEpoch: json['encryption_epoch'] as String?,
        decryptionFailureReason: json['decryption_failure_reason'] as String?,
      );

  @override
  final String type;

  /// Either `encrypted` or `failed_decryption`.
  @override
  final String encryptedState;
  @override
  final String payloadHash;
  @override
  final String ciphertext;
  @override
  final ClaimedEntryFunctionResponse? claimedEntryFun;
  @override
  final String? encryptionEpoch;

  /// Present when [encryptedState] is `failed_decryption`. Not yet surfaced
  /// by the REST API; reserved for future use.
  final String? decryptionFailureReason;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'encrypted_state': encryptedState,
        'payload_hash': payloadHash,
        'ciphertext': ciphertext,
        'claimed_entry_fun': claimedEntryFun?.toJson(),
        if (encryptionEpoch != null) 'encryption_epoch': encryptionEpoch,
        if (decryptionFailureReason != null)
          'decryption_failure_reason': decryptionFailureReason,
      };
}

/// Encrypted payload response after the node has successfully decrypted it.
/// Narrow on `encryptedState == 'decrypted'` to access [decryptedPayload].
class DecryptedEncryptedTransactionPayloadResponse
    extends EncryptedTransactionPayloadResponse {
  const DecryptedEncryptedTransactionPayloadResponse({
    this.type = 'encrypted_payload',
    this.encryptedState = 'decrypted',
    required this.payloadHash,
    required this.ciphertext,
    this.claimedEntryFun,
    required this.decryptedPayload,
    required this.decryptionNonce,
    this.encryptionEpoch,
  });

  factory DecryptedEncryptedTransactionPayloadResponse.fromJson(
          Map<String, dynamic> json) =>
      DecryptedEncryptedTransactionPayloadResponse(
        type: json['type'] as String,
        encryptedState: json['encrypted_state'] as String,
        payloadHash: json['payload_hash'] as String,
        ciphertext: json['ciphertext'] as String,
        claimedEntryFun: json['claimed_entry_fun'] == null
            ? null
            : ClaimedEntryFunctionResponse.fromJson(
                json['claimed_entry_fun'] as Map<String, dynamic>),
        decryptedPayload: TransactionPayloadResponse.fromJson(
            json['decrypted_payload'] as Map<String, dynamic>),
        decryptionNonce: json['decryption_nonce'] as String,
        encryptionEpoch: json['encryption_epoch'] as String?,
      );

  @override
  final String type;

  /// Always `decrypted`.
  @override
  final String encryptedState;
  @override
  final String payloadHash;
  @override
  final String ciphertext;
  @override
  final ClaimedEntryFunctionResponse? claimedEntryFun;

  /// The decrypted payload: an entry function, script, or multisig payload.
  final TransactionPayloadResponse decryptedPayload;
  final String decryptionNonce;
  @override
  final String? encryptionEpoch;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'encrypted_state': encryptedState,
        'payload_hash': payloadHash,
        'ciphertext': ciphertext,
        'claimed_entry_fun': claimedEntryFun?.toJson(),
        'decrypted_payload': decryptedPayload.toJson(),
        'decryption_nonce': decryptionNonce,
        if (encryptionEpoch != null) 'encryption_epoch': encryptionEpoch,
      };
}

// ===
// WRITE SET TYPES (GENESIS)
// ===

/// A write set, which can be either a script or a direct write set.
abstract class WriteSet {
  const WriteSet();

  /// Creates the concrete [WriteSet] variant by dispatching on the `type`
  /// field of the JSON payload.
  factory WriteSet.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'script_write_set':
        return ScriptWriteSet.fromJson(json);
      case 'direct_write_set':
        return DirectWriteSet.fromJson(json);
      default:
        throw ArgumentError('Unknown write set type: $type');
    }
  }

  String get type;

  Map<String, dynamic> toJson();
}

/// The set of properties for writing scripts, including the type of script.
class ScriptWriteSet extends WriteSet {
  const ScriptWriteSet({
    this.type = 'script_write_set',
    required this.executeAs,
    required this.script,
  });

  factory ScriptWriteSet.fromJson(Map<String, dynamic> json) => ScriptWriteSet(
        type: json['type'] as String,
        executeAs: json['execute_as'] as String,
        script: ScriptPayloadResponse.fromJson(
            json['script'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final String executeAs;
  final ScriptPayloadResponse script;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'execute_as': executeAs,
        'script': script.toJson(),
      };
}

/// The set of direct write operations, identified by a type string.
class DirectWriteSet extends WriteSet {
  const DirectWriteSet({
    this.type = 'direct_write_set',
    required this.changes,
    required this.events,
  });

  factory DirectWriteSet.fromJson(Map<String, dynamic> json) => DirectWriteSet(
        type: json['type'] as String,
        changes: (json['changes'] as List)
            .map((e) => WriteSetChange.fromJson(e as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List)
            .map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  final String type;
  final List<WriteSetChange> changes;
  final List<Event> events;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'changes': changes.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
      };
}

/// The payload for the genesis block containing the type of the payload.
class GenesisPayload {
  const GenesisPayload({
    this.type = 'write_set_payload',
    required this.writeSet,
  });

  factory GenesisPayload.fromJson(Map<String, dynamic> json) => GenesisPayload(
        type: json['type'] as String,
        writeSet: WriteSet.fromJson(json['write_set'] as Map<String, dynamic>),
      );

  final String type;
  final WriteSet writeSet;

  Map<String, dynamic> toJson() => {
        'type': type,
        'write_set': writeSet.toJson(),
      };
}

// ===
// TRANSACTION SIGNATURE TYPES
// ===

/// JSON representations of transaction signatures returned from the node API.
abstract class TransactionSignature {
  const TransactionSignature();

  /// Creates the concrete [TransactionSignature] variant by dispatching on
  /// the `type` field of the JSON payload.
  factory TransactionSignature.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'ed25519_signature':
        return TransactionEd25519Signature.fromJson(json);
      case 'secp256k1_ecdsa_signature':
        return TransactionSecp256k1Signature.fromJson(json);
      case 'multi_ed25519_signature':
        return TransactionMultiEd25519Signature.fromJson(json);
      case 'multi_agent_signature':
        return TransactionMultiAgentSignature.fromJson(json);
      case 'fee_payer_signature':
        return TransactionFeePayerSignature.fromJson(json);
      case 'single_sender':
        return TransactionSingleSenderSignature.fromJson(json);
      default:
        throw ArgumentError('Unknown transaction signature type: $type');
    }
  }

  String get type;

  Map<String, dynamic> toJson();
}

/// The union of all single account signatures, including Ed25519, Secp256k1,
/// and MultiEd25519 signatures.
abstract class AccountSignature extends TransactionSignature {
  const AccountSignature();

  /// Creates the concrete [AccountSignature] variant by dispatching on the
  /// `type` field of the JSON payload.
  factory AccountSignature.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'ed25519_signature':
        return TransactionEd25519Signature.fromJson(json);
      case 'secp256k1_ecdsa_signature':
        return TransactionSecp256k1Signature.fromJson(json);
      case 'multi_ed25519_signature':
        return TransactionMultiEd25519Signature.fromJson(json);
      default:
        throw ArgumentError('Unknown account signature type: $type');
    }
  }
}

/// The signature for a transaction using the Ed25519 algorithm.
class TransactionEd25519Signature extends AccountSignature {
  const TransactionEd25519Signature({
    this.type = 'ed25519_signature',
    required this.publicKey,
    required this.signature,
  });

  factory TransactionEd25519Signature.fromJson(Map<String, dynamic> json) =>
      TransactionEd25519Signature(
        type: json['type'] as String,
        publicKey: json['public_key'] as String,
        signature: json['signature'] as String,
      );

  @override
  final String type;
  final String publicKey;
  final String signature;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'public_key': publicKey,
        'signature': signature,
      };
}

/// The structure for a Secp256k1 signature in a transaction.
class TransactionSecp256k1Signature extends AccountSignature {
  const TransactionSecp256k1Signature({
    this.type = 'secp256k1_ecdsa_signature',
    required this.publicKey,
    required this.signature,
  });

  factory TransactionSecp256k1Signature.fromJson(Map<String, dynamic> json) =>
      TransactionSecp256k1Signature(
        type: json['type'] as String,
        publicKey: json['public_key'] as String,
        signature: json['signature'] as String,
      );

  @override
  final String type;
  final String publicKey;
  final String signature;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'public_key': publicKey,
        'signature': signature,
      };
}

/// A `{ type, value }` pair used by single sender signatures for the public
/// key and signature fields.
class TypedValue {
  const TypedValue({required this.type, required this.value});

  factory TypedValue.fromJson(Map<String, dynamic> json) => TypedValue(
        type: json['type'] as String,
        value: json['value'] as String,
      );

  final String type;
  final String value;

  Map<String, dynamic> toJson() => {'type': type, 'value': value};
}

/// The structure for a single sender signature in a transaction.
class TransactionSingleSenderSignature extends TransactionSignature {
  const TransactionSingleSenderSignature({
    this.type = 'single_sender',
    required this.publicKey,
    required this.signature,
  });

  factory TransactionSingleSenderSignature.fromJson(
          Map<String, dynamic> json) =>
      TransactionSingleSenderSignature(
        type: json['type'] as String,
        publicKey:
            TypedValue.fromJson(json['public_key'] as Map<String, dynamic>),
        signature:
            TypedValue.fromJson(json['signature'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final TypedValue publicKey;
  final TypedValue signature;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'public_key': publicKey.toJson(),
        'signature': signature.toJson(),
      };
}

/// The structure for a multi-signature transaction using Ed25519.
class TransactionMultiEd25519Signature extends AccountSignature {
  const TransactionMultiEd25519Signature({
    this.type = 'multi_ed25519_signature',
    required this.publicKeys,
    required this.signatures,
    required this.threshold,
    required this.bitmap,
  });

  factory TransactionMultiEd25519Signature.fromJson(
          Map<String, dynamic> json) =>
      TransactionMultiEd25519Signature(
        type: json['type'] as String,
        publicKeys: (json['public_keys'] as List).cast<String>(),
        signatures: (json['signatures'] as List).cast<String>(),
        threshold: json['threshold'] as int,
        bitmap: json['bitmap'] as String,
      );

  @override
  final String type;

  /// The public keys for the Ed25519 signature.
  final List<String> publicKeys;

  /// Signature associated with the public keys in the same order.
  final List<String> signatures;

  /// The number of signatures required for a successful transaction.
  final int threshold;
  final String bitmap;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'public_keys': publicKeys,
        'signatures': signatures,
        'threshold': threshold,
        'bitmap': bitmap,
      };
}

/// The structure for a multi-agent signature in a transaction.
class TransactionMultiAgentSignature extends TransactionSignature {
  const TransactionMultiAgentSignature({
    this.type = 'multi_agent_signature',
    required this.sender,
    required this.secondarySignerAddresses,
    required this.secondarySigners,
  });

  factory TransactionMultiAgentSignature.fromJson(Map<String, dynamic> json) =>
      TransactionMultiAgentSignature(
        type: json['type'] as String,
        sender:
            AccountSignature.fromJson(json['sender'] as Map<String, dynamic>),
        secondarySignerAddresses:
            (json['secondary_signer_addresses'] as List).cast<String>(),
        secondarySigners: (json['secondary_signers'] as List)
            .map((e) => AccountSignature.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  final String type;
  final AccountSignature sender;

  /// The other involved parties' addresses.
  final List<String> secondarySignerAddresses;

  /// The associated signatures, in the same order as the secondary addresses.
  final List<AccountSignature> secondarySigners;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'sender': sender.toJson(),
        'secondary_signer_addresses': secondarySignerAddresses,
        'secondary_signers': secondarySigners.map((e) => e.toJson()).toList(),
      };
}

/// The signature of the fee payer in a transaction.
class TransactionFeePayerSignature extends TransactionSignature {
  const TransactionFeePayerSignature({
    this.type = 'fee_payer_signature',
    required this.sender,
    required this.secondarySignerAddresses,
    required this.secondarySigners,
    required this.feePayerAddress,
    required this.feePayerSigner,
  });

  factory TransactionFeePayerSignature.fromJson(Map<String, dynamic> json) =>
      TransactionFeePayerSignature(
        type: json['type'] as String,
        sender:
            AccountSignature.fromJson(json['sender'] as Map<String, dynamic>),
        secondarySignerAddresses:
            (json['secondary_signer_addresses'] as List).cast<String>(),
        secondarySigners: (json['secondary_signers'] as List)
            .map((e) => AccountSignature.fromJson(e as Map<String, dynamic>))
            .toList(),
        feePayerAddress: json['fee_payer_address'] as String,
        feePayerSigner: AccountSignature.fromJson(
            json['fee_payer_signer'] as Map<String, dynamic>),
      );

  @override
  final String type;
  final AccountSignature sender;

  /// The other involved parties' addresses.
  final List<String> secondarySignerAddresses;

  /// The associated signatures, in the same order as the secondary addresses.
  final List<AccountSignature> secondarySigners;
  final String feePayerAddress;
  final AccountSignature feePayerSigner;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'sender': sender.toJson(),
        'secondary_signer_addresses': secondarySignerAddresses,
        'secondary_signers': secondarySigners.map((e) => e.toJson()).toList(),
        'fee_payer_address': feePayerAddress,
        'fee_payer_signer': feePayerSigner.toJson(),
      };
}

// ===
// TRANSACTION RESPONSE TYPES
// ===

/// The response for a transaction, which can be either pending or committed.
abstract class TransactionResponse {
  const TransactionResponse();

  /// Creates the concrete [TransactionResponse] variant by dispatching on the
  /// `type` field of the JSON payload, using [TransactionResponseType].
  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String;
    final type = TransactionResponseType.values.firstWhere(
      (t) => t.value == typeValue,
      orElse: () =>
          throw ArgumentError('Unknown transaction response type: $typeValue'),
    );
    switch (type) {
      case TransactionResponseType.pending:
        return PendingTransactionResponse.fromJson(json);
      case TransactionResponseType.user:
        return UserTransactionResponse.fromJson(json);
      case TransactionResponseType.genesis:
        return GenesisTransactionResponse.fromJson(json);
      case TransactionResponseType.blockMetadata:
        return BlockMetadataTransactionResponse.fromJson(json);
      case TransactionResponseType.stateCheckpoint:
        return StateCheckpointTransactionResponse.fromJson(json);
      case TransactionResponseType.validator:
        return ValidatorTransactionResponse.fromJson(json);
      case TransactionResponseType.blockEpilogue:
        return BlockEpilogueTransactionResponse.fromJson(json);
    }
  }

  TransactionResponseType get type;
  String get hash;

  Map<String, dynamic> toJson();
}

/// The response for a pending transaction, indicating that the transaction is
/// still being processed.
class PendingTransactionResponse extends TransactionResponse {
  const PendingTransactionResponse({
    required this.hash,
    required this.sender,
    required this.sequenceNumber,
    required this.maxGasAmount,
    required this.gasUnitPrice,
    required this.expirationTimestampSecs,
    required this.payload,
    this.signature,
  });

  factory PendingTransactionResponse.fromJson(Map<String, dynamic> json) =>
      PendingTransactionResponse(
        hash: json['hash'] as String,
        sender: json['sender'] as String,
        sequenceNumber: json['sequence_number'] as String,
        maxGasAmount: json['max_gas_amount'] as String,
        gasUnitPrice: json['gas_unit_price'] as String,
        expirationTimestampSecs: json['expiration_timestamp_secs'] as String,
        payload: TransactionPayloadResponse.fromJson(
            json['payload'] as Map<String, dynamic>),
        signature: json['signature'] == null
            ? null
            : TransactionSignature.fromJson(
                json['signature'] as Map<String, dynamic>),
      );

  @override
  TransactionResponseType get type => TransactionResponseType.pending;

  @override
  final String hash;
  final String sender;
  final String sequenceNumber;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final TransactionPayloadResponse payload;
  final TransactionSignature? signature;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'hash': hash,
        'sender': sender,
        'sequence_number': sequenceNumber,
        'max_gas_amount': maxGasAmount,
        'gas_unit_price': gasUnitPrice,
        'expiration_timestamp_secs': expirationTimestampSecs,
        'payload': payload.toJson(),
        if (signature != null) 'signature': signature!.toJson(),
      };
}

/// The response for a committed transaction, which can be one of several
/// transaction types. Contains the fields shared by all committed
/// transactions.
abstract class CommittedTransactionResponse extends TransactionResponse {
  const CommittedTransactionResponse({
    required this.version,
    required this.hash,
    required this.stateChangeHash,
    required this.eventRootHash,
    this.stateCheckpointHash,
    required this.gasUsed,
    required this.success,
    required this.vmStatus,
    required this.accumulatorRootHash,
    required this.changes,
  });

  final String version;

  @override
  final String hash;
  final String stateChangeHash;
  final String eventRootHash;
  final String? stateCheckpointHash;
  final String gasUsed;

  /// Whether the transaction was successful.
  final bool success;

  /// The VM status of the transaction, can tell useful information in a
  /// failure.
  final String vmStatus;
  final String accumulatorRootHash;

  /// Final state of resources changed by the transaction.
  final List<WriteSetChange> changes;

  /// The JSON representation of the fields shared by all committed
  /// transactions.
  Map<String, dynamic> _committedToJson() => {
        'type': type.value,
        'version': version,
        'hash': hash,
        'state_change_hash': stateChangeHash,
        'event_root_hash': eventRootHash,
        'state_checkpoint_hash': stateCheckpointHash,
        'gas_used': gasUsed,
        'success': success,
        'vm_status': vmStatus,
        'accumulator_root_hash': accumulatorRootHash,
        'changes': changes.map((e) => e.toJson()).toList(),
      };
}

List<WriteSetChange> _changesFromJson(Map<String, dynamic> json) =>
    (json['changes'] as List)
        .map((e) => WriteSetChange.fromJson(e as Map<String, dynamic>))
        .toList();

List<Event> _eventsFromJson(Map<String, dynamic> json) =>
    (json['events'] as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();

/// The response structure for a user transaction.
class UserTransactionResponse extends CommittedTransactionResponse {
  const UserTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.sender,
    required this.sequenceNumber,
    this.replayProtectionNonce,
    required this.maxGasAmount,
    required this.gasUnitPrice,
    required this.expirationTimestampSecs,
    required this.payload,
    this.signature,
    required this.events,
    required this.timestamp,
  });

  factory UserTransactionResponse.fromJson(Map<String, dynamic> json) =>
      UserTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        sender: json['sender'] as String,
        sequenceNumber: json['sequence_number'] as String,
        replayProtectionNonce: json['replay_protection_nonce'] as String?,
        maxGasAmount: json['max_gas_amount'] as String,
        gasUnitPrice: json['gas_unit_price'] as String,
        expirationTimestampSecs: json['expiration_timestamp_secs'] as String,
        payload: TransactionPayloadResponse.fromJson(
            json['payload'] as Map<String, dynamic>),
        signature: json['signature'] == null
            ? null
            : TransactionSignature.fromJson(
                json['signature'] as Map<String, dynamic>),
        events: _eventsFromJson(json),
        timestamp: json['timestamp'] as String,
      );

  @override
  TransactionResponseType get type => TransactionResponseType.user;

  final String sender;
  final String sequenceNumber;

  /// The replay protection nonce for orderless transactions. Only present
  /// when the transaction uses a nonce instead of a sequence number.
  final String? replayProtectionNonce;
  final String maxGasAmount;
  final String gasUnitPrice;
  final String expirationTimestampSecs;
  final TransactionPayloadResponse payload;
  final TransactionSignature? signature;

  /// Events generated by the transaction.
  final List<Event> events;
  final String timestamp;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'sender': sender,
        'sequence_number': sequenceNumber,
        if (replayProtectionNonce != null)
          'replay_protection_nonce': replayProtectionNonce,
        'max_gas_amount': maxGasAmount,
        'gas_unit_price': gasUnitPrice,
        'expiration_timestamp_secs': expirationTimestampSecs,
        'payload': payload.toJson(),
        if (signature != null) 'signature': signature!.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'timestamp': timestamp,
      };
}

/// The response for a genesis transaction, indicating the type of
/// transaction.
class GenesisTransactionResponse extends CommittedTransactionResponse {
  const GenesisTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.payload,
    required this.events,
  });

  factory GenesisTransactionResponse.fromJson(Map<String, dynamic> json) =>
      GenesisTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        payload:
            GenesisPayload.fromJson(json['payload'] as Map<String, dynamic>),
        events: _eventsFromJson(json),
      );

  @override
  TransactionResponseType get type => TransactionResponseType.genesis;

  final GenesisPayload payload;

  /// Events emitted during genesis.
  final List<Event> events;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'payload': payload.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
      };
}

/// The structure representing a blockchain block with its height.
class BlockMetadataTransactionResponse extends CommittedTransactionResponse {
  const BlockMetadataTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.id,
    required this.epoch,
    required this.round,
    required this.events,
    required this.previousBlockVotesBitvec,
    required this.proposer,
    required this.failedProposerIndices,
    required this.timestamp,
  });

  factory BlockMetadataTransactionResponse.fromJson(
          Map<String, dynamic> json) =>
      BlockMetadataTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        id: json['id'] as String,
        epoch: json['epoch'] as String,
        round: json['round'] as String,
        events: _eventsFromJson(json),
        previousBlockVotesBitvec:
            (json['previous_block_votes_bitvec'] as List).cast<int>(),
        proposer: json['proposer'] as String,
        failedProposerIndices:
            (json['failed_proposer_indices'] as List).cast<int>(),
        timestamp: json['timestamp'] as String,
      );

  @override
  TransactionResponseType get type => TransactionResponseType.blockMetadata;

  final String id;
  final String epoch;
  final String round;

  /// The events emitted at the block creation.
  final List<Event> events;

  /// Previous block votes.
  final List<int> previousBlockVotesBitvec;
  final String proposer;

  /// The indices of the proposers who failed to propose.
  final List<int> failedProposerIndices;
  final String timestamp;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'id': id,
        'epoch': epoch,
        'round': round,
        'events': events.map((e) => e.toJson()).toList(),
        'previous_block_votes_bitvec': previousBlockVotesBitvec,
        'proposer': proposer,
        'failed_proposer_indices': failedProposerIndices,
        'timestamp': timestamp,
      };
}

/// The response for a state checkpoint transaction, indicating the type of
/// transaction.
class StateCheckpointTransactionResponse extends CommittedTransactionResponse {
  const StateCheckpointTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.timestamp,
  });

  factory StateCheckpointTransactionResponse.fromJson(
          Map<String, dynamic> json) =>
      StateCheckpointTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        timestamp: json['timestamp'] as String,
      );

  @override
  TransactionResponseType get type => TransactionResponseType.stateCheckpoint;

  final String timestamp;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'timestamp': timestamp,
      };
}

/// The response for a validator transaction, indicating the type of
/// transaction.
class ValidatorTransactionResponse extends CommittedTransactionResponse {
  const ValidatorTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.events,
    required this.timestamp,
  });

  factory ValidatorTransactionResponse.fromJson(Map<String, dynamic> json) =>
      ValidatorTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        events: _eventsFromJson(json),
        timestamp: json['timestamp'] as String,
      );

  @override
  TransactionResponseType get type => TransactionResponseType.validator;

  /// The events emitted by the validator transaction.
  final List<Event> events;
  final String timestamp;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'timestamp': timestamp,
      };
}

/// Describes the gas state of the block, indicating whether the block gas
/// limit has been reached.
class BlockEndInfo {
  const BlockEndInfo({
    required this.blockGasLimitReached,
    required this.blockOutputLimitReached,
    required this.blockEffectiveBlockGasUnits,
    required this.blockApproxOutputSize,
  });

  factory BlockEndInfo.fromJson(Map<String, dynamic> json) => BlockEndInfo(
        blockGasLimitReached: json['block_gas_limit_reached'] as bool,
        blockOutputLimitReached: json['block_output_limit_reached'] as bool,
        blockEffectiveBlockGasUnits:
            json['block_effective_block_gas_units'] as int,
        blockApproxOutputSize: json['block_approx_output_size'] as int,
      );

  final bool blockGasLimitReached;
  final bool blockOutputLimitReached;
  final int blockEffectiveBlockGasUnits;
  final int blockApproxOutputSize;

  Map<String, dynamic> toJson() => {
        'block_gas_limit_reached': blockGasLimitReached,
        'block_output_limit_reached': blockOutputLimitReached,
        'block_effective_block_gas_units': blockEffectiveBlockGasUnits,
        'block_approx_output_size': blockApproxOutputSize,
      };
}

/// A transaction executed at the end of a block that tracks data from the
/// entire block.
class BlockEpilogueTransactionResponse extends CommittedTransactionResponse {
  const BlockEpilogueTransactionResponse({
    required super.version,
    required super.hash,
    required super.stateChangeHash,
    required super.eventRootHash,
    super.stateCheckpointHash,
    required super.gasUsed,
    required super.success,
    required super.vmStatus,
    required super.accumulatorRootHash,
    required super.changes,
    required this.timestamp,
    this.blockEndInfo,
  });

  factory BlockEpilogueTransactionResponse.fromJson(
          Map<String, dynamic> json) =>
      BlockEpilogueTransactionResponse(
        version: json['version'] as String,
        hash: json['hash'] as String,
        stateChangeHash: json['state_change_hash'] as String,
        eventRootHash: json['event_root_hash'] as String,
        stateCheckpointHash: json['state_checkpoint_hash'] as String?,
        gasUsed: json['gas_used'] as String,
        success: json['success'] as bool,
        vmStatus: json['vm_status'] as String,
        accumulatorRootHash: json['accumulator_root_hash'] as String,
        changes: _changesFromJson(json),
        timestamp: json['timestamp'] as String,
        blockEndInfo: json['block_end_info'] == null
            ? null
            : BlockEndInfo.fromJson(
                json['block_end_info'] as Map<String, dynamic>),
      );

  @override
  TransactionResponseType get type => TransactionResponseType.blockEpilogue;

  final String timestamp;
  final BlockEndInfo? blockEndInfo;

  @override
  Map<String, dynamic> toJson() => {
        ..._committedToJson(),
        'timestamp': timestamp,
        'block_end_info': blockEndInfo?.toJson(),
      };
}
