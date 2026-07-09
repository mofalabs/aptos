/// Remote ABI handling: fetching function/module ABIs from the chain and
/// converting raw argument values into BCS-encoded entry function arguments.
/// Also includes the argument type-guard helpers.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../api/aptos_config.dart';
import '../../bcs/serializable/fixed_bytes.dart';
import '../../bcs/serializable/move_primitives.dart';
import '../../bcs/serializable/move_structs.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../internal/account.dart';
import '../../types/move_types.dart';
import '../../utils/helpers.dart';
import '../../utils/memoize.dart';
import '../instances/transaction_argument.dart';
import '../type_tag/parser.dart';
import '../type_tag/type_tag.dart';
import '../types.dart';
import 'struct_enum_parser.dart';

/// Convert type arguments to only type tags, allowing for string
/// representations of type tags.
List<TypeTag> standardizeTypeTags(List<TypeArgument>? typeArguments) {
  if (typeArguments == null) return [];
  return typeArguments.map((typeArg) {
    // Convert to TypeTag if it's a string representation.
    if (typeArg is String) {
      return parseTypeTag(typeArg);
    }
    if (typeArg is TypeTag) {
      return typeArg;
    }
    throw ArgumentError(
      'Type argument must be a TypeTag or String, got '
      '${typeArg.runtimeType}',
    );
  }).toList();
}

/// Cache TTL for module ABIs (5 minutes).
/// ABIs rarely change, so a longer cache is acceptable.
const Duration _moduleAbiCacheTtl = Duration(minutes: 5);

/// Represents a bundle of a module ABI along with all struct ABIs it
/// references. This allows for offline struct/enum encoding without
/// additional network calls.
class ModuleAbiBundle {
  /// The main module ABI.
  final MoveModule module;

  /// Map of modules containing referenced struct ABIs:
  /// "address::module" -> [MoveModule].
  final Map<String, MoveModule> referencedStructModules;

  const ModuleAbiBundle({
    required this.module,
    required this.referencedStructModules,
  });
}

/// Extracts all struct type references from a module's struct fields and
/// function parameters. Returns a set of unique module identifiers
/// (`address::moduleName`) that need to be fetched.
Set<String> _extractReferencedStructModules(MoveModule module) {
  final referencedModules = <String>{};
  final moduleId = '${module.address}::${module.name}';

  // Helper to parse a type string and extract struct references. Matches
  // patterns like 0x1::module::Struct, address::module::Struct<T>, and
  // handles generic types and vectors: vector<0x1::module::Struct<T>>.
  final structPattern = RegExp(r'(0x[a-fA-F0-9]+)::([\w_]+)::([\w_]+)');
  void parseTypeForStructs(String typeStr) {
    for (final match in structPattern.allMatches(typeStr)) {
      final address = match.group(1)!;
      final modName = match.group(2)!;
      final refModuleId = '$address::$modName';

      // Don't include self-references or standard library types that don't
      // need fetching.
      if (refModuleId != moduleId && !refModuleId.startsWith('0x1::')) {
        referencedModules.add(refModuleId);
      }
    }
  }

  // Extract from struct fields.
  for (final struct in module.structs) {
    for (final field in struct.fields) {
      parseTypeForStructs(field.type);
    }
  }

  // Extract from function parameters and return types.
  for (final func in module.exposedFunctions) {
    for (final param in func.params) {
      parseTypeForStructs(param);
    }
    for (final ret in func.returnTypes) {
      parseTypeForStructs(ret);
    }
  }

  return referencedModules;
}

/// Fetches the ABI of a specified module from the on-chain module ABI.
/// Results are cached for 5 minutes to reduce redundant network calls.
Future<MoveModule?> fetchModuleAbi(
  String moduleAddress,
  String moduleName,
  AptosConfig aptosConfig,
) {
  final cacheKey =
      'module-abi-${aptosConfig.network.value}-$moduleAddress-$moduleName';

  return memoizeAsync<MoveModule?>(
    () async {
      final moduleBytecode = await getModule(
        aptosConfig: aptosConfig,
        accountAddress: moduleAddress,
        moduleName: moduleName,
      );
      return moduleBytecode.abi;
    },
    cacheKey,
    ttl: _moduleAbiCacheTtl,
  )();
}

