/// Parser for public copy structs and enums as transaction arguments.
///
/// This module enables the Dart SDK to accept public copy structs and enums
/// as transaction arguments in JSON format, automatically encoding them to
/// BCS.
///
/// Key features:
/// - Queries on-chain metadata for struct/enum definitions
/// - Parses JSON input matching Move struct/enum types
/// - Encodes arguments to BCS format
/// - Supports nested structs/enums with depth limits
/// - Handles Option&lt;T&gt; in both vector and enum formats
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../api/aptos_config.dart';
import '../../bcs/serializable/move_primitives.dart';
import '../../bcs/serializable/move_structs.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../internal/account.dart';
import '../../types/move_types.dart';
import '../instances/transaction_argument.dart';
import '../type_tag/parser.dart';
import '../type_tag/type_tag.dart';

/// Maximum nesting depth for structs, enums, and vectors.
/// Prevents stack overflow and excessively complex arguments.
/// Matches the limit in the Rust CLI implementation.
const int _maxNestingDepth = 7;

/// Module path separator used in fully-qualified type names.
const String _moduleSeparator = '::';

/// Represents a BCS-serializable struct argument.
/// Encodes struct fields in declaration order.
class MoveStructArgument extends Serializable implements EntryFunctionArgument {
  /// The encoded BCS bytes for this struct.
  final Uint8List _bcsBytes;

  /// Creates a new struct argument from pre-encoded BCS bytes.
  MoveStructArgument(Uint8List bcsBytes) : _bcsBytes = bcsBytes;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(_bcsBytes);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    // For entry functions, we need to prefix with the byte length.
    serializer.serializeU32AsUleb128(_bcsBytes.length);
    serializer.serializeFixedBytes(_bcsBytes);
  }

  /// Returns the raw struct bytes without additional wrapping.
  @override
  Uint8List bcsToBytes() => _bcsBytes;
}

/// Represents a BCS-serializable enum argument.
/// Encodes variant tag (ULEB128) followed by variant fields.
class MoveEnumArgument extends Serializable implements EntryFunctionArgument {
  /// The encoded BCS bytes for this enum.
  final Uint8List _bcsBytes;

  /// Creates a new enum argument from pre-encoded BCS bytes.
  MoveEnumArgument(Uint8List bcsBytes) : _bcsBytes = bcsBytes;

  @override
  void serialize(Serializer serializer) {
    serializer.serializeFixedBytes(_bcsBytes);
  }

  @override
  void serializeForEntryFunction(Serializer serializer) {
    // For entry functions, we need to prefix with the byte length.
    serializer.serializeU32AsUleb128(_bcsBytes.length);
    serializer.serializeFixedBytes(_bcsBytes);
  }

  /// Returns the raw enum bytes without additional wrapping.
  @override
  Uint8List bcsToBytes() => _bcsBytes;
}

/// Parser for struct and enum transaction arguments.
///
/// This class enables passing public copy structs and enums as transaction
/// arguments by automatically fetching module ABIs and encoding values to
/// BCS format.
///
/// ```dart
/// // Encode a simple struct
/// final parser = StructEnumArgumentParser(config);
/// final structTag = parseTypeTag('0x1::test::Point') as TypeTagStruct;
/// final value = {'x': '10', 'y': '20'};
/// final encoded = await parser.encodeStructArgument(structTag, value);
///
/// // Encode an enum variant
/// final enumTag = parseTypeTag('0x1::test::Color') as TypeTagStruct;
/// final encodedEnum =
///     await parser.encodeEnumArgument(enumTag, {'Red': <String, Object?>{}});
///
/// // Option enum (dual format support)
/// // Vector format (backward compatible): [] (None) or [42] (Some)
/// // Enum format (new standard): {'None': {}} or {'Some': {'0': '42'}}
/// ```
///
/// Features:
/// - Automatic module ABI fetching and caching
/// - Recursive encoding for nested structs/enums
/// - Generic type parameter substitution (T0, T1, etc.)
/// - Depth limit enforcement (max 7 levels)
/// - Support for all Move primitive types
/// - Vector encoding with element recursion
/// - Special handling for String, Object&lt;T&gt;, Option&lt;T&gt;
class StructEnumArgumentParser {
  final AptosConfig _aptosConfig;

