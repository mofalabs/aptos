/// An async-aware FIFO queue for coordinating asynchronous tasks.
library;

import 'dart:async';

/// The AsyncQueue class is an async-aware data structure that provides a
/// queue-like behavior for managing asynchronous tasks or operations. It
/// allows to enqueue items and dequeue them asynchronously. This is not
/// thread-safe, but it is async concurrency safe, and it does not guarantee
/// ordering for those that call into and await on enqueue.
class AsyncQueue<T> {
  final List<T> queue = [];

  // The pendingDequeue is used to handle the resolution of futures when items
  // are enqueued and dequeued.
  final List<Completer<T>> _pendingDequeue = [];

  bool _cancelled = false;

  /// Adds an item to the queue. If there are pending dequeued futures, it
  /// resolves the oldest future with the enqueued item immediately;
  /// otherwise, it adds the item to the queue.
  void enqueue(T item) {
    _cancelled = false;

    if (_pendingDequeue.isNotEmpty) {
      final completer = _pendingDequeue.removeAt(0);
      completer.complete(item);
      return;
    }

    queue.add(item);
  }

  /// Dequeues the next item from the queue and returns a future that
  /// resolves to it. If the queue is empty, it creates a new future that
  /// will be resolved when an item is enqueued.
  Future<T> dequeue() {
    if (queue.isNotEmpty) {
      return Future.value(queue.removeAt(0));
    }

    final completer = Completer<T>();
    _pendingDequeue.add(completer);
    return completer.future;
  }

  /// Determine whether the queue is empty.
  ///
  /// Returns true if the queue has no elements, otherwise false.
  bool isEmpty() => queue.isEmpty;

  /// Cancels all pending futures in the queue and rejects them with an
  /// [AsyncQueueCancelledError]. This ensures that any awaiting code can
  /// handle the cancellation appropriately.
  void cancel() {
    _cancelled = true;

    for (final completer in _pendingDequeue) {
      completer.completeError(const AsyncQueueCancelledError('Task cancelled'));
    }

    _pendingDequeue.clear();
    queue.clear();
  }

  /// Determine whether the queue has been cancelled.
  ///
  /// Returns true if the queue is cancelled, otherwise false.
  bool isCancelled() => _cancelled;

  /// Retrieve the length of the pending dequeue.
  ///
  /// Returns the number of futures currently awaiting an item.
  int pendingDequeueLength() => _pendingDequeue.length;
}

/// Represents an error that occurs when an asynchronous queue operation is
/// cancelled. This error provides additional context for cancellation events.
class AsyncQueueCancelledError implements Exception {
  final String message;

  const AsyncQueueCancelledError(this.message);

  @override
  String toString() => 'AsyncQueueCancelledError: $message';
}
