import 'dart:typed_data';

import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../core/crypto/ed25519.dart';
import '../../core/crypto/multi_ed25519.dart';
import '../../core/crypto/multi_key.dart';
import '../../core/crypto/single_key.dart';
import '../../core/hex.dart';
import '../../types/abstraction.dart';
import '../../types/move_types.dart';
import '../../types/types.dart';
import '../../utils/helpers.dart';

// Re-exported so existing imports of this file keep seeing the AA enum
// variants, which live in types/abstraction.dart.
export '../../types/abstraction.dart'
    show AbstractAuthenticationDataVariant, AASigningDataVariant;

/// Represents an account authenticator that can handle multiple
/// authentication variants.
///
/// This class serves as a base for different types of account
/// authenticators, allowing for serialization and deserialization of various
/// authenticator types.
abstract class AccountAuthenticator extends Serializable {
  @override
  void serialize(Serializer serializer);

  /// Deserializes an AccountAuthenticator from the provided deserializer.
  /// This function helps in reconstructing the AccountAuthenticator object
  /// based on the variant index.
  static AccountAuthenticator deserialize(Deserializer deserializer) {
    final index = deserializer.deserializeUleb128AsU32();
    if (index == AccountAuthenticatorVariant.ed25519.value) {
      return AccountAuthenticatorEd25519.load(deserializer);
    } else if (index == AccountAuthenticatorVariant.multiEd25519.value) {
      return AccountAuthenticatorMultiEd25519.load(deserializer);
    } else if (index == AccountAuthenticatorVariant.singleKey.value) {
      return AccountAuthenticatorSingleKey.load(deserializer);
    } else if (index == AccountAuthenticatorVariant.multiKey.value) {
      return AccountAuthenticatorMultiKey.load(deserializer);
    } else if (index ==
        AccountAuthenticatorVariant.noAccountAuthenticator.value) {
      return AccountAuthenticatorNoAccountAuthenticator.load(deserializer);
    } else if (index == AccountAuthenticatorVariant.abstraction.value) {
      return AccountAuthenticatorAbstraction.load(deserializer);
    }
    throw StateError('Unknown variant index for AccountAuthenticator: $index');
  }

  /// Determines if the current instance is an Ed25519 account authenticator.
  bool isEd25519() => this is AccountAuthenticatorEd25519;

  /// Determines if the current instance is of type
  /// AccountAuthenticatorMultiEd25519.
  bool isMultiEd25519() => this is AccountAuthenticatorMultiEd25519;

  /// Determines if the current instance is of the type
  /// AccountAuthenticatorSingleKey.
  bool isSingleKey() => this is AccountAuthenticatorSingleKey;

  /// Determine if the current instance is of type
  /// AccountAuthenticatorMultiKey.
  bool isMultiKey() => this is AccountAuthenticatorMultiKey;
}

/// Represents an Ed25519 transaction authenticator for multi-signer
/// transactions.
///
/// This class encapsulates the account's Ed25519 public key and signature.
class AccountAuthenticatorEd25519 extends AccountAuthenticator {
  /// The Ed25519 public key associated with the account.
  final Ed25519PublicKey publicKey;

  /// The Ed25519 signature for the account.
  final Ed25519Signature signature;

  /// Creates an instance of the class with the specified public key and
  /// signature.
  AccountAuthenticatorEd25519(this.publicKey, this.signature);

  /// Serializes the account authenticator data into the provided serializer,
  /// capturing the variant, public key, and signature.
  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(AccountAuthenticatorVariant.ed25519.value);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  /// Loads an instance of AccountAuthenticatorEd25519 from the provided
  /// deserializer.
  static AccountAuthenticatorEd25519 load(Deserializer deserializer) {
    final publicKey = Ed25519PublicKey.deserialize(deserializer);
    final signature = Ed25519Signature.deserialize(deserializer);
    return AccountAuthenticatorEd25519(publicKey, signature);
  }
}

