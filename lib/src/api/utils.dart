/// Shared helpers used across the API namespaces, including the
/// `waitForIndexer` indexer-sync helper.
library;

import '../internal/general.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';

/// Waits for the indexer to sync up to the specified ledger version. The
/// timeout is 3 seconds.
///
/// [minimumLedgerVersion] - The minimum ledger version that the indexer
/// should sync to.
/// [processorType] - Optional. The type of processor to check the last
/// success version from; when omitted, the first processor status is used.
Future<void> waitForIndexer({
  required AptosConfig aptosConfig,
  required AnyNumber minimumLedgerVersion,
  ProcessorType? processorType,
}) async {
  final minimumVersion = minimumLedgerVersion is BigInt
      ? minimumLedgerVersion
      : BigInt.from(minimumLedgerVersion as int);
  const timeout = Duration(seconds: 3);
  final startTime = DateTime.now();
  var indexerVersion = -BigInt.one;

  while (indexerVersion < minimumVersion) {
    // Check for timeout.
    if (DateTime.now().difference(startTime) > timeout) {
      throw StateError('waitForLastSuccessIndexerVersionSync timeout');
    }

    if (processorType == null) {
      // Get the last success version from all processors.
      indexerVersion =
          await getIndexerLastSuccessVersion(aptosConfig: aptosConfig);
    } else {
      // Get the last success version from the specific processor.
      final processor = await getProcessorStatus(
        aptosConfig: aptosConfig,
        processorType: processorType,
      );
      indexerVersion = BigInt.parse(processor.lastSuccessVersion.toString());
    }

    if (indexerVersion >= minimumVersion) {
      // Break out immediately if we are synced.
      break;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// Waits for the indexer to reach a specified ledger version, allowing for
/// synchronization with the blockchain. If [minimumLedgerVersion] is null,
/// this function does not wait.
///
/// This function is useful for ensuring that your application is working
/// with the most up-to-date data before proceeding.
Future<void> waitForIndexerOnVersion({
  required AptosConfig config,
  AnyNumber? minimumLedgerVersion,
  required ProcessorType processorType,
}) async {
  if (minimumLedgerVersion != null) {
    await waitForIndexer(
      aptosConfig: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: processorType,
    );
  }
}