  /// Cache of module bytecode to avoid repeated fetches.
  /// Key: "address::module_name"
  final Map<String, MoveModuleBytecode> _moduleCache = {};

  StructEnumArgumentParser(AptosConfig aptosConfig)
      : _aptosConfig = aptosConfig;

  /// Pre-populates the module cache with modules.
  /// This optimization eliminates nested network calls by providing all
  /// necessary struct definitions upfront.
  ///
  /// [modules] - Map of module ID (`address::name`) to [MoveModuleBytecode].
  void preloadModules(Map<String, MoveModuleBytecode> modules) {
    _moduleCache.addAll(modules);
  }

  /// Parses a type string into a [TypeTag], with generics support.
  TypeTag parseTypeString(String typeStr) {
    return parseTypeTag(typeStr, allowGenerics: true);
  }

  /// Checks if the nesting depth exceeds the maximum allowed.
  void _checkDepth(int depth, String typeName) {
    if (depth > _maxNestingDepth) {
      throw ArgumentError(
        '$typeName nesting depth $depth exceeds maximum allowed depth of '
        '$_maxNestingDepth',
      );
    }
  }

  /// Fetches module bytecode from the chain.
  /// Results are cached to avoid repeated fetches.
  Future<MoveModuleBytecode> _fetchModule(
    AccountAddress moduleAddress,
    String moduleName,
  ) async {
    final cacheKey = '$moduleAddress$_moduleSeparator$moduleName';

    // Check cache first.
    final cached = _moduleCache[cacheKey];
    if (cached != null) return cached;

    // Fetch from chain.
    try {
      final accountModule = await getModule(
        aptosConfig: _aptosConfig,
        accountAddress: moduleAddress,
        moduleName: moduleName,
      );
      _moduleCache[cacheKey] = accountModule;
      return accountModule;
    } catch (error) {
      throw StateError(
        'Failed to fetch module '
        '$moduleAddress$_moduleSeparator$moduleName: $error',
      );
    }
  }

  /// Determines if a type is a struct or enum that requires special
  /// handling (i.e. not one of the special built-in framework types).
  bool isStructOrEnum(TypeTag typeTag) {
    if (typeTag is! TypeTagStruct) {
      return false;
    }

    final qualifiedName = '${typeTag.value.address}$_moduleSeparator'
        '${typeTag.value.moduleName.identifier}$_moduleSeparator'
        '${typeTag.value.name.identifier}';

    // Special built-in types that are already handled.
    const builtinTypes = [
      '0x1::string::String',
      '0x1::object::Object',
      '0x1::option::Option',
    ];

    for (final builtinType in builtinTypes) {
      if (qualifiedName.startsWith(builtinType)) {
        return false;
      }
    }

    return true;
  }

  /// Encodes a struct argument to BCS bytes.
  ///
  /// [structTag] - The struct type tag.
  /// [value] - JSON-like map with field values.
  /// [depth] - Current nesting depth.
  Future<MoveStructArgument> encodeStructArgument(
    TypeTagStruct structTag,
    Object? value, [
    int depth = 0,
  ]) async {
    _checkDepth(depth, 'Struct');

    if (value is! Map) {
      throw ArgumentError(
        'Expected object for struct argument, got ${value.runtimeType}',
      );
    }

    // Fetch module to get struct definition.
    final module = await _fetchModule(
      structTag.value.address,
      structTag.value.moduleName.identifier,
    );

    final abi = module.abi;
    if (abi == null) {
      throw StateError(
        'Module ${structTag.value.address}$_moduleSeparator'
        '${structTag.value.moduleName.identifier} has no ABI',
      );
    }

    // Find the struct definition.
    final structDef = _findStruct(abi, structTag.value.name.identifier);

    if (structDef == null) {
      throw StateError(
        'Struct ${structTag.value.name.identifier} not found in module '
        '${structTag.value.address}$_moduleSeparator'
        '${structTag.value.moduleName.identifier}',
      );
    }

    if (structDef.isEnum) {
      throw ArgumentError(
        'Type ${structTag.value.name.identifier} is an enum. Use enum '
        'variant syntax instead (e.g., {"VariantName": {...}})',
      );
    }

    if (structDef.isNative) {
      throw ArgumentError(
        'Struct ${structTag.value.name.identifier} is a native struct and '
        'cannot be used as an argument',
      );
    }

    // Encode each field in order.
    final serializer = Serializer();

    for (final field in structDef.fields) {
      if (!value.containsKey(field.name)) {
        throw ArgumentError(
          "Missing field '${field.name}' for struct "
          '${structTag.value.name.identifier}',
        );
      }
      final fieldValue = value[field.name];

      // Parse field type and substitute generics.
      final fieldTypeTag = parseTypeString(field.type);
      final substitutedType = _substituteTypeParams(fieldTypeTag, structTag);

      // Encode field value.
      final encoded =
          await _encodeValueByType(substitutedType, fieldValue, depth + 1);
      serializer.serializeFixedBytes(encoded);
    }

    return MoveStructArgument(serializer.toUint8List());
  }

