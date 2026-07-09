import '../../bcs/deserializer.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../core/crypto/ed25519.dart';
import '../../core/crypto/multi_ed25519.dart';
import '../../types/types.dart';
import 'account.dart';

/// Represents an abstract base class for transaction authenticators.
///
/// This class provides methods for serializing and deserializing different
/// types of transaction authenticators.
abstract class TransactionAuthenticator extends Serializable {
  @override
  void serialize(Serializer serializer);

  /// Deserializes a TransactionAuthenticator from the provided deserializer.
  /// This function helps in reconstructing the TransactionAuthenticator based
  /// on the variant index found in the serialized data.
  static TransactionAuthenticator deserialize(Deserializer deserializer) {
    final index = deserializer.deserializeUleb128AsU32();
    if (index == TransactionAuthenticatorVariant.ed25519.value) {
      return TransactionAuthenticatorEd25519.load(deserializer);
    } else if (index == TransactionAuthenticatorVariant.multiEd25519.value) {
      return TransactionAuthenticatorMultiEd25519.load(deserializer);
    } else if (index == TransactionAuthenticatorVariant.multiAgent.value) {
      return TransactionAuthenticatorMultiAgent.load(deserializer);
    } else if (index == TransactionAuthenticatorVariant.feePayer.value) {
      return TransactionAuthenticatorFeePayer.load(deserializer);
    } else if (index == TransactionAuthenticatorVariant.singleSender.value) {
      return TransactionAuthenticatorSingleSender.load(deserializer);
    }
    throw StateError(
      'Unknown variant index for TransactionAuthenticator: $index',
    );
  }

  bool isEd25519() => this is TransactionAuthenticatorEd25519;

  bool isMultiEd25519() => this is TransactionAuthenticatorMultiEd25519;

  bool isMultiAgent() => this is TransactionAuthenticatorMultiAgent;

  bool isFeePayer() => this is TransactionAuthenticatorFeePayer;

  bool isSingleSender() => this is TransactionAuthenticatorSingleSender;
}

/// Represents a transaction authenticator using Ed25519 for a single signer
/// transaction.
///
/// This class encapsulates the client's public key and the Ed25519 signature
/// of a raw transaction.
class TransactionAuthenticatorEd25519 extends TransactionAuthenticator {
  /// The client's public key.
  final Ed25519PublicKey publicKey;

  /// The Ed25519 signature of a raw transaction.
  final Ed25519Signature signature;

  /// Creates an instance of the class with the specified public key and
  /// signature.
  TransactionAuthenticatorEd25519(this.publicKey, this.signature);

  /// Serializes the transaction authenticator by encoding the sender
  /// information.
  @override
  void serialize(Serializer serializer) {
    serializer
        .serializeU32AsUleb128(TransactionAuthenticatorVariant.ed25519.value);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  /// Loads a TransactionAuthenticatorEd25519 instance from the provided
  /// deserializer.
  static TransactionAuthenticatorEd25519 load(Deserializer deserializer) {
    final publicKey = Ed25519PublicKey.deserialize(deserializer);
    final signature = Ed25519Signature.deserialize(deserializer);
    return TransactionAuthenticatorEd25519(publicKey, signature);
  }
}

/// Represents a transaction authenticator for multi-signature transactions
/// using Ed25519.
///
/// This class is used to validate transactions that require multiple
/// signatures from different signers.
class TransactionAuthenticatorMultiEd25519 extends TransactionAuthenticator {
  /// The MultiEd25519 public key of the client involved in the transaction.
  final MultiEd25519PublicKey publicKey;

  /// The multi-signature of the raw transaction.
  final MultiEd25519Signature signature;

  TransactionAuthenticatorMultiEd25519(this.publicKey, this.signature);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionAuthenticatorVariant.multiEd25519.value,
    );
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static TransactionAuthenticatorMultiEd25519 load(Deserializer deserializer) {
    final publicKey = MultiEd25519PublicKey.deserialize(deserializer);
    final signature = MultiEd25519Signature.deserialize(deserializer);
    return TransactionAuthenticatorMultiEd25519(publicKey, signature);
  }
}

