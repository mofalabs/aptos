

import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:aptos/aptos_types/authenticator.dart';
import 'package:aptos/aptos_types/identifier.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/utils/sha.dart';
import 'package:pointycastle/digests/sha3.dart';

class RawTransaction with Serializable {
  /**
   * RawTransactions contain the metadata and payloads that can be submitted to Aptos chain for execution.
   * RawTransactions must be signed before Aptos chain can execute them.
   *
   * @param sender Account address of the sender.
   * @param sequence_number Sequence number of this transaction. This must match the sequence number stored in
   *   the sender's account at the time the transaction executes.
   * @param payload Instructions for the Aptos Blockchain, including publishing a module,
   *   execute a entry function or execute a script payload.
   * @param max_gas_amount Maximum total gas to spend for this transaction. The account must have more
   *   than this gas or the transaction will be discarded during validation.
   * @param gas_unit_price Price to be paid per gas unit.
   * @param expiration_timestamp_secs The blockchain timestamp at which the blockchain would discard this transaction.
   * @param chain_id The chain ID of the blockchain that this transaction is intended to be run on.
   */
  RawTransaction(
    this.sender, 
    this.sequenceNumber, 
    this.payload, 
    this.maxGasAmount, 
    this.gasUnitPrice, 
    this.expirationTimestampSecs, 
    this.chainId);

  final AccountAddress sender;
  final BigInt sequenceNumber;
  final TransactionPayload payload;
  final BigInt maxGasAmount;
  final BigInt gasUnitPrice;
  final BigInt expirationTimestampSecs;
  final ChainId chainId;

  @override
  void serialize(Serializer serializer) {
    sender.serialize(serializer);
    serializer.serializeU64(sequenceNumber);
    payload.serialize(serializer);
    serializer.serializeU64(maxGasAmount);
    serializer.serializeU64(gasUnitPrice);
    serializer.serializeU64(expirationTimestampSecs);
    chainId.serialize(serializer);
  }

  static RawTransaction deserialize(Deserializer deserializer) {
    final sender = AccountAddress.deserialize(deserializer);
    final sequenceNumber = deserializer.deserializeU64();
    final payload = TransactionPayload.deserialize(deserializer);
    final maxGasAmount = deserializer.deserializeU64();
    final gasUnitPrice = deserializer.deserializeU64();
    final expirationTimestampSecs = deserializer.deserializeU64();
    final chainId = ChainId.deserialize(deserializer);
    return RawTransaction(
      sender,
      sequenceNumber,
      payload,
      maxGasAmount,
      gasUnitPrice,
      expirationTimestampSecs,
      chainId,
    );
  }
}

class Script with Serializable {

  Script(this.code, this.typeArgs, this.args);

  final Uint8List code;
  final List<TypeTag> typeArgs;
  final List<TransactionArgument> args;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(code);
    serializeVector<TypeTag>(typeArgs, serializer);
    serializeVector<TransactionArgument>(args, serializer);
  }

  static Script deserialize(Deserializer deserializer) {
    final code = deserializer.deserializeBytes();
    final typeArgs = deserializeVector<TypeTag>(deserializer, TypeTag.deserialize);
    final args = deserializeVector<TransactionArgument>(deserializer, TransactionArgument.deserialize);
    return Script(code, typeArgs, args);
  }
}

class EntryFunction with Serializable {

  EntryFunction(this.moduleName, this.functionName, this.typeArgs, this.args);

  final ModuleId moduleName;
  final Identifier functionName;
  final List<TypeTag> typeArgs;
  final List<Uint8List> args;

  static EntryFunction natural(String module, String func, List<TypeTag> typeArgs, List<Uint8List> args) {
    return EntryFunction(ModuleId.fromStr(module), Identifier(func), typeArgs, args);
  }

  static EntryFunction natual(String module, String func, List<TypeTag> typeArgs, List<Uint8List> args) {
    return EntryFunction.natural(module, func, typeArgs, args);
  }

  @override
  void serialize(Serializer serializer) {
    moduleName.serialize(serializer);
    functionName.serialize(serializer);
    serializeVector<TypeTag>(typeArgs, serializer);

    serializer.serializeU32AsUleb128(args.length);
    args.forEach((item) {
      serializer.serializeBytes(item);
    });
  }

