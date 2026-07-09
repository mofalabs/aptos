/// Internal helper for calling Move view functions on the fullnode.
library;

import '../api/aptos_config.dart';
import '../client/post.dart';
import '../transactions/transaction_builder/transaction_builder.dart';
import '../transactions/types.dart';
import '../types/api_extras.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../types/types.dart';

/// Queries a Move view function on the fullnode, BCS-encoding the view
/// function payload (the arguments are converted/type-checked against the
/// function ABI, which is fetched remotely unless provided on the payload).
Future<List<MoveValue>> view({
  required AptosConfig aptosConfig,
  required InputViewFunctionData payload,
  LedgerVersionArg? options,
}) async {
  final viewFunctionPayload =
      await generateViewFunctionPayload(payload, aptosConfig);

  final bytes = viewFunctionPayload.bcsToBytes();

  final response = await postAptosFullNode(
    aptosConfig: aptosConfig,
    path: 'view',
    originMethod: 'view',
    contentType: MimeType.bcsViewFunction,
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
    body: bytes,
  );

  return List<MoveValue>.from(response.data as List);
}

/// Queries a Move view function on the fullnode with a JSON payload. This
/// provides compatibility with the old `aptos` package: the arguments are
/// sent as JSON without ABI checking or BCS encoding.
Future<List<MoveValue>> viewJson({
  required AptosConfig aptosConfig,
  required InputViewFunctionJsonData payload,
  LedgerVersionArg? options,
}) async {
  final response = await postAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: 'viewJson',
    path: 'view',
    params: {
      if (options?.ledgerVersion != null)
        'ledger_version': options!.ledgerVersion,
    },
    body: {
      'function': payload.function,
      'type_arguments': payload.typeArguments ?? [],
      'arguments': payload.functionArguments ?? [],
    },
  );

  return List<MoveValue>.from(response.data as List);
}