/// Fetches a module ABI along with all struct ABIs it references.
/// This optimization minimizes nested network calls when encoding
/// struct/enum arguments.
///
/// Strategy:
/// - Fetches the main module ABI
/// - Parses all type references in struct fields and function parameters
/// - Fetches ABIs for all referenced struct modules in parallel
/// - Caches the complete bundle together
Future<ModuleAbiBundle> fetchModuleAbiWithStructs(
  String moduleAddress,
  String moduleName,
  AptosConfig aptosConfig,
) {
  final cacheKey = 'module-abi-bundle-${aptosConfig.network.value}-'
      '$moduleAddress-$moduleName';

  return memoizeAsync(
    () async {
      // Fetch the main module ABI.
      final module =
          await fetchModuleAbi(moduleAddress, moduleName, aptosConfig);
      if (module == null) {
        throw StateError('Module not found: $moduleAddress::$moduleName');
      }

      // Extract all struct modules referenced by this module.
      final referencedModuleIds = _extractReferencedStructModules(module);
      final referencedStructModules = <String, MoveModule>{};

      // Fetch all referenced struct modules in parallel.
      if (referencedModuleIds.isNotEmpty) {
        await Future.wait(referencedModuleIds.map((moduleId) async {
          final parts = moduleId.split('::');
          try {
            final structModule =
                await fetchModuleAbi(parts[0], parts[1], aptosConfig);
            if (structModule != null) {
              referencedStructModules[moduleId] = structModule;
            }
          } catch (_) {
            // Silently ignore fetch failures - the struct might not be used
            // in this execution path. If it's actually needed, the error
            // will surface during encoding.
          }
        }));
      }

      return ModuleAbiBundle(
        module: module,
        referencedStructModules: referencedStructModules,
      );
    },
    cacheKey,
    ttl: _moduleAbiCacheTtl,
  )();
}

/// Fetches the ABI of a specified function from the on-chain module ABI.
/// This function allows you to access the details of a specific function
/// within a module.
Future<MoveFunction?> fetchFunctionAbi(
  String moduleAddress,
  String moduleName,
  String functionName,
  AptosConfig aptosConfig,
) async {
  final moduleAbi =
      await fetchModuleAbi(moduleAddress, moduleName, aptosConfig);
  if (moduleAbi == null) {
    throw StateError(
      "Could not find module ABI for '$moduleAddress::$moduleName'",
    );
  }
  for (final func in moduleAbi.exposedFunctions) {
    if (func.name == functionName) return func;
  }
  return null;
}

/// Fetches a function's generic ABI (all parameters, including signers).
@Deprecated('Use fetchFunctionAbi instead and manually parse the type tags.')
Future<FunctionABI> fetchMoveFunctionAbi(
  String moduleAddress,
  String moduleName,
  String functionName,
  AptosConfig aptosConfig,
) async {
  final functionAbi = await fetchFunctionAbi(
      moduleAddress, moduleName, functionName, aptosConfig);
  if (functionAbi == null) {
    throw StateError(
      'Could not find function ABI for '
      "'$moduleAddress::$moduleName::$functionName'",
    );
  }
  final params = <TypeTag>[];
  for (final param in functionAbi.params) {
    params.add(parseTypeTag(param, allowGenerics: true));
  }

  return FunctionABI(
    typeParameters: functionAbi.genericTypeParams,
    parameters: params,
  );
}

/// Fetches the ABI for an entry function from the specified module address.
/// This function validates if the ABI corresponds to an entry function and
/// retrieves its parameters (with leading signer arguments removed).
///
/// Throws if the ABI cannot be found or if the function is not an entry
/// function.
Future<EntryFunctionABI> fetchEntryFunctionAbi(
  String moduleAddress,
  String moduleName,
  String functionName,
  AptosConfig aptosConfig,
) async {
  final functionAbi = await fetchFunctionAbi(
      moduleAddress, moduleName, functionName, aptosConfig);

  // If there's no ABI, then the function is invalid.
  if (functionAbi == null) {
    throw StateError(
      'Could not find entry function ABI for '
      "'$moduleAddress::$moduleName::$functionName'",
    );
  }

  // Non-entry functions also can't be used.
  if (!functionAbi.isEntry) {
    throw StateError(
      "'$moduleAddress::$moduleName::$functionName' is not an entry function",
    );
  }

  // Remove the signer arguments.
  final numSigners = findFirstNonSignerArg(functionAbi);
  final params = <TypeTag>[];
  for (var i = numSigners; i < functionAbi.params.length; i += 1) {
    params.add(parseTypeTag(functionAbi.params[i], allowGenerics: true));
  }

  return EntryFunctionABI(
    signers: numSigners,
    typeParameters: functionAbi.genericTypeParams,
    parameters: params,
  );
}

/// Fetches the ABI for a view function from the specified module address.
/// This function ensures that the ABI is valid and retrieves the type
/// parameters, parameters, and return types for the view function.
///
/// Throws if the ABI cannot be found or if the function is not a view
/// function.
Future<ViewFunctionABI> fetchViewFunctionAbi(
  String moduleAddress,
  String moduleName,
  String functionName,
  AptosConfig aptosConfig,
) async {
  final functionAbi = await fetchFunctionAbi(
      moduleAddress, moduleName, functionName, aptosConfig);

  // If there's no ABI, then the function is invalid.
  if (functionAbi == null) {
    throw StateError(
      'Could not find view function ABI for '
      "'$moduleAddress::$moduleName::$functionName'",
    );
  }

  // Non-view functions can't be used.
  if (!functionAbi.isView) {
    throw StateError(
      "'$moduleAddress::$moduleName::$functionName' is not an view function",
    );
  }

  // Type tag parameters for the function.
  final params = <TypeTag>[];
  for (final param in functionAbi.params) {
    params.add(parseTypeTag(param, allowGenerics: true));
  }

  // The return types of the view function.
  final returnTypes = <TypeTag>[];
  for (final returnType in functionAbi.returnTypes) {
    returnTypes.add(parseTypeTag(returnType, allowGenerics: true));
  }

  return ViewFunctionABI(
    typeParameters: functionAbi.genericTypeParams,
    parameters: params,
    returnTypes: returnTypes,
  );
}

