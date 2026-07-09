// An end-to-end example of the Aptos Dart SDK against devnet:
// generate accounts, fund via the faucet, build/sign/submit a transfer,
// wait for it to commit, and read balances back.
//
// Run with: dart run example/main.dart
import 'package:aptos/aptos.dart';

Future<void> main() async {
  final aptos = Aptos(AptosConfig(network: Network.devnet));

  // Generate two fresh accounts (default: legacy Ed25519).
  final alice = Account.generate();
  final bob = Account.generate();
  print('Alice: ${alice.accountAddress}');
  print('Bob:   ${bob.accountAddress}');

  // Fund Alice via the devnet faucet.
  await aptos.fundAccount(
    accountAddress: alice.accountAddress,
    amount: 100000000,
  );
  print('Alice funded');

  // Build a transfer transaction (fetches the entry function ABI remotely).
  final transaction = await aptos.transaction.build.simple(
    sender: alice.accountAddress,
    data: InputEntryFunctionData(
      function: '0x1::aptos_account::transfer',
      functionArguments: [bob.accountAddress, 1000000],
    ),
    // The default maxGasAmount (2,000,000) requires a 2 APT gas deposit;
    // cap it so a 1 APT faucet grant is enough.
    options: InputGenerateTransactionOptions(maxGasAmount: 200000),
  );

  // Simulate before submitting (optional).
  final simulations = await aptos.transaction.simulate.simple(
    signerPublicKey: alice.publicKey,
    transaction: transaction,
  );
  print('Simulation success: ${simulations.first.success}, '
      'gas used: ${simulations.first.gasUsed}');

  // Sign and submit.
  final pending = await aptos.signAndSubmitTransaction(
    signer: alice,
    transaction: transaction,
  );
  print('Submitted: ${pending.hash}');

  // Wait for the transaction to be committed.
  final committed = await aptos.waitForTransaction(
    transactionHash: pending.hash,
  );
  print('Committed, success: ${(committed as UserTransactionResponse).success}');

  // Check Bob's balance.
  final bobBalance = await aptos.getBalance(
    accountAddress: bob.accountAddress,
    asset: aptosCoin,
  );
  print('Bob balance: $bobBalance octas');
}