/// Represents a transaction authenticator for Multi Ed25519, designed for
/// multi-signer transactions.
class AccountAuthenticatorMultiEd25519 extends AccountAuthenticator {
  /// The MultiEd25519 public key of the account.
  final MultiEd25519PublicKey publicKey;

  /// The MultiEd25519 signature of the account.
  final MultiEd25519Signature signature;

  AccountAuthenticatorMultiEd25519(this.publicKey, this.signature);

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(AccountAuthenticatorVariant.multiEd25519.value);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static AccountAuthenticatorMultiEd25519 load(Deserializer deserializer) {
    final publicKey = MultiEd25519PublicKey.deserialize(deserializer);
    final signature = MultiEd25519Signature.deserialize(deserializer);
    return AccountAuthenticatorMultiEd25519(publicKey, signature);
  }
}

/// Represents an account authenticator that utilizes a single key for
/// signing.
///
/// This class is designed to handle authentication using a public key and
/// its corresponding signature.
class AccountAuthenticatorSingleKey extends AccountAuthenticator {
  /// The public key used for authentication.
  final AnyPublicKey publicKey;

  /// The signature associated with the public key.
  final AnySignature signature;

  AccountAuthenticatorSingleKey(this.publicKey, this.signature);

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(AccountAuthenticatorVariant.singleKey.value);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static AccountAuthenticatorSingleKey load(Deserializer deserializer) {
    final publicKey = AnyPublicKey.deserialize(deserializer);
    final signature = AnySignature.deserialize(deserializer);
    return AccountAuthenticatorSingleKey(publicKey, signature);
  }
}

/// Represents an account authenticator that supports multiple keys and
/// signatures for multi-signature scenarios.
class AccountAuthenticatorMultiKey extends AccountAuthenticator {
  /// The public keys used for authentication.
  final MultiKey publicKeys;

  /// The signatures corresponding to the public keys.
  final MultiKeySignature signatures;

  AccountAuthenticatorMultiKey(this.publicKeys, this.signatures);

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(AccountAuthenticatorVariant.multiKey.value);
    publicKeys.serialize(serializer);
    signatures.serialize(serializer);
  }

  static AccountAuthenticatorMultiKey load(Deserializer deserializer) {
    final publicKeys = MultiKey.deserialize(deserializer);
    final signatures = MultiKeySignature.deserialize(deserializer);
    return AccountAuthenticatorMultiKey(publicKeys, signatures);
  }
}

/// AccountAuthenticatorNoAccountAuthenticator for no account authenticator.
///
/// It represents the absence of a public key for transaction simulation.
/// It allows skipping the public/auth key check during the simulation.
class AccountAuthenticatorNoAccountAuthenticator extends AccountAuthenticator {
  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      AccountAuthenticatorVariant.noAccountAuthenticator.value,
    );
  }

  static AccountAuthenticatorNoAccountAuthenticator load(
    Deserializer deserializer,
  ) {
    return AccountAuthenticatorNoAccountAuthenticator();
  }
}

/// Represents an account authenticator that supports abstract
/// authentication.
class AccountAuthenticatorAbstraction extends AccountAuthenticator {
  /// The function info of the authentication function, in the form
  /// `moduleAddress::moduleName::functionName`.
  final MoveFunctionId functionInfo;

  /// The digest of the signing message.
  final Hex signingMessageDigest;

  /// The signature of the authentication function.
  final Uint8List abstractionSignature;

  /// DAA, which is extended of the AA module, requires an account identity.
  final Uint8List? accountIdentity;