  /// Encodes an enum argument to BCS bytes.
  ///
  /// [structTag] - The enum type tag.
  /// [value] - JSON-like map with the variant name and fields.
  /// [depth] - Current nesting depth.
  Future<MoveEnumArgument> encodeEnumArgument(
    TypeTagStruct structTag,
    Object? value, [
    int depth = 0,
  ]) async {
    _checkDepth(depth, 'Enum');

    if (value is! Map) {
      throw ArgumentError(
        'Expected object for enum argument, got ${value.runtimeType}',
      );
    }

    // Enum format: { "VariantName": { "field1": value1, ... } }
    final variantNames = value.keys.toList();
    if (variantNames.length != 1) {
      throw ArgumentError(
        'Enum value must have exactly one variant, got '
        '${variantNames.length}',
      );
    }

    final variantName = variantNames.first as String;
    final variantFields = value[variantName];

    // Special handling for Option<T> - uses vector encoding for backward
    // compatibility.
    if (_isOptionType(structTag)) {
      return _encodeOptionArgument(
          structTag, variantName, variantFields, depth);
    }

    // Fetch module to get enum definition.
    final module = await _fetchModule(
      structTag.value.address,
      structTag.value.moduleName.identifier,
    );

    final abi = module.abi;
    if (abi == null) {
      throw StateError(
        'Module ${structTag.value.address}$_moduleSeparator'
        '${structTag.value.moduleName.identifier} has no ABI',
      );
    }

    // Find the enum definition.
    final enumDef = _findStruct(abi, structTag.value.name.identifier);

    if (enumDef == null) {
      throw StateError(
        'Enum ${structTag.value.name.identifier} not found in module '
        '${structTag.value.address}$_moduleSeparator'
        '${structTag.value.moduleName.identifier}',
      );
    }

    if (!enumDef.isEnum) {
      throw ArgumentError(
        'Type ${structTag.value.name.identifier} is a struct, not an enum. '
        'Provide field values directly as an object.',
      );
    }

    // For enums, the fields array represents variants.
    // Find variant index by name.
    final variantIndex =
        enumDef.fields.indexWhere((f) => f.name == variantName);

    if (variantIndex == -1) {
      final availableVariants = enumDef.fields.map((f) => f.name).join(', ');
      throw ArgumentError(
        "Variant '$variantName' not found in enum "
        '${structTag.value.name.identifier}. Available variants: '
        '$availableVariants',
      );
    }

    final serializer = Serializer();

    // Encode variant index as ULEB128.
    serializer.serializeU32AsUleb128(variantIndex);

    // Note: For enum variants with fields, the field information is in the
    // variant's type string. The REST API may not provide complete field
    // metadata for enum variants, so we handle the variantFields based on
    // the type string.
    final variantDef = enumDef.fields[variantIndex];
    // Substitute generic type parameters for the variant payload type so
    // that generic enums (e.g. `Some(T0)`) are encoded against the
    // instantiated type.
    final variantType =
        _substituteTypeParams(parseTypeString(variantDef.type), structTag);

    // If the variant has fields, encode them.
    if (variantFields is Map) {
      // Variant has fields as an object.
      final fieldKeys = variantFields.keys.cast<String>().toList();

      // Sort keys to ensure correct field order.
      // Enum variants with multiple fields should use numbered keys:
      // {"0": val1, "1": val2, ...}
      final sortedKeys = [...fieldKeys]..sort((a, b) {
          final numA = int.tryParse(a);
          final numB = int.tryParse(b);

          // If keys are not numeric, maintain object key order (which may
          // be wrong).
          if (numA == null || numB == null) {
            return 0;
          }

          return numA.compareTo(numB);
        });

      // Validate that multi-field variants use sequential numeric keys.
      if (sortedKeys.length > 1) {
        for (var i = 0; i < sortedKeys.length; i += 1) {
          final expectedKey = i.toString();
          if (sortedKeys[i] != expectedKey) {
            throw ArgumentError(
              'Enum variant with multiple fields must use sequential numeric '
              'keys starting from "0". Expected key "$expectedKey" at '
              'position $i, got "${sortedKeys[i]}". Use format: '
              '{ $variantName: { "0": value1, "1": value2, ... } }',
            );
          }
        }

        // Note: The REST API doesn't provide individual field type
        // information for enum variants. For multi-field variants, we use
        // the variant's type for all fields (limitation).
      }

      // Encode each field in order.
      for (final key in sortedKeys) {
        final fieldValue = variantFields[key];
        // Use the variant's type as the field type (simplified approach).
        final encoded =
            await _encodeValueByType(variantType, fieldValue, depth + 1);
        serializer.serializeFixedBytes(encoded);
      }
    } else if (variantFields != null) {
      // Single value variant (not an object).
      final encoded =
          await _encodeValueByType(variantType, variantFields, depth + 1);
      serializer.serializeFixedBytes(encoded);
    }

    return MoveEnumArgument(serializer.toUint8List());
  }

