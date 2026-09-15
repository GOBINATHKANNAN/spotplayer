import 'package:spotube/services/logger/logger.dart';

class CachedSourceEntry {
  final String url;
  final DateTime createdAt;
  final Duration ttl;

  CachedSourceEntry({
    required this.url,
    required this.createdAt,
    this.ttl = const Duration(minutes: 30),
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// Bounded, thread-safe in-memory cache for resolved audio stream URLs with TTL expiration.
class ResolvedSourceCache {
  static final Map<String, CachedSourceEntry> _cache = {};
  static const int _maxSize = 25;

  static void put(
    String trackId,
    String url, {
    Duration ttl = const Duration(minutes: 30),
  }) {
    if (url.isEmpty) return;

    if (_cache.length >= _maxSize) {
      _cache.removeWhere((key, value) => value.isExpired);
      if (_cache.length >= _maxSize) {
        _cache.remove(_cache.keys.first);
      }
    }
    _cache[trackId] = CachedSourceEntry(
      url: url,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    AppLogger.log.d('Cached resolved source for track $trackId');
  }

  static String? get(String trackId) {
    final entry = _cache[trackId];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(trackId);
      AppLogger.log.d('Expired resolved source cache for track $trackId');
      return null;
    }
    return entry.url;
  }

  static void invalidate(String trackId) {
    _cache.remove(trackId);
  }

  static void clear() {
    _cache.clear();
  }

  static int get size => _cache.length;
}