/// Resolves the parameter [TypeTag] for the argument at [position] from
/// either a [MoveModule] or a [FunctionABI].
TypeTag _resolveParam(
  String functionName,
  Object functionAbiOrModuleAbi,
  int position,
) {
  if (functionAbiOrModuleAbi is MoveModule) {
    MoveFunction? functionAbi;
    for (final func in functionAbiOrModuleAbi.exposedFunctions) {
      if (func.name == functionName) {
        functionAbi = func;
        break;
      }
    }
    if (functionAbi == null) {
      throw StateError(
        'Could not find function ABI for '
        "'${functionAbiOrModuleAbi.address}::"
        "${functionAbiOrModuleAbi.name}::$functionName'",
      );
    }

    if (position >= functionAbi.params.length) {
      throw ArgumentError(
        "Too many arguments for '$functionName', expected "
        '${functionAbi.params.length}',
      );
    }

    return parseTypeTag(functionAbi.params[position], allowGenerics: true);
  }

  if (functionAbiOrModuleAbi is FunctionABI) {
    if (position >= functionAbiOrModuleAbi.parameters.length) {
      throw ArgumentError(
        "Too many arguments for '$functionName', expected "
        '${functionAbiOrModuleAbi.parameters.length}',
      );
    }

    return functionAbiOrModuleAbi.parameters[position];
  }

  throw ArgumentError(
    'functionAbiOrModuleAbi must be a MoveModule or FunctionABI, got '
    '${functionAbiOrModuleAbi.runtimeType}',
  );
}

/// Converts a non-BCS encoded argument into BCS encoded, if necessary.
/// This is the synchronous version that works offline with pre-fetched ABIs.
/// Does NOT support plain-object struct/enum arguments - use
/// [convertArgumentWithABI] for those.
///
/// [functionAbiOrModuleAbi] is either a [MoveModule] or a [FunctionABI].
EntryFunctionArgument convertArgument(
  String functionName,
  Object functionAbiOrModuleAbi,
  Object? arg,
  int position,
  List<TypeTag> genericTypeParams, {
  bool allowUnknownStructs = false,
}) {
  final param = _resolveParam(functionName, functionAbiOrModuleAbi, position);

  return checkOrConvertArgument(
    arg,
    param,
    position,
    genericTypeParams,
    moduleAbi:
        functionAbiOrModuleAbi is MoveModule ? functionAbiOrModuleAbi : null,
    allowUnknownStructs: allowUnknownStructs,
  );
}

/// Converts a non-BCS encoded argument into BCS encoded, with support for
/// struct/enum arguments. This is the asynchronous version that fetches
/// module ABIs from the network as needed.
Future<EntryFunctionArgument> convertArgumentWithABI(
  String functionName,
  Object functionAbiOrModuleAbi,
  Object? arg,
  int position,
  List<TypeTag> genericTypeParams,
  AptosConfig aptosConfig, {
  bool allowUnknownStructs = false,
}) {
  final param = _resolveParam(functionName, functionAbiOrModuleAbi, position);

  return checkOrConvertArgumentWithABI(
    arg,
    param,
    position,
    genericTypeParams,
    aptosConfig,
    moduleAbi:
        functionAbiOrModuleAbi is MoveModule ? functionAbiOrModuleAbi : null,
    allowUnknownStructs: allowUnknownStructs,
  );
}

/// Checks if the provided argument is BCS encoded and converts it if
/// necessary, ensuring type compatibility with the ABI.
/// This is the synchronous version that works offline with pre-fetched ABIs.
/// Does NOT support plain-object struct/enum arguments - use
/// [checkOrConvertArgumentWithABI] for those.
EntryFunctionArgument checkOrConvertArgument(
  Object? arg,
  TypeTag param,
  int position,
  List<TypeTag> genericTypeParams, {
  MoveModule? moduleAbi,
  bool allowUnknownStructs = false,
}) {
  // If the argument is bcs encoded, we can just use it directly.
  if (isEncodedEntryFunctionArgument(arg)) {
    // If the expected type is Option but the arg is not already a
    // MoveOption, wrap it after validating it matches the Option's inner
    // type. This handles cases like Vector<Option<address>> where elements
    // may be passed as AccountAddress instead of MoveOption<AccountAddress>.
    if (param is TypeTagStruct && param.isOption() && arg is! MoveOption) {
      return MoveOption<Serializable>(
        checkOrConvertArgument(
          arg,
          param.value.typeArgs[0],
          position,
          genericTypeParams,
          moduleAbi: moduleAbi,
          allowUnknownStructs: allowUnknownStructs,
        ) as Serializable,
      );
    }

    // Ensure the type matches the ABI.
    _checkType(param, arg, position);
    return arg as EntryFunctionArgument;
  }

  // If it is not BCS encoded, we will need to convert it with the ABI.
  return _parseArgSync(
    arg,
    param,
    position,
    genericTypeParams,
    moduleAbi: moduleAbi,
    allowUnknownStructs: allowUnknownStructs,
  );
}

