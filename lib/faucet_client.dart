
import 'package:aptos/aptos.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/http/http.dart';

class FaucetClient {

  late final AptosClient aptosClient;
  final String endpoint;

  FaucetClient._(this.endpoint, {AptosClient? client, String? clientEndpoint, bool enableDebugLog = false}) {
    if (client == null && clientEndpoint == null) throw ArgumentError("client or clientEndpoint cannot be null at the same time.");
    aptosClient = client ?? AptosClient(clientEndpoint!, enableDebugLog: enableDebugLog);
  }

  factory FaucetClient.fromEndpoint(String endpoint, String clientEndpoint, {bool enableDebugLog = false}) {
    return FaucetClient._(endpoint, clientEndpoint: clientEndpoint, enableDebugLog: enableDebugLog);
  }

  factory FaucetClient.fromClient(String endpoint, AptosClient client) {
    return FaucetClient._(endpoint, client: client, enableDebugLog: client.enableDebugLog);
  }

  factory FaucetClient.fromNetwork(Network network, {bool enableDebugLog = false}) {
    String endpoint;
    String clientEndpoint;
    switch (network) {
      case Network.testnet:
        endpoint = Constants.faucetTestAPI;
        clientEndpoint = Constants.testnetAPI;
        break;
      case Network.devnet:
        endpoint = Constants.faucetDevAPI;
        clientEndpoint = Constants.devnetAPI;
      default:
        throw ArgumentError("Unsupport Network $network");
    }
    return FaucetClient._(endpoint, clientEndpoint: clientEndpoint, enableDebugLog: enableDebugLog);
  }

  Future<List<String>> fundAccount(String address, String amount, {int timeoutSecs = 20}) async {
    final params = { "address": HexString.ensure(address).noPrefix(), "amount": amount };
    final response = await http.post("$endpoint/mint", queryParameters: params);

    final futures = <Future<void>>[];
    for (var txhash in response.data) {
         futures.add(aptosClient.waitForTransaction(txhash, timeoutSecs: timeoutSecs));
    }

    await Future.wait(futures);
    return response.data.cast<String>();
  }

}