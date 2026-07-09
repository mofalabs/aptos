import '../api/aptos_config.dart';
import '../types/types.dart';
import '../utils/const.dart';
import 'core.dart';
import 'types.dart';

/// Executes a POST request to the specified URL with the provided options.
Future<AptosResponse<dynamic>> post({
  required AptosConfig aptosConfig,
  required AptosApiType type,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  final url = aptosConfig.getRequestUrl(type);

  return aptosRequest(
    AptosRequest(
      url: url,
      method: 'POST',
      originMethod: originMethod,
      path: path,
      body: body,
      contentType: contentType?.value,
      acceptType: acceptType?.value,
      params: params,
      overrides: overrides ??
          AptosRequestOverrides(
            apiKey: aptosConfig.clientConfig.apiKey,
            withCredentials: aptosConfig.clientConfig.withCredentials,
            headers: aptosConfig.clientConfig.headers,
          ),
    ),
    aptosConfig,
    type,
  );
}

/// Sends a POST request to the Aptos fullnode using the specified options.
Future<AptosResponse<dynamic>> postAptosFullNode({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  return post(
    aptosConfig: aptosConfig,
    type: AptosApiType.fullnode,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    params: params,
    body: body,
    overrides: AptosRequestOverrides(
      apiKey: overrides?.apiKey ?? aptosConfig.clientConfig.apiKey,
      withCredentials:
          overrides?.withCredentials ?? aptosConfig.clientConfig.withCredentials,
      headers: {
        ...?aptosConfig.clientConfig.headers,
        ...?aptosConfig.fullnodeConfig.headers,
        ...?overrides?.headers,
      },
      authToken: overrides?.authToken,
    ),
  );
}

/// Sends a POST request to the Aptos indexer with the specified options.
Future<AptosResponse<dynamic>> postAptosIndexer({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  return post(
    aptosConfig: aptosConfig,
    type: AptosApiType.indexer,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    params: params,
    body: body,
    overrides: AptosRequestOverrides(
      apiKey: overrides?.apiKey ?? aptosConfig.clientConfig.apiKey,
      withCredentials:
          overrides?.withCredentials ?? aptosConfig.clientConfig.withCredentials,
      headers: {
        ...?aptosConfig.clientConfig.headers,
        ...?aptosConfig.indexerConfig.headers,
        ...?overrides?.headers,
      },
      authToken: overrides?.authToken,
    ),
  );
}

/// Sends a POST request to the Aptos faucet to obtain test tokens.
/// The API key is never included in faucet requests.
///
/// Note that only devnet has a publicly accessible faucet. For testnet, you
/// must use the minting page at https://aptos.dev/network/faucet.
Future<AptosResponse<dynamic>> postAptosFaucet({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Map<String, Object?>? params,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  return post(
    aptosConfig: aptosConfig,
    type: AptosApiType.faucet,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    params: params,
    body: body,
    overrides: AptosRequestOverrides(
      // Faucet does not support API_KEY.
      withCredentials:
          overrides?.withCredentials ?? aptosConfig.clientConfig.withCredentials,
      headers: {
        ...?aptosConfig.clientConfig.headers,
        ...?aptosConfig.faucetConfig.headers,
        ...?overrides?.headers,
      },
      authToken: overrides?.authToken ?? aptosConfig.faucetConfig.authToken,
    ),
  );
}

/// Makes a POST request to the pepper service.
Future<AptosResponse<dynamic>> postAptosPepperService({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  return post(
    aptosConfig: aptosConfig,
    type: AptosApiType.pepper,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    body: body,
    overrides: overrides,
  );
}

/// Sends a POST request to the Aptos proving service with the specified
/// options.
Future<AptosResponse<dynamic>> postAptosProvingService({
  required AptosConfig aptosConfig,
  required String originMethod,
  required String path,
  MimeType? contentType,
  MimeType? acceptType,
  Object? body,
  AptosRequestOverrides? overrides,
}) {
  return post(
    aptosConfig: aptosConfig,
    type: AptosApiType.prover,
    originMethod: originMethod,
    path: path,
    contentType: contentType,
    acceptType: acceptType,
    body: body,
    overrides: overrides,
  );
}
