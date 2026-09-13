import 'dart:async';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/audio_player/queue_controller.dart';
import 'package:spotube/services/logger/logger.dart';

class NextTrackPreloadManager {
  final PlaybackQueueController queueController;
  final Future<String?> Function(SpotubeFullTrackObject track)? sourceResolver;

  StreamSubscription? _positionSubscription;
  String? _preloadedTrackId;
  String? _activePreloadToken;
  bool _isPreloading = false;

  NextTrackPreloadManager({
    required this.queueController,
    this.sourceResolver,
  }) {
    _positionSubscription = audioPlayer.positionStream.listen(_onPositionChanged);
    queueController.addListener(_onQueueChanged);
  }

  void _onQueueChanged() {
    // Cancel active preloading if active track or queue token changes
    final currentToken = queueController.activeRequestId;
    if (_activePreloadToken != currentToken) {
      cancelPreload();
      _activePreloadToken = currentToken;
    }
  }

  void _onPositionChanged(Duration position) async {
    if (_isPreloading) return;

    final duration = audioPlayer.duration;
    if (duration == Duration.zero || duration.inSeconds < 10) return;

    final progressPercent = (position.inSeconds / duration.inSeconds) * 100;
    if (progressPercent < 75) return;

    final nextTrack = _getNextTrackInQueue();
    if (nextTrack == null || nextTrack.id == _preloadedTrackId) return;

    if (nextTrack is SpotubeLocalTrackObject) {
      _preloadedTrackId = nextTrack.id;
      return;
    }

    if (nextTrack is SpotubeFullTrackObject && sourceResolver != null) {
      _isPreloading = true;
      final preloadToken = queueController.activeRequestId;

      try {
        AppLogger.log.d('Preloading next track: ${nextTrack.name}');
        final url = await sourceResolver!(nextTrack).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );

        if (preloadToken == queueController.activeRequestId && url != null) {
          _preloadedTrackId = nextTrack.id;
          AppLogger.log.i('Successfully preloaded source for ${nextTrack.name}');
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      } finally {
        _isPreloading = false;
      }
    }
  }

  SpotubeTrackObject? _getNextTrackInQueue() {
    final effective = queueController.effectiveTracks;
    final currentActive = queueController.activeTrack;
    if (currentActive == null || effective.isEmpty) return null;

    final currentIndex = effective.indexWhere((t) => t.id == currentActive.id);
    if (currentIndex != -1 && currentIndex + 1 < effective.length) {
      return effective[currentIndex + 1];
    }
    return null;
  }

  void cancelPreload() {
    _preloadedTrackId = null;
    _isPreloading = false;
  }

  void dispose() {
    _positionSubscription?.cancel();
    queueController.removeListener(_onQueueChanged);
  }
}
