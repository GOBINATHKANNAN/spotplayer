import 'dart:async';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/queue_controller.dart';
import 'package:spotube/services/logger/logger.dart';

typedef RadioFetcher = Future<List<SpotubeTrackObject>> Function(String trackId);

class RecommendationEngine {
  final PlaybackQueueController queueController;
  final RadioFetcher? radioFetcher;

  bool _isFetching = false;
  final Set<String> _recentlyPlayedIds = {};

  RecommendationEngine({
    required this.queueController,
    this.radioFetcher,
  }) {
    queueController.addListener(_onQueueStateChanged);
  }

  void recordPlayedTrack(String trackId) {
    _recentlyPlayedIds.add(trackId);
    if (_recentlyPlayedIds.length > 50) {
      _recentlyPlayedIds.remove(_recentlyPlayedIds.first);
    }
  }

  void _onQueueStateChanged() async {
    final activeTrack = queueController.activeTrack;
    if (activeTrack != null) {
      recordPlayedTrack(activeTrack.id);
    }

    final remainingCount = _getRemainingTracksCount();
    if (remainingCount < 2 && !_isFetching && radioFetcher != null && activeTrack != null) {
      await fetchEndlessRecommendations(activeTrack.id);
    }
  }

  int _getRemainingTracksCount() {
    final effective = queueController.effectiveTracks;
    final active = queueController.activeTrack;
    if (active == null || effective.isEmpty) return 0;

    final index = effective.indexWhere((t) => t.id == active.id);
    if (index == -1) return 0;
    return effective.length - 1 - index;
  }

  Future<List<SpotubeTrackObject>> fetchRelatedSongs(String trackId) async {
    if (radioFetcher == null) return [];

    try {
      _isFetching = true;
      final rawRecommendations = await radioFetcher!(trackId);

      // Filter current track, existing queue items, and recently played tracks
      final existingIds = {
        ...queueController.effectiveTracks.map((t) => t.id),
        ..._recentlyPlayedIds,
        trackId,
      };

      final filtered = rawRecommendations
          .where((track) => !existingIds.contains(track.id))
          .toList();

      return filtered;
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return [];
    } finally {
      _isFetching = false;
    }
  }

  Future<void> fetchEndlessRecommendations(String trackId) async {
    final newTracks = await fetchRelatedSongs(trackId);
    if (newTracks.isNotEmpty) {
      queueController.addRecommendations(newTracks);
      AppLogger.log.i(
        'Endless Playback: Added ${newTracks.length} recommendation tracks to queue',
      );
    }
  }

  void dispose() {
    queueController.removeListener(_onQueueStateChanged);
  }
}
