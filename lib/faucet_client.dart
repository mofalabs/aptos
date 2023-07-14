
import 'package:aptos/aptos.dart';
import 'package:aptos/http/http.dart';

class FaucetClient {

  late final AptosClient aptosClient;
  final String endpoint;

  FaucetClient(this.endpoint, {AptosClient? client, String? clientEndpoint, bool? enableDebugLog}) {
    if (client == null && clientEndpoint == null) throw ArgumentError("client or clientEndpoint cannot be null at the same time.");
    aptosClient = client ?? AptosClient(clientEndpoint!, enableDebugLog: enableDebugLog ?? false);
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