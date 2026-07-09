/// A wrapper that handles and manages an account sequence number.
///
/// Submit up to `maximumInFlight` transactions per account in parallel with a
/// timeout of `sleepTime`.
/// If local assumes `maximumInFlight` are in flight, determine the actual
/// committed state from the network.
/// If there are less than `maximumInFlight` due to some being committed,
/// adjust the window.
/// If `maximumInFlight` are in flight, wait `sleepTime` seconds before
/// re-evaluating.
/// If ever waiting more than `maxWaitTime` restart the sequence number to the
/// current on-chain state.
///
/// Assumptions:
/// Accounts are expected to be managed by a single AccountSequenceNumber and
/// not used otherwise. They are initialized to the current on-chain state, so
/// if there are already transactions in flight, they may take some time to
/// reset. Accounts are automatically initialized if not explicitly.
///
/// Notes:
/// This is co-routine safe, that is many async tasks can be reading from this
/// concurrently. The state of an account cannot be used across multiple
/// AccountSequenceNumber services. The synchronize method will create a
/// barrier that prevents additional nextSequenceNumber calls until it is
/// complete. This only manages the distribution of sequence numbers it does
/// not help handle transaction failures. If a transaction fails, you should
/// call synchronize and wait for timeouts.
library;

import '../../account/account.dart';
import '../../api/aptos_config.dart';
import '../../internal/account.dart';
import '../../utils/helpers.dart';

/// Represents an account's sequence number management for transaction
/// handling on the Aptos blockchain. This class provides methods to retrieve
/// the next available sequence number, synchronize with the on-chain sequence
/// number, and manage local sequence numbers while ensuring async-concurrency
/// safety.
class AccountSequenceNumber {
  final AptosConfig aptosConfig;

  final Account account;

  /// Sequence number on chain.
  BigInt? lastUncommittedNumber;

  /// Local sequence number.
  BigInt? currentNumber;

  /// We want to guarantee that we preserve ordering of workers to requests.
  ///
  /// `lock` is used to try to prevent multiple coroutines from accessing a
  /// shared resource at the same time, which can result in race conditions
  /// and data inconsistency. This code actually doesn't do it though, since
  /// we aren't giving out a slot, it is still somewhat a race condition.
  ///
  /// The ideal solution is likely that each thread grabs the next number from
  /// an incremental integer. When they complete, they increment that number
  /// and that entity is able to enter the `lock`. That would guarantee
  /// ordering.
  bool lock = false;

  /// The maximum time to wait (in seconds) for a transaction to commit before
  /// re-syncing to the current on-chain state.
  int maxWaitTime;

  /// The maximum number of transactions that can be in flight at once.
  int maximumInFlight;

  /// The time to wait (in milliseconds) before re-evaluating whether the
  /// maximum number of transactions are in flight.
  int sleepTime;

  /// Creates an instance of the class with the specified configuration and
  /// account details. This constructor initializes the necessary parameters
  /// for managing Aptos transactions.
  AccountSequenceNumber(
    this.aptosConfig,
    this.account,
    this.maxWaitTime,
    this.maximumInFlight,
    this.sleepTime,
  );

  /// Returns the next available sequence number for this account. This
  /// function ensures that the sequence number is updated and synchronized,
  /// handling potential delays in transaction commits.
  Future<BigInt?> nextSequenceNumber() async {
    while (lock) {
      await sleep(sleepTime);
    }

    lock = true;
    var nextNumber = BigInt.zero;
    try {
      if (lastUncommittedNumber == null || currentNumber == null) {
        await initialize();
      }

      if (currentNumber! - lastUncommittedNumber! >=
          BigInt.from(maximumInFlight)) {
        await update();

        final startTime = nowInSeconds();
        while (currentNumber! - lastUncommittedNumber! >=
            BigInt.from(maximumInFlight)) {
          await sleep(sleepTime);
          if (nowInSeconds() - startTime > maxWaitTime) {
            warnIfDevelopment(
              'Waited over 30 seconds for a transaction to commit, '
              're-syncing ${account.accountAddress}',
            );
            await initialize();
          } else {
            await update();
          }
        }
      }
      nextNumber = currentNumber!;
      currentNumber = currentNumber! + BigInt.one;
    } catch (e) {
      warnIfDevelopment(
        'error in getting next sequence number for this account: $e',
      );
    } finally {
      lock = false;
    }
    return nextNumber;
  }

  /// Initializes this account with the sequence number on chain.
  Future<void> initialize() async {
    final info = await getInfo(
      aptosConfig: aptosConfig,
      accountAddress: account.accountAddress,
    );
    currentNumber = BigInt.parse(info.sequenceNumber);
    lastUncommittedNumber = BigInt.parse(info.sequenceNumber);
  }

  /// Updates this account's sequence number with the one on-chain.
  ///
  /// Returns the on-chain sequence number for this account.
  Future<BigInt> update() async {
    final info = await getInfo(
      aptosConfig: aptosConfig,
      accountAddress: account.accountAddress,
    );
    lastUncommittedNumber = BigInt.parse(info.sequenceNumber);
    return lastUncommittedNumber!;
  }

  /// Synchronizes the local sequence number with the sequence number
  /// on-chain for the specified account. This function polls the network
  /// until all submitted transactions have either been committed or until
  /// the maximum wait time has elapsed.
  Future<void> synchronize() async {
    if (lastUncommittedNumber == currentNumber) return;

    while (lock) {
      await sleep(sleepTime);
    }

    lock = true;

    try {
      await update();
      final startTime = nowInSeconds();
      while (lastUncommittedNumber != currentNumber) {
        if (nowInSeconds() - startTime > maxWaitTime) {
          warnIfDevelopment(
            'Waited over 30 seconds for a transaction to commit, '
            're-syncing ${account.accountAddress}',
          );
          await initialize();
        } else {
          await sleep(sleepTime);
          await update();
        }
      }
    } catch (e) {
      warnIfDevelopment(
        'error in synchronizing this account sequence number with the one '
        'on chain: $e',
      );
    } finally {
      lock = false;
    }
  }
}
