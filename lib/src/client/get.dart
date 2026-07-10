import '../api/aptos_config.dart';
import '../types/types.dart';
import '../utils/const.dart';
import 'core.dart';
import 'types.dart';

/// Executes a GET request to retrieve data based on the provided options.
Future<AptosResponse<dynamic>> get({
  required AptosConfig aptosConfig,
  required AptosApiType type,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) {
  final url = aptosConfig.getRequestUrl(type);

  return aptosRequest(
    AptosRequest(
      url: url,
      method: 'GET',
      originMethod: originMethod,
      path: path,
      contentType: contentType?.value,
      acceptType: acceptType?.value,
      params: params,
      overrides: AptosRequestOverrides(
        apiKey: overrides?.apiKey ?? aptosConfig.clientConfig.apiKey,
        withCredentials: overrides?.withCredentials ??
            aptosConfig.clientConfig.withCredentials,
        headers: {...?aptosConfig.clientConfig.headers, ...?overrides?.headers},
        authToken: overrides?.authToken,
      ),
    ),
    aptosConfig,
    type,
  );
}

/// Retrieves data from the Aptos fullnode using the provided options.
Future<AptosResponse<dynamic>> getAptosFullNode({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) {
  return get(
    aptosConfig: aptosConfig,
    type: AptosApiType.fullnode,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    params: params,
    overrides: AptosRequestOverrides(
      apiKey: overrides?.apiKey,
      withCredentials: overrides?.withCredentials,
      headers: {
        ...?aptosConfig.fullnodeConfig.headers,
        ...?overrides?.headers,
      },
      authToken: overrides?.authToken,
    ),
  );
}

/// Makes a GET request to the Aptos pepper service to retrieve data.
Future<AptosResponse<dynamic>> getAptosPepperService({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) {
  return get(
    aptosConfig: aptosConfig,
    type: AptosApiType.pepper,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    params: params,
    overrides: overrides,
  );
}

/// This function is a helper for paginating using a function wrapping an API.
///
/// The cursor is a "state key" from the API perspective. The client should not
/// need to "care" what it represents but just use it to query the next chunk
/// of data.
Future<List<dynamic>> paginateWithCursor({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) async {
  final out = <dynamic>[];
  final requestParams = {...?params};
  String? cursor;
  do {
    final response = await getAptosFullNode(
      aptosConfig: aptosConfig,
      originMethod: originMethod,
      path: path,
      // Pass a copy: requestParams is mutated below for the next iteration.
      params: {...requestParams},
      overrides: overrides,
    );
    cursor = response.headers?['x-aptos-cursor'] as String?;
    out.addAll(response.data as List);
    requestParams['start'] = cursor;
  } while (cursor != null);
  return out;
}

/// This function is a helper for paginating using a function wrapping an API
/// using offset instead of start.
Future<List<dynamic>> paginateWithObfuscatedCursor({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) async {
  final out = <dynamic>[];
  final requestParams = {...?params};
  final totalLimit = requestParams['limit'] as int?;
  String? cursor;
  do {
    final page = await getPageWithObfuscatedCursor(
      aptosConfig: aptosConfig,
      originMethod: originMethod,
      path: path,
      // Pass a copy: requestParams is mutated below for the next iteration.
      params: {...requestParams},
      overrides: overrides,
    );

    cursor = page.cursor;
    out.addAll(page.response.data as List);
    requestParams['cursor'] = cursor;

    // Re-evaluate length.
    if (totalLimit != null) {
      final newLimit = totalLimit - out.length;
      if (newLimit <= 0) {
        break;
      }
      requestParams['limit'] = newLimit;
    }
  } while (cursor != null);
  return out;
}

/// Fetches a single page from a fullnode endpoint that uses obfuscated
/// cursors, returning the response and the cursor for the next page (if any).
Future<({AptosResponse<dynamic> response, String? cursor})>
    getPageWithObfuscatedCursor({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  Map<String, Object?>? params,
  AptosRequestOverrides? overrides,
}) async {
  final requestParams = <String, Object?>{};

  // Drop any other values.
  final cursorParam = params?['cursor'];
  if (cursorParam is String) {
    requestParams['start'] = cursorParam;
  }
  final limitParam = params?['limit'];
  if (limitParam is int) {
    requestParams['limit'] = limitParam;
  }

  final response = await getAptosFullNode(
    aptosConfig: aptosConfig,
    originMethod: originMethod,
    path: path,
    params: requestParams,
    overrides: overrides,
  );

  final cursor = response.headers?['x-aptos-cursor'] as String?;
  return (response: response, cursor: cursor);
}
