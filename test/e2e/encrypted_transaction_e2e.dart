@Tags(['e2e'])
library;

import 'package:aptos/aptos.dart';
import 'package:test/test.dart';

/// Live-network end-to-end validation of encrypted transactions.
///
/// Skipped by default (see dart_test.yaml). Run with:
///   dart test -t e2e --run-skipped test/e2e/encrypted_transaction_e2e.dart
///
/// This proves the client-side BLS12-381 / BIBE encryption is byte-correct:
/// the node decrypts the ciphertext with its master secret key and executes
/// the recovered payload. A successful on-chain result is only possible if the
/// encryption matches aptos-core exactly.
void main() {
  test('encrypted transfer is decrypted and executed on devnet', () async {
    final aptos = Aptos(AptosConfig(network: Network.devnet));

    // The node must advertise a batch-encryption key; parse the real key and
    // confirm it round-trips byte-exactly (validates production G2 decoding).
    final ledger = await aptos.getLedgerInfo();
    final hexKey = ledger.encryptionKey;
    expect(hexKey, isNotNull,
        reason: 'devnet does not advertise an encryption key');
    final key = EncryptionKey.deserialize(
      Deserializer(Hex.fromHexInput(hexKey!).toUint8List()),
    );
    expect(
      Hex.fromHexInput(key.bcsToBytes()).toString(),
      Hex.fromHexInput(hexKey).toString(),
    );

    // Fund a fresh account (devnet faucet caps per request, so fund thrice).
    final alice = Account.generate();
    final bob = Account.generate();
    for (var i = 0; i < 3; i += 1) {
      await aptos.fundAccount(
        accountAddress: alice.accountAddress,
        amount: 100000000,
      );
    }

    InputEntryFunctionData transfer() => InputEntryFunctionData(
          function: '0x1::aptos_account::transfer',
          functionArguments: [bob.accountAddress, BigInt.from(1000)],
        );

    // Baseline: a plain transfer must succeed.
    final plain = await aptos.transaction.build.simple(
      sender: alice.accountAddress,
      data: transfer(),
      options: const InputGenerateTransactionOptions(
        maxGasAmount: 200000,
        gasUnitPrice: 100,
      ),
    );
    final plainPending =
        await aptos.signAndSubmitTransaction(signer: alice, transaction: plain);
    final plainDone =
        await aptos.waitForTransaction(transactionHash: plainPending.hash);
    expect(plainDone.success, isTrue);

    // The encrypted transfer: the node must accept, decrypt, and execute it.
    // Encrypted transactions require a higher minimum gas unit price.
    final enc = await aptos.transaction.build.simple(
      sender: alice.accountAddress,
      data: transfer(),
      options: const InputGenerateTransactionOptions(
        maxGasAmount: 50000,
        gasUnitPrice: 1000,
        encrypted: true,
      ),
    );
    expect(
        enc.rawTransaction.payload, isA<TransactionPayloadEncryptedPayload>());

    final encPending =
        await aptos.signAndSubmitTransaction(signer: alice, transaction: enc);
    final encDone =
        await aptos.waitForTransaction(transactionHash: encPending.hash);
    expect(encDone.success, isTrue,
        reason: 'node failed to decrypt/execute: ${encDone.vmStatus}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
