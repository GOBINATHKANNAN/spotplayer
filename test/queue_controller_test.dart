import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/playback_status.dart';
import 'package:spotube/services/audio_player/queue_controller.dart';
import 'package:spotube/services/audio_player/preload_manager.dart';
import 'package:spotube/services/audio_player/recommendation_engine.dart';

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

  group('PlaybackQueueController & Engine Runtime Integration Tests', () {
    test('TEST 1 — Sequential Playback with Shuffle OFF (Exact A -> J)', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);

      expect(queueController.isShuffled, isFalse);
      expect(queueController.mainQueue.length, equals(10));
      expect(queueController.activeTrack?.name, equals('Song A'));

      final observedSequence = ['Song A'];
      for (int i = 0; i < 9; i++) {
        await queueController.skipToNext();
        observedSequence.add(queueController.activeTrack!.name);
      }

      expect(
        observedSequence,
        equals(['Song A', 'Song B', 'Song C', 'Song D', 'Song E', 'Song F', 'Song G', 'Song H', 'Song I', 'Song J']),
      );
    });

    test('TEST 2 — Real Source Resolution Failure & Single Advancement', () async {
      String? reportedErrorMessage;
      queueController.errorNotifier = (track, message) {
        reportedErrorMessage = message;
      };

      queueController.sourceResolver = (track, {retryCount = 0}) async {
        if (track.id == 'track_3') return null; // Song D fails
        return 'https://stream.example.com/${track.id}.mp3';
      };

      await queueController.load(testTracks, initialIndex: 2, autoPlay: false); // Song C
      expect(queueController.activeTrack?.name, equals('Song C'));

      // Skip to Song D (fails source resolution)
      await queueController.skipToNext();

      expect(reportedErrorMessage, contains('Song D'));
      expect(queueController.activeTrack?.name, equals('Song E'));
    });

    test('TEST 3 — Slow Source Resolution Waits Without Auto-Skipping', () async {
      queueController.sourceResolver = (track, {retryCount = 0}) async {
        if (track.id == 'track_2') {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        return 'https://stream.example.com/${track.id}.mp3';
      };

      await queueController.load(testTracks, initialIndex: 1, autoPlay: false); // Song B
      await queueController.skipToNext(); // Song C (slow)

      expect(queueController.activeTrack?.name, equals('Song C'));
      expect(queueController.status, equals(TrackPlaybackStatus.playing));
    });

    test('TEST 4 — Rapid Next Command De-duplication', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);

      final token1 = queueController.activeRequestId;
      queueController.skipToNext();
      queueController.skipToNext();
      await queueController.skipToNext();

      final tokenFinal = queueController.activeRequestId;
      expect(tokenFinal, isNot(equals(token1)));
      expect(queueController.activeTrack?.name, equals('Song D'));
    });

    test('TEST 5 — Rapid Navigation Race (Next -> Previous -> Next)', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false); // Song A

      queueController.skipToNext(); // -> B
      queueController.skipToPrevious(); // -> A
      await queueController.skipToNext(); // -> B

      expect(queueController.activeTrack?.name, equals('Song B'));
    });

    test('TEST 6 — Shuffle Order Stability & Reversion', () async {
      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);
      queueController.setShuffle(true);

      final firstTrack = queueController.activeTrack;
      await queueController.skipToNext();
      final secondTrack = queueController.activeTrack;

      await queueController.skipToPrevious();
      expect(queueController.activeTrack?.id, equals(firstTrack?.id));

      await queueController.skipToNext();
      expect(queueController.activeTrack?.id, equals(secondTrack?.id));

      queueController.setShuffle(false);
      expect(queueController.activeTrack?.name, equals('Song B'));
    });

    test('TEST 7 — Queue Mutation During Playback (Play Next & Reorder)', () async {
      await queueController.load(testTracks, initialIndex: 2, autoPlay: false); // Song C

      final playNextTrack = SpotubeTrackObject.full(
        id: 'play_next_1',
        name: 'Play Next Song',
        externalUri: 'https://example.com/play_next_1',
        isrc: 'PN1',
        explicit: false,
        artists: [],
        album: SpotubeSimpleAlbumObject(
          id: 'a',
          name: 'a',
          externalUri: 'a',
          albumType: SpotubeAlbumType.album,
        ),
        durationMs: 180000,
      );

      queueController.addPlayNext(playNextTrack);
      expect(queueController.effectiveTracks.first.name, equals('Play Next Song'));

      await queueController.skipToNext();
      expect(queueController.activeTrack?.name, equals('Play Next Song'));
    });

    test('TEST 8 — Preloader Logical Next Lookup & Cancellation', () async {
      final preloader = NextTrackPreloadManager(
        queueController: queueController,
        sourceResolver: (track) async => 'https://stream.example.com/${track.id}.mp3',
      );

      await queueController.load(testTracks, initialIndex: 0, autoPlay: false);
      expect(queueController.activeTrack?.name, equals('Song A'));

      preloader.cancelPreload();
      preloader.dispose();
    });

    test('TEST 9 — Endless Playback & Recommendation Priority', () async {
      final recEngine = RecommendationEngine(
        queueController: queueController,
        radioFetcher: (id) async => [
          SpotubeTrackObject.full(
            id: 'rec_1',
            name: 'Recommended Song 1',
            externalUri: 'https://example.com/rec_1',
            isrc: 'R1',
            explicit: false,
            artists: [],
            album: SpotubeSimpleAlbumObject(
              id: 'a',
              name: 'a',
              externalUri: 'a',
              albumType: SpotubeAlbumType.album,
            ),
            durationMs: 180000,
          )
        ],
      );

      await queueController.load([testTracks[0], testTracks[1]], initialIndex: 0, autoPlay: false);
      await recEngine.fetchEndlessRecommendations(testTracks[0].id);

      expect(queueController.recommendationsQueue.first.name, equals('Recommended Song 1'));
      recEngine.dispose();
    });
  });
}