/// Checks if the provided argument is BCS encoded and converts it if
/// necessary, with support for struct/enum arguments. This is the
/// asynchronous version that fetches module ABIs from the network as needed.
Future<EntryFunctionArgument> checkOrConvertArgumentWithABI(
  Object? arg,
  TypeTag param,
  int position,
  List<TypeTag> genericTypeParams,
  AptosConfig aptosConfig, {
  MoveModule? moduleAbi,
  bool allowUnknownStructs = false,
}) async {
  // If the argument is bcs encoded, we can just use it directly.
  if (isEncodedEntryFunctionArgument(arg)) {
    // If the expected type is Option but the arg is not already a
    // MoveOption, wrap it after validating it matches the Option's inner
    // type. This mirrors the behavior of the synchronous
    // `checkOrConvertArgument` path.
    if (param is TypeTagStruct && param.isOption() && arg is! MoveOption) {
      final inner = await checkOrConvertArgumentWithABI(
        arg,
        param.value.typeArgs[0],
        position,
        genericTypeParams,
        aptosConfig,
        moduleAbi: moduleAbi,
        allowUnknownStructs: allowUnknownStructs,
      );
      return MoveOption<Serializable>(inner as Serializable);
    }

    // Ensure the type matches the ABI.
    _checkType(param, arg, position);
    return arg as EntryFunctionArgument;
  }

  // If it is not BCS encoded, we will need to convert it with the ABI.
  return _parseArgAsync(
    arg,
    param,
    position,
    genericTypeParams,
    aptosConfig,
    moduleAbi: moduleAbi,
    allowUnknownStructs: allowUnknownStructs,
  );
}

/// Reconstructs an empty `MoveOption` typed by the Option's inner type tag.
MoveOption<Serializable> _emptyOptionFor(TypeTag innerParam) {
  if (innerParam is TypeTagBool) return MoveOption<Bool>(null);
  if (innerParam is TypeTagAddress) return MoveOption<AccountAddress>(null);
  if (innerParam is TypeTagU8) return MoveOption<U8>(null);
  if (innerParam is TypeTagU16) return MoveOption<U16>(null);
  if (innerParam is TypeTagU32) return MoveOption<U32>(null);
  if (innerParam is TypeTagU64) return MoveOption<U64>(null);
  if (innerParam is TypeTagU128) return MoveOption<U128>(null);
  if (innerParam is TypeTagU256) return MoveOption<U256>(null);
  if (innerParam is TypeTagI8) return MoveOption<I8>(null);
  if (innerParam is TypeTagI16) return MoveOption<I16>(null);
  if (innerParam is TypeTagI32) return MoveOption<I32>(null);
  if (innerParam is TypeTagI64) return MoveOption<I64>(null);
  if (innerParam is TypeTagI128) return MoveOption<I128>(null);
  if (innerParam is TypeTagI256) return MoveOption<I256>(null);

  // In all other cases, we will use a placeholder; it doesn't actually
  // matter what the type is, since an empty option serializes identically.
  return MoveOption<MoveString>(null);
}

