import 'types.dart';

/// A number representing a Move uint8 type.
typedef MoveUint8Type = int;

/// A 16-bit unsigned integer used in the Move programming language.
typedef MoveUint16Type = int;

/// A 32-bit unsigned integer type used in Move programming.
typedef MoveUint32Type = int;

/// A string representation of a 64-bit unsigned integer used in Move
/// programming.
typedef MoveUint64Type = String;

/// A string representing a 128-bit unsigned integer in the Move programming
/// language.
typedef MoveUint128Type = String;

/// A string representation of a 256-bit unsigned integer used in Move
/// programming.
typedef MoveUint256Type = String;

/// A number representing a Move int8 type.
typedef MoveInt8Type = int;

/// A 16-bit signed integer used in the Move programming language.
typedef MoveInt16Type = int;

/// A 32-bit signed integer type used in Move programming.
typedef MoveInt32Type = int;

/// A string representation of a 64-bit signed integer used in Move
/// programming.
typedef MoveInt64Type = String;

/// A string representing a 128-bit signed integer in the Move programming
/// language.
typedef MoveInt128Type = String;

/// A string representation of a 256-bit signed integer used in Move
/// programming.
typedef MoveInt256Type = String;

/// A string representing a Move address.
typedef MoveAddressType = String;

/// The type for identifying objects to be moved within the system.
typedef MoveObjectType = String;

/// A structure representing a Move struct identifier, formatted as
/// `address::module_name::struct_name`.
typedef MoveStructId = String;

/// The Move function identifier, formatted as
/// `address::module_name::function_name`. Same as [MoveStructId] since it
/// reads weird to take a StructId for a Function.
typedef MoveFunctionId = MoveStructId;

/// A string representation of a Move module, formatted as
/// `address::module_name`. Module names are case-sensitive.
typedef MoveModuleId = String;

/// A Move struct value in its JSON representation.
typedef MoveStructType = Object;

/// Possible Move values acceptable by Move functions (entry, view).
///
/// Map of a Move value to the corresponding Dart value:
///
/// `Bool -> bool`
///
/// `u8, u16, u32 -> int`
///
/// `u64, u128, u256 -> String`
///
/// `i8, i16, i32 -> int`
///
/// `i64, i128, i256 -> String`
///
/// `String -> String`
///
/// `Address -> String (0x...)`
///
/// `Struct -> String (0x...::module::struct)`
///
/// `Object -> String (0x...)`
///
/// `Vector -> List<MoveValue>`
///
/// `Option -> MoveValue or null`
///
/// Dart has no union types, so this is an alias of a nullable [Object].
typedef MoveValue = Object?;

/// The type for Move options, which can be a [MoveType] or null.
typedef MoveOptionType = Object?;

/// A union type that encompasses various data types used in Move, including
/// primitive types, address types, object types, and arrays of MoveType.
///
/// Dart has no union types, so this is an alias of [Object].
typedef MoveType = Object;

MoveAbility _moveAbilityFromJson(String value) => MoveAbility.values.firstWhere(
      (ability) => ability.value == value,
      orElse: () => throw ArgumentError('Unknown Move ability: $value'),
    );

MoveFunctionVisibility _moveFunctionVisibilityFromJson(String value) =>
    MoveFunctionVisibility.values.firstWhere(
      (visibility) => visibility.value == value,
      orElse: () =>
          throw ArgumentError('Unknown Move function visibility: $value'),
    );

/// A Move resource as returned by the fullnode API, containing its type and
/// JSON data.
class MoveResource {
  const MoveResource({required this.type, required this.data});

  factory MoveResource.fromJson(Map<String, dynamic> json) => MoveResource(
        type: json['type'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
      );

  final MoveStructId type;

  /// The JSON representation of the resource data.
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'type': type, 'data': data};
}

/// A Move module containing its bytecode and, optionally, its ABI.
class MoveModuleBytecode {
  const MoveModuleBytecode({required this.bytecode, this.abi});

  factory MoveModuleBytecode.fromJson(Map<String, dynamic> json) =>
      MoveModuleBytecode(
        bytecode: json['bytecode'] as String,
        abi: json['abi'] == null
            ? null
            : MoveModule.fromJson(json['abi'] as Map<String, dynamic>),
      );

  final String bytecode;
  final MoveModule? abi;

  Map<String, dynamic> toJson() => {
        'bytecode': bytecode,
        if (abi != null) 'abi': abi!.toJson(),
      };
}

/// A Move module.
class MoveModule {
  const MoveModule({
    required this.address,
    required this.name,
    required this.friends,
    required this.exposedFunctions,
    required this.structs,
  });

