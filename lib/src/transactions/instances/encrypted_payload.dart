import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../core/authentication_key.dart';
import 'identifier.dart';
import 'module_id.dart';
import 'transaction_payload.dart';

/// 16-byte decryption nonce for encrypted payloads (aptos-core
/// `DecryptionNonce`).
const int decryptionNonceLength = 16;

/// Length of an ed25519 verification key in bytes.
const int _vkLength = 32;

/// Length of an ed25519 signature in bytes.
const int _signatureLength = 64;

/// Length of the AES-GCM nonce in bytes.
const int _gcmNonceLength = 12;

/// Length of the padded symmetric key in bytes.
const int _symmetricKeyLength = 16;

Uint8List _sha3_256(Uint8List input) => SHA3Digest(256).process(input);

final Uint8List _decryptedPlaintextSalt =
    _sha3_256(Uint8List.fromList(utf8.encode('APTOS::DecryptedPlaintext')));

/// Optional claim about the entry function inside an encrypted payload
/// (`claimed_entry_fun` in aptos-core). Lets fee payers and multisig
/// co-signers see the module and optionally the function name without
/// decrypting.
///
/// BCS: `module: ModuleId` then `function: Option<Identifier>`. The REST API
/// renames the optional field to `name`.
class ClaimedEntryFunction extends Serializable {
  final ModuleId moduleId;

  /// BCS/Rust `function`; JSON API field is `name`.
  final Identifier? functionName;

  ClaimedEntryFunction(this.moduleId, [this.functionName]);

  @override
  void serialize(Serializer serializer) {
    moduleId.serialize(serializer);
    serializer.serializeOption(functionName);
  }

  static ClaimedEntryFunction deserialize(Deserializer deserializer) {
    final moduleId = ModuleId.deserialize(deserializer);
    final functionName = deserializer.deserializeOption(Identifier.deserialize);
    return ClaimedEntryFunction(moduleId, functionName);
  }

  /// Creates a claim from an [EntryFunction].
  ///
  /// When [includeFunctionName] is false, only the module is claimed
  /// (`Option::None` for the function on the wire).
  static ClaimedEntryFunction fromEntryFunction(
    EntryFunction entry, {
    bool includeFunctionName = true,
  }) {
    return ClaimedEntryFunction(
      entry.moduleName,
      includeFunctionName ? entry.functionName : null,
    );
  }
}

/// BCS-serializable `DecryptedPlaintext`. Built client-side before encrypting;
/// its BCS hash becomes `payload_hash`.
/// Matches Rust: `DecryptedPlaintext { executable, decryption_nonce: [u8; 16] }`.
class DecryptedPlaintext extends Serializable {
  final TransactionExecutable executable;

  final Uint8List decryptionNonce;

  DecryptedPlaintext(this.executable, this.decryptionNonce) {
    if (decryptionNonce.length != decryptionNonceLength) {
      throw ArgumentError(
        'decryptionNonce must be $decryptionNonceLength bytes',
      );
    }
  }

  @override
  void serialize(Serializer serializer) {
    executable.serialize(serializer);
    serializer.serializeFixedBytes(decryptionNonce);
  }

  static DecryptedPlaintext deserialize(Deserializer deserializer) {
    final executable = TransactionExecutable.deserialize(deserializer);
    final decryptionNonce =
        deserializer.deserializeFixedBytes(decryptionNonceLength);
    return DecryptedPlaintext(executable, decryptionNonce);
  }

  /// Domain-separated BCS crypto hash (`BCSCryptoHash` in aptos-core):
  /// SHA3-256( SHA3-256("APTOS::DecryptedPlaintext") || BCS(self) ).
  Uint8List hash() {
    final input = Uint8List.fromList([..._decryptedPlaintextSalt, ...bcsToBytes()]);
    return _sha3_256(input);
  }
}

/// One `(AccountAddress, AuthenticationKey)` entry in
/// `PayloadAssociatedData::V1.signer_auth_keys` (aptos-core).
class SignerAuthKeyPair {
  final AccountAddress address;
  final AuthenticationKey authenticationKey;

  const SignerAuthKeyPair({
    required this.address,
    required this.authenticationKey,
  });
}

const int _payloadAssociatedDataV1 = 0;

/// AAD for batch-encrypted transaction payloads. BCS matches Rust
/// `PayloadAssociatedData::V1`:
/// uleb128 variant | `sender` | `Vec<(AccountAddress, AuthenticationKey)>`.
class PayloadAssociatedData extends Serializable {
  final AccountAddress sender;
  final List<SignerAuthKeyPair> signerAuthKeys;

  PayloadAssociatedData(this.sender, this.signerAuthKeys) {
    if (signerAuthKeys.isEmpty) {
      throw ArgumentError(
        'PayloadAssociatedData requires at least one signer auth key pair',
      );
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(_payloadAssociatedDataV1);
    sender.serialize(serializer);
    serializer.serializeU32AsUleb128(signerAuthKeys.length);
    for (final pair in signerAuthKeys) {
      pair.address.serialize(serializer);
      pair.authenticationKey.serialize(serializer);
    }
  }

  static PayloadAssociatedData deserialize(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant != _payloadAssociatedDataV1) {
      throw StateError('Unknown PayloadAssociatedData variant: $variant');
    }
    final sender = AccountAddress.deserialize(deserializer);
    final len = deserializer.deserializeUleb128AsU32();
    final signerAuthKeys = <SignerAuthKeyPair>[];
    for (var i = 0; i < len; i += 1) {
      signerAuthKeys.add(SignerAuthKeyPair(
        address: AccountAddress.deserialize(deserializer),
        authenticationKey: AuthenticationKey.deserialize(deserializer),
      ));
    }
    return PayloadAssociatedData(sender, signerAuthKeys);
  }
}