  /// Encodes an Option&lt;T&gt; enum using vector encoding for backward
  /// compatibility.
  Future<MoveEnumArgument> _encodeOptionArgument(
    TypeTagStruct structTag,
    String variant,
    Object? fieldValue,
    int depth,
  ) async {
    if (structTag.value.typeArgs.isEmpty) {
      throw ArgumentError('Option must have a type parameter');
    }

    final innerType = structTag.value.typeArgs.first;
    final serializer = Serializer();

    if (variant == 'None') {
      // None: empty vector (length = 0).
      serializer.serializeU32AsUleb128(0);
    } else if (variant == 'Some') {
      // Some: vector with one element (length = 1).
      serializer.serializeU32AsUleb128(1);

      // Extract the value from the field.
      Object? value;
      if (fieldValue is Map) {
        // Handle {"0": value} format.
        value = fieldValue.containsKey('0') && fieldValue['0'] != null
            ? fieldValue['0']
            : fieldValue;
      } else {
        value = fieldValue;
      }

      final encoded = await _encodeValueByType(innerType, value, depth + 1);
      serializer.serializeFixedBytes(encoded);
    } else {
      throw ArgumentError(
        "Unknown Option variant '$variant'. Expected 'None' or 'Some'",
      );
    }

    return MoveEnumArgument(serializer.toUint8List());
  }

  /// Checks if a struct tag represents `std::option::Option`.
  bool _isOptionType(TypeTagStruct structTag) {
    return structTag.value.address.toString() ==
            AccountAddress.one.toString() &&
        structTag.value.moduleName.identifier == 'option' &&
        structTag.value.name.identifier == 'Option';
  }

  /// Finds a struct definition by name within a module ABI.
  MoveStruct? _findStruct(MoveModule abi, String name) {
    for (final struct in abi.structs) {
      if (struct.name == name) return struct;
    }
    return null;
  }

