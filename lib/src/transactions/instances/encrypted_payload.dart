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

// The BIBE ciphertext types and the encryption key live in the crypto layer;
// re-exported here so the encrypted-payload API is reachable from one place.
export '../../core/crypto/encryption/ciphertext.dart'
    show BIBECiphertext, Ciphertext, EncryptionKey;

/// 16-byte decryption nonce for encrypted payloads (aptos-core
/// `DecryptionNonce`).
const int decryptionNonceLength = 16;

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
    final input =
        Uint8List.fromList([..._decryptedPlaintextSalt, ...bcsToBytes()]);
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