  /// Creates an abstraction authenticator.
  ///
  /// [functionInfo] - The function info of the authentication function.
  /// [signingMessageDigest] - The digest of the signing message.
  /// [abstractionSignature] - The signature of the authentication function.
  /// [accountIdentity] - optional. The account identity for DAA.
  ///
  /// Throws an [ArgumentError] if [functionInfo] is not a valid
  /// fully-qualified function name.
  AccountAuthenticatorAbstraction(
    this.functionInfo,
    HexInput signingMessageDigest,
    this.abstractionSignature, [
    this.accountIdentity,
  ]) : signingMessageDigest =
            Hex(Hex.fromHexInput(signingMessageDigest).toUint8List()) {
    if (!isValidFunctionInfo(functionInfo)) {
      throw ArgumentError(
        'Invalid function info $functionInfo passed into '
        'AccountAuthenticatorAbstraction',
      );
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(AccountAuthenticatorVariant.abstraction.value);
    final parts = getFunctionParts(functionInfo);
    AccountAddress.fromString(parts.moduleAddress).serialize(serializer);
    serializer.serializeStr(parts.moduleName);
    serializer.serializeStr(parts.functionName);
    if (accountIdentity != null) {
      serializer.serializeU32AsUleb128(
        AbstractAuthenticationDataVariant.derivableV1.value,
      );
    } else {
      serializer
          .serializeU32AsUleb128(AbstractAuthenticationDataVariant.v1.value);
    }
    serializer.serializeBytes(signingMessageDigest.toUint8List());
    if (accountIdentity != null) {
      serializer.serializeBytes(abstractionSignature);
    } else {
      serializer.serializeFixedBytes(abstractionSignature);
    }

    if (accountIdentity != null) {
      serializer.serializeBytes(accountIdentity!);
    }
  }

  static AccountAuthenticatorAbstraction load(Deserializer deserializer) {
    // Deserialize the function info.
    final moduleAddress = AccountAddress.deserialize(deserializer);
    final moduleName = deserializer.deserializeStr();
    final functionName = deserializer.deserializeStr();
    // Deserialize the variant.
    final variant = deserializer.deserializeUleb128AsU32();
    // Deserialize the signing message digest.
    final signingMessageDigest = deserializer.deserializeBytes();

    if (variant == AbstractAuthenticationDataVariant.v1.value) {
      final abstractionSignature =
          deserializer.deserializeFixedBytes(deserializer.remaining());
      return AccountAuthenticatorAbstraction(
        '$moduleAddress::$moduleName::$functionName',
        signingMessageDigest,
        abstractionSignature,
      );
    }
    if (variant == AbstractAuthenticationDataVariant.derivableV1.value) {
      final abstractionSignature = deserializer.deserializeBytes();
      final abstractPublicKey = deserializer.deserializeBytes();
      return AccountAuthenticatorAbstraction(
        '$moduleAddress::$moduleName::$functionName',
        signingMessageDigest,
        abstractionSignature,
        abstractPublicKey,
      );
    }
    throw StateError(
      'Unknown variant index for AccountAuthenticatorAbstraction: $variant',
    );
  }
}

/// Represents an account abstraction message that contains the original
/// signing message and the function info.
class AccountAbstractionMessage extends Serializable {
  /// The original signing message.
  final Hex originalSigningMessage;

  /// The function info of the authentication function.
  final String functionInfo;

  AccountAbstractionMessage(HexInput originalSigningMessage, this.functionInfo)
      : originalSigningMessage =
            Hex(Hex.fromHexInput(originalSigningMessage).toUint8List());

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(AASigningDataVariant.v1.value);
    serializer.serializeBytes(originalSigningMessage.toUint8List());
    final parts = getFunctionParts(functionInfo);
    AccountAddress.fromString(parts.moduleAddress).serialize(serializer);
    serializer.serializeStr(parts.moduleName);
    serializer.serializeStr(parts.functionName);
  }

  static AccountAbstractionMessage deserialize(Deserializer deserializer) {
    final variant = deserializer.deserializeUleb128AsU32();
    if (variant != AASigningDataVariant.v1.value) {
      throw StateError(
        'Unknown variant index for AccountAbstractionMessage: $variant',
      );
    }
    final originalSigningMessage = deserializer.deserializeBytes();
    final functionInfoModuleAddress = AccountAddress.deserialize(deserializer);
    final functionInfoModuleName = deserializer.deserializeStr();
    final functionInfoFunctionName = deserializer.deserializeStr();
    final functionInfo = '$functionInfoModuleAddress::'
        '$functionInfoModuleName::$functionInfoFunctionName';
    return AccountAbstractionMessage(originalSigningMessage, functionInfo);
  }
}
