import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:spotube/services/audio_player/custom_player.dart';
import 'package:spotube/services/logger/logger.dart';

class CrossfadeAudioPlayer {
  late final CustomPlayer _playerA;
  late final CustomPlayer _playerB;

  bool _isPlayerAActive = true;
  Timer? _crossfadeTimer;

  bool crossfadeEnabled = true;
  Duration crossfadeDuration = const Duration(seconds: 5);

  CrossfadeAudioPlayer() {
    _playerA = CustomPlayer(
      configuration: const PlayerConfiguration(
        title: "SpotPlayer_A",
        logLevel: kDebugMode ? MPVLogLevel.info : MPVLogLevel.error,
        async: true,
      ),
    );
    _playerB = CustomPlayer(
      configuration: const PlayerConfiguration(
        title: "SpotPlayer_B",
        logLevel: kDebugMode ? MPVLogLevel.info : MPVLogLevel.error,
        async: true,
      ),
    );
  }

  CustomPlayer get activePlayer => _isPlayerAActive ? _playerA : _playerB;
  CustomPlayer get nextPlayer => _isPlayerAActive ? _playerB : _playerA;

  Future<void> playMedia(Media media, {bool autoPlay = true}) async {
    await activePlayer.open(Playlist([media]), play: autoPlay);
  }

  /// Performs a smooth crossfade transition from activePlayer to nextPlayer playing nextMedia.
  Future<void> crossfadeToNext(Media nextMedia) async {
    if (!crossfadeEnabled || crossfadeDuration.inSeconds <= 0) {
      await activePlayer.open(Playlist([nextMedia]), play: true);
      return;
    }

    final outgoingPlayer = activePlayer;
    final incomingPlayer = nextPlayer;

    _crossfadeTimer?.cancel();

    try {
      // Initialize incoming player at 0 volume and start playing
      await incomingPlayer.setVolume(0);
      await incomingPlayer.open(Playlist([nextMedia]), play: true);

      final totalSteps = (crossfadeDuration.inMilliseconds / 50).round();
      int step = 0;

      _crossfadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        step++;
        final progress = (step / totalSteps).clamp(0.0, 1.0);

        final outgoingVolume = ((1.0 - progress) * 100).clamp(0.0, 100.0);
        final incomingVolume = (progress * 100).clamp(0.0, 100.0);

        await outgoingPlayer.setVolume(outgoingVolume);
        await incomingPlayer.setVolume(incomingVolume);

        if (step >= totalSteps) {
          timer.cancel();
          await outgoingPlayer.stop();
          await outgoingPlayer.setVolume(100);
          _isPlayerAActive = !_isPlayerAActive;
          AppLogger.log.i('Crossfade transition completed successfully');
        }
      });
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      // Graceful fallback on failure
      await outgoingPlayer.stop();
      await incomingPlayer.setVolume(100);
      await incomingPlayer.open(Playlist([nextMedia]), play: true);
      _isPlayerAActive = !_isPlayerAActive;
    }
  }

  Future<void> pause() async {
    await activePlayer.pause();
  }

  Future<void> resume() async {
    await activePlayer.play();
  }

  Future<void> stop() async {
    _crossfadeTimer?.cancel();
    await _playerA.stop();
    await _playerB.stop();
  }

  Future<void> dispose() async {
    _crossfadeTimer?.cancel();
    await _playerA.dispose();
    await _playerB.dispose();
  }
}
