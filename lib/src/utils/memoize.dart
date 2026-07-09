import 'dart:async';

/// Maximum number of entries to keep in the cache to prevent unbounded memory
/// growth. When this limit is exceeded, the oldest entries are evicted.
const int _maxCacheSize = 1000;

/// Minimum required key length to help ensure uniqueness.
/// Keys should include a namespace prefix (e.g., "module-abi-",
/// "ledger-info-").
const int _minKeyLength = 10;

class _CacheEntry {
  final Object? value;
  final DateTime timestamp;
  DateTime lastAccess;
  final Duration? ttl;

  _CacheEntry({
    required this.value,
    required this.timestamp,
    required this.lastAccess,
    this.ttl,
  });

  bool get isExpired =>
      ttl != null && DateTime.now().difference(timestamp) > ttl!;
}

/// The global cache shared across all functions with LRU eviction support.
///
/// SECURITY: All cache keys should include a unique namespace prefix to
/// prevent collisions between different caching use cases (e.g.,
/// "module-abi-", "ledger-info-").
final Map<String, _CacheEntry> _cache = {};

void _validateCacheKey(String key) {
  if (key.length < _minKeyLength) {
    throw ArgumentError(
      'Cache key "$key" is too short. Keys should be at least $_minKeyLength '
      'characters and include a namespace prefix.',
    );
  }
}

void _evictIfNeeded() {
  if (_cache.length >= _maxCacheSize) {
    // Find and remove the least recently accessed entries (~10% of cache).
    final entriesToRemove = (_maxCacheSize * 0.1).ceil();
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));
    for (var i = 0; i < entriesToRemove && i < entries.length; i += 1) {
      _cache.remove(entries[i].key);
    }
  }
}

/// A memoize higher-order function to cache the response of an async
/// function. This helps to improve performance by avoiding repeated calls to
/// the same async function with the same key within a specified time-to-live.
Future<T> Function() memoizeAsync<T>(
  Future<T> Function() func,
  String key, {
  Duration? ttl,
}) {
  _validateCacheKey(key);

  return () async {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      entry.lastAccess = DateTime.now();
      return entry.value as T;
    }
    if (entry != null) _cache.remove(key);

    final result = await func();
    _evictIfNeeded();
    final now = DateTime.now();
    _cache[key] =
        _CacheEntry(value: result, timestamp: now, lastAccess: now, ttl: ttl);
    return result;
  };
}

/// Caches the result of a function call to improve performance on subsequent
/// calls with the same key.
T Function() memoize<T>(T Function() func, String key, {Duration? ttl}) {
  _validateCacheKey(key);

  return () {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      entry.lastAccess = DateTime.now();
      return entry.value as T;
    }
    if (entry != null) _cache.remove(key);

    final result = func();
    _evictIfNeeded();
    final now = DateTime.now();
    _cache[key] =
        _CacheEntry(value: result, timestamp: now, lastAccess: now, ttl: ttl);
    return result;
  };
}

/// Clears all entries from the memoization cache.
/// Useful for testing or when you need to force fresh data.
void clearMemoizeCache() {
  _cache.clear();
}

/// Returns the current size of the memoization cache.
/// Useful for monitoring and debugging.
int getMemoizeCacheSize() => _cache.length;
