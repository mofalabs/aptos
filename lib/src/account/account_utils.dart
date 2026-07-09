import 'dart:typed_data';

import '../bcs/deserializer.dart';
import '../bcs/serializer.dart';
import '../core/account_address.dart';
import '../core/crypto/ed25519.dart';
import '../core/crypto/keyless.dart';
import '../core/crypto/multi_key.dart';
import '../core/crypto/secp256k1.dart';
import '../core/hex.dart';
import '../types/types.dart';
import 'abstract_keyless_account.dart';
import 'account.dart';
import 'ed25519_account.dart';
import 'ephemeral_key_pair.dart';
import 'federated_keyless_account.dart';
import 'keyless_account.dart';
import 'multi_key_account.dart';
import 'single_key_account.dart';
import 'utils.dart';

void _serializeKeylessAccountCommon(
  AbstractKeylessAccount account,
  Serializer serializer,
) {
  serializer.serializeStr(account.jwt);
  serializer.serializeStr(account.uidKey);
  serializer.serializeFixedBytes(account.pepper);
  account.ephemeralKeyPair.serialize(serializer);
  final proof = account.proof;
  if (proof == null) {
    throw StateError('Cannot serialize - proof undefined');
  }
  proof.serialize(serializer);
  serializer.serializeOptionFixedBytes(account.verificationKeyHash);
}

({
  String jwt,
  String uidKey,
  Uint8List pepper,
  EphemeralKeyPair ephemeralKeyPair,
  ZeroKnowledgeSig proof,
  Uint8List? verificationKeyHash,
}) _deserializeKeylessAccountCommon(Deserializer deserializer) {
  final jwt = deserializer.deserializeStr();
  final uidKey = deserializer.deserializeStr();
  final pepper = deserializer.deserializeFixedBytes(31);
  final ephemeralKeyPair = EphemeralKeyPair.deserialize(deserializer);
  final proof = ZeroKnowledgeSig.deserialize(deserializer);
  final verificationKeyHash = deserializer.deserializeOptionFixedBytes(32);
  return (
    jwt: jwt,
    uidKey: uidKey,
    pepper: pepper,
    ephemeralKeyPair: ephemeralKeyPair,
    proof: proof,
    verificationKeyHash: verificationKeyHash,
  );
}

/// Utility functions for working with accounts.
abstract final class AccountUtils {
  /// Serializes an account into bytes: the signing scheme variant, account
  /// address, and the scheme-specific key material.
  ///
  /// Throws a [StateError] for unsupported account or key types.
  static Uint8List toBytes(Account account) {
    final serializer = Serializer();
    serializer.serializeU32AsUleb128(account.signingScheme.value);
    account.accountAddress.serialize(serializer);
    switch (account.signingScheme) {
      case SigningScheme.ed25519:
        (account as Ed25519Account).privateKey.serialize(serializer);
        return serializer.toUint8List();
      case SigningScheme.singleKey:
        if (!isSingleKeySigner(account)) {
          throw StateError('Account is not a SingleKeySigner');
        }
        final anyPublicKey = (account as SingleKeySigner).getAnyPublicKey();
        serializer.serializeU32AsUleb128(anyPublicKey.variant.value);
        switch (anyPublicKey.variant) {
          case AnyPublicKeyVariant.keyless:
            final keylessAccount = account as KeylessAccount;
            _serializeKeylessAccountCommon(keylessAccount, serializer);
            return serializer.toUint8List();
          case AnyPublicKeyVariant.federatedKeyless:
            final federatedKeylessAccount = account as FederatedKeylessAccount;
            _serializeKeylessAccountCommon(federatedKeylessAccount, serializer);
            federatedKeylessAccount.publicKey.jwkAddress
                .serialize(serializer);
            serializer.serializeBool(federatedKeylessAccount.audless);
            return serializer.toUint8List();
          case AnyPublicKeyVariant.secp256k1:
          case AnyPublicKeyVariant.ed25519:
            final singleKeyAccount = account as SingleKeyAccount;
            // Ed25519PrivateKey and Secp256k1PrivateKey are both
            // BCS-serializable.
            (singleKeyAccount.privateKey as Serializable)
                .serialize(serializer);
            return serializer.toUint8List();
          default:
            throw StateError(
              'Invalid public key variant: ${anyPublicKey.variant}',
            );
        }
      case SigningScheme.multiKey:
        final multiKeyAccount = account as MultiKeyAccount;
        multiKeyAccount.publicKey.serialize(serializer);
        serializer.serializeU32AsUleb128(multiKeyAccount.signers.length);
        for (final signer in multiKeyAccount.signers) {
          serializer.serializeFixedBytes(toBytes(signer));
        }
        return serializer.toUint8List();
      default:
        throw StateError(
          'Serialization of Account failed: invalid signingScheme value '
          '${account.signingScheme}',
        );
    }
  }

  /// Returns the serialized account as a hex string without the 0x prefix.
  static String toHexStringWithoutPrefix(Account account) {
    return Hex.hexInputToStringWithoutPrefix(toBytes(account));
  }

  /// Returns the serialized account as a hex string with a 0x prefix.
  static String toHexString(Account account) {
    return Hex.hexInputToString(toBytes(account));
  }

