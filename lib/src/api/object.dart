import '../core/account_address.dart';
import '../internal/object.dart' as internal_object;
import '../types/indexer.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class to query all `Object` related queries on Aptos.
///
/// Named `AptosObject` to avoid clashing with `dart:core`'s `Object`.
class AptosObject {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `AptosObject` namespace with the
  /// specified configuration.
  const AptosObject(this.config);

  /// Fetches the object data based on the specified object address.
  ///
  /// [minimumLedgerVersion] - Optional minimum ledger version to wait for.
  /// [options] - Optional configuration options for pagination and ordering.
  Future<ObjectData> getObjectDataByObjectAddress({
    required AccountAddressInput objectAddress,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.objectProcessor,
    );
    return internal_object.getObjectDataByObjectAddress(
      aptosConfig: config,
      objectAddress: objectAddress,
      options: options,
    );
  }
}
