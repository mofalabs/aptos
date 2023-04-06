
import 'dart:typed_data';

import 'package:aptos/aptos_types/abi.dart';
import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/authenticator.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/identifier.dart';
import 'package:aptos/aptos_types/multi_ed25519.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/bcs/deserializer.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/bcs/serializer.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/models/account_data.dart';
import 'package:aptos/transaction_builder/builder_utils.dart';
import 'package:aptos/utils/sha.dart';

const RAW_TRANSACTION_SALT = "APTOS::RawTransaction";
const RAW_TRANSACTION_WITH_DATA_SALT = "APTOS::RawTransactionWithData";

const DEFAULT_MAX_GAS_AMOUNT = 20000;
// Transaction expire timestamp
const DEFAULT_TXN_EXP_SEC_FROM_NOW = 20;

// @return Ed25519Signature | MultiEd25519Signature
typedef SigningFn = dynamic Function(Uint8List txn);

class TransactionBuilder<F extends SigningFn> {

  TransactionBuilder(this.signingFunction, {this.rawTxnBuilder});

  final F signingFunction;
  final TransactionBuilderABI? rawTxnBuilder;

  RawTransaction build(String func, List<String> tyTags, List<dynamic> args) {
    if (rawTxnBuilder == null) {
      throw ArgumentError("this.rawTxnBuilder doesn't exist.");
    }

    return rawTxnBuilder!.build(func, tyTags, args);
  }

  static Uint8List getSigningMessage(Serializable rawTxn) {
    Uint8List hash;
    if (rawTxn is RawTransaction) {
      hash = sha3256FromString(RAW_TRANSACTION_SALT);
    } else if (rawTxn is MultiAgentRawTransaction) {
      hash = sha3256FromString(RAW_TRANSACTION_WITH_DATA_SALT);
    } else {
      throw ArgumentError("Unknown transaction type.");
    }

    final prefix = hash;
    final body = bcsToBytes(rawTxn);

    final mergedArray = Uint8List(prefix.length + body.length);
    mergedArray.setAll(0, prefix);
    mergedArray.setAll(prefix.length, body);
    return mergedArray;
  }
}

class TransactionBuilderEd25519 extends TransactionBuilder<SigningFn> {

  TransactionBuilderEd25519(this.publicKey, SigningFn signingFunction, {TransactionBuilderABI? rawTxnBuilder})
    : super(signingFunction, rawTxnBuilder: rawTxnBuilder);

  final Uint8List publicKey;

  SignedTransaction rawToSigned(RawTransaction rawTxn) {
    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = signingFunction(signingMessage);

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(publicKey),
      signature as Ed25519Signature,
    );

    return SignedTransaction(rawTxn, authenticator);
  }

  Uint8List sign(RawTransaction rawTxn) {
    return bcsToBytes(rawToSigned(rawTxn));
  }
}

/// Provides signing method for signing a raw transaction with multisig public key.
class TransactionBuilderMultiEd25519 extends TransactionBuilder<SigningFn> {

  TransactionBuilderMultiEd25519(this.publicKey, SigningFn signingFunction): super(signingFunction);

  final MultiEd25519PublicKey publicKey;

  SignedTransaction rawToSigned(RawTransaction rawTxn) {
    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = signingFunction(signingMessage);

    final authenticator = TransactionAuthenticatorMultiEd25519(publicKey, signature as MultiEd25519Signature);
    return SignedTransaction(rawTxn, authenticator);
  }

  Uint8List sign(RawTransaction rawTxn) {
    return bcsToBytes(rawToSigned(rawTxn));
  }
}


class ABIBuilderConfig {
  ABIBuilderConfig({
    this.sender,
    this.sequenceNumber,
    this.gasUnitPrice,
    this.chainId,
    this.maxGasAmount,
    this.expSecFromNow,
  });

  dynamic sender;
  BigInt? sequenceNumber;
  BigInt? gasUnitPrice;
  BigInt? maxGasAmount;
  BigInt? expSecFromNow;
  int? chainId;
}


class TransactionBuilderABI {
  final abiMap = <String, ScriptABI>{};

  late final ABIBuilderConfig builderConfig;