/// Handles the primitive conversions shared between the sync and async parse
/// paths. Returns `null` when [param] is not a primitive type.
EntryFunctionArgument? _parsePrimitiveArg(
  Object? arg,
  TypeTag param,
  int position,
) {
  if (param.isBool()) {
    if (arg is bool) {
      return Bool(arg);
    }
    if (arg is String) {
      if (arg == 'true') return Bool(true);
      if (arg == 'false') return Bool(false);
    }
    throwTypeMismatch('boolean', position);
  }
  if (param.isAddress()) {
    if (arg is String) {
      return AccountAddress.fromString(arg);
    }
    throwTypeMismatch('string | AccountAddress', position);
  }
  if (param.isU8()) {
    final num = convertNumber(arg);
    if (num != null) return U8(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isU16()) {
    final num = convertNumber(arg);
    if (num != null) return U16(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isU32()) {
    final num = convertNumber(arg);
    if (num != null) return U32(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isU64()) {
    if (isLargeNumber(arg)) return U64(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  if (param.isU128()) {
    if (isLargeNumber(arg)) return U128(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  if (param.isU256()) {
    if (isLargeNumber(arg)) return U256(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  if (param.isI8()) {
    final num = convertNumber(arg);
    if (num != null) return I8(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isI16()) {
    final num = convertNumber(arg);
    if (num != null) return I16(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isI32()) {
    final num = convertNumber(arg);
    if (num != null) return I32(num);
    throwTypeMismatch('number | string', position);
  }
  if (param.isI64()) {
    if (isLargeNumber(arg)) return I64(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  if (param.isI128()) {
    if (isLargeNumber(arg)) return I128(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  if (param.isI256()) {
    if (isLargeNumber(arg)) return I256(_toBigInt(arg));
    throwTypeMismatch('bigint | number | string', position);
  }
  return null;
}

/// Parses a non-BCS encoded argument into a BCS encoded argument recursively.
/// This is the synchronous version that works offline with pre-fetched ABIs.
/// Does NOT support plain-object struct/enum arguments - throws an error if
/// encountered.
EntryFunctionArgument _parseArgSync(
  Object? arg,
  TypeTag param,
  int position,
  List<TypeTag> genericTypeParams, {
  MoveModule? moduleAbi,
  bool allowUnknownStructs = false,
}) {
  final primitive = _parsePrimitiveArg(arg, param, position);
  if (primitive != null) return primitive;

  // Generic needs to use the subtype.
  if (param is TypeTagGeneric) {
    final genericIndex = param.value;
    if (genericIndex < 0 || genericIndex >= genericTypeParams.length) {
      throw ArgumentError(
        'Generic argument $param is invalid for argument $position',
      );
    }

    return checkOrConvertArgument(
      arg,
      genericTypeParams[genericIndex],
      position,
      genericTypeParams,
      moduleAbi: moduleAbi,
      allowUnknownStructs: allowUnknownStructs,
    );
  }

  // We have to special case some vectors for Vector<u8>.
  if (param is TypeTagVector) {
    // Check special case for Vector<u8>.
    if (param.value.isU8()) {
      // We don't allow vector<u8>, but we convert strings to UTF-8 bytes.
      // This is legacy behavior from the original SDK.
      if (arg is String) {
        return MoveVector.u8(Uint8List.fromList(utf8.encode(arg)));
      }
      if (arg is Uint8List) {
        return MoveVector.u8(arg);
      }
      if (arg is ByteBuffer) {
        return MoveVector.u8(arg.asUint8List());
      }
    }

    if (arg is String && arg.startsWith('[')) {
      // In a web env, arguments are passed as strings.
      return checkOrConvertArgument(
        jsonDecode(arg),
        param,
        position,
        genericTypeParams,
        moduleAbi: moduleAbi,
        allowUnknownStructs: allowUnknownStructs,
      );
    }

    // Note: typed-data lists (e.g. Int8List, Uint16List) are intentionally
    // not treated as plain arrays; typed byte buffers other than Uint8List
    // are unsupported here.
    if (arg is List && arg is! TypedData) {
      return MoveVector<Serializable>(
        arg
            .map((item) => checkOrConvertArgument(
                  item,
                  param.value,
                  position,
                  genericTypeParams,
                  moduleAbi: moduleAbi,
                  allowUnknownStructs: allowUnknownStructs,
                ) as Serializable)
            .toList(),
      );
    }

    throw ArgumentError("Type mismatch for argument $position, type '$param'");
  }

  // Handle structs as they're more complex.
  if (param is TypeTagStruct) {
    if (param.isString()) {
      if (arg is String) {
        return MoveString(arg);
      }
      throwTypeMismatch('string', position);
    }
    if (param.isObject()) {
      // The inner type of Object doesn't matter, since it's just syntactic
      // sugar.
      if (arg is String) {
        return AccountAddress.fromString(arg);
      }
      throwTypeMismatch('string | AccountAddress', position);
    }
    // Handle known enum types from the Aptos framework.
    if (param.isDelegationKey() || param.isRateLimiter()) {
      if (arg is Uint8List) {
        return FixedBytes(arg);
      }
      throwTypeMismatch('Uint8Array', position);
    }

    if (param.isOption()) {
      if (isEmptyOption(arg)) {
        // Here we attempt to reconstruct the underlying type.
        return _emptyOptionFor(param.value.typeArgs[0]);
      }

      return MoveOption<Serializable>(
        checkOrConvertArgument(
          arg,
          param.value.typeArgs[0],
          position,
          genericTypeParams,
          moduleAbi: moduleAbi,
        ) as Serializable,
      );
    }

    // Check if this looks like a custom struct/enum argument.
    if (arg is Map) {
      // Struct/enum arguments require async conversion.
      throw ArgumentError(
        'Struct/enum arguments require async conversion. '
        'Use checkOrConvertArgumentWithABI() instead, or pre-encode the '
        'argument with StructEnumArgumentParser. '
        "Type: '$param', position: $position",
      );
    }

    // We are assuming that fieldless structs are enums.
    final structDefinition = _findStructDef(moduleAbi, param);
    if (structDefinition != null &&
        structDefinition.fields.isEmpty &&
        arg is Uint8List) {
      return FixedBytes(arg);
    }

    if (arg is Uint8List && allowUnknownStructs) {
      warnIfDevelopment(
        '[Aptos SDK] Unsupported struct input type for argument $position. '
        "Continuing since 'allowUnknownStructs' is enabled.",
      );
      return FixedBytes(arg);
    }

    throw ArgumentError(
      "Unsupported struct input type for argument $position, type '$param'",
    );
  }

  throw ArgumentError("Type mismatch for argument $position, type '$param'");
}

/// Parses a non-BCS encoded argument into a BCS encoded argument recursively.
/// This is the asynchronous version that supports struct/enum arguments via
/// network calls.
Future<EntryFunctionArgument> _parseArgAsync(
  Object? arg,
  TypeTag param,
  int position,
  List<TypeTag> genericTypeParams,
  AptosConfig aptosConfig, {
  MoveModule? moduleAbi,
  bool allowUnknownStructs = false,
}) async {
  final primitive = _parsePrimitiveArg(arg, param, position);
  if (primitive != null) return primitive;

  // Generic needs to use the subtype.
  if (param is TypeTagGeneric) {
    final genericIndex = param.value;
    if (genericIndex < 0 || genericIndex >= genericTypeParams.length) {
      throw ArgumentError(
        'Generic argument $param is invalid for argument $position',
      );
    }

    return checkOrConvertArgumentWithABI(
      arg,
      genericTypeParams[genericIndex],
      position,
      genericTypeParams,
      aptosConfig,
      moduleAbi: moduleAbi,
      allowUnknownStructs: allowUnknownStructs,
    );
  }

  // We have to special case some vectors for Vector<u8>.
  if (param is TypeTagVector) {
    // Check special case for Vector<u8>.
    if (param.value.isU8()) {
      // We don't allow vector<u8>, but we convert strings to UTF-8 bytes.
      // This is legacy behavior from the original SDK.
      if (arg is String) {
        return MoveVector.u8(Uint8List.fromList(utf8.encode(arg)));
      }
      if (arg is Uint8List) {
        return MoveVector.u8(arg);
      }
      if (arg is ByteBuffer) {
        return MoveVector.u8(arg.asUint8List());
      }
    }

    if (arg is String && arg.startsWith('[')) {
      // In a web env, arguments are passed as strings.
      return checkOrConvertArgumentWithABI(
        jsonDecode(arg),
        param,
        position,
        genericTypeParams,
        aptosConfig,
        moduleAbi: moduleAbi,
        allowUnknownStructs: allowUnknownStructs,
      );
    }

    // Note: typed-data lists (e.g. Int8List, Uint16List) are intentionally
    // not treated as plain arrays; typed byte buffers other than Uint8List
    // are unsupported here.
    if (arg is List && arg is! TypedData) {
      final elements = <Serializable>[];
      for (final item in arg) {
        elements.add(await checkOrConvertArgumentWithABI(
          item,
          param.value,
          position,
          genericTypeParams,
          aptosConfig,
          moduleAbi: moduleAbi,
          allowUnknownStructs: allowUnknownStructs,
        ) as Serializable);
      }
      return MoveVector<Serializable>(elements);
    }

    throw ArgumentError("Type mismatch for argument $position, type '$param'");
  }

  // Handle structs as they're more complex.
  if (param is TypeTagStruct) {
    if (param.isString()) {
      if (arg is String) {
        return MoveString(arg);
      }
      throwTypeMismatch('string', position);
    }
    if (param.isObject()) {
      // The inner type of Object doesn't matter, since it's just syntactic
      // sugar.
      if (arg is String) {
        return AccountAddress.fromString(arg);
      }
      throwTypeMismatch('string | AccountAddress', position);
    }
    // Handle known enum types from the Aptos framework.
    if (param.isDelegationKey() || param.isRateLimiter()) {
      if (arg is Uint8List) {
        return FixedBytes(arg);
      }
      throwTypeMismatch('Uint8Array', position);
    }

    if (param.isOption()) {
      if (isEmptyOption(arg)) {
        // Here we attempt to reconstruct the underlying type.
        return _emptyOptionFor(param.value.typeArgs[0]);
      }

      final value = await checkOrConvertArgumentWithABI(
        arg,
        param.value.typeArgs[0],
        position,
        genericTypeParams,
        aptosConfig,
        moduleAbi: moduleAbi,
      );
      return MoveOption<Serializable>(value as Serializable);
    }

    // Handle custom public copy structs and enums.
    if (arg is Map) {
      // Fetch the module ABI bundle with all referenced struct modules.
      // This optimization minimizes nested network calls.
      final moduleAddress = param.value.address.toString();
      final moduleName = param.value.moduleName.identifier;

      try {
        final abiBundle = await fetchModuleAbiWithStructs(
            moduleAddress, moduleName, aptosConfig);

        // Instantiate the parser and preload it with all referenced struct
        // modules.
        final parser = StructEnumArgumentParser(aptosConfig);

        // Convert the bundle's modules to MoveModuleBytecode format for
        // preloading.
        final modulesToPreload = <String, MoveModuleBytecode>{
          '$moduleAddress::$moduleName':
              MoveModuleBytecode(bytecode: '', abi: abiBundle.module),
        };
        for (final entry in abiBundle.referencedStructModules.entries) {
          modulesToPreload[entry.key] =
              MoveModuleBytecode(bytecode: '', abi: entry.value);
        }
        parser.preloadModules(modulesToPreload);

        // Check the ABI to determine if this is an enum or struct.
        MoveStruct? structDef;
        for (final struct in abiBundle.module.structs) {
          if (struct.name == param.value.name.identifier) {
            structDef = struct;
            break;
          }
        }

        bool isEnumType;
        if (structDef != null) {
          // Trust the ABI when available.
          isEnumType = structDef.isEnum;
        } else {
          // Fallback heuristic when the ABI is not available:
          // Enums typically have format: { "VariantName": {...} } with a
          // single key.
          final keys = arg.keys.toList();
          isEnumType = keys.length == 1 && arg[keys.first] is Map;
        }

        if (isEnumType) {
          // Encode as enum.
          return await parser.encodeEnumArgument(param, arg);
        }
        // Encode as struct.
        return await parser.encodeStructArgument(param, arg);
      } catch (e) {
        throw StateError(
          'Failed to encode struct/enum argument at position $position, '
          "type '$param': $e",
        );
      }
    }

    // We are assuming that fieldless structs are enums, and therefore we
    // cannot typecheck any further due to limited information from the ABI.
    // This does not work for structs on other modules.
    final structDefinition = _findStructDef(moduleAbi, param);
    if (structDefinition != null &&
        structDefinition.fields.isEmpty &&
        arg is Uint8List) {
      return FixedBytes(arg);
    }

    if (arg is Uint8List && allowUnknownStructs) {
      warnIfDevelopment(
        '[Aptos SDK] Unsupported struct input type for argument $position. '
        "Continuing since 'allowUnknownStructs' is enabled.",
      );
      return FixedBytes(arg);
    }

    throw ArgumentError(
      "Unsupported struct input type for argument $position, type '$param'",
    );
  }

  throw ArgumentError("Type mismatch for argument $position, type '$param'");
}

MoveStruct? _findStructDef(MoveModule? moduleAbi, TypeTagStruct param) {
  if (moduleAbi == null) return null;
  for (final struct in moduleAbi.structs) {
    if (struct.name == param.value.name.identifier) return struct;
  }
  return null;
}

/// Checks that the type of the BCS encoded argument matches the ABI.
void _checkType(TypeTag param, Object? arg, int position) {
  if (param.isBool()) {
    if (isBcsBool(arg)) return;
    throwTypeMismatch('Bool', position);
  }
  if (param.isAddress()) {
    if (isBcsAddress(arg)) return;
    throwTypeMismatch('AccountAddress', position);
  }
  if (param.isU8()) {
    if (isBcsU8(arg)) return;
    throwTypeMismatch('U8', position);
  }
  if (param.isU16()) {
    if (isBcsU16(arg)) return;
    throwTypeMismatch('U16', position);
  }
  if (param.isU32()) {
    if (isBcsU32(arg)) return;
    throwTypeMismatch('U32', position);
  }
  if (param.isU64()) {
    if (isBcsU64(arg)) return;
    throwTypeMismatch('U64', position);
  }
  if (param.isU128()) {
    if (isBcsU128(arg)) return;
    throwTypeMismatch('U128', position);
  }
  if (param.isU256()) {
    if (isBcsU256(arg)) return;
    throwTypeMismatch('U256', position);
  }
  if (param.isI8()) {
    if (isBcsI8(arg)) return;
    throwTypeMismatch('I8', position);
  }
  if (param.isI16()) {
    if (isBcsI16(arg)) return;
    throwTypeMismatch('I16', position);
  }
  if (param.isI32()) {
    if (isBcsI32(arg)) return;
    throwTypeMismatch('I32', position);
  }
  if (param.isI64()) {
    if (isBcsI64(arg)) return;
    throwTypeMismatch('I64', position);
  }
  if (param.isI128()) {
    if (isBcsI128(arg)) return;
    throwTypeMismatch('I128', position);
  }
  if (param.isI256()) {
    if (isBcsI256(arg)) return;
    throwTypeMismatch('I256', position);
  }
  if (param is TypeTagVector) {
    if (arg is MoveVector) {
      // If there's anything in it, check that the inner types match.
      // Note that since it's typed, the first item should be the same as
      // the rest.
      if (arg.values.isNotEmpty) {
        _checkType(param.value, arg.values.first, position);
      }
      return;
    }
    throwTypeMismatch('MoveVector', position);
  }

  // Handle structs as they're more complex.
  if (param is TypeTagStruct) {
    if (param.isString()) {
      if (isBcsString(arg)) return;
      throwTypeMismatch('MoveString', position);
    }
    if (param.isObject()) {
      if (isBcsAddress(arg)) return;
      throwTypeMismatch('AccountAddress', position);
    }
    if (param.isOption()) {
      if (arg is MoveOption) {
        // If there's a value, we can check the inner type (otherwise it
        // doesn't really matter).
        if (arg.value != null) {
          _checkType(param.value.typeArgs[0], arg.value, position);
        }
        return;
      }
      throwTypeMismatch('MoveOption', position);
    }

    // For custom (non-framework) struct/enum params, accept the pre-encoded
    // argument types: MoveStructArgument, MoveEnumArgument, or FixedBytes.
    // We cannot fully verify the inner BCS bytes without the ABI, but
    // accepting these classes is safer than rejecting valid pre-encoded
    // inputs and is required for documented "pre-encode and pass" flows.
    if (arg is MoveStructArgument ||
        arg is MoveEnumArgument ||
        arg is FixedBytes) {
      return;
    }

    throwTypeMismatch(
        'MoveStructArgument | MoveEnumArgument | FixedBytes', position);
  }

  throw ArgumentError(
      "Type mismatch for argument $position, expected '$param'");
}

// ARGUMENT TYPE HELPERS //

/// Determines if the provided argument is of type boolean.
bool isBool(Object? arg) => arg is bool;

/// Determines if the provided argument is of type number.
bool isNumber(Object? arg) => arg is int;

/// Converts a number or a string representation of a number into an `int`.
/// Returns `null` if the input cannot be converted.
int? convertNumber(Object? arg) {
  if (arg is int) return arg;
  if (arg is String && arg.isNotEmpty) return int.tryParse(arg);
  return null;
}

/// Determines if the provided argument is a large number: an `int`, a
/// [BigInt], or a string representation of a number.
bool isLargeNumber(Object? arg) => arg is int || arg is BigInt || arg is String;

/// Converts an `int`, [BigInt], or numeric [String] into a [BigInt].
BigInt _toBigInt(Object? arg) {
  if (arg is BigInt) return arg;
  if (arg is int) return BigInt.from(arg);
  if (arg is String) return BigInt.parse(arg);
  throw ArgumentError('Cannot convert ${arg.runtimeType} to BigInt');
}

/// Checks if the provided argument is empty (i.e. `null`), meaning "no value"
/// for an option.
bool isEmptyOption(Object? arg) => arg == null;

/// Determines if the provided argument is a valid, already BCS-encoded entry
/// function argument type.
bool isEncodedEntryFunctionArgument(Object? arg) {
  return isBcsBool(arg) ||
      isBcsU8(arg) ||
      isBcsU16(arg) ||
      isBcsU32(arg) ||
      isBcsU64(arg) ||
      isBcsU128(arg) ||
      isBcsU256(arg) ||
      isBcsAddress(arg) ||
      isBcsString(arg) ||
      isBcsFixedBytes(arg) ||
      isBcsI8(arg) ||
      isBcsI16(arg) ||
      isBcsI32(arg) ||
      isBcsI64(arg) ||
      isBcsI128(arg) ||
      isBcsI256(arg) ||
      arg is MoveVector ||
      arg is MoveOption ||
      arg is MoveStructArgument ||
      arg is MoveEnumArgument;
}

/// Determines if the provided argument is an instance of [Bool].
bool isBcsBool(Object? arg) => arg is Bool;

/// Determines if the provided argument is an instance of [AccountAddress].
bool isBcsAddress(Object? arg) => arg is AccountAddress;

/// Determines if the provided argument is an instance of [MoveString].
bool isBcsString(Object? arg) => arg is MoveString;

/// Determines if the provided argument is an instance of [FixedBytes].
bool isBcsFixedBytes(Object? arg) => arg is FixedBytes;

/// Determines if the provided argument is an instance of [U8].
bool isBcsU8(Object? arg) => arg is U8;

/// Determines if the provided argument is an instance of [U16].
bool isBcsU16(Object? arg) => arg is U16;

/// Determines if the provided argument is an instance of [U32].
bool isBcsU32(Object? arg) => arg is U32;

/// Determines if the provided argument is an instance of [U64].
bool isBcsU64(Object? arg) => arg is U64;

/// Determines if the provided argument is an instance of [U128].
bool isBcsU128(Object? arg) => arg is U128;

/// Determines if the provided argument is an instance of [U256].
bool isBcsU256(Object? arg) => arg is U256;

/// Determines if the provided argument is an instance of [I8].
bool isBcsI8(Object? arg) => arg is I8;

/// Determines if the provided argument is an instance of [I16].
bool isBcsI16(Object? arg) => arg is I16;

/// Determines if the provided argument is an instance of [I32].
bool isBcsI32(Object? arg) => arg is I32;

/// Determines if the provided argument is an instance of [I64].
bool isBcsI64(Object? arg) => arg is I64;

/// Determines if the provided argument is an instance of [I128].
bool isBcsI128(Object? arg) => arg is I128;

/// Determines if the provided argument is an instance of [I256].
bool isBcsI256(Object? arg) => arg is I256;

/// Throws an [ArgumentError] indicating a type mismatch for a specified
/// argument position.
Never throwTypeMismatch(String expectedType, int position) {
  throw ArgumentError(
    "Type mismatch for argument $position, expected '$expectedType'",
  );
}

/// Finds the index of the first non-signer argument in the function ABI
/// parameters.
///
/// A function is often defined with `signer` or `&signer` arguments at the
/// start, which are filled in by signatures and not by the caller. This
/// function helps identify the position of the first argument that can be
/// provided by the caller.
int findFirstNonSignerArg(MoveFunction functionAbi) {
  final index = functionAbi.params
      .indexWhere((param) => param != 'signer' && param != '&signer');
  if (index < 0) {
    return functionAbi.params.length;
  }
  return index;
}