// TODO: `BIBECiphertext` belongs in `core/crypto/encryption/` once the
// batch-encryption cryptography is implemented. Until then this class holds
// the raw byte representations of the curve points and symmetric primitives
// so the BCS wire layout is byte-exact. The symmetric key (fixed 16 bytes)
// and symmetric ciphertext (fixed 12-byte GCM nonce + length-prefixed body)
// are flattened into raw fields.
///
/// Corresponds to the Rust type
/// `aptos_batch_encryption::shared::ciphertext::BIBECiphertext`.
///
/// BCS: `id` bytes | `ct_g2` bytes (single length prefix for all 3 G2
/// elements) | padded key fixed 16 bytes | GCM nonce fixed 12 bytes |
/// ciphertext body bytes.
class BIBECiphertext extends Serializable {
  /// Little-endian Fr scalar bytes (length-prefixed on the wire).
  final Uint8List idBytes;

  /// Concatenated compressed G2 points (length-prefixed on the wire).
  final Uint8List ctG2Bytes;

  /// Padded symmetric key, fixed 16 bytes.
  final Uint8List paddedKey;

  /// AES-GCM nonce, fixed 12 bytes.
  final Uint8List gcmNonce;

  /// Symmetric ciphertext body (length-prefixed on the wire).
  final Uint8List ctBody;

  BIBECiphertext({
    required this.idBytes,
    required this.ctG2Bytes,
    required this.paddedKey,
    required this.gcmNonce,
    required this.ctBody,
  }) {
    if (paddedKey.length != _symmetricKeyLength) {
      throw ArgumentError('paddedKey must be $_symmetricKeyLength bytes');
    }
    if (gcmNonce.length != _gcmNonceLength) {
      throw ArgumentError('gcmNonce must be $_gcmNonceLength bytes');
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(idBytes);
    // BCS: single length prefix for all 3 G2 elements (matches the
    // arkworks-serde wrapper in Rust).
    serializer.serializeBytes(ctG2Bytes);
    serializer.serializeFixedBytes(paddedKey);
    serializer.serializeFixedBytes(gcmNonce);
    serializer.serializeBytes(ctBody);
  }

  static BIBECiphertext deserialize(Deserializer deserializer) {
    final idBytes = deserializer.deserializeBytes();
    final ctG2Bytes = deserializer.deserializeBytes();
    final paddedKey = deserializer.deserializeFixedBytes(_symmetricKeyLength);
    final gcmNonce = deserializer.deserializeFixedBytes(_gcmNonceLength);
    final ctBody = deserializer.deserializeBytes();
    return BIBECiphertext(
      idBytes: idBytes,
      ctG2Bytes: ctG2Bytes,
      paddedKey: paddedKey,
      gcmNonce: gcmNonce,
      ctBody: ctBody,
    );
  }
}

// TODO: `Ciphertext` belongs in `core/crypto/encryption/` once the
// batch-encryption cryptography is implemented. Only the BCS data structure
// is defined here; encryption/decryption math is not yet included.
///
/// Corresponds to the Rust type
/// `aptos_batch_encryption::shared::ciphertext::Ciphertext`.
class Ciphertext extends Serializable {
  /// ed25519 verification key, 32 bytes (length-prefixed on the wire).
  final Uint8List vk;

  final BIBECiphertext bibeCt;

  final Uint8List associatedDataBytes;

  /// ed25519 signature, fixed 64 bytes.
  final Uint8List signature;

  Ciphertext(this.vk, this.bibeCt, this.associatedDataBytes, this.signature) {
    if (vk.length != _vkLength) {
      throw ArgumentError(
        'ed25519 public key must be $_vkLength bytes, got ${vk.length}',
      );
    }
    if (signature.length != _signatureLength) {
      throw ArgumentError(
        'ed25519 signature must be $_signatureLength bytes, got ${signature.length}',
      );
    }
  }

  @override
  void serialize(Serializer serializer) {
    // Rust: ed25519 VKs serialized as variable bytes.
    serializer.serializeBytes(vk);
    bibeCt.serialize(serializer);
    serializer.serializeBytes(associatedDataBytes);
    // Rust: signatures serialized as fixed bytes.
    serializer.serializeFixedBytes(signature);
  }

  static Ciphertext deserialize(Deserializer deserializer) {
    final vk = deserializer.deserializeBytes();
    final bibeCt = BIBECiphertext.deserialize(deserializer);
    final associatedDataBytes = deserializer.deserializeBytes();
    final signature = deserializer.deserializeFixedBytes(_signatureLength);
    return Ciphertext(vk, bibeCt, associatedDataBytes, signature);
  }
}