  static EntryFunction deserialize(Deserializer deserializer) {
    final moduleName = ModuleId.deserialize(deserializer);
    final functionName = Identifier.deserialize(deserializer);
    final typeArgs = deserializeVector<TypeTag>(deserializer, TypeTag.deserialize);

    final length = deserializer.deserializeUleb128AsU32();
    final list = <Uint8List>[];
    for (int i = 0; i < length; i += 1) {
      list.add(deserializer.deserializeBytes());
    }

    final args = list;
    return EntryFunction(moduleName, functionName, typeArgs, args);
  }
}

class Module with Serializable {

  Module(this.code);

  final Uint8List code;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(code);
  }

  static Module deserialize(Deserializer deserializer) {
    final code = deserializer.deserializeBytes();
    return Module(code);
  }
}

class ModuleId with Serializable {

  ModuleId(this.address, this.name);

  final AccountAddress address;
  final Identifier name;

  /**
   * Converts a string literal to a ModuleId
   * @param moduleId String literal in format "AccountAddress::module_name",
   *   e.g. "0x1::coin"
   * @returns
   */
  static ModuleId fromStr(String moduleId) {
    final parts = moduleId.split("::");
    if (parts.length != 2) {
      throw ArgumentError("Invalid module id.");
    }
    return ModuleId(AccountAddress.fromHex(HexString(parts[0]).hex()), Identifier(parts[1]));
  }

  @override
  void serialize(Serializer serializer) {
    address.serialize(serializer);
    name.serialize(serializer);
  }

  static ModuleId deserialize(Deserializer deserializer) {
    final address = AccountAddress.deserialize(deserializer);
    final name = Identifier.deserialize(deserializer);
    return ModuleId(address, name);
  }
}

class ChangeSet with Serializable {

  @override
  void serialize(Serializer serializer) {
    throw UnimplementedError("Not implemented.");
  }

  static ChangeSet deserialize(Deserializer deserializer) {
    throw UnimplementedError("Not implemented.");
  }
}

class WriteSet with Serializable {

  @override
  void serialize(Serializer serializer) {
    throw UnimplementedError("Not implemented.");
  }

  static WriteSet deserialize(Deserializer deserializer) {
    throw UnimplementedError("Not implemented.");
  }
}

class SignedTransaction with Serializable {
  
  SignedTransaction(this.rawTxn, this.authenticator);

  final RawTransaction rawTxn;
  final TransactionAuthenticator authenticator;

  @override
  void serialize(Serializer serializer) {
    rawTxn.serialize(serializer);
    authenticator.serialize(serializer);
  }

  static SignedTransaction deserialize(Deserializer deserializer) {
    final rawTxn = RawTransaction.deserialize(deserializer);
    final authenticator = TransactionAuthenticator.deserialize(deserializer);
    return SignedTransaction(rawTxn, authenticator);
  }
}

abstract class RawTransactionWithData with Serializable {

  @override
  void serialize(Serializer serializer);

  static RawTransactionWithData deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return MultiAgentRawTransaction.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for RawTransactionWithData: $index");
    }
  }
}

class MultiAgentRawTransaction extends RawTransactionWithData {
  MultiAgentRawTransaction(this.rawTxn, this.secondarySignerAddresses): super();

  final RawTransaction rawTxn;
  final List<AccountAddress> secondarySignerAddresses;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    rawTxn.serialize(serializer);
    serializeVector<AccountAddress>(secondarySignerAddresses, serializer);
  }

  static MultiAgentRawTransaction load(Deserializer deserializer) {
    final rawTxn = RawTransaction.deserialize(deserializer);
    final secondarySignerAddresses = deserializeVector<AccountAddress>(
      deserializer, 
      AccountAddress.deserialize
    );

    return MultiAgentRawTransaction(rawTxn, secondarySignerAddresses);
  }
}

abstract class TransactionPayload with Serializable {

  @override
  void serialize(Serializer serializer);

  static TransactionPayload deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return TransactionPayloadScript.load(deserializer);
      // TODO: change to 1 once ModuleBundle has been removed from rust
      case 2:
        return TransactionPayloadEntryFunction.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for TransactionPayload: $index");
    }
  }
}

class TransactionPayloadScript extends TransactionPayload {
  TransactionPayloadScript(this.value): super();

  final Script value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    value.serialize(serializer);
  }

  static TransactionPayloadScript load(Deserializer deserializer) {
    final value = Script.deserialize(deserializer);
    return TransactionPayloadScript(value);
  }
}

