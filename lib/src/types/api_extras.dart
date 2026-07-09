/// Supplementary input/response types needed by the api namespace layer that
/// are not present in the other type files.
library;

import 'move_types.dart';

/// The data needed to generate a View Function payload in JSON format
/// (without ABI checking or BCS encoding of the arguments).
class InputViewFunctionJsonData {
  /// The function to be called, in the format
  /// `moduleAddress::moduleName::functionName`.
  final MoveFunctionId function;

  /// Type arguments for the function, as string representations of type tags.
  final List<MoveStructId>? typeArguments;

  /// The JSON-encodable arguments to pass to the function.
  final List<MoveValue>? functionArguments;

  const InputViewFunctionJsonData({
    required this.function,
    this.typeArguments,
    this.functionArguments,
  });
}