  /// Deserializes an account from the provided deserializer.
  ///
  /// Throws a [StateError] for invalid signing schemes or key variants.
  static Account deserialize(Deserializer deserializer) {
    final schemeAndAddress = deserializeSchemeAndAddress(deserializer);
    final address = schemeAndAddress.address;
    switch (schemeAndAddress.signingScheme) {
      case SigningScheme.ed25519:
        final privateKey = Ed25519PrivateKey.deserialize(deserializer);
        return Ed25519Account(privateKey: privateKey, address: address);
      case SigningScheme.singleKey:
        final variantIndex = deserializer.deserializeUleb128AsU32();
        if (variantIndex == AnyPublicKeyVariant.ed25519.value) {
          final privateKey = Ed25519PrivateKey.deserialize(deserializer);
          return SingleKeyAccount(privateKey: privateKey, address: address);
        } else if (variantIndex == AnyPublicKeyVariant.secp256k1.value) {
          final privateKey = Secp256k1PrivateKey.deserialize(deserializer);
          return SingleKeyAccount(privateKey: privateKey, address: address);
        } else if (variantIndex == AnyPublicKeyVariant.keyless.value) {
          final components = _deserializeKeylessAccountCommon(deserializer);
          final claims = getIssAudAndUidVal(
            jwt: components.jwt,
            uidKey: components.uidKey,
          );
          return KeylessAccount(
            address: address,
            jwt: components.jwt,
            uidKey: components.uidKey,
            pepper: components.pepper,
            ephemeralKeyPair: components.ephemeralKeyPair,
            proof: components.proof,
            verificationKeyHash: components.verificationKeyHash,
            iss: claims.iss,
            uidVal: claims.uidVal,
            aud: claims.aud,
          );
        } else if (variantIndex ==
            AnyPublicKeyVariant.federatedKeyless.value) {
          final components = _deserializeKeylessAccountCommon(deserializer);
          final jwkAddress = AccountAddress.deserialize(deserializer);
          final audless = deserializer.deserializeBool();
          final claims = getIssAudAndUidVal(
            jwt: components.jwt,
            uidKey: components.uidKey,
          );
          return FederatedKeylessAccount(
            address: address,
            jwt: components.jwt,
            uidKey: components.uidKey,
            pepper: components.pepper,
            ephemeralKeyPair: components.ephemeralKeyPair,
            proof: components.proof,
            verificationKeyHash: components.verificationKeyHash,
            jwkAddress: jwkAddress,
            audless: audless,
            iss: claims.iss,
            uidVal: claims.uidVal,
            aud: claims.aud,
          );
        } else {
          throw StateError('Unsupported public key variant $variantIndex');
        }
      case SigningScheme.multiKey:
        final multiKey = MultiKey.deserialize(deserializer);
        final length = deserializer.deserializeUleb128AsU32();
        final signers = <SingleKeySignerOrLegacyEd25519Account>[];
        for (var i = 0; i < length; i += 1) {
          final signer = deserialize(deserializer);
          if (!isSingleKeySigner(signer) && signer is! Ed25519Account) {
            throw StateError(
              'Deserialization of MultiKeyAccount failed. Signer is not a '
              'SingleKeySigner or Ed25519Account',
            );
          }
          signers.add(signer);
        }
        return MultiKeyAccount(
          multiKey: multiKey,
          signers: signers,
          address: address,
        );
      default:
        throw StateError(
          'Deserialization of Account failed: invalid signingScheme value '
          '${schemeAndAddress.signingScheme}',
        );
    }
  }

  /// Deserializes a [KeylessAccount] from hex.
  ///
  /// Throws a [StateError] if the account is not a KeylessAccount.
  static KeylessAccount keylessAccountFromHex(HexInput hex) {
    final account = fromHex(hex);
    if (account is! KeylessAccount) {
      throw StateError('Deserialization of KeylessAccount failed');
    }
    return account;
  }

  /// Deserializes a [FederatedKeylessAccount] from hex.
  ///
  /// Throws a [StateError] if the account is not a FederatedKeylessAccount.
  static FederatedKeylessAccount federatedKeylessAccountFromHex(
    HexInput hex,
  ) {
    final account = fromHex(hex);
    if (account is! FederatedKeylessAccount) {
      throw StateError('Deserialization of FederatedKeylessAccount failed');
    }
    return account;
  }

  /// Deserializes a [MultiKeyAccount] from hex.
  ///
  /// Throws a [StateError] if the account is not a MultiKeyAccount.
  static MultiKeyAccount multiKeyAccountFromHex(HexInput hex) {
    final account = fromHex(hex);
    if (account is! MultiKeyAccount) {
      throw StateError('Deserialization of MultiKeyAccount failed');
    }
    return account;
  }

  /// Deserializes a [SingleKeyAccount] from hex.
  ///
  /// Throws a [StateError] if the account is not a SingleKeyAccount.
  static SingleKeyAccount singleKeyAccountFromHex(HexInput hex) {
    final account = fromHex(hex);
    if (account is! SingleKeyAccount) {
      throw StateError('Deserialization of SingleKeyAccount failed');
    }
    return account;
  }

  /// Deserializes an [Ed25519Account] from hex.
  ///
  /// Throws a [StateError] if the account is not an Ed25519Account.
  static Ed25519Account ed25519AccountFromHex(HexInput hex) {
    final account = fromHex(hex);
    if (account is! Ed25519Account) {
      throw StateError('Deserialization of Ed25519Account failed');
    }
    return account;
  }

  /// Deserializes an account from hex.
  static Account fromHex(HexInput hex) {
    return deserialize(Deserializer.fromHex(hex));
  }

  /// Deserializes an account from bytes.
  static Account fromBytes(Uint8List bytes) {
    return fromHex(bytes);
  }
}