  TransactionBuilderABI(List<Uint8List> abis, {ABIBuilderConfig? builderConfig}) {

    abis.forEach((abi) {
      var deserializer = Deserializer(abi);
      final scriptABI = ScriptABI.deserialize(deserializer);
      String k;
      if (scriptABI is EntryFunctionABI) {
        final module = scriptABI.moduleName;
        k = "${HexString.fromUint8Array(module.address.address).toShortString()}::${module.name.value}::${scriptABI.name}";
      } else {
        final funcABI = scriptABI as TransactionScriptABI;
        k = funcABI.name;
      }

      if (abiMap.containsKey(k)) {
        throw ArgumentError("Found conflicting ABI interfaces");
      }

      abiMap[k] = scriptABI;
    });

    this.builderConfig = ABIBuilderConfig(
        maxGasAmount: builderConfig?.maxGasAmount ?? BigInt.from(DEFAULT_MAX_GAS_AMOUNT),
        expSecFromNow: builderConfig?.expSecFromNow ?? BigInt.from(DEFAULT_TXN_EXP_SEC_FROM_NOW),
        sender: builderConfig?.sender,
        sequenceNumber: builderConfig?.sequenceNumber,
        gasUnitPrice: builderConfig?.gasUnitPrice,
        chainId: builderConfig?.chainId
      );
  }

  static List<Uint8List> _toBCSArgs(List<ArgumentABI> abiArgs, List<dynamic> args) {
    if (abiArgs.length != args.length) {
      throw ArgumentError("Wrong number of args provided.");
    }

    final result = <Uint8List>[];
    for (int i = 0; i < args.length; i++) {
      final serializer = Serializer();
      serializeArg(args[i], abiArgs[i].typeTag, serializer);
      result.add(serializer.getBytes());
    }
    return result;
  }

  static List<TransactionArgument> _toTransactionArguments(List<ArgumentABI> abiArgs, List<dynamic> args) {
    if (abiArgs.length != args.length) {
      throw ArgumentError("Wrong number of args provided.");
    }

    final result = <TransactionArgument>[];
    for (int i = 0; i < args.length; i++) {
      result.add(argToTransactionArgument(args[i], abiArgs[i].typeTag));
    }
    return result;
  }

  setSequenceNumber(dynamic seqNumber) {
    builderConfig.sequenceNumber = BigInt.parse(seqNumber.toString());
  }

  TransactionPayload buildTransactionPayload(String func, List<String> tyTags, List<dynamic> args) {

    final typeTags = tyTags.map((e) => TypeTagParser(e).parseTypeTag()).toList();

    TransactionPayload payload;

    if (!abiMap.containsKey(func)) {
      throw ArgumentError("Cannot find function: $func");
    }

    final scriptABI = abiMap[func];

    if (scriptABI is EntryFunctionABI) {
      final bcsArgs = TransactionBuilderABI._toBCSArgs(scriptABI.args, args);
      payload = TransactionPayloadEntryFunction(
        EntryFunction(scriptABI.moduleName, Identifier(scriptABI.name), typeTags, bcsArgs),
      );
    } else if (scriptABI is TransactionScriptABI) {
      final scriptArgs = TransactionBuilderABI._toTransactionArguments(scriptABI.args, args);
      payload = TransactionPayloadScript(Script(scriptABI.code, typeTags, scriptArgs));
    } else {
      /* istanbul ignore next */
      throw ArgumentError("Unknown ABI format.");
    }

    return payload;
  }

  RawTransaction build(String func, List<String> tyTags, List<dynamic> args) {
    if (builderConfig.gasUnitPrice == null) {
      throw ArgumentError("No gasUnitPrice provided.");
    }

    final senderAccount = builderConfig.sender is AccountAddress ? builderConfig.sender : AccountAddress.fromHex(builderConfig.sender);
    final nowSeconds = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond);
    final addSeconds = builderConfig.expSecFromNow ?? BigInt.from(DEFAULT_TXN_EXP_SEC_FROM_NOW);
    final expTimestampSec = nowSeconds + addSeconds;
    final payload = buildTransactionPayload(func, tyTags, args);

