/// A configuration object with headers for sending requests.
class ClientHeadersType {
  final Map<String, String>? headers;

  const ClientHeadersType({this.headers});
}

/// A configuration object for requests to the server, including API key and
/// extra headers.
class ClientConfig extends ClientHeadersType {
  final bool? withCredentials;
  final String? apiKey;

  const ClientConfig({this.withCredentials, this.apiKey, super.headers});
}

/// A configuration object for a fullnode, with additional headers for
/// requests.
class FullNodeConfig extends ClientHeadersType {
  const FullNodeConfig({super.headers});
}

/// An indexer configuration object for sending requests with additional
/// headers.
class IndexerConfig extends ClientHeadersType {
  const IndexerConfig({super.headers});
}

/// A configuration object for a faucet, including optional authentication and
/// headers for requests.
class FaucetConfig extends ClientHeadersType {
  final String? authToken;

  const FaucetConfig({this.authToken, super.headers});
}

/// The request type sent to a [Client] implementation.
class ClientRequest {
  final String url;

  /// GET or POST.
  final String method;

  final String? originMethod;

  /// The body of the request (a JSON-encodable object or raw bytes).
  final Object? body;

  final String? contentType;

  final Map<String, Object?>? params;

  final Map<String, String>? headers;

  final AptosRequestOverrides? overrides;

  const ClientRequest({
    required this.url,
    required this.method,
    this.originMethod,
    this.body,
    this.contentType,
    this.params,
    this.headers,
    this.overrides,
  });
}

/// The response type returned by a [Client] implementation.
class ClientResponse<Res> {
  final int status;
  final String? statusText;
  final Res data;
  final Object? config;
  final Object? request;
  final Object? response;
  final Map<String, dynamic>? headers;

  const ClientResponse({
    required this.status,
    required this.data,
    this.statusText,
    this.config,
    this.request,
    this.response,
    this.headers,
  });
}

/// Represents a client for making HTTP requests to a service provider.
///
/// Implement this interface to plug a custom HTTP stack into the SDK. The
/// default implementation is `DioClient`.
abstract class Client {
  Future<ClientResponse<dynamic>> provider(ClientRequest requestOptions);
}

/// The API request type.
class AptosRequest {
  final String url;

  /// GET or POST.
  final String method;

  /// The endpoint (path) to make the request to.
  final String? path;

  /// The body of the request (JSON-encodable object or raw bytes).
  final Object? body;

  /// The content type of the request body.
  final String? contentType;

  /// The accepted response content type.
  final String? acceptType;

  /// The request query parameters.
  final Map<String, Object?>? params;

  /// Tag identifying the SDK method that originated the request, sent in
  /// telemetry headers.
  final String? originMethod;

  /// Per-request configuration overrides.
  final AptosRequestOverrides? overrides;

  const AptosRequest({
    required this.url,
    required this.method,
    this.path,
    this.body,
    this.contentType,
    this.acceptType,
    this.params,
    this.originMethod,
    this.overrides,
  });
}

/// Per-request overrides, merging the client, fullnode, indexer, and faucet
/// configuration options.
class AptosRequestOverrides {
  final Map<String, String>? headers;
  final bool? withCredentials;
  final String? apiKey;
  final String? authToken;

  const AptosRequestOverrides({
    this.headers,
    this.withCredentials,
    this.apiKey,
    this.authToken,
  });
}

/// The API response type.
class AptosResponse<Res> {
  final int status;
  final String statusText;
  final Res data;
  final String url;
  final Map<String, dynamic>? headers;
  final Object? config;
  final Object? request;

  const AptosResponse({
    required this.status,
    required this.statusText,
    required this.data,
    required this.url,
    this.headers,
    this.config,
    this.request,
  });
}
