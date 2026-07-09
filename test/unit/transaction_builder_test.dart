// Offline tests for the transaction building pipeline (no live network):
// argument conversion (remote_abi), struct/enum encoding
// (struct_enum_parser), payload/raw transaction/signed transaction building
// (transaction_builder). Network-dependent code paths are exercised through
// a FakeClient returning canned responses.

import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/bcs/consts.dart';
import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/bcs/serializable/fixed_bytes.dart';
import 'package:aptos/src/bcs/serializable/move_primitives.dart';
import 'package:aptos/src/bcs/serializable/move_structs.dart';
import 'package:aptos/src/bcs/serializer.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/core/account_address.dart';
import 'package:aptos/src/core/crypto/ed25519.dart';
import 'package:aptos/src/core/crypto/keyless.dart';
import 'package:aptos/src/core/crypto/single_key.dart';
import 'package:aptos/src/internal/general.dart';
import 'package:aptos/src/transactions/authenticator/account.dart';
import 'package:aptos/src/transactions/authenticator/transaction.dart';
import 'package:aptos/src/transactions/instances/chain_id.dart';
import 'package:aptos/src/transactions/instances/identifier.dart';
import 'package:aptos/src/transactions/instances/module_id.dart';
import 'package:aptos/src/transactions/instances/multi_agent_transaction.dart';
import 'package:aptos/src/transactions/instances/raw_transaction.dart';
import 'package:aptos/src/transactions/instances/signed_transaction.dart';
import 'package:aptos/src/transactions/instances/simple_transaction.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/transactions/transaction_builder/remote_abi.dart';
import 'package:aptos/src/transactions/transaction_builder/signing_message.dart';
import 'package:aptos/src/transactions/transaction_builder/struct_enum_parser.dart';
import 'package:aptos/src/transactions/transaction_builder/transaction_builder.dart';
import 'package:aptos/src/transactions/type_tag/parser.dart';
import 'package:aptos/src/transactions/type_tag/type_tag.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/types/move_types.dart';
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:aptos/src/utils/memoize.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:test/test.dart';

/// A fake client that returns canned responses and records requests.
class FakeClient implements Client {
  final List<ClientRequest> requests = [];
  final List<ClientResponse<dynamic>> responses;
  int _index = 0;

  FakeClient(this.responses);

  @override
  Future<ClientResponse<dynamic>> provider(ClientRequest requestOptions) async {
    requests.add(requestOptions);
    final response = responses[_index];
    if (_index < responses.length - 1) _index += 1;
    return response;
  }
}

/// A transaction payload type unknown to convertPayloadToInnerPayload.
class _UnknownPayload extends TransactionPayload {
  @override
  void serialize(Serializer serializer) {}
}

final BigInt maxU8 = BigInt.from(255);
final BigInt maxU16 = BigInt.from(65535);
final BigInt maxU64 = BigInt.parse('18446744073709551615');
final BigInt maxU128 = BigInt.parse('340282366920938463463374607431768211455');
final BigInt maxU256 = BigInt.parse(
    '115792089237316195423570985008687907853269984665640564039457584007913129639935');
final BigInt minI64 = BigInt.parse('-9223372036854775808');
final BigInt maxI64 = BigInt.parse('9223372036854775807');
final BigInt minI128 = BigInt.parse('-170141183460469231731687303715884105728');

TypeTag tt(String s) => parseTypeTag(s);

EntryFunctionArgumentTypes conv(Object? arg, String type) =>
    checkOrConvertArgument(arg, tt(type), 0, []);

/// Compares the BCS bytes of an argument against an expected serializable.
void expectBcs(EntryFunctionArgumentTypes actual, Serializable expected) {
  expect(actual.bcsToBytes(), equals(expected.bcsToBytes()));
}

TransactionPayloadEntryFunction makeEntryPayload() {
  final moduleId = ModuleId(AccountAddress.one, Identifier('aptos_account'));
  return TransactionPayloadEntryFunction(
    EntryFunction(moduleId, Identifier('transfer'), [], []),
  );
}

RawTransaction makeRaw(AccountAddress sender, [BigInt? seq]) {
  return RawTransaction(
    sender,
    seq ?? BigInt.one,
    makeEntryPayload(),
    BigInt.from(200000),
    BigInt.from(100),
    BigInt.from(9999999999),
    ChainId(4),
  );
}

Map<String, dynamic> pointModuleJson({String name = 'test'}) => {
      'bytecode': '0x',
      'abi': {
        'address': '0x1',
        'name': name,
        'friends': <String>[],
        'exposed_functions': <Map<String, dynamic>>[],
        'structs': [
          {
            'name': 'Point',
            'is_native': false,
            'is_event': false,
            'is_enum': false,
            'abilities': ['copy', 'drop'],
            'generic_type_params': <Map<String, dynamic>>[],
            'fields': [
              {'name': 'x', 'type': 'u64'},
              {'name': 'y', 'type': 'u64'},
            ],
          },
        ],
      },
    };

void main() {
  setUp(clearMemoizeCache);

  group('standardizeTypeTags', () {
    test('parses strings and passes TypeTags through', () {
      final tags = standardizeTypeTags(['u8', TypeTagBool(), 'vector<u64>']);
      expect(tags[0], isA<TypeTagU8>());
      expect(tags[1], isA<TypeTagBool>());
      expect(tags[2], isA<TypeTagVector>());
      expect(standardizeTypeTags(null), isEmpty);
    });

    test('rejects non TypeTag/String inputs', () {
      expect(() => standardizeTypeTags([1]), throwsArgumentError);
    });
  });

  group('checkOrConvertArgument - primitives', () {
    test('parses primitive simple arguments', () {
      expectBcs(conv('0x1', 'address'), AccountAddress.one);
      expect(conv('0x1', 'address'), isA<AccountAddress>());
      expectBcs(conv(true, 'bool'), Bool(true));
      expectBcs(conv(255, 'u8'), U8(255));
      expectBcs(conv(65535, 'u16'), U16(65535));
      expectBcs(conv(65535, 'u32'), U32(65535));
      expectBcs(conv(4294967295, 'u32'), U32(4294967295));
      expectBcs(conv(65535, 'u64'), U64(maxU16));
      expectBcs(conv(maxU64, 'u64'), U64(maxU64));
      expectBcs(conv(maxU64.toString(), 'u64'), U64(maxU64));
      expectBcs(conv(maxU128, 'u128'), U128(maxU128));
      expectBcs(conv(maxU128.toString(), 'u128'), U128(maxU128));
      expectBcs(conv(maxU256, 'u256'), U256(maxU256));
      expectBcs(conv(maxU256.toString(), 'u256'), U256(maxU256));
    });

    test('parses signed integer primitive arguments', () {
      expectBcs(conv(127, 'i8'), I8(127));
      expectBcs(conv(-128, 'i8'), I8(-128));
      expectBcs(conv(32767, 'i16'), I16(32767));
      expectBcs(conv(-32768, 'i16'), I16(-32768));
      expectBcs(conv(2147483647, 'i32'), I32(2147483647));
      expectBcs(conv(-2147483648, 'i32'), I32(-2147483648));
      expectBcs(conv(maxI64, 'i64'), I64(maxI64));
      expectBcs(conv(minI64, 'i64'), I64(minI64));
      expectBcs(conv(minI64.toString(), 'i64'), I64(minI64));
      expectBcs(conv(minI128, 'i128'), I128(minI128));
      expectBcs(conv(-5, 'i64'), I64(BigInt.from(-5)));
      expectBcs(conv(-5, 'i256'), I256(BigInt.from(-5)));
    });

    test('parses primitive types for sdk v1 compatibility (strings)', () {
      expectBcs(conv('true', 'bool'), Bool(true));
      expectBcs(conv('false', 'bool'), Bool(false));
      expectBcs(conv('255', 'u8'), U8(255));
      expectBcs(conv('65535', 'u16'), U16(65535));
      expectBcs(conv('255', 'u32'), U32(255));
      expectBcs(conv('255', 'u64'), U64(maxU8));
      expectBcs(conv('255', 'u128'), U128(maxU8));
      expectBcs(conv('255', 'u256'), U256(maxU8));
      expectBcs(conv('-128', 'i8'), I8(-128));
      expectBcs(conv('-9223372036854775808', 'i64'), I64(minI64));
    });

    test('passes typed arguments through unchanged', () {
      final addr = AccountAddress.one;
      expect(conv(addr, 'address'), same(addr));
      final b = Bool(true);
      expect(conv(b, 'bool'), same(b));
      final u = U64(maxU64);
      expect(conv(u, 'u64'), same(u));
      final i = I128(minI128);
      expect(conv(i, 'i128'), same(i));
    });
  });

  group('checkOrConvertArgument - complex types', () {
    test('parses vectors of simple arguments', () {
      expectBcs(
        conv(['0x1', '0x2'], 'vector<address>'),
        MoveVector<AccountAddress>([AccountAddress.one, AccountAddress.two]),
      );
      expectBcs(conv([true, false], 'vector<bool>'),
          MoveVector.boolean([true, false]));
      expectBcs(conv([0, 255], 'vector<u8>'), MoveVector.u8([0, 255]));
      expectBcs(conv(Uint8List.fromList([0, 255]), 'vector<u8>'),
          MoveVector.u8([0, 255]));
      expectBcs(
        conv('[1, 2]', 'vector<u128>'),
        MoveVector<U128>([U128(BigInt.one), U128(BigInt.two)]),
      );
      expectBcs(conv([-128, 0, 127], 'vector<i8>'),
          MoveVector.i8([-128, 0, 127]));
      expectBcs(conv('[-32768, 0, 32767]', 'vector<i16>'),
          MoveVector.i16([-32768, 0, 32767]));
      // Mixed raw and typed values.
      expectBcs(
        conv([AccountAddress.one, '0x2'], 'vector<address>'),
        MoveVector<AccountAddress>([AccountAddress.one, AccountAddress.two]),
      );
      expectBcs(
        conv([0, BigInt.zero, '0'], 'vector<u256>'),
        MoveVector.u256([BigInt.zero, BigInt.zero, BigInt.zero]),
      );
    });

    test('vector<u8> from a string is UTF-8 encoded (not hex decoded)', () {
      final converted = conv('0xFF', 'vector<u8>');
      expect(converted, isA<MoveVector>());
      expect(converted.bcsToBytes(), equals(MoveString('0xFF').bcsToBytes()));
      expect(conv('Hello', 'vector<u8>').bcsToBytes(),
          equals(MoveString('Hello').bcsToBytes()));
    });

    test('parses strings and vectors of strings', () {
      expectBcs(conv('Hello', '0x1::string::String'), MoveString('Hello'));
      expectBcs(
        conv(['hello', 'goodbye'], 'vector<0x1::string::String>'),
        MoveVector.string(['hello', 'goodbye']),
      );
    });

    test('parses options', () {
      expectBcs(conv(0, '0x1::option::Option<u8>'), MoveOption<U8>(U8(0)));
      expectBcs(conv(255, '0x1::option::Option<u8>'), MoveOption<U8>(U8(255)));
      expectBcs(conv(null, '0x1::option::Option<u8>'), MoveOption<U8>(null));
      expectBcs(conv(-5, '0x1::option::Option<i8>'), MoveOption<I8>(I8(-5)));
      expectBcs(conv(null, '0x1::option::Option<i64>'), MoveOption<I64>(null));
      // BCS-encoded values are auto-wrapped in MoveOption.
      expectBcs(conv(U8(255), '0x1::option::Option<u8>'),
          MoveOption<U8>(U8(255)));
      expectBcs(conv(AccountAddress.one, '0x1::option::Option<address>'),
          MoveOption<AccountAddress>(AccountAddress.one));
      final opt = MoveOption<U8>(U8(255));
      expect(conv(opt, '0x1::option::Option<u8>'), same(opt));
    });

    test('parses objects as account addresses', () {
      expectBcs(conv('0x1', '0x1::object::Object<0x1::string::String>'),
          AccountAddress.one);
      expectBcs(
        conv(AccountAddress.one, '0x1::object::Object<0x1::string::String>'),
        AccountAddress.one,
      );
    });

    test('supports generics', () {
      final converted = checkOrConvertArgument(
        255,
        parseTypeTag('0x1::option::Option<T0>', allowGenerics: true),
        0,
        [TypeTagU8()],
      );
      expectBcs(converted, MoveOption<U8>(U8(255)));

      final obj = checkOrConvertArgument(
        AccountAddress.one,
        parseTypeTag('0x1::object::Object<T0>', allowGenerics: true),
        0,
        [TypeTagVector(TypeTagU256())],
      );
      expectBcs(obj, AccountAddress.one);
    });

    test('parses vector<Option<T>> arguments', () {
      expectBcs(
        conv([AccountAddress.one], 'vector<0x1::option::Option<address>>'),
        MoveVector([MoveOption<AccountAddress>(AccountAddress.one)]),
      );
      expectBcs(
        conv(['0x1'], 'vector<0x1::option::Option<address>>'),
        MoveVector([MoveOption<AccountAddress>(AccountAddress.one)]),
      );
      expectBcs(
        conv([null], 'vector<0x1::option::Option<address>>'),
        MoveVector([MoveOption<AccountAddress>(null)]),
      );
      expectBcs(
        conv([AccountAddress.one, null, '0x2'],
            'vector<0x1::option::Option<address>>'),
        MoveVector([
          MoveOption<AccountAddress>(AccountAddress.one),
          MoveOption<AccountAddress>(null),
          MoveOption<AccountAddress>(AccountAddress.two),
        ]),
      );
      expectBcs(
        conv([1, 2, 3], 'vector<0x1::option::Option<u8>>'),
        MoveVector(
            [MoveOption(U8(1)), MoveOption(U8(2)), MoveOption(U8(3))]),
      );
      expectBcs(
        conv([BigInt.from(100), null], 'vector<0x1::option::Option<u64>>'),
        MoveVector([MoveOption(U64(BigInt.from(100))), MoveOption<U64>(null)]),
      );
      expectBcs(
        conv([MoveOption(U8(42))], 'vector<0x1::option::Option<u8>>'),
        MoveVector([MoveOption(U8(42))]),
      );
    });

    test('fails on invalid simple inputs', () {
      expect(() => conv(false, 'address'), throwsArgumentError);
      expect(() => conv(0, 'bool'), throwsArgumentError);
      expect(() => conv(false, 'u8'), throwsArgumentError);
      expect(() => conv(false, 'u64'), throwsArgumentError);
      expect(() => conv(false, 'i8'), throwsArgumentError);
      expect(() => conv(false, 'i64'), throwsArgumentError);
      expect(() => conv(false, '0x1::string::String'), throwsArgumentError);
      expect(() => conv(false, '0x1::option::Option<u8>'),
          throwsArgumentError);
      expect(() => conv(false, '0x1::object::Object<u8>'),
          throwsArgumentError);
      expect(() => conv(false, 'vector<u8>'), throwsArgumentError);
      expect(() => conv(false, 'vector<i8>'), throwsArgumentError);
      expect(() => conv(false, '0x1::account::Account'), throwsArgumentError);
      expect(() => conv(false, 'signer'), throwsArgumentError);
      // Generic index out of range.
      expect(
        () => checkOrConvertArgument(
            [0], parseTypeTag('vector<T0>', allowGenerics: true), 0, []),
        throwsArgumentError,
      );
    });

    test('fails on mismatched typed inputs', () {
      expect(() => conv(Bool(true), 'address'), throwsArgumentError);
      expect(() => conv(U8(0), 'bool'), throwsArgumentError);
      expect(() => conv(Bool(true), 'u8'), throwsArgumentError);
      expect(() => conv(Bool(true), 'u64'), throwsArgumentError);
      expect(() => conv(Bool(true), 'i8'), throwsArgumentError);
      expect(() => conv(I16(5), 'i8'), throwsArgumentError);
      expect(() => conv(I8(5), 'i16'), throwsArgumentError);
      expect(() => conv(Bool(true), '0x1::string::String'),
          throwsArgumentError);
      expect(() => conv(Bool(true), 'vector<u8>'), throwsArgumentError);
    });

    test('does not support unsupported typed-data vector conversions', () {
      expect(() => conv(Int8List.fromList([1, 2, 3]), 'vector<u8>'),
          throwsArgumentError);
      expect(() => conv(Int32List.fromList([1, 2, 3]), 'vector<u32>'),
          throwsArgumentError);
      // Below u64 can't support BigInts.
      expect(() => conv([BigInt.one], 'vector<u8>'), throwsArgumentError);
      expect(() => conv([BigInt.one], 'vector<u32>'), throwsArgumentError);
    });

    test('plain-object struct arguments require the async path', () {
      expect(
        () => conv({'x': '1'}, '0x1::account::Account'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('async conversion'))),
      );
    });

    test('fieldless struct definition accepts raw bytes as FixedBytes', () {
      final module = MoveModule.fromJson({
        'address': '0x1',
        'name': 'test',
        'friends': <String>[],
        'exposed_functions': <Map<String, dynamic>>[],
        'structs': [
          {
            'name': 'Empty',
            'is_native': false,
            'is_event': false,
            'is_enum': false,
            'abilities': <String>[],
            'generic_type_params': <Map<String, dynamic>>[],
            'fields': <Map<String, dynamic>>[],
          },
        ],
      });
      final converted = checkOrConvertArgument(
        Uint8List.fromList([1, 2]),
        tt('0x1::test::Empty'),
        0,
        [],
        moduleAbi: module,
      );
      expect(converted, isA<FixedBytes>());
      expect(converted.bcsToBytes(), equals(Uint8List.fromList([1, 2])));
    });

    test('allowUnknownStructs converts unknown structs to FixedBytes', () {
      final converted = checkOrConvertArgument(
        Uint8List.fromList([7]),
        tt('0x1::account::Account'),
        0,
        [],
        allowUnknownStructs: true,
      );
      expect(converted, isA<FixedBytes>());
    });
  });

  group('convertArgument', () {
    final transferAbi = FunctionABI(
      typeParameters: [],
      parameters: [TypeTagAddress(), TypeTagU64()],
    );

    test('resolves parameters positionally from a FunctionABI', () {
      final arg0 =
          convertArgument('0x1::aptos_account::transfer', transferAbi, '0x1', 0, []);
      expectBcs(arg0, AccountAddress.one);
      final arg1 =
          convertArgument('0x1::aptos_account::transfer', transferAbi, 1, 1, []);
      expectBcs(arg1, U64(BigInt.one));
    });

    test('throws on too many arguments', () {
      expect(
        () => convertArgument(
            '0x1::aptos_account::transfer', transferAbi, 1, 2, []),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Too many arguments'))),
      );
    });

    test('resolves parameters from a MoveModule ABI', () {
      final module = MoveModule.fromJson({
        'address': '0x1',
        'name': 'aptos_account',
        'friends': <String>[],
        'exposed_functions': [
          {
            'name': 'transfer',
            'visibility': 'public',
            'is_entry': true,
            'is_view': false,
            'generic_type_params': <Map<String, dynamic>>[],
            'params': ['&signer', 'address', 'u64'],
            'return': <String>[],
          },
        ],
        'structs': <Map<String, dynamic>>[],
      });
      // Position is against the raw params list here (including signer).
      final arg = convertArgument('transfer', module, '0x2', 1, []);
      expectBcs(arg, AccountAddress.two);
    });
  });

  group('findFirstNonSignerArg', () {
    MoveFunction fn(List<String> params) => MoveFunction.fromJson({
          'name': 'f',
          'visibility': 'public',
          'is_entry': true,
          'is_view': false,
          'generic_type_params': <Map<String, dynamic>>[],
          'params': params,
          'return': <String>[],
        });

    test('finds the first non-signer parameter', () {
      expect(findFirstNonSignerArg(fn(['&signer', 'address'])), equals(1));
      expect(findFirstNonSignerArg(fn(['signer', 'signer', 'u8'])), equals(2));
      expect(findFirstNonSignerArg(fn(['address'])), equals(0));
      expect(findFirstNonSignerArg(fn(['signer', '&signer'])), equals(2));
    });
  });

  group('StructEnumArgumentParser (offline via preloadModules)', () {
    late StructEnumArgumentParser parser;

    setUp(() {
      parser = StructEnumArgumentParser(AptosConfig(network: Network.devnet));
    });

    test('encodes a simple struct with primitive fields', () async {
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson(pointModuleJson()),
      });

      final structTag = tt('0x1::test::Point') as TypeTagStruct;
      final result =
          await parser.encodeStructArgument(structTag, {'x': '10', 'y': '20'});

      expect(result, isA<MoveStructArgument>());
      expect(
        result.bcsToBytes(),
        equals(Uint8List.fromList(
            [10, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0])),
      );
    });

    test('encodes nested structs', () async {
      final moduleJson = pointModuleJson();
      (((moduleJson['abi'] as Map)['structs'] as List)).add({
        'name': 'Line',
        'is_native': false,
        'is_event': false,
        'is_enum': false,
        'abilities': ['copy', 'drop'],
        'generic_type_params': <Map<String, dynamic>>[],
        'fields': [
          {'name': 'start', 'type': '0x1::test::Point'},
          {'name': 'end', 'type': '0x1::test::Point'},
        ],
      });
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson(moduleJson),
      });

      final structTag = tt('0x1::test::Line') as TypeTagStruct;
      final result = await parser.encodeStructArgument(structTag, {
        'start': {'x': '1', 'y': '2'},
        'end': {'x': '3', 'y': '4'},
      });

      final bytes = result.bcsToBytes();
      expect(bytes.length, equals(32)); // 4 u64s.
      expect(bytes[0], equals(1));
      expect(bytes[8], equals(2));
      expect(bytes[16], equals(3));
      expect(bytes[24], equals(4));
    });

    test('throws for missing struct fields', () async {
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson(pointModuleJson()),
      });
      final structTag = tt('0x1::test::Point') as TypeTagStruct;
      await expectLater(
        parser.encodeStructArgument(structTag, {'x': '10'}),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains("Missing field 'y'"))),
      );
    });

    test('substitutes generic type parameters', () async {
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson({
          'bytecode': '0x',
          'abi': {
            'address': '0x1',
            'name': 'test',
            'friends': <String>[],
            'exposed_functions': <Map<String, dynamic>>[],
            'structs': [
              {
                'name': 'Box',
                'is_native': false,
                'is_event': false,
                'is_enum': false,
                'abilities': ['copy', 'drop'],
                'generic_type_params': [
                  {'constraints': <String>[]},
                ],
                'fields': [
                  {'name': 'value', 'type': 'T0'},
                ],
              },
            ],
          },
        }),
      });

      final structTag = tt('0x1::test::Box<u64>') as TypeTagStruct;
      final result =
          await parser.encodeStructArgument(structTag, {'value': '42'});
      expect(result.bcsToBytes(),
          equals(Uint8List.fromList([42, 0, 0, 0, 0, 0, 0, 0])));
    });

    test('rejects enum values passed as structs (and vice versa)', () async {
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson({
          'bytecode': '0x',
          'abi': {
            'address': '0x1',
            'name': 'test',
            'friends': <String>[],
            'exposed_functions': <Map<String, dynamic>>[],
            'structs': [
              {
                'name': 'MyEnum',
                'is_native': false,
                'is_event': false,
                'is_enum': true,
                'abilities': ['copy', 'drop'],
                'generic_type_params': <Map<String, dynamic>>[],
                'fields': [
                  {'name': 'VariantA', 'type': 'u64'},
                  {'name': 'VariantB', 'type': 'u64'},
                ],
              },
            ],
          },
        }),
      });
      final structTag = tt('0x1::test::MyEnum') as TypeTagStruct;
      await expectLater(
        parser.encodeStructArgument(structTag, {'field': '100'}),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('is an enum. Use enum variant syntax'))),
      );
    });

    test('encodes enum variants with the ULEB128 variant index', () async {
      parser.preloadModules({
        '0x1::test': MoveModuleBytecode.fromJson({
          'bytecode': '0x',
          'abi': {
            'address': '0x1',
            'name': 'test',
            'friends': <String>[],
            'exposed_functions': <Map<String, dynamic>>[],
            'structs': [
              {
                'name': 'MyEnum',
                'is_native': false,
                'is_event': false,
                'is_enum': true,
                'abilities': ['copy', 'drop'],
                'generic_type_params': <Map<String, dynamic>>[],
                'fields': [
                  {'name': 'VariantA', 'type': 'u64'},
                  {'name': 'VariantB', 'type': 'u64'},
                ],
              },
            ],
          },
        }),
      });
      final structTag = tt('0x1::test::MyEnum') as TypeTagStruct;

      final a = await parser.encodeEnumArgument(structTag, {
        'VariantA': {'0': '100'},
      });
      expect(a, isA<MoveEnumArgument>());
      expect(a.bcsToBytes(),
          equals(Uint8List.fromList([0, 100, 0, 0, 0, 0, 0, 0, 0])));

      final b = await parser.encodeEnumArgument(structTag, {
        'VariantB': {'0': '7'},
      });
      expect(b.bcsToBytes()[0], equals(1));

      await expectLater(
        parser.encodeEnumArgument(structTag, {'Nope': <String, Object?>{}}),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains("Variant 'Nope' not found"))),
      );
    });

    test('encodes Option::None and Option::Some in enum format', () async {
      final structTag = tt('0x1::option::Option<u64>') as TypeTagStruct;

      final none =
          await parser.encodeEnumArgument(structTag, {'None': <String, Object?>{}});
      expect(none.bcsToBytes(), equals(Uint8List.fromList([0])));

      final some = await parser.encodeEnumArgument(structTag, {
        'Some': {'0': '42'},
      });
      expect(some.bcsToBytes(),
          equals(Uint8List.fromList([1, 42, 0, 0, 0, 0, 0, 0, 0])));
    });

    test('serializeForEntryFunction length-prefixes the encoded bytes', () {
      final arg = MoveStructArgument(Uint8List.fromList([1, 2, 3]));
      final serializer = Serializer();
      arg.serializeForEntryFunction(serializer);
      expect(serializer.toUint8List(),
          equals(Uint8List.fromList([3, 1, 2, 3])));
    });
  });

  group('checkOrConvertArgumentWithABI (struct via FakeClient)', () {
    test('encodes a plain-object struct argument end to end', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: pointModuleJson(name: 'geo')),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final converted = await checkOrConvertArgumentWithABI(
        {'x': '10', 'y': '20'},
        tt('0x1::geo::Point'),
        0,
        [],
        config,
      );

      expect(converted, isA<MoveStructArgument>());
      expect(
        converted.bcsToBytes(),
        equals(Uint8List.fromList(
            [10, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0])),
      );
      expect(client.requests, hasLength(1));
      expect(client.requests.single.url, contains('module/geo'));
    });
  });

  group('generateTransactionPayloadWithABI', () {
    final transferAbi = EntryFunctionABI(
      signers: 1,
      typeParameters: [],
      parameters: [TypeTagAddress(), TypeTagU64()],
    );

    test('builds an entry-function payload and converts arguments', () {
      final payload = generateTransactionPayloadWithABI(InputEntryFunctionData(
        function: '0x1::aptos_account::transfer',
        functionArguments: ['0x2', 100],
        abi: transferAbi,
      ));

      expect(payload, isA<TransactionPayloadEntryFunction>());
      final entry = (payload as TransactionPayloadEntryFunction).entryFunction;
      expect(entry.functionName.identifier, equals('transfer'));
      expect(entry.moduleName.name.identifier, equals('aptos_account'));
      expect(entry.args, hasLength(2));
      expect(entry.args[0].bcsToBytes(),
          equals(AccountAddress.two.bcsToBytes()));
      expect(entry.args[1].bcsToBytes(),
          equals(U64(BigInt.from(100)).bcsToBytes()));
    });

    test('throws when type argument count mismatches the ABI', () {
      expect(
        () => generateTransactionPayloadWithABI(InputEntryFunctionData(
          function: '0x1::aptos_account::transfer',
          typeArguments: ['0x1::aptos_coin::AptosCoin'],
          functionArguments: ['0x2', 1],
          abi: transferAbi,
        )),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('Type argument count mismatch, expected 0, received 1'))),
      );
    });

    test('throws when too few arguments are provided', () {
      expect(
        () => generateTransactionPayloadWithABI(InputEntryFunctionData(
          function: '0x1::aptos_account::transfer',
          functionArguments: ['0x2'],
          abi: transferAbi,
        )),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Too few arguments'))),
      );
    });

    test('builds a multisig payload when multisigAddress is provided', () {
      final payload = generateTransactionPayloadWithABI(InputMultiSigData(
        multisigAddress: AccountAddress.a,
        function: '0x1::aptos_account::transfer',
        functionArguments: ['0x2', 1],
        abi: transferAbi,
      ));

      expect(payload, isA<TransactionPayloadMultiSig>());
      final multiSig = (payload as TransactionPayloadMultiSig).multiSig;
      expect(multiSig.multisigAddress.equals(AccountAddress.a), isTrue);
      expect(multiSig.transactionPayload?.transactionPayload,
          isA<EntryFunction>());
    });
  });

  group('generateTransactionPayload', () {
    test('builds a script payload from bytecode without a config', () async {
      final payload = await generateTransactionPayload(const InputScriptData(
        bytecode: '0x00',
        typeArguments: [],
        functionArguments: [],
      ));
      expect(payload, isA<TransactionPayloadScript>());
    });

    test('wraps script bytecode in a multisig payload', () async {
      final payload = await generateTransactionPayload(InputMultiSigScriptData(
        multisigAddress: AccountAddress.a,
        bytecode: '0x00',
        typeArguments: const [],
        functionArguments: const [],
      ));
      expect(payload, isA<TransactionPayloadMultiSig>());
    });

    test('uses a provided ABI without any network call', () async {
      final payload = await generateTransactionPayload(InputEntryFunctionData(
        function: '0x1::aptos_account::transfer',
        functionArguments: ['0x2', 1],
        abi: EntryFunctionABI(
          typeParameters: [],
          parameters: [TypeTagAddress(), TypeTagU64()],
        ),
      ));
      expect(payload, isA<TransactionPayloadEntryFunction>());
    });

    test('requires aptosConfig when no ABI is given', () async {
      await expectLater(
        generateTransactionPayload(const InputEntryFunctionData(
          function: '0x1::aptos_account::transfer',
          functionArguments: [],
        )),
        throwsArgumentError,
      );
    });

    test('fetches the entry function ABI remotely', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'bytecode': '0x',
          'abi': {
            'address': '0x1',
            'name': 'aptos_account',
            'friends': <String>[],
            'exposed_functions': [
              {
                'name': 'transfer',
                'visibility': 'public',
                'is_entry': true,
                'is_view': false,
                'generic_type_params': <Map<String, dynamic>>[],
                'params': ['&signer', 'address', 'u64'],
                'return': <String>[],
              },
            ],
            'structs': <Map<String, dynamic>>[],
          },
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final payload = await generateTransactionPayload(
        InputEntryFunctionData(
          function: '0x1::aptos_account::transfer',
          functionArguments: ['0x2', 1],
        ),
        config,
      );

      expect(payload, isA<TransactionPayloadEntryFunction>());
      final entry = (payload as TransactionPayloadEntryFunction).entryFunction;
      expect(entry.args, hasLength(2));
    });
  });

  group('generateViewFunctionPayloadWithABI', () {
    final viewAbi = ViewFunctionABI(
      typeParameters: [],
      parameters: [],
      returnTypes: [TypeTagU8()],
    );

    test('builds an EntryFunction for a zero-arg view ABI', () {
      final entry = generateViewFunctionPayloadWithABI(InputViewFunctionData(
        function: '0x1::chain_id::get',
        typeArguments: const [],
        abi: viewAbi,
      ));
      expect(entry, isA<EntryFunction>());
      expect(entry.functionName.identifier, equals('get'));
    });

    test('throws on type-argument and function-argument mismatches', () {
      expect(
        () => generateViewFunctionPayloadWithABI(InputViewFunctionData(
          function: '0x1::chain_id::get',
          typeArguments: ['0x1::aptos_coin::AptosCoin'],
          abi: viewAbi,
        )),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('Type argument count mismatch'))),
      );
      expect(
        () => generateViewFunctionPayloadWithABI(InputViewFunctionData(
          function: '0x1::chain_id::get',
          typeArguments: const [],
          functionArguments: const [1],
          abi: viewAbi,
        )),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Too many arguments'))),
      );
    });
  });

  group('convertPayloadToInnerPayload', () {
    test('wraps an entry-function payload with a replay protection nonce', () {
      final inner =
          convertPayloadToInnerPayload(makeEntryPayload(), BigInt.from(42));
      expect(inner, isA<TransactionInnerPayloadV1>());
      final v1 = inner as TransactionInnerPayloadV1;
      expect(v1.executable, isA<TransactionExecutableEntryFunction>());
      expect((v1.extraConfig as TransactionExtraConfigV1).replayProtectionNonce,
          equals(BigInt.from(42)));
    });

    test('wraps script and multisig payload variants', () {
      final scriptPayload = TransactionPayloadScript(
          Script(Uint8List.fromList([1]), [], []));
      final scriptInner =
          convertPayloadToInnerPayload(scriptPayload, BigInt.one);
      expect((scriptInner as TransactionInnerPayloadV1).executable,
          isA<TransactionExecutableScript>());

      final entry = makeEntryPayload();
      final msPayload = TransactionPayloadMultiSig(MultiSig(
        AccountAddress.a,
        MultiSigTransactionPayload(entry.entryFunction),
      ));
      final msInner = convertPayloadToInnerPayload(msPayload, BigInt.two);
      final msV1 = msInner as TransactionInnerPayloadV1;
      expect(msV1.executable, isA<TransactionExecutableEntryFunction>());
      expect(
        (msV1.extraConfig as TransactionExtraConfigV1)
            .multisigAddress
            ?.equals(AccountAddress.a),
        isTrue,
      );

      final scriptMsPayload = TransactionPayloadMultiSig(MultiSig(
        AccountAddress.a,
        MultiSigTransactionPayload(Script(Uint8List.fromList([2]), [], [])),
      ));
      expect(
        (convertPayloadToInnerPayload(scriptMsPayload)
                as TransactionInnerPayloadV1)
            .executable,
        isA<TransactionExecutableScript>(),
      );

      final emptyMsPayload =
          TransactionPayloadMultiSig(MultiSig(AccountAddress.a));
      expect(
        (convertPayloadToInnerPayload(emptyMsPayload)
                as TransactionInnerPayloadV1)
            .executable,
        isA<TransactionExecutableEmpty>(),
      );
    });

    test('throws for unsupported payload instances', () {
      expect(
        () => convertPayloadToInnerPayload(_UnknownPayload()),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('Unsupported payload type'))),
      );
    });
  });

  group('buildTransaction (offline, mainnet chain id)', () {
    final config = AptosConfig(network: Network.mainnet);
    final sender = AccountAddress.fromString('0x123', maxMissingChars: 63);

    test('returns a SimpleTransaction with the provided options', () async {
      final txn = await buildTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.from(99),
          gasUnitPrice: 100,
          maxGasAmount: 50000,
          expireTimestamp: 1735689600,
        ),
      );

      expect(txn, isA<SimpleTransaction>());
      expect(txn.feePayerAddress, isNull);
      expect(txn.secondarySignerAddresses, isNull);
      final raw = txn.rawTransaction;
      expect(raw.sequenceNumber, equals(BigInt.from(99)));
      expect(raw.gasUnitPrice, equals(BigInt.from(100)));
      expect(raw.maxGasAmount, equals(BigInt.from(50000)));
      expect(raw.expirationTimestampSecs, equals(BigInt.from(1735689600)));
      expect(raw.chainId.chainId, equals(1)); // NetworkToChainId[mainnet]
      expect(raw.sender.equals(sender), isTrue);
      expect(raw.payload, isA<TransactionPayloadEntryFunction>());
    });

    test('enforces the minimum max gas amount floor', () async {
      final txn = await buildTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.one,
          gasUnitPrice: 100,
          maxGasAmount: 1,
        ),
      );
      expect(txn.rawTransaction.maxGasAmount, equals(BigInt.from(2000)));
    });

    test('returns a MultiAgentTransaction for secondary signers', () async {
      final txn = await buildTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        secondarySignerAddresses: ['0x2'],
        feePayerAddress: AccountAddress.zero,
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.one,
          gasUnitPrice: 100,
        ),
      );

      expect(txn, isA<MultiAgentTransaction>());
      expect(txn.secondarySignerAddresses, hasLength(1));
      expect(
        txn.secondarySignerAddresses!.single
            .equals(AccountAddress.two),
        isTrue,
      );
      expect(txn.feePayerAddress?.equals(AccountAddress.zero), isTrue);
    });

    test('withFeePayer sets the AccountAddress.zero sentinel', () async {
      final txn = await buildTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        withFeePayer: true,
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.one,
          gasUnitPrice: 100,
        ),
      );

      expect(txn, isA<SimpleTransaction>());
      expect(txn.feePayerAddress?.equals(AccountAddress.zero), isTrue);
    });

    test('orderless: replayProtectionNonce implies u64::MAX sequence number '
        'and a TransactionInnerPayloadV1', () async {
      final txn = await buildTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(
          replayProtectionNonce: BigInt.from(7),
          gasUnitPrice: 100,
        ),
      );

      final raw = txn.rawTransaction;
      expect(raw.sequenceNumber, equals(maxU64BigInt));
      expect(raw.payload, isA<TransactionInnerPayloadV1>());
      final inner = raw.payload as TransactionInnerPayloadV1;
      expect(inner.executable, isA<TransactionExecutableEntryFunction>());
      expect(
        (inner.extraConfig as TransactionExtraConfigV1).replayProtectionNonce,
        equals(BigInt.from(7)),
      );
    });

    test('throws when both replayProtectionNonce and accountSequenceNumber '
        'are set', () async {
      await expectLater(
        buildTransaction(
          aptosConfig: config,
          sender: sender,
          payload: makeEntryPayload(),
          options: InputGenerateTransactionOptions(
            replayProtectionNonce: BigInt.one,
            accountSequenceNumber: BigInt.two,
          ),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains(
              'Cannot specify both replayProtectionNonce and accountSequenceNumber'),
        )),
      );
    });
  });

  group('generateRawTransaction (network lookups via FakeClient)', () {
    final sender = AccountAddress.fromString('0x123', maxMissingChars: 63);

    test('fetches the sequence number when not provided', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'sequence_number': '12',
          'authentication_key': '0x1',
        }),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);

      final raw = await generateRawTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(gasUnitPrice: 50),
      );

      expect(raw.sequenceNumber, equals(BigInt.from(12)));
      expect(raw.gasUnitPrice, equals(BigInt.from(50)));
      expect(client.requests.single.url, contains('accounts/'));
    });

    test('fetches the gas price estimation when gasUnitPrice is omitted',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {'gas_estimate': 77}),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);

      final raw = await generateRawTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.from(3),
        ),
      );

      expect(raw.gasUnitPrice, equals(BigInt.from(77)));
      expect(client.requests.single.url, contains('estimate_gas_price'));
    });

    test('fetches the chain id from ledger info on unknown networks',
        () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {
          'chain_id': 4,
          'epoch': '1',
          'ledger_version': '10',
          'oldest_ledger_version': '0',
          'ledger_timestamp': '170000000',
          'node_role': 'full_node',
          'oldest_block_height': '0',
          'block_height': '5',
        }),
      ]);
      final config = AptosConfig(network: Network.devnet, client: client);

      final raw = await generateRawTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        options: InputGenerateTransactionOptions(
          accountSequenceNumber: BigInt.one,
          gasUnitPrice: 100,
        ),
      );

      expect(raw.chainId.chainId, equals(4));
    });

    test('AIP-52: uses sequence number 0 for sponsored transactions when '
        'the sender account is missing', () async {
      final client = FakeClient([
        const ClientResponse(
          status: 404,
          statusText: 'Not Found',
          data: {'message': 'account not found', 'error_code': 'not_found'},
        ),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);

      final raw = await generateRawTransaction(
        aptosConfig: config,
        sender: sender,
        payload: makeEntryPayload(),
        feePayerAddress: AccountAddress.zero,
        options: InputGenerateTransactionOptions(gasUnitPrice: 100),
      );

      expect(raw.sequenceNumber, equals(BigInt.zero));
    });
  });

  group('memoized network fetches', () {
    test('getGasPriceEstimation is memoized per network', () async {
      final client = FakeClient([
        const ClientResponse(status: 200, data: {'gas_estimate': 88}),
      ]);
      final config = AptosConfig(network: Network.mainnet, client: client);

      final first = await getGasPriceEstimation(aptosConfig: config);
      final second = await getGasPriceEstimation(aptosConfig: config);
      expect(first.gasEstimate, equals(88));
      expect(second.gasEstimate, equals(88));
      expect(client.requests, hasLength(1));
    });
  });

  group('generateSignedTransaction', () {
    final senderKey = Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 3)));
    final senderAddress = AccountAddress.fromString('0x123', maxMissingChars: 63);
    final edAuth = AccountAuthenticatorEd25519(
      senderKey.publicKey(),
      senderKey.sign(Uint8List.fromList([2])),
    );

    test('serializes a single-signer ed25519 transaction', () {
      final simple = SimpleTransaction(makeRaw(senderAddress));
      final bytes = generateSignedTransaction(InputSubmitTransactionData(
        transaction: simple,
        senderAuthenticator: edAuth,
      ));

      expect(bytes, isNotEmpty);
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      expect(decoded.authenticator, isA<TransactionAuthenticatorEd25519>());
      expect(decoded.rawTxn.sequenceNumber, equals(BigInt.one));
    });

    test('serializes a fee-payer transaction and round-trips it', () {
      final feePayerTxn =
          SimpleTransaction(makeRaw(senderAddress), AccountAddress.a);
      final feePayerKey =
          Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 4)));
      final feePayerAuth = AccountAuthenticatorEd25519(
        feePayerKey.publicKey(),
        feePayerKey.sign(Uint8List.fromList([3])),
      );

      final bytes = generateSignedTransaction(InputSubmitTransactionData(
        transaction: feePayerTxn,
        senderAuthenticator: edAuth,
        feePayerAuthenticator: feePayerAuth,
      ));

      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      final auth = decoded.authenticator as TransactionAuthenticatorFeePayer;
      expect(auth.feePayer.address.equals(AccountAddress.a), isTrue);
      expect(auth.secondarySignerAddresses, isEmpty);
    });

    test('throws when the fee payer authenticator is missing', () {
      final feePayerTxn =
          SimpleTransaction(makeRaw(senderAddress), AccountAddress.a);
      expect(
        () => generateSignedTransaction(InputSubmitTransactionData(
          transaction: feePayerTxn,
          senderAuthenticator: edAuth,
        )),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('Must provide a feePayerAuthenticator'))),
      );
    });

    test('serializes a multi-agent transaction and round-trips it', () {
      final multi =
          MultiAgentTransaction(makeRaw(senderAddress), [AccountAddress.a]);
      final secondaryKey =
          Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 5)));
      final secondaryAuth = AccountAuthenticatorEd25519(
        secondaryKey.publicKey(),
        secondaryKey.sign(Uint8List.fromList([4])),
      );

      final bytes = generateSignedTransaction(InputSubmitTransactionData(
        transaction: multi,
        senderAuthenticator: edAuth,
        additionalSignersAuthenticators: [secondaryAuth],
      ));

      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      final auth = decoded.authenticator as TransactionAuthenticatorMultiAgent;
      expect(auth.secondarySignerAddresses, hasLength(1));
      expect(auth.secondarySigners, hasLength(1));
    });

    test('throws when multi-agent additional authenticators are missing', () {
      final multi =
          MultiAgentTransaction(makeRaw(senderAddress), [AccountAddress.a]);
      expect(
        () => generateSignedTransaction(InputSubmitTransactionData(
          transaction: multi,
          senderAuthenticator: edAuth,
        )),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            contains('Must provide a additionalSignersAuthenticators'))),
      );
    });

    test('wraps single-key sender authenticators in SingleSender', () {
      final simple = SimpleTransaction(makeRaw(senderAddress));
      final anyPk = AnyPublicKey(senderKey.publicKey());
      final singleKeyAuth = AccountAuthenticatorSingleKey(
        anyPk,
        AnySignature(senderKey.sign(Uint8List.fromList([9]))),
      );

      final bytes = generateSignedTransaction(InputSubmitTransactionData(
        transaction: simple,
        senderAuthenticator: singleKeyAuth,
      ));
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      expect(
          decoded.authenticator, isA<TransactionAuthenticatorSingleSender>());
    });
  });

  group('generateUserTransactionHash', () {
    test('produces a deterministic, domain-separated sha3-256 hash', () {
      final senderKey =
          Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 7)));
      final simple =
          SimpleTransaction(makeRaw(AccountAddress.fromString('0x123', maxMissingChars: 63)));
      final auth = AccountAuthenticatorEd25519(
        senderKey.publicKey(),
        senderKey.sign(Uint8List.fromList([1])),
      );
      final input = InputSubmitTransactionData(
        transaction: simple,
        senderAuthenticator: auth,
      );

      final hash = generateUserTransactionHash(input);
      expect(hash, matches(RegExp(r'^0x[0-9a-f]{64}$')));
      expect(generateUserTransactionHash(input), equals(hash));

      // Independently recompute:
      // sha3_256(sha3_256("APTOS::Transaction") | 0x00 | signed_txn_bcs).
      final signedTxn = generateSignedTransaction(input);
      final prefix = SHA3Digest(256)
          .process(Uint8List.fromList(utf8.encode('APTOS::Transaction')));
      final message = Uint8List.fromList([...prefix, 0, ...signedTxn]);
      final expected = SHA3Digest(256).process(message);
      final expectedHex =
          '0x${expected.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      expect(hash, equals(expectedHex));
    });

    test('hashValues concatenates sha3 inputs in order', () {
      final a = hashValues(['hello', Uint8List.fromList([1, 2])]);
      final b = hashValues(['hello', Uint8List.fromList([1, 2])]);
      expect(a, equals(b));
      expect(a.length, equals(32));
      expect(a, isNot(equals(hashValues([Uint8List.fromList([1, 2]), 'hello']))));
    });
  });

  group('signing message correctness', () {
    final sender = AccountAddress.fromString('0x123', maxMissingChars: 63);

    test('simple transaction uses the RawTransaction salt', () {
      final simple = SimpleTransaction(makeRaw(sender));
      final message = generateSigningMessageForTransaction(simple);
      final prefix = SHA3Digest(256)
          .process(Uint8List.fromList(utf8.encode('APTOS::RawTransaction')));
      expect(message.sublist(0, 32), equals(prefix));
      expect(message.sublist(32), equals(simple.rawTransaction.bcsToBytes()));
    });

    test('fee payer transaction uses the RawTransactionWithData salt', () {
      final feePayerTxn = SimpleTransaction(makeRaw(sender), AccountAddress.a);
      final message = generateSigningMessageForTransaction(feePayerTxn);
      final prefix = SHA3Digest(256).process(
          Uint8List.fromList(utf8.encode('APTOS::RawTransactionWithData')));
      expect(message.sublist(0, 32), equals(prefix));
      final expectedBody = FeePayerRawTransaction(
        feePayerTxn.rawTransaction,
        [],
        AccountAddress.a,
      ).bcsToBytes();
      expect(message.sublist(32), equals(expectedBody));
    });

    test('multi-agent transaction uses the RawTransactionWithData salt', () {
      final multi = MultiAgentTransaction(makeRaw(sender), [AccountAddress.a]);
      final message = generateSigningMessageForTransaction(multi);
      final prefix = SHA3Digest(256).process(
          Uint8List.fromList(utf8.encode('APTOS::RawTransactionWithData')));
      expect(message.sublist(0, 32), equals(prefix));
    });
  });

  group('simulation authenticators', () {
    final sender = AccountAddress.fromString('0x123', maxMissingChars: 63);
    final senderKey = Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 8)));

    test('returns a no-op authenticator when the public key is omitted',
        () async {
      final auth = await getAuthenticatorForSimulation(null);
      expect(auth, isA<AccountAuthenticatorNoAccountAuthenticator>());
    });

    test('uses an invalid ed25519 signature for ed25519 keys', () async {
      final auth = await getAuthenticatorForSimulation(senderKey.publicKey());
      expect(auth, isA<AccountAuthenticatorEd25519>());
      expect((auth as AccountAuthenticatorEd25519).signature.toUint8Array(),
          equals(Uint8List(64)));
    });

    test('wraps keyless public keys with a keyless simulation signature',
        () async {
      final keylessPk =
          KeylessPublicKey('https://accounts.google.com', Uint8List(32));
      final auth = await getAuthenticatorForSimulation(keylessPk);
      expect(auth, isA<AccountAuthenticatorSingleKey>());
      final singleKey = auth as AccountAuthenticatorSingleKey;
      expect(singleKey.signature.signature, isA<KeylessSignature>());
    });

    test('builds signed bytes for a simple transaction simulation', () async {
      final simple = SimpleTransaction(makeRaw(sender));
      final bytes = await generateSignedTransactionForSimulation(
        InputSimulateTransactionData(
          transaction: simple,
          signerPublicKey: senderKey.publicKey(),
        ),
      );
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      expect(decoded.authenticator, isA<TransactionAuthenticatorEd25519>());
    });

    test('serializes a no-account-authenticator simple simulation', () async {
      final simple = SimpleTransaction(makeRaw(sender));
      final bytes = await generateSignedTransactionForSimulation(
        InputSimulateTransactionData(transaction: simple),
      );
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      final auth =
          decoded.authenticator as TransactionAuthenticatorSingleSender;
      expect(auth.sender, isA<AccountAuthenticatorNoAccountAuthenticator>());
    });

    test('builds signed bytes for a fee-payer multi-agent simulation',
        () async {
      final secondaryKey =
          Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 9)));
      final feePayerKey =
          Ed25519PrivateKey(Uint8List.fromList(List.filled(32, 10)));
      final multi = MultiAgentTransaction(
        makeRaw(sender),
        [AccountAddress.two],
        AccountAddress.a,
      );
      final bytes = await generateSignedTransactionForSimulation(
        InputSimulateTransactionData(
          transaction: multi,
          signerPublicKey: senderKey.publicKey(),
          secondarySignersPublicKeys: [secondaryKey.publicKey()],
          feePayerPublicKey: feePayerKey.publicKey(),
        ),
      );
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      final auth = decoded.authenticator as TransactionAuthenticatorFeePayer;
      expect(auth.secondarySigners, hasLength(1));
      expect(auth.feePayer.address.equals(AccountAddress.a), isTrue);
    });

    test('uses placeholder secondary authenticators when secondary keys are '
        'omitted', () async {
      final multi =
          MultiAgentTransaction(makeRaw(sender), [AccountAddress.two]);
      final bytes = await generateSignedTransactionForSimulation(
        InputSimulateTransactionData(
          transaction: multi,
          signerPublicKey: senderKey.publicKey(),
        ),
      );
      final decoded = SignedTransaction.deserialize(Deserializer(bytes));
      final auth = decoded.authenticator as TransactionAuthenticatorMultiAgent;
      expect(auth.secondarySigners.single,
          isA<AccountAuthenticatorNoAccountAuthenticator>());
    });
  });
}
