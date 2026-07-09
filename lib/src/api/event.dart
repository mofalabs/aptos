import '../core/account_address.dart';
import '../internal/event.dart' as internal_event;
import '../types/indexer.dart';
import '../types/move_types.dart';
import '../types/pagination.dart';
import '../utils/const.dart';
import 'aptos_config.dart';
import 'utils.dart';

/// A class to query all `Event` related queries on Aptos (via the indexer).
///
/// NOTE: named `EventApi` to avoid clashing with the fullnode transaction
/// `Event` type from `types/transaction_responses.dart` under a
/// single-namespace import.
class EventApi {
  /// The configuration settings for the Aptos client.
  final AptosConfig config;

  /// Initializes a new instance of the `Event` namespace with the specified
  /// configuration.
  const EventApi(this.config);

  /// Retrieve module events based on a specified event type.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and ordering parameters.
  Future<List<IndexerEvent>> getModuleEventsByEventType({
    required MoveStructId eventType,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.eventsProcessor,
    );
    return internal_event.getModuleEventsByEventType(
      aptosConfig: config,
      eventType: eventType,
      options: options,
    );
  }

  /// Retrieve events associated with a specific account and creation number.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and ordering parameters.
  Future<List<IndexerEvent>> getAccountEventsByCreationNumber({
    required AccountAddressInput accountAddress,
    required AnyNumber creationNumber,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.eventsProcessor,
    );
    return internal_event.getAccountEventsByCreationNumber(
      aptosConfig: config,
      accountAddress: accountAddress,
      creationNumber: creationNumber,
      options: options,
    );
  }

  /// Retrieve events associated with a specific account and event type.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination and ordering parameters.
  Future<List<IndexerEvent>> getAccountEventsByEventType({
    required AccountAddressInput accountAddress,
    required MoveStructId eventType,
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.eventsProcessor,
    );
    return internal_event.getAccountEventsByEventType(
      aptosConfig: config,
      accountAddress: accountAddress,
      eventType: eventType,
      options: options,
    );
  }

  /// Retrieve all events with optional filtering, pagination and ordering.
  ///
  /// [minimumLedgerVersion] - Optional ledger version to sync up to before
  /// querying.
  /// [options] - Optional pagination, ordering and where-condition
  /// parameters.
  Future<List<IndexerEvent>> getEvents({
    AnyNumber? minimumLedgerVersion,
    IndexerQueryArgs? options,
  }) async {
    await waitForIndexerOnVersion(
      config: config,
      minimumLedgerVersion: minimumLedgerVersion,
      processorType: ProcessorType.eventsProcessor,
    );
    return internal_event.getEvents(aptosConfig: config, options: options);
  }
}
