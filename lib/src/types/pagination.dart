/// A number or a [BigInt] value.
///
/// Dart has no union types, so this is an alias of [Object]; values must be
/// [int] or [BigInt] at runtime.
typedef AnyNumber = Object;

/// Defines the parameters for paginating query results, including the
/// starting position and maximum number of items to return.
class PaginationArgs {
  const PaginationArgs({this.offset, this.limit});

  /// Specifies the starting position of the query result. Default is 0.
  final AnyNumber? offset;

  /// Specifies the maximum number of items to return. Default is 25.
  final int? limit;
}

/// Defines the parameters for paginating query results with a cursor,
/// including the starting position and maximum number of items to return.
class CursorPaginationArgs {
  const CursorPaginationArgs({this.cursor, this.limit});

  /// Specifies the starting position of the query result. Default is at the
  /// beginning if null. This is not a number and must come from the API.
  final String? cursor;

  /// Specifies the maximum number of items to return. Default is 25.
  final int? limit;
}

/// The ledger version of transactions, defaulting to the latest version if
/// not specified.
class LedgerVersionArg {
  const LedgerVersionArg({this.ledgerVersion});

  final AnyNumber? ledgerVersion;
}

/// Options for configuring the behavior of the waitForTransaction() function.
class WaitForTransactionOptions {
  const WaitForTransactionOptions({
    this.timeoutSecs,
    this.checkSuccess,
    this.waitForIndexer,
  });

  final int? timeoutSecs;
  final bool? checkSuccess;

  /// Default behavior is to wait for the indexer. Set this to false to
  /// disable waiting.
  final bool? waitForIndexer;
}
