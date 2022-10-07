
import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/multi_ed25519.dart';

abstract class TransactionAuthenticator with Serializable {

  @override
  void serialize(Serializer serializer);

  static TransactionAuthenticator deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return TransactionAuthenticatorEd25519.load(deserializer);
      case 1:
        return TransactionAuthenticatorMultiEd25519.load(deserializer);
      case 2:
        return TransactionAuthenticatorMultiAgent.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for TransactionAuthenticator: $index");
    }
  }
}

class TransactionAuthenticatorEd25519 extends TransactionAuthenticator {

  TransactionAuthenticatorEd25519(this.publicKey, this.signature): super();

  final Ed25519PublicKey publicKey;
  final Ed25519Signature signature;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static TransactionAuthenticatorEd25519 load(Deserializer deserializer) {
    final publicKey = Ed25519PublicKey.deserialize(deserializer);
    final signature = Ed25519Signature.deserialize(deserializer);
    return TransactionAuthenticatorEd25519(publicKey, signature);
  }
}

class TransactionAuthenticatorMultiEd25519 extends TransactionAuthenticator {

  TransactionAuthenticatorMultiEd25519(this.publicKey, this.signature): super();

  final MultiEd25519PublicKey publicKey;
  final MultiEd25519Signature signature;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static TransactionAuthenticatorMultiEd25519 load(Deserializer deserializer) {
    final publicKey = MultiEd25519PublicKey.deserialize(deserializer);
    final signature = MultiEd25519Signature.deserialize(deserializer);
    return TransactionAuthenticatorMultiEd25519(publicKey, signature);
  }
}

class TransactionAuthenticatorMultiAgent extends TransactionAuthenticator {
  TransactionAuthenticatorMultiAgent(
   this.sender,
   this.secondarySignerAddresses,
   this.secondarySigners
  ): super();

  final AccountAuthenticator sender;
  final List<AccountAddress> secondarySignerAddresses;
  final List<AccountAuthenticator> secondarySigners;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(2);
    sender.serialize(serializer);
    serializeVector<AccountAddress>(secondarySignerAddresses, serializer);
    serializeVector<AccountAuthenticator>(secondarySigners, serializer);
  }

  static TransactionAuthenticatorMultiAgent load(Deserializer deserializer) {
    final sender = AccountAuthenticator.deserialize(deserializer);
    final secondarySignerAddresses = deserializeVector<AccountAddress>(deserializer, AccountAddress.deserialize);
    final secondarySigners = deserializeVector<AccountAuthenticator>(deserializer, AccountAuthenticator.deserialize);
    return TransactionAuthenticatorMultiAgent(sender, secondarySignerAddresses, secondarySigners);
  }
}

abstract class AccountAuthenticator with Serializable {

  @override
  void serialize(Serializer serializer);

  static AccountAuthenticator deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return AccountAuthenticatorEd25519.load(deserializer);
      case 1:
        return AccountAuthenticatorMultiEd25519.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for AccountAuthenticator: $index");
    }
  }
}

class AccountAuthenticatorEd25519 extends AccountAuthenticator {
  AccountAuthenticatorEd25519(this.publicKey, this.signature): super();

  final Ed25519PublicKey publicKey;
  final Ed25519Signature signature;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static AccountAuthenticatorEd25519 load(Deserializer deserializer) {
    final publicKey = Ed25519PublicKey.deserialize(deserializer);
    final signature = Ed25519Signature.deserialize(deserializer);
    return AccountAuthenticatorEd25519(publicKey, signature);
  }
}

class AccountAuthenticatorMultiEd25519 extends AccountAuthenticator {
  AccountAuthenticatorMultiEd25519(this.publicKey, this.signature): super();

  final MultiEd25519PublicKey publicKey;
  final MultiEd25519Signature signature;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
    publicKey.serialize(serializer);
    signature.serialize(serializer);
  }

  static AccountAuthenticatorMultiEd25519 load(Deserializer deserializer) {
    final publicKey = MultiEd25519PublicKey.deserialize(deserializer);
    final signature = MultiEd25519Signature.deserialize(deserializer);
    return AccountAuthenticatorMultiEd25519(publicKey, signature);
  }
}
