import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/audio_player/playback_status.dart';
import 'package:spotube/services/audio_player/source_cache.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Function signature for source resolution callback.
/// Resolves a full track object into a playable stream URL or validates it.
typedef SourceResolutionHandler = Future<String?> Function(
  SpotubeFullTrackObject track, {
  int retryCount,
});

/// Function signature for non-blocking error notification.
typedef PlaybackErrorNotifier = void Function(
  SpotubeTrackObject track,
  String message,
);

class PlaybackQueueController extends ChangeNotifier {
  static final _uuid = const Uuid();

  // Internal Queues
  final List<SpotubeTrackObject> _mainQueue = [];
  final List<SpotubeTrackObject> _playNextQueue = [];
  final List<SpotubeTrackObject> _recommendationsQueue = [];

  // Deterministic Shuffle Order (stores indices into _mainQueue)
  List<int> _shuffleOrder = [];
  int _shuffleIndex = 0;

  int _currentIndex = 0;
  bool _isShuffled = false;
  PlaylistMode _loopMode = PlaylistMode.none;
  TrackPlaybackStatus _status = TrackPlaybackStatus.idle;

  // Active Transaction Token for De-duplication & Race Condition Prevention
  String _activeRequestId = '';

  // Callbacks
  SourceResolutionHandler? sourceResolver;
  PlaybackErrorNotifier? errorNotifier;

  StreamSubscription? _completionSubscription;

  PlaybackQueueController() {
    _completionSubscription = audioPlayer.completedStream.listen((_) {
      handleTrackCompletion(_activeRequestId);
    });
  }

  // Getters
  List<SpotubeTrackObject> get mainQueue => List.unmodifiable(_mainQueue);
  List<SpotubeTrackObject> get playNextQueue => List.unmodifiable(_playNextQueue);
  List<SpotubeTrackObject> get recommendationsQueue =>
      List.unmodifiable(_recommendationsQueue);

  int get currentIndex => _currentIndex;
  bool get isShuffled => _isShuffled;
  PlaylistMode get loopMode => _loopMode;
  TrackPlaybackStatus get status => _status;
  String get activeRequestId => _activeRequestId;

  /// Returns the current active track if available.
  SpotubeTrackObject? get activeTrack {
    if (_playNextQueue.isNotEmpty) {
      return _playNextQueue.first;
    }
    if (_isShuffled) {
      if (_shuffleIndex >= 0 && _shuffleIndex < _shuffleOrder.length) {
        final mainIdx = _shuffleOrder[_shuffleIndex];
        if (mainIdx >= 0 && mainIdx < _mainQueue.length) {
          return _mainQueue[mainIdx];
        }
      }
      return null;
    } else {
      if (_currentIndex >= 0 && _currentIndex < _mainQueue.length) {
        return _mainQueue[_currentIndex];
      }
      if (_recommendationsQueue.isNotEmpty) {
        return _recommendationsQueue.first;
      }
      return null;
    }
  }

  /// Full effective track list for display.
  List<SpotubeTrackObject> get effectiveTracks {
    if (_isShuffled) {
      final shuffledMain =
          _shuffleOrder.map((idx) => _mainQueue[idx]).toList();
      return [..._playNextQueue, ...shuffledMain, ..._recommendationsQueue];
    }
    return [..._playNextQueue, ..._mainQueue, ..._recommendationsQueue];
  }

  String _generateRequestId() {
    _activeRequestId = _uuid.v4();
    return _activeRequestId;
  }

