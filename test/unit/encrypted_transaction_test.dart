import 'dart:convert';
import 'dart:io';

import 'package:aptos/src/api/aptos.dart';
import 'package:aptos/src/api/aptos_config.dart';
import 'package:aptos/src/bcs/deserializer.dart';
import 'package:aptos/src/client/types.dart';
import 'package:aptos/src/transactions/instances/transaction_payload.dart';
import 'package:aptos/src/transactions/transaction_builder/encrypt_payload.dart';
import 'package:aptos/src/transactions/types.dart';
import 'package:aptos/src/utils/api_endpoints.dart';
import 'package:test/test.dart';

/// Returns scripted responses in order (repeating the last one).
class FakeClient implements Client {
  final List<ClientResponse<dynamic>> responses;
  final List<ClientRequest> requests = [];
  int _index = 0;

  FakeClient(this.responses);

  @override
  Future<ClientResponse<dynamic>> provider(ClientRequest requestOptions) async {
    requests.add(requestOptions);
    final response = responses[_index];
    if (_index < responses.length - 1) _index += 1;
    return response;
  }
}

Map<String, dynamic> ledgerInfoJson({
  String epoch = '42',
  String? encryptionKey,
}) =>
    {
      'chain_id': 4,
      'epoch': epoch,
      'ledger_version': '100',
      'oldest_ledger_version': '0',
      'ledger_timestamp': '1719000000000000',
      'node_role': 'full_node',
      'oldest_block_height': '0',
      'block_height': '50',
      if (encryptionKey != null) 'encryption_key': encryptionKey,
    };

TransactionPayloadEntryFunction transferPayload() =>
    TransactionPayloadEntryFunction(
      EntryFunction.build('0x1::aptos_account', 'transfer', const [], const []),
    );

const senderAuthKey =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  final vectors = jsonDecode(
    File('test/vectors/bls12381_bibe.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final encKeyHex = vectors['enc_bcs'] as String;

  // Each test uses a distinct network so the process-wide ledger-info and
  // encryption-key caches do not leak state between tests.
  Aptos aptosWith(FakeClient client, Network network) =>
      Aptos(AptosConfig(network: network, client: client));

  group('buildEncryptedPayload', () {
    test('encrypts the payload against the node key and round-trips', () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: ledgerInfoJson(epoch: '42', encryptionKey: encKeyHex),
        ),
      ]);
      final aptos = aptosWith(client, Network.devnet);

      final payload = await buildEncryptedPayload(
        aptosConfig: aptos.config,
        sender: '0x1',
        payload: transferPayload(),
        options: const InputGenerateTransactionOptions(
          encrypted: true,
          senderAuthenticationKey: senderAuthKey,
        ),
      );

      expect(payload, isA<TransactionPayloadEncryptedPayload>());
      expect(payload.encryptionEpoch, BigInt.from(42));
      expect(payload.payloadHash.length, 32);
      // No fee payer and no multisig, so nothing is claimed.
      expect(payload.claimedEntryFunction, isNull);

      // The serialized payload round-trips byte-exactly.
      final bytes = payload.bcsToBytes();
      final restored = TransactionPayload.deserialize(Deserializer(bytes));
      expect(restored.bcsToBytes(), bytes);
    });

    test('claims the entry function when a fee payer is present', () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: ledgerInfoJson(epoch: '7', encryptionKey: encKeyHex),
        ),
      ]);
      final aptos = aptosWith(client, Network.testnet);

      final payload = await buildEncryptedPayload(
        aptosConfig: aptos.config,
        sender: '0x1',
        payload: transferPayload(),
        options: const InputGenerateTransactionOptions(
          encrypted: true,
          senderAuthenticationKey: senderAuthKey,
          // Provide the fee payer key so no extra network fetch is needed.
          feePayerAuthenticationKey: senderAuthKey,
        ),
        feePayerAddress: '0x2',
      );

      expect(payload.claimedEntryFunction, isNotNull);
      expect(
        payload.claimedEntryFunction!.moduleId.name.identifier,
        'aptos_account',
      );
      expect(
        payload.claimedEntryFunction!.functionName?.identifier,
        'transfer',
      );
    });

    test('honors an explicit InputClaimedEntryFunction override', () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: ledgerInfoJson(epoch: '7', encryptionKey: encKeyHex),
        ),
      ]);
      final aptos = aptosWith(client, Network.mainnet);

      final payload = await buildEncryptedPayload(
        aptosConfig: aptos.config,
        sender: '0x1',
        payload: transferPayload(),
        options: const InputGenerateTransactionOptions(
          encrypted: true,
          senderAuthenticationKey: senderAuthKey,
          feePayerAuthenticationKey: senderAuthKey,
          // Claim only the module (no function name).
          claimedEntryFunction:
              InputClaimedEntryFunction(module: '0x1::aptos_account'),
        ),
        feePayerAddress: '0x2',
      );

      expect(payload.claimedEntryFunction!.functionName, isNull);
    });

    test('rejects a claim that does not match the entry function', () async {
      final client = FakeClient([
        ClientResponse(
          status: 200,
          data: ledgerInfoJson(epoch: '7', encryptionKey: encKeyHex),
        ),
      ]);
      final aptos = aptosWith(client, Network.mainnet);

      await expectLater(
        buildEncryptedPayload(
          aptosConfig: aptos.config,
          sender: '0x1',
          payload: transferPayload(),
          options: const InputGenerateTransactionOptions(
            encrypted: true,
            senderAuthenticationKey: senderAuthKey,
            feePayerAuthenticationKey: senderAuthKey,
            claimedEntryFunction:
                InputClaimedEntryFunction(module: '0x1::coin'),
          ),
          feePayerAddress: '0x2',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the node does not advertise an encryption key', () async {
      final client = FakeClient([
        ClientResponse(status: 200, data: ledgerInfoJson(epoch: '99')),
      ]);
      final aptos = aptosWith(client, Network.local);

      await expectLater(
        buildEncryptedPayload(
          aptosConfig: aptos.config,
          sender: '0x1',
          payload: transferPayload(),
          options: const InputGenerateTransactionOptions(
            encrypted: true,
            senderAuthenticationKey: senderAuthKey,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