/// Represents a transaction authenticator for a multi-agent transaction.
///
/// This class manages the authentication process involving a primary sender
/// and multiple secondary signers.
class TransactionAuthenticatorMultiAgent extends TransactionAuthenticator {
  /// The authenticator for the sender account.
  final AccountAuthenticator sender;

  /// The addresses of the secondary signers.
  final List<AccountAddress> secondarySignerAddresses;

  /// The authenticators for the secondary signer accounts.
  final List<AccountAuthenticator> secondarySigners;

  TransactionAuthenticatorMultiAgent(
    this.sender,
    this.secondarySignerAddresses,
    this.secondarySigners,
  );

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionAuthenticatorVariant.multiAgent.value,
    );
    sender.serialize(serializer);
    serializer.serializeVector(secondarySignerAddresses);
    serializer.serializeVector(secondarySigners);
  }

  static TransactionAuthenticatorMultiAgent load(Deserializer deserializer) {
    final sender = AccountAuthenticator.deserialize(deserializer);
    final secondarySignerAddresses =
        deserializer.deserializeVector(AccountAddress.deserialize);
    final secondarySigners =
        deserializer.deserializeVector(AccountAuthenticator.deserialize);
    return TransactionAuthenticatorMultiAgent(
      sender,
      secondarySignerAddresses,
      secondarySigners,
    );
  }
}

/// Represents a transaction authenticator specifically for fee payer
/// transactions.
///
/// It encapsulates the sender's account authenticator, addresses of
/// secondary signers, their respective authenticators, and the fee payer's
/// account information.
class TransactionAuthenticatorFeePayer extends TransactionAuthenticator {
  /// The authenticator for the sender's account.
  final AccountAuthenticator sender;

  /// The addresses of the secondary signers.
  final List<AccountAddress> secondarySignerAddresses;

  /// The authenticators for the secondary signers' accounts.
  final List<AccountAuthenticator> secondarySigners;

  /// The fee payer's account address and authenticator.
  final ({AccountAddress address, AccountAuthenticator authenticator}) feePayer;

  TransactionAuthenticatorFeePayer(
    this.sender,
    this.secondarySignerAddresses,
    this.secondarySigners,
    this.feePayer,
  );

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionAuthenticatorVariant.feePayer.value,
    );
    sender.serialize(serializer);
    serializer.serializeVector(secondarySignerAddresses);
    serializer.serializeVector(secondarySigners);
    feePayer.address.serialize(serializer);
    feePayer.authenticator.serialize(serializer);
  }

  static TransactionAuthenticatorFeePayer load(Deserializer deserializer) {
    final sender = AccountAuthenticator.deserialize(deserializer);
    final secondarySignerAddresses =
        deserializer.deserializeVector(AccountAddress.deserialize);
    final secondarySigners =
        deserializer.deserializeVector(AccountAuthenticator.deserialize);
    final address = AccountAddress.deserialize(deserializer);
    final authenticator = AccountAuthenticator.deserialize(deserializer);
    return TransactionAuthenticatorFeePayer(
      sender,
      secondarySignerAddresses,
      secondarySigners,
      (address: address, authenticator: authenticator),
    );
  }
}

/// Represents a single sender authenticator for transactions that require a
/// single signer.
///
/// This class is responsible for managing the authentication of a
/// transaction initiated by a single sender.
class TransactionAuthenticatorSingleSender extends TransactionAuthenticator {
  /// The account authenticator of the sender.
  final AccountAuthenticator sender;

  TransactionAuthenticatorSingleSender(this.sender);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(
      TransactionAuthenticatorVariant.singleSender.value,
    );
    sender.serialize(serializer);
  }

  static TransactionAuthenticatorSingleSender load(Deserializer deserializer) {
    final sender = AccountAuthenticator.deserialize(deserializer);
    return TransactionAuthenticatorSingleSender(sender);
  }
}