    return RawTransaction(
      senderAccount,
      builderConfig.sequenceNumber!,
      payload,
      builderConfig.maxGasAmount!,
      builderConfig.gasUnitPrice!,
      expTimestampSec,
      ChainId(builderConfig.chainId!),
    );
  }
}

mixin AptosClientInterface {
  Future<dynamic> getAccountModules(String address);
  Future<AccountData> getAccount(String address);
  Future<int> getChainId();
  Future<int> estimateGasPrice();
}

class TransactionBuilderRemoteABI {
  // We don't want the builder to depend on the actual AptosClient.
  // There might be circular dependencies.
  TransactionBuilderRemoteABI(this.aptosClient, this.builderConfig);

  final AptosClientInterface aptosClient;
  final ABIBuilderConfig builderConfig;

  Future<Map<String, dynamic>> fetchABI(String addr) async {
    final modules = await aptosClient.getAccountModules(addr);
    final abis = (modules as List)
      .map((module) => module["abi"])
      .expand((abi) =>
        abi["exposed_functions"]
          .where((ef) => ef["is_entry"] as bool)
          .map((ef) => {
                "fullName": "${abi["address"]}::${abi["name"]}::${ef["name"]}",
                ...ef,
              },
          ),
      );

    final abiMap = <String, dynamic>{};
    for (var abi in abis) {
      abiMap[abi["fullName"]] = abi;
    }

    return abiMap;
  }


  Future<RawTransaction> build(String func, List<String> typeArgs, List<dynamic> args) async {
    func = func.replaceAll(RegExp(r"^0[xX]0*"), "0x");
    final funcNameParts = func.split("::");
    if (funcNameParts.length != 3) {
      throw ArgumentError(
        "'func' needs to be a fully qualified function name in format <address>::<module>::<function>, e.g. 0x1::coins::transfer",
      );
    }

    final addr = funcNameParts[0];
    final module = funcNameParts[1];

    final abiMap = await fetchABI(addr);
    if (!abiMap.containsKey(func)) {
      throw ArgumentError("$func doesn't exist.");
    }

    final funcAbi = abiMap[func];

    // Remove all `signer` and `&signer` from argument list because the Move VM injects those arguments. Clients do not
    // need to care about those args. `signer` and `&signer` are required be in the front of the argument list. But we
    // just loop through all arguments and filter out `signer` and `&signer`.
    final originalArgs = (funcAbi["params"] as List).where((param) => param != "signer" && param != "&signer").toList();

    // Convert string arguments to TypeArgumentABI
    final typeArgABIs = <ArgumentABI>[];
    for (var i = 0; i < originalArgs.length; i++) {
      typeArgABIs.add(ArgumentABI("var$i", TypeTagParser(originalArgs[i]).parseTypeTag()));
    }

    final genericTypeParams = funcAbi["generic_type_params"];
    final genericTypeParamsList = <TypeArgumentABI>[];
    for (var i = 0; i < genericTypeParams.length; i++) {
      genericTypeParamsList.add(TypeArgumentABI("$i"));
    }

    final entryFunctionABI = EntryFunctionABI(
      funcAbi["name"],
      ModuleId.fromStr("$addr::$module"),
      "",
      genericTypeParamsList,
      typeArgABIs,
    );

    final sender = builderConfig.sender;
    final senderAddress = sender is AccountAddress ? HexString.fromUint8Array(sender.address).hex() : sender;
    final sequenceNumber = builderConfig.sequenceNumber ?? BigInt.parse((await aptosClient.getAccount(senderAddress)).sequenceNumber);
    final chainId = builderConfig.chainId ?? await aptosClient.getChainId();
    final gasUnitPrice = builderConfig.gasUnitPrice ?? BigInt.from(await aptosClient.estimateGasPrice());

    final config = ABIBuilderConfig(
      sender: sender,
      sequenceNumber: sequenceNumber,
      gasUnitPrice: gasUnitPrice,
      chainId: chainId,
      maxGasAmount: builderConfig.maxGasAmount,
      expSecFromNow: builderConfig.expSecFromNow
    );
    final builderABI = TransactionBuilderABI([bcsToBytes(entryFunctionABI)], builderConfig: config);

    return builderABI.build(func, typeArgs, args);
  }
}