  factory MoveModule.fromJson(Map<String, dynamic> json) => MoveModule(
        address: json['address'] as String,
        name: json['name'] as String,
        friends: (json['friends'] as List).cast<String>(),
        exposedFunctions: (json['exposed_functions'] as List)
            .map((e) => MoveFunction.fromJson(e as Map<String, dynamic>))
            .toList(),
        structs: (json['structs'] as List)
            .map((e) => MoveStruct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String address;
  final String name;

  /// Friends of the module.
  final List<MoveModuleId> friends;

  /// Public functions of the module.
  final List<MoveFunction> exposedFunctions;

  /// Structs of the module.
  final List<MoveStruct> structs;

  Map<String, dynamic> toJson() => {
        'address': address,
        'name': name,
        'friends': friends,
        'exposed_functions': exposedFunctions.map((e) => e.toJson()).toList(),
        'structs': structs.map((e) => e.toJson()).toList(),
      };
}

/// A Move struct.
class MoveStruct {
  const MoveStruct({
    required this.name,
    required this.isNative,
    required this.isEvent,
    required this.isEnum,
    required this.abilities,
    required this.genericTypeParams,
    required this.fields,
  });

  factory MoveStruct.fromJson(Map<String, dynamic> json) => MoveStruct(
        name: json['name'] as String,
        isNative: json['is_native'] as bool,
        isEvent: json['is_event'] as bool,
        isEnum: json['is_enum'] as bool,
        abilities: (json['abilities'] as List)
            .map((e) => _moveAbilityFromJson(e as String))
            .toList(),
        genericTypeParams: (json['generic_type_params'] as List)
            .map((e) => MoveFunctionGenericTypeParam.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        fields: (json['fields'] as List)
            .map((e) => MoveStructField.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String name;

  /// Whether the struct is a native struct of Move.
  final bool isNative;

  /// Whether the struct is a module event (aka v2 event). This will be false
  /// for v1 events because the value is derived from the #[event] attribute
  /// on the struct in the Move source code. This attribute is only relevant
  /// for v2 events.
  final bool isEvent;

  /// True if the struct is an enum (e.g. enum MyEnum { A, B, C }), false if
  /// it is a regular struct (e.g. struct MyStruct { a: u8, b: u8 }).
  final bool isEnum;

  /// Abilities associated with the struct.
  final List<MoveAbility> abilities;

  /// Generic types associated with the struct.
  final List<MoveFunctionGenericTypeParam> genericTypeParams;

  /// Fields associated with the struct.
  final List<MoveStructField> fields;

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_native': isNative,
        'is_event': isEvent,
        'is_enum': isEnum,
        'abilities': abilities.map((e) => e.value).toList(),
        'generic_type_params':
            genericTypeParams.map((e) => e.toJson()).toList(),
        'fields': fields.map((e) => e.toJson()).toList(),
      };
}

/// A field in a Move struct, identified by its name.
class MoveStructField {
  const MoveStructField({required this.name, required this.type});

  factory MoveStructField.fromJson(Map<String, dynamic> json) =>
      MoveStructField(
        name: json['name'] as String,
        type: json['type'] as String,
      );

  final String name;
  final String type;

  Map<String, dynamic> toJson() => {'name': name, 'type': type};
}

/// Move abilities associated with the generic type parameter of a function.
class MoveFunctionGenericTypeParam {
  const MoveFunctionGenericTypeParam({required this.constraints});

  factory MoveFunctionGenericTypeParam.fromJson(Map<String, dynamic> json) =>
      MoveFunctionGenericTypeParam(
        constraints: (json['constraints'] as List)
            .map((e) => _moveAbilityFromJson(e as String))
            .toList(),
      );

  final List<MoveAbility> constraints;

  Map<String, dynamic> toJson() => {
        'constraints': constraints.map((e) => e.value).toList(),
      };
}

/// A Move function.
class MoveFunction {
  const MoveFunction({
    required this.name,
    required this.visibility,
    required this.isEntry,
    required this.isView,
    required this.genericTypeParams,
    required this.params,
    required this.returnTypes,
  });

  factory MoveFunction.fromJson(Map<String, dynamic> json) => MoveFunction(
        name: json['name'] as String,
        visibility:
            _moveFunctionVisibilityFromJson(json['visibility'] as String),
        isEntry: json['is_entry'] as bool,
        isView: json['is_view'] as bool,
        genericTypeParams: (json['generic_type_params'] as List)
            .map((e) => MoveFunctionGenericTypeParam.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        params: (json['params'] as List).cast<String>(),
        returnTypes: (json['return'] as List).cast<String>(),
      );

  final String name;
  final MoveFunctionVisibility visibility;

  /// Whether the function can be called as an entry function directly in a
  /// transaction.
  final bool isEntry;

  /// Whether the function is a view function or not.
  final bool isView;

  /// Generic type params associated with the Move function.
  final List<MoveFunctionGenericTypeParam> genericTypeParams;

  /// Parameters associated with the Move function.
  final List<String> params;

  /// Return type of the function. Named `returnTypes` because `return` is a
  /// reserved word in Dart; serialized as `return` on the wire.
  final List<String> returnTypes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'visibility': visibility.value,
        'is_entry': isEntry,
        'is_view': isView,
        'generic_type_params':
            genericTypeParams.map((e) => e.toJson()).toList(),
        'params': params,
        'return': returnTypes,
      };
}

/// The bytecode for a Move script and, optionally, its ABI.
class MoveScriptBytecode {
  const MoveScriptBytecode({required this.bytecode, this.abi});

  factory MoveScriptBytecode.fromJson(Map<String, dynamic> json) =>
      MoveScriptBytecode(
        bytecode: json['bytecode'] as String,
        abi: json['abi'] == null
            ? null
            : MoveFunction.fromJson(json['abi'] as Map<String, dynamic>),
      );

  final String bytecode;
  final MoveFunction? abi;

  Map<String, dynamic> toJson() => {
        'bytecode': bytecode,
        if (abi != null) 'abi': abi!.toJson(),
      };
}
