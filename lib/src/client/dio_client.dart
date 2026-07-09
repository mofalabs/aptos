import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../types/types.dart';
import 'types.dart';

/// The default [Client] implementation, backed by `package:dio`.
class DioClient implements Client {
  final Dio _dio;

  DioClient([Dio? dio]) : _dio = dio ?? Dio();

  @override
  Future<ClientResponse<dynamic>> provider(ClientRequest requestOptions) async {
    final isBinaryBody = requestOptions.body is Uint8List;
    final acceptsBinary =
        requestOptions.headers?['accept'] == MimeType.bcs.value;

    final response = await _dio.request<dynamic>(
      requestOptions.url,
      data: requestOptions.body,
      queryParameters: _normalizeParams(requestOptions.params),
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
        contentType: isBinaryBody
            ? requestOptions.contentType
            : (requestOptions.contentType ?? MimeType.json.value),
        responseType: acceptsBinary ? ResponseType.bytes : ResponseType.json,
        // The SDK inspects status codes itself and throws AptosApiError, so
        // never let dio throw on non-2xx statuses.
        validateStatus: (_) => true,
      ),
    );

    return ClientResponse<dynamic>(
      status: response.statusCode ?? 0,
      statusText: response.statusMessage,
      data: response.data,
      headers: response.headers.map
          .map((key, values) => MapEntry(key, values.join(', '))),
      request: requestOptions,
    );
  }

  Map<String, dynamic>? _normalizeParams(Map<String, Object?>? params) {
    if (params == null) return null;
    final normalized = <String, dynamic>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      normalized[entry.key] = value.toString();
    }
    return normalized.isEmpty ? null : normalized;
  }
}