  void _setStatus(TrackPlaybackStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Regenerates a deterministic shuffle order for the current _mainQueue.
  void _generateShuffleOrder({int startingIndex = 0}) {
    if (_mainQueue.isEmpty) {
      _shuffleOrder = [];
      _shuffleIndex = 0;
      return;
    }

    final indices = List<int>.generate(_mainQueue.length, (i) => i);
    final random = Random();

    // Remove starting index, shuffle the rest, and place starting index at 0
    indices.remove(startingIndex);
    for (int i = indices.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = indices[i];
      indices[i] = indices[j];
      indices[j] = temp;
    }

    _shuffleOrder = [startingIndex, ...indices];
    _shuffleIndex = 0;
  }

  /// Load a new playlist and start playback.
  Future<void> load(
    List<SpotubeTrackObject> tracks, {
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    final requestId = _generateRequestId();

    _mainQueue.clear();
    _mainQueue.addAll(tracks);
    _playNextQueue.clear();
    _recommendationsQueue.clear();
    _currentIndex = initialIndex.clamp(0, max(0, tracks.length - 1));

    if (_isShuffled) {
      _generateShuffleOrder(startingIndex: _currentIndex);
    }

    notifyListeners();

    if (autoPlay && activeTrack != null) {
      await _playActiveTrack(requestId);
    }
  }

  /// Resolves and plays the current active track.
  Future<void> _playActiveTrack(String requestId) async {
    if (requestId != _activeRequestId) return;

    final targetTrack = activeTrack;
    if (targetTrack == null) {
      _setStatus(TrackPlaybackStatus.idle);
      return;
    }

    _setStatus(TrackPlaybackStatus.resolving);

    try {
      if (targetTrack is SpotubeLocalTrackObject) {
        if (requestId != _activeRequestId) return;
        _setStatus(TrackPlaybackStatus.ready);
        await audioPlayer.openPlaylist(
          [SpotubeMedia(targetTrack)],
          autoPlay: true,
          initialIndex: 0,
        );
        _setStatus(TrackPlaybackStatus.playing);
      } else if (targetTrack is SpotubeFullTrackObject) {
        String? resolvedUrl = ResolvedSourceCache.get(targetTrack.id);
        int retries = 0;

        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          while (retries <= 2 && requestId == _activeRequestId) {
            try {
              if (sourceResolver != null) {
                resolvedUrl = await sourceResolver!(
                  targetTrack,
                  retryCount: retries,
                ).timeout(const Duration(seconds: 10));
              } else {
                // Default fallback: SpotubeMedia endpoint
                resolvedUrl = SpotubeMedia(targetTrack).uri;
              }
              if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                ResolvedSourceCache.put(targetTrack.id, resolvedUrl);
                break;
              }
            } catch (e) {
              AppLogger.log.w(
                'Source resolution attempt $retries failed for ${targetTrack.name}: $e',
              );
            }
            retries++;
            if (retries <= 2) {
              await Future.delayed(Duration(milliseconds: 300 * retries));
            }
          }
        }

        if (requestId != _activeRequestId) return;

        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          // Source Resolution Failed completely
          _setStatus(TrackPlaybackStatus.unavailable);
          errorNotifier?.call(
            targetTrack,
            "Track '${targetTrack.name}' is currently unavailable.",
          );
          AppLogger.log.e('Failed to resolve track ${targetTrack.name}');

          // Advance deterministically to next valid item
          await skipToNext(isManual: false);
          return;
        }

        _setStatus(TrackPlaybackStatus.ready);
        await audioPlayer.openPlaylist(
          [SpotubeMedia(targetTrack)],
          autoPlay: true,
          initialIndex: 0,
        );
        _setStatus(TrackPlaybackStatus.playing);
      }
    } catch (e, stack) {
      if (requestId != _activeRequestId) return;
      AppLogger.reportError(e, stack);
      _setStatus(TrackPlaybackStatus.failed);
      errorNotifier?.call(
        targetTrack,
        "Failed to play '${targetTrack.name}': $e",
      );
      await skipToNext(isManual: false);
    }
  }

  /// Handles completion event from MediaKit in a thread-safe manner.
  Future<void> handleTrackCompletion(String requestId) async {
    // Verify transaction token to prevent duplicate or stale completion events
    if (requestId != _activeRequestId) return;
    if (_status == TrackPlaybackStatus.completed) return;

    _setStatus(TrackPlaybackStatus.completed);

    if (_loopMode == PlaylistMode.single) {
      // Repeat ONE
      final newRequestId = _generateRequestId();
      await _playActiveTrack(newRequestId);
      return;
    }

    // Pop playNextQueue item if present
    if (_playNextQueue.isNotEmpty) {
      _playNextQueue.removeAt(0);
      notifyListeners();
    } else if (_isShuffled) {
      if (_shuffleIndex < _shuffleOrder.length - 1) {
        _shuffleIndex++;
      } else if (_loopMode == PlaylistMode.loop) {
        _shuffleIndex = 0;
      } else {
        _setStatus(TrackPlaybackStatus.idle);
        return;
      }
    } else {
      if (_currentIndex < _mainQueue.length - 1) {
        _currentIndex++;
      } else if (_recommendationsQueue.isNotEmpty) {
        _recommendationsQueue.removeAt(0);
      } else if (_loopMode == PlaylistMode.loop) {
        _currentIndex = 0;
      } else {
        _setStatus(TrackPlaybackStatus.idle);
        return;
      }
    }

    final newRequestId = _generateRequestId();
    notifyListeners();
    await _playActiveTrack(newRequestId);
  }

  Future<void> play() async {
    if (_status == TrackPlaybackStatus.paused) {
      await audioPlayer.resume();
      _setStatus(TrackPlaybackStatus.playing);
    } else if (_status == TrackPlaybackStatus.idle ||
        _status == TrackPlaybackStatus.failed) {
      final requestId = _generateRequestId();
      await _playActiveTrack(requestId);
    }
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    _setStatus(TrackPlaybackStatus.paused);
  }

  Future<void> stop() async {
    _generateRequestId();
    await audioPlayer.stop();
    _setStatus(TrackPlaybackStatus.idle);
  }

  Future<void> skipToNext({bool isManual = true}) async {
    final requestId = _generateRequestId();

    if (_playNextQueue.isNotEmpty) {
      _playNextQueue.removeAt(0);
    } else if (_isShuffled) {
      if (_shuffleIndex < _shuffleOrder.length - 1) {
        _shuffleIndex++;
      } else if (_loopMode == PlaylistMode.loop) {
        _shuffleIndex = 0;
      } else {
        _setStatus(TrackPlaybackStatus.idle);
        return;
      }
    } else {
      if (_currentIndex < _mainQueue.length - 1) {
        _currentIndex++;
      } else if (_recommendationsQueue.isNotEmpty) {
        _recommendationsQueue.removeAt(0);
      } else if (_loopMode == PlaylistMode.loop) {
        _currentIndex = 0;
      } else {
        _setStatus(TrackPlaybackStatus.idle);
        return;
      }
    }

    notifyListeners();
    await _playActiveTrack(requestId);
  }

  Future<void> skipToPrevious({bool isManual = true}) async {
    final requestId = _generateRequestId();

    if (_isShuffled) {
      if (_shuffleIndex > 0) {
        _shuffleIndex--;
      } else if (_loopMode == PlaylistMode.loop) {
        _shuffleIndex = _shuffleOrder.length - 1;
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else if (_loopMode == PlaylistMode.loop) {
        _currentIndex = _mainQueue.length - 1;
      }
    }

    notifyListeners();
    await _playActiveTrack(requestId);
  }

  Future<void> jumpToTrack(SpotubeTrackObject track) async {
    final index = _mainQueue.indexWhere((t) => t.id == track.id);
    if (index == -1) return;

    final requestId = _generateRequestId();
    _currentIndex = index;

    if (_isShuffled) {
      final sIdx = _shuffleOrder.indexOf(index);
      if (sIdx != -1) {
        _shuffleIndex = sIdx;
      }
    }

    notifyListeners();
    await _playActiveTrack(requestId);
  }

  void addPlayNext(SpotubeTrackObject track) {
    _playNextQueue.add(track);
    notifyListeners();
  }

  void addPlayNextTracks(Iterable<SpotubeTrackObject> tracks) {
    _playNextQueue.addAll(tracks);
    notifyListeners();
  }

  void addTrack(SpotubeTrackObject track) {
    _mainQueue.add(track);
    if (_isShuffled) {
      _shuffleOrder.add(_mainQueue.length - 1);
    }
    notifyListeners();
  }

  void addTracks(Iterable<SpotubeTrackObject> tracks) {
    for (final track in tracks) {
      addTrack(track);
    }
  }

  void addRecommendations(Iterable<SpotubeTrackObject> tracks) {
    final existingIds = {
      ..._mainQueue.map((t) => t.id),
      ..._playNextQueue.map((t) => t.id),
      ..._recommendationsQueue.map((t) => t.id),
    };
    final newTracks = tracks.where((t) => !existingIds.contains(t.id));
    _recommendationsQueue.addAll(newTracks);
    notifyListeners();
  }

  void removeTrackAt(int index) {
    if (index < 0 || index >= _mainQueue.length) return;
    _mainQueue.removeAt(index);
    if (_isShuffled) {
      _generateShuffleOrder(startingIndex: min(_currentIndex, max(0, _mainQueue.length - 1)));
    } else if (_currentIndex >= _mainQueue.length) {
      _currentIndex = max(0, _mainQueue.length - 1);
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _mainQueue.length ||
        newIndex < 0 ||
        newIndex >= _mainQueue.length) {
      return;
    }
    final item = _mainQueue.removeAt(oldIndex);
    _mainQueue.insert(newIndex, item);

    if (_isShuffled) {
      _generateShuffleOrder(startingIndex: _currentIndex);
    } else if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    }
    notifyListeners();
  }

  void setShuffle(bool shuffle) {
    if (_isShuffled == shuffle) return;
    _isShuffled = shuffle;
    if (_isShuffled) {
      _generateShuffleOrder(startingIndex: _currentIndex);
    }
    notifyListeners();
  }

  void setLoopMode(PlaylistMode mode) {
    if (_loopMode == mode) return;
    _loopMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    super.dispose();
  }
}
