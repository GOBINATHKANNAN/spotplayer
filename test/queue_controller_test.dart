import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/playback_status.dart';
import 'package:spotube/services/audio_player/queue_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  late PlaybackQueueController queueController;

  final testTracks = List.generate(
    10,
    (index) => SpotubeTrackObject.full(
      id: 'track_$index',
      name: 'Song ${String.fromCharCode(65 + index)}',
      externalUri: 'https://example.com/track_$index',
      isrc: 'ISRC$index',
      explicit: false,
      artists: [
        SpotubeSimpleArtistObject(
          id: 'artist_1',
          name: 'Test Artist',
          externalUri: 'https://example.com/artist_1',
        )
      ],
      album: SpotubeSimpleAlbumObject(
        id: 'album_1',
        name: 'Test Album',
        externalUri: 'https://example.com/album_1',
        albumType: SpotubeAlbumType.album,
      ),
      durationMs: 180000,
    ),
  );

  setUp(() {
    queueController = PlaybackQueueController();
    queueController.sourceResolver = (track, {retryCount = 0}) async {
      return 'https://stream.example.com/${track.id}.mp3';
    };
  });

  tearDown(() {
    queueController.dispose();
  });

  group('PlaybackQueueController - Phase 2 Core Engine Tests', () {
    test('1. Sequential Playback with Shuffle OFF (Exact Order A -> J)', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);

      expect(queueController.isShuffled, isFalse);
      expect(queueController.mainQueue.length, equals(10));
      expect(queueController.activeTrack?.name, equals('Song A'));

      for (int i = 0; i < 9; i++) {
        final expectedNextName = 'Song ${String.fromCharCode(65 + i + 1)}';
        await queueController.skipToNext();
        expect(queueController.activeTrack?.name, equals(expectedNextName));
      }
    });

    test('2. Deterministic Shuffle Mode maintains stable order', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);
      queueController.setShuffle(true);

      expect(queueController.isShuffled, isTrue);

      final firstTrack = queueController.activeTrack;
      expect(firstTrack, isNotNull);

      // Skip forward and back, verifying order consistency
      await queueController.skipToNext();
      final secondTrack = queueController.activeTrack;

      await queueController.skipToPrevious();
      expect(queueController.activeTrack?.id, equals(firstTrack?.id));

      await queueController.skipToNext();
      expect(queueController.activeTrack?.id, equals(secondTrack?.id));

      // Disable shuffle -> should restore original order
      queueController.setShuffle(false);
      expect(queueController.isShuffled, isFalse);
      expect(queueController.activeTrack?.name, equals('Song A'));
    });

    test('3. Failed Track Handling & Non-blocking Error', () async {
      String? reportedErrorMessage;
      queueController.errorNotifier = (track, message) {
        reportedErrorMessage = message;
      };

      // Set source resolver to fail for track_1 ('Song B')
      queueController.sourceResolver = (track, {retryCount = 0}) async {
        if (track.id == 'track_1') return null; // Failure
        return 'https://stream.example.com/${track.id}.mp3';
      };

      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);
      expect(queueController.activeTrack?.name, equals('Song A'));

      // Skip to Song B (which will fail source resolution)
      await queueController.skipToNext();

      // Controller should mark track unavailable, notify error, and advance to Song C
      expect(reportedErrorMessage, contains("Song B"));
      expect(queueController.activeTrack?.name, equals('Song C'));
    });

    test('4. Repeat Modes (ONE, ALL, OFF)', () async {
      await queueController.load(testTracks, initialIndex: 9, autoPlay: false);
      expect(queueController.activeTrack?.name, equals('Song J'));

      // Repeat OFF -> Next at end of queue stays idle
      queueController.setLoopMode(PlaylistMode.none);
      await queueController.skipToNext();
      expect(queueController.status, equals(TrackPlaybackStatus.idle));

      // Repeat ALL -> Next at end wraps around to Song A
      queueController.setLoopMode(PlaylistMode.loop);
      await queueController.load(testTracks, initialIndex: 9, autoPlay: false);
      await queueController.skipToNext();
      expect(queueController.activeTrack?.name, equals('Song A'));

      // Repeat ONE -> completion re-plays current track
      queueController.setLoopMode(PlaylistMode.single);
      final activeToken = queueController.activeRequestId;
      await queueController.handleTrackCompletion(activeToken);
      expect(queueController.activeTrack?.name, equals('Song A'));
    });

    test('5. Transaction Token De-duplication ignores stale events', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);
      final staleToken = queueController.activeRequestId;

      // User skips to next track (generates new token)
      await queueController.skipToNext();
      final newToken = queueController.activeRequestId;
      expect(newToken, isNot(equals(staleToken)));

      // Simulate stale completion event with old token
      await queueController.handleTrackCompletion(staleToken);

      // Active track should remain Song B, not advanced again
      expect(queueController.activeTrack?.name, equals('Song B'));
    });
  });
}