  /// Substitute generic type parameters with concrete types.
  ///
  /// Replaces generic type parameters (T0, T1, T2, etc.) with their concrete
  /// instantiations from the struct/enum type arguments.
  ///
  /// Example: for `Box<T0> { value: T0 }` instantiated as `Box<u64>`, the
  /// field type `T0` becomes `u64`.
  TypeTag _substituteTypeParams(TypeTag fieldType, TypeTagStruct structTag) {
    // Handle generic type parameter (T0, T1, T2, etc.).
    if (fieldType is TypeTagGeneric) {
      final index = fieldType.value;
      if (index >= structTag.value.typeArgs.length) {
        throw ArgumentError(
          'Generic type parameter T$index out of bounds. '
          '${structTag.value.name.identifier} has '
          '${structTag.value.typeArgs.length} type arguments.',
        );
      }
      return structTag.value.typeArgs[index];
    }

    // Handle vector types - recursively substitute the inner type.
    if (fieldType is TypeTagVector) {
      final substitutedInner =
          _substituteTypeParams(fieldType.value, structTag);
      return TypeTagVector(substitutedInner);
    }

    // Handle struct types - recursively substitute type arguments.
    if (fieldType is TypeTagStruct) {
      if (fieldType.value.typeArgs.isEmpty) {
        // No type arguments, return as-is.
        return fieldType;
      }

      // Substitute each type argument.
      final substitutedTypeArgs = fieldType.value.typeArgs
          .map((typeArg) => _substituteTypeParams(typeArg, structTag))
          .toList();

      // Create a new struct tag with substituted type arguments.
      final newStructTag = StructTag(
        fieldType.value.address,
        fieldType.value.moduleName,
        fieldType.value.name,
        substitutedTypeArgs,
      );
      return TypeTagStruct(newStructTag);
    }

    // Primitive types and other non-generic types remain unchanged.
    return fieldType;
  }

  /// Encode a value based on its Move type.
  Future<Uint8List> _encodeValueByType(
    TypeTag typeTag,
    Object? value,
    int depth,
  ) async {
    _checkDepth(depth, 'Type');

    if (typeTag is TypeTagBool) {
      if (value is! bool) {
        throw ArgumentError(
          'Expected boolean for bool type, got ${value.runtimeType}',
        );
      }
      return Bool(value).bcsToBytes();
    }
    if (typeTag is TypeTagU8) {
      return U8(_parseNumber(value, 'u8')).bcsToBytes();
    }
    if (typeTag is TypeTagU16) {
      return U16(_parseNumber(value, 'u16')).bcsToBytes();
    }
    if (typeTag is TypeTagU32) {
      return U32(_parseNumber(value, 'u32')).bcsToBytes();
    }
    if (typeTag is TypeTagU64) {
      return U64(_parseNumberBigInt(value, 'u64')).bcsToBytes();
    }
    if (typeTag is TypeTagU128) {
      return U128(_parseNumberBigInt(value, 'u128')).bcsToBytes();
    }
    if (typeTag is TypeTagU256) {
      return U256(_parseNumberBigInt(value, 'u256')).bcsToBytes();
    }
    if (typeTag is TypeTagI8) {
      return I8(_parseNumber(value, 'i8')).bcsToBytes();
    }
    if (typeTag is TypeTagI16) {
      return I16(_parseNumber(value, 'i16')).bcsToBytes();
    }
    if (typeTag is TypeTagI32) {
      return I32(_parseNumber(value, 'i32')).bcsToBytes();
    }
    if (typeTag is TypeTagI64) {
      return I64(_parseNumberBigInt(value, 'i64')).bcsToBytes();
    }
    if (typeTag is TypeTagI128) {
      return I128(_parseNumberBigInt(value, 'i128')).bcsToBytes();
    }
    if (typeTag is TypeTagI256) {
      return I256(_parseNumberBigInt(value, 'i256')).bcsToBytes();
    }
    if (typeTag is TypeTagAddress) {
      final addr = AccountAddress.from(value!);
      return addr.bcsToBytes();
    }
    if (typeTag is TypeTagVector) {
      return _encodeVector(typeTag, value, depth);
    }
    if (typeTag is TypeTagStruct) {
      return _encodeStruct(typeTag, value, depth);
    }

    throw ArgumentError('Unsupported type: $typeTag');
  }

  /// Encode a vector value.
  Future<Uint8List> _encodeVector(
    TypeTagVector vectorType,
    Object? value,
    int depth,
  ) async {
    if (value is! List) {
      // Special case: vector<u8> can be a string.
      if (vectorType.value is TypeTagU8 && value is String) {
        // Treat as a UTF-8 encoded string. `serializeBytes` already writes
        // the ULEB128 length prefix, so we must not write the length
        // explicitly.
        final bytes = Uint8List.fromList(utf8.encode(value));
        final serializer = Serializer();
        serializer.serializeBytes(bytes);
        return serializer.toUint8List();
      }

      throw ArgumentError(
        'Expected array for vector type, got ${value.runtimeType}',
      );
    }

    final serializer = Serializer();
    serializer.serializeU32AsUleb128(value.length);

    for (final item in value) {
      final encoded =
          await _encodeValueByType(vectorType.value, item, depth + 1);
      serializer.serializeFixedBytes(encoded);
    }

    return serializer.toUint8List();
  }