class TransactionPayloadEntryFunction extends TransactionPayload {
  TransactionPayloadEntryFunction(this.value): super();

  final EntryFunction value; 

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(2);
    value.serialize(serializer);
  }

  static TransactionPayloadEntryFunction load(Deserializer deserializer) {
    final value = EntryFunction.deserialize(deserializer);
    return TransactionPayloadEntryFunction(value);
  }
}

class ChainId with Serializable {
  ChainId(this.value);

  final int value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU8(value);
  }

  static ChainId deserialize(Deserializer deserializer) {
    final value = deserializer.deserializeU8();
    return ChainId(value);
  }
}

abstract class TransactionArgument with Serializable {

  @override
  void serialize(Serializer serializer);

  static TransactionArgument deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return TransactionArgumentU8.load(deserializer);
      case 1:
        return TransactionArgumentU64.load(deserializer);
      case 2:
        return TransactionArgumentU128.load(deserializer);
      case 3:
        return TransactionArgumentAddress.load(deserializer);
      case 4:
        return TransactionArgumentU8Vector.load(deserializer);
      case 5:
        return TransactionArgumentBool.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for TransactionArgument: $index");
    }
  }
}

class TransactionArgumentU8 extends TransactionArgument {
  TransactionArgumentU8(this.value): super();

  final int value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    serializer.serializeU8(value);
  }

  static TransactionArgumentU8 load(Deserializer deserializer) {
    final value = deserializer.deserializeU8();
    return TransactionArgumentU8(value);
  }
}

class TransactionArgumentU64 extends TransactionArgument {
  TransactionArgumentU64(this.value): super();

  final BigInt value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(1);
    serializer.serializeU64(value);
  }

  static TransactionArgumentU64 load(Deserializer deserializer) {
    final value = deserializer.deserializeU64();
    return TransactionArgumentU64(value);
  }
}

class TransactionArgumentU128 extends TransactionArgument {
  TransactionArgumentU128(this.value): super();

  final BigInt value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(2);
    serializer.serializeU128(value);
  }

  static TransactionArgumentU128 load(Deserializer deserializer) {
    final value = deserializer.deserializeU128();
    return TransactionArgumentU128(value);
  }
}

class TransactionArgumentAddress extends TransactionArgument {
  TransactionArgumentAddress(this.value): super();

  final AccountAddress value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(3);
    value.serialize(serializer);
  }

  static TransactionArgumentAddress load(Deserializer deserializer) {
    final value = AccountAddress.deserialize(deserializer);
    return TransactionArgumentAddress(value);
  }
}

class TransactionArgumentU8Vector extends TransactionArgument {
  TransactionArgumentU8Vector(this.value): super();

  final Uint8List value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(4);
    serializer.serializeBytes(value);
  }

  static TransactionArgumentU8Vector load(Deserializer deserializer) {
    final value = deserializer.deserializeBytes();
    return TransactionArgumentU8Vector(value);
  }
}

class TransactionArgumentBool extends TransactionArgument {
  TransactionArgumentBool(this.value): super();

  final bool value;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(5);
    serializer.serializeBool(value);
  }

  static TransactionArgumentBool load(Deserializer deserializer) {
    final value = deserializer.deserializeBool();
    return TransactionArgumentBool(value);
  }
}

abstract class Transaction with Serializable {

  @override
  void serialize(Serializer serializer);

  Uint8List hash();

  Uint8List getHashSalt() {
    return sha3256FromString("APTOS::Transaction");
  }

  static Transaction deserialize(Deserializer deserializer) {
    int index = deserializer.deserializeUleb128AsU32();
    switch (index) {
      case 0:
        return UserTransaction.load(deserializer);
      default:
        throw ArgumentError("Unknown variant index for Transaction: $index");
    }
  }
}

class UserTransaction extends Transaction {
  UserTransaction(this.value): super();

  final SignedTransaction value;

  @override
  Uint8List hash() {
    final sha3Hash = SHA3Digest(256);
    final data = <int>[];
    data.addAll(getHashSalt());
    data.addAll(bcsToBytes(this));
    return sha3Hash.process(Uint8List.fromList(data));
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeU32AsUleb128(0);
    value.serialize(serializer);
  }

  static UserTransaction load(Deserializer deserializer) {
    return UserTransaction(SignedTransaction.deserialize(deserializer));
  }
}
