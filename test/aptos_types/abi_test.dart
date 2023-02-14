
import 'package:aptos/aptos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  const SCRIPT_FUNCTION_ABI =
    "010E6372656174655F6163636F756E740000000000000000000000000000000000000000000000000000000000000001074163636F756E7420204261736963206163636F756E74206372656174696F6E206D6574686F64732E000108617574685F6B657904";

  const TRANSACTION_SCRIPT_ABI =
    "00046D61696E0F20412074657374207363726970742E8B01A11CEB0B050000000501000403040A050E0B071924083D200000000101020301000003010400020C0301050001060C0101074163636F756E74065369676E65720A616464726573735F6F66096578697374735F617400000000000000000000000000000000000000000000000000000000000000010000010A0E0011000C020B021101030705090B0127020001016902";


  test("parses create_account successfully", () async {
    const name = "create_account";
    const doc = " Basic account creation methods.";
    final typeArgABIs = [ArgumentABI("auth_key", TypeTagAddress())];

    final abi = EntryFunctionABI(name, ModuleId.fromStr("0x1::Account"), doc, [], typeArgABIs);
    final serializer = Serializer();
    abi.serialize(serializer);
    expect(HexString.fromUint8Array(serializer.getBytes()).noPrefix(), SCRIPT_FUNCTION_ABI.toLowerCase());

    final deserializer = Deserializer(HexString(SCRIPT_FUNCTION_ABI).toUint8Array());
    final entryFunctionABI = ScriptABI.deserialize(deserializer) as EntryFunctionABI;
    final moduleName = entryFunctionABI.moduleName;
    expect(entryFunctionABI.name, "create_account");
    expect(entryFunctionABI.doc.trim(), "Basic account creation methods.");
    expect(HexString(moduleName.address.hexAddress()).toShortString(), "0x1");
    expect(moduleName.name.value, "Account");

    final arg = entryFunctionABI.args[0];
    expect(arg.name, "auth_key");
    expect(arg.typeTag is TypeTagAddress, true);
  });

  test("parses script abi successfully", () async {
    const name = "main";
    const code =
      "0xa11ceb0b050000000501000403040a050e0b071924083d200000000101020301000003010400020c0301050001060c0101074163636f756e74065369676e65720a616464726573735f6f66096578697374735f617400000000000000000000000000000000000000000000000000000000000000010000010a0e0011000c020b021101030705090b012702";
    const doc = " A test script.";
    final typeArgABIs = [ArgumentABI("i", TypeTagU64())];
    final abi = TransactionScriptABI(name, doc, HexString.ensure(code).toUint8Array(), [], typeArgABIs);
    final serializer = Serializer();
    abi.serialize(serializer);
    expect(HexString.fromUint8Array(serializer.getBytes()).noPrefix(), TRANSACTION_SCRIPT_ABI.toLowerCase());

    final deserializer = Deserializer(HexString(TRANSACTION_SCRIPT_ABI).toUint8Array());
    final transactionScriptABI = ScriptABI.deserialize(deserializer) as TransactionScriptABI;
    expect(transactionScriptABI.name, "main");
    expect(transactionScriptABI.doc.trim(), "A test script.");

    expect(HexString.fromUint8Array(transactionScriptABI.code).hex(), code);

    final arg = transactionScriptABI.args[0];
    expect(arg.name, "i");
    expect(arg.typeTag is TypeTagU64, true);
  });
  
}