  /// Encode a struct value.
  Future<Uint8List> _encodeStruct(
    TypeTagStruct structTag,
    Object? value,
    int depth,
  ) async {
    final qualifiedName = '${structTag.value.address}$_moduleSeparator'
        '${structTag.value.moduleName.identifier}$_moduleSeparator'
        '${structTag.value.name.identifier}';

    // Handle special framework types.
    if (qualifiedName == '0x1::string::String') {
      if (value is! String) {
        throw ArgumentError(
          'Expected string for String type, got ${value.runtimeType}',
        );
      }
      return MoveString(value).bcsToBytes();
    }

    if (qualifiedName == '0x1::object::Object') {
      final addr = AccountAddress.from(value!);
      return addr.bcsToBytes();
    }

    if (qualifiedName == '0x1::option::Option') {
      // Handle Option<T> in both formats.
      if (value is List) {
        // Vector format: [] or [value].
        if (value.isEmpty) {
          return MoveOption<Serializable>(null).bcsToBytes();
        }
        if (value.length == 1) {
          // Encode the inner value.
          if (structTag.value.typeArgs.isEmpty) {
            throw ArgumentError('Option must have a type parameter');
          }
          final innerType = structTag.value.typeArgs.first;
          final encodedInner =
              await _encodeValueByType(innerType, value.first, depth + 1);
          final serializer = Serializer();
          serializer.serializeU32AsUleb128(1); // Some
          serializer.serializeFixedBytes(encodedInner);
          return serializer.toUint8List();
        }
        throw ArgumentError(
          'Option as vector must have 0 or 1 elements, got ${value.length}',
        );
      }

      if (value is Map) {
        // Enum format: {"None": {}} or {"Some": {"0": value}}.
        final variantNames = value.keys.toList();
        if (variantNames.length == 1) {
          final result = await encodeEnumArgument(structTag, value, depth);
          return result.bcsToBytes();
        }
      }

      throw ArgumentError(
        'Invalid Option format. Expected array [] or [value], or enum '
        '{"None": {}} or {"Some": {...}}',
      );
    }

    // Check if this is an enum (single key = variant name).
    if (value is Map) {
      final keys = value.keys.toList();
      if (keys.length == 1) {
        // Might be an enum variant.
        // Try to fetch the struct and check the isEnum flag.
        try {
          final module = await _fetchModule(
            structTag.value.address,
            structTag.value.moduleName.identifier,
          );
          final abi = module.abi;
          if (abi != null) {
            final structDef = _findStruct(abi, structTag.value.name.identifier);
            if (structDef != null && structDef.isEnum) {
              final result = await encodeEnumArgument(structTag, value, depth);
              return result.bcsToBytes();
            }
          }
        } catch (_) {
          // If we can't determine, treat as struct.
        }
      }
    }

    // Regular struct.
    final result = await encodeStructArgument(structTag, value, depth);
    return result.bcsToBytes();
  }

  /// Parse a number from a JSON value.
  int _parseNumber(Object? value, String typeName) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        throw ArgumentError('Invalid $typeName value: $value');
      }
      return parsed;
    }
    throw ArgumentError(
      'Expected number or string for $typeName, got ${value.runtimeType}',
    );
  }

  /// Parse a [BigInt] from a JSON value.
  BigInt _parseNumberBigInt(Object? value, String typeName) {
    if (value is BigInt) {
      return value;
    }
    if (value is int) {
      return BigInt.from(value);
    }
    if (value is String) {
      final parsed = BigInt.tryParse(value);
      if (parsed == null) {
        throw ArgumentError('Invalid $typeName value: $value');
      }
      return parsed;
    }
    throw ArgumentError(
      'Expected number, bigint, or string for $typeName, got '
      '${value.runtimeType}',
    );
  }
}
