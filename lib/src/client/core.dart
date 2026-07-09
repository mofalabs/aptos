import '../api/aptos_config.dart';
import '../errors/errors.dart';
import '../types/types.dart';
import '../utils/const.dart';
import '../version.dart';
import 'types.dart';

/// Sends a request using the specified options and returns the raw client
/// response.
Future<ClientResponse<dynamic>> request(
  AptosRequest options,
  Client client,
) async {
  final headers = <String, String>{
    ...?options.overrides?.headers,
    'x-aptos-client': 'aptos-dart-sdk/$sdkVersion',
    'content-type': options.contentType ?? MimeType.json.value,
  };
  if (options.acceptType != null) {
    headers['accept'] = options.acceptType!;
  }
  if (options.originMethod != null) {
    headers['x-aptos-dart-sdk-origin-method'] = options.originMethod!;
  }

  final authToken = options.overrides?.authToken;
  final apiKey = options.overrides?.apiKey;
  if (authToken != null) {
    headers['Authorization'] = 'Bearer $authToken';
  }
  if (apiKey != null) {
    headers['Authorization'] = 'Bearer $apiKey';
  }

  return client.provider(ClientRequest(
    url: options.url,
    method: options.method,
    body: options.body,
    params: options.params,
    headers: headers,
    contentType: options.contentType,
    originMethod: options.originMethod,
    overrides: options.overrides,
  ));
}

/// The main function to use when making an API request, returning the
/// response or throwing an [AptosApiError] on failure.
Future<AptosResponse<dynamic>> aptosRequest(
  AptosRequest aptosRequestOpts,
  AptosConfig aptosConfig,
  AptosApiType apiType,
) async {
  final path = aptosRequestOpts.path;
  final fullUrl = path != null && path.isNotEmpty
      ? '${aptosRequestOpts.url}/$path'
      : aptosRequestOpts.url;

  final requestWithFullUrl = AptosRequest(
    url: fullUrl,
    method: aptosRequestOpts.method,
    body: aptosRequestOpts.body,
    contentType: aptosRequestOpts.contentType,
    acceptType: aptosRequestOpts.acceptType,
    params: aptosRequestOpts.params,
    originMethod: aptosRequestOpts.originMethod,
    overrides: aptosRequestOpts.overrides,
  );

  final clientResponse = await request(requestWithFullUrl, aptosConfig.client);

  var aptosResponse = AptosResponse<dynamic>(
    status: clientResponse.status,
    statusText: clientResponse.statusText ?? 'No status text provided',
    data: clientResponse.data,
    headers: clientResponse.headers,
    config: clientResponse.config,
    request: clientResponse.request,
    url: fullUrl,
  );

  // Handle case for `Unauthorized` error (i.e. API_KEY error).
  if (aptosResponse.status == 401) {
    throw AptosApiError(
      apiType: apiType,
      aptosRequest: requestWithFullUrl,
      aptosResponse: aptosResponse,
    );
  }

  // To support both fullnode and indexer responses, check if it is an indexer
  // query, and adjust response.data.
  if (apiType == AptosApiType.indexer) {
    final indexerResponse = aptosResponse.data;
    if (indexerResponse is Map) {
      // Handle indexer general errors.
      if (indexerResponse['errors'] != null) {
        throw AptosApiError(
          apiType: apiType,
          aptosRequest: requestWithFullUrl,
          aptosResponse: aptosResponse,
        );
      }
      if (indexerResponse.containsKey('data')) {
        aptosResponse = AptosResponse<dynamic>(
          status: aptosResponse.status,
          statusText: aptosResponse.statusText,
          data: indexerResponse['data'],
          headers: aptosResponse.headers,
          config: aptosResponse.config,
          request: aptosResponse.request,
          url: aptosResponse.url,
        );
      }
    }
  } else if (apiType == AptosApiType.pepper || apiType == AptosApiType.prover) {
    if (aptosResponse.status >= 400) {
      throw AptosApiError(
        apiType: apiType,
        aptosRequest: requestWithFullUrl,
        aptosResponse: aptosResponse,
      );
    }
  }

  if (aptosResponse.status >= 200 && aptosResponse.status < 300) {
    return aptosResponse;
  }

  // We have to explicitly check for all request types, because if the error
  // is a non-indexer error, but comes from an indexer request (e.g. 404),
  // we'll need to mention it appropriately.
  throw AptosApiError(
    apiType: apiType,
    aptosRequest: requestWithFullUrl,
    aptosResponse: aptosResponse,
  );
}
