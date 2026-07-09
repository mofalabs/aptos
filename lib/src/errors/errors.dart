import 'dart:convert';

import '../client/types.dart';
import '../types/transaction_responses.dart';
import '../utils/const.dart';

/// Represents an error returned from the Aptos API.
/// This class encapsulates the details of the error, including the request
/// URL, response status, and additional data.
///
/// SECURITY: [message] is sanitized for [AptosApiType.pepper] and
/// [AptosApiType.prover] so that response bodies (which can contain JWT
/// claims or pepper-derived material) don't leak into default log/crash
/// sinks. The [data] field, however, ALWAYS holds the raw response body —
/// including for those sensitive API types — so callers that log or serialize
/// [data] must treat it accordingly. If you only need a human-readable
/// summary, prefer [message].
class AptosApiError implements Exception {
  final String message;

  /// The URL to which the request was made.
  final String url;

  /// The HTTP response status code (e.g., 400).
  final int status;

  /// The message associated with the response status.
  final String statusText;

  /// The raw response body returned by the API.
  ///
  /// SECURITY: For [AptosApiType.pepper] and [AptosApiType.prover], this can
  /// contain sensitive keyless-flow material. It is NOT redacted here — only
  /// [message] is.
  final Object? data;

  /// The original request that triggered the error.
  final AptosRequest request;

  AptosApiError({
    required AptosApiType apiType,
    required AptosRequest aptosRequest,
    required AptosResponse<dynamic> aptosResponse,
  })  : url = aptosResponse.url,
        status = aptosResponse.status,
        statusText = aptosResponse.statusText,
        data = aptosResponse.data,
        request = aptosRequest,
        message = _deriveErrorMessage(
          apiType: apiType,
          aptosRequest: aptosRequest,
          aptosResponse: aptosResponse,
        );

  @override
  String toString() => 'AptosApiError: $message';
}

/// API types whose response bodies may contain keyless-account material (JWT
/// claims, pepper-derived state). For these we exclude the body from the
/// error message so nothing about the response payload reaches the default
/// error message sink. Callers that need the full body can still read it from
/// [AptosApiError.data].
const Set<AptosApiType> _sensitiveBodyApiTypes = {
  AptosApiType.pepper,
  AptosApiType.prover,
};

String _deriveErrorMessage({
  required AptosApiType apiType,
  required AptosRequest aptosRequest,
  required AptosResponse<dynamic> aptosResponse,
}) {
  // Extract the W3C trace_id from the response headers if it exists. Some
  // services set this in the response, and it's useful for debugging.
  // See https://www.w3.org/TR/trace-context/#relationship-between-the-headers
  final traceparent = aptosResponse.headers?['traceparent'];
  final traceId =
      traceparent is String ? traceparent.split('-').elementAtOrNull(1) : null;
  final traceIdString = traceId != null ? '(trace_id:$traceId) ' : '';

  final errorPrelude = 'Request to [${apiType.value}]: '
      '${aptosRequest.method} ${aptosResponse.url} ${traceIdString}failed with';

  // For sensitive API types, redact the response body in every branch below.
  if (_sensitiveBodyApiTypes.contains(apiType)) {
    return '$errorPrelude status: ${aptosResponse.statusText}'
        '(code:${aptosResponse.status}) '
        '(response body redacted for ${apiType.value})';
  }

  final data = aptosResponse.data;

  // Handle graphql responses from indexer api and extract the error message
  // of the first error.
  if (apiType == AptosApiType.indexer && data is Map) {
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final firstMessage = (errors.first as Map?)?['message'];
      if (firstMessage != null) {
        return '$errorPrelude: $firstMessage';
      }
    }
  }

  // Received a well-known structured error response body - simply serialize
  // and return it. We don't need http status codes etc. in this case.
  if (data is Map && data['message'] != null && data['error_code'] != null) {
    return '$errorPrelude: ${jsonEncode(data)}';
  }

  // This is the generic/catch-all case. We received some response from the
  // API, but it doesn't appear to be a well-known structure. We print http
  // status codes and the response body (after some trimming), in the hope
  // that this gives enough context what went wrong without printing overly
  // huge messages.
  return '$errorPrelude status: ${aptosResponse.statusText}'
      '(code:${aptosResponse.status}) and response body: '
      '${_serializeAnyPayloadForErrorMessage(data)}';
}

const int _serializedPayloadTrimToMaxLength = 400;

/// Serializes a payload of any type to a string, truncating to the first and
/// last 200 characters with a "..." in the middle when too long.
String _serializeAnyPayloadForErrorMessage(Object? payload) {
  final String serializedPayload;
  try {
    serializedPayload = jsonEncode(payload);
  } catch (_) {
    return payload.toString();
  }
  if (serializedPayload.length <= _serializedPayloadTrimToMaxLength) {
    return serializedPayload;
  }
  const half = _serializedPayloadTrimToMaxLength ~/ 2;
  return 'truncated(original_size:${serializedPayload.length}): '
      '${serializedPayload.substring(0, half)}...'
      '${serializedPayload.substring(serializedPayload.length - half)}';
}

/// Represents an error that occurs when waiting for a transaction to
/// complete. This error is thrown by the `waitForTransaction` function when a
/// transaction times out or when the transaction response is undefined.
class WaitForTransactionError implements Exception {
  /// A descriptive message for the error.
  final String message;

  /// The last submitted transaction response, if available.
  final TransactionResponse? lastSubmittedTransaction;

  const WaitForTransactionError(this.message, this.lastSubmittedTransaction);

  @override
  String toString() => 'WaitForTransactionError: $message';
}

/// Represents an error that occurs when a transaction fails.
/// This error is thrown by the `waitForTransaction` function when the
/// `checkSuccess` parameter is set to true.
class FailedTransactionError implements Exception {
  /// A description of the error.
  final String message;

  /// The transaction response associated with the failure.
  final TransactionResponse transaction;

  const FailedTransactionError(this.message, this.transaction);

  @override
  String toString() => 'FailedTransactionError: $message';
}
