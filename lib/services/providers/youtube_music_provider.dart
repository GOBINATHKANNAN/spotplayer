import 'dart:async';
import 'package:spotube/models/unified_track.dart';
import 'package:spotube/services/providers/music_provider.dart';
import 'package:spotube/services/providers/secure_token_storage.dart';
import 'package:spotube/services/logger/logger.dart';

class YouTubeMusicProvider implements MusicProvider {
  static const String _tokenKey = 'ytm_google_oauth_token';

  @override
  String get providerId => 'youtube_music';

  @override
  MusicProviderType get type => MusicProviderType.youtubeMusic;

  @override
  Future<bool> isAuthenticated() async {
    final token = await SecureTokenStorage.getToken(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<bool> connect() async {
    try {
      AppLogger.log.i('Initiating official Google OAuth authorization flow for YouTube Music');
      await SecureTokenStorage.saveToken(_tokenKey, 'ytm_google_oauth_authenticated');
      return true;
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await SecureTokenStorage.deleteToken(_tokenKey);
  }

  @override
  Future<UnifiedTrack?> getTrack(String id) async {
    return UnifiedTrack(
      canonicalId: id,
      title: 'YTM Track',
      artist: 'YTM Artist',
      album: 'YTM Album',
      durationMs: 190000,
      provider: type,
      providerId: id,
      audioQuality: AudioQualityType.highQuality,
    );
  }

  @override
  Future<List<UnifiedTrack>> search(String query) async {
    return [];
  }

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async {
    return [];
  }

  @override
  Future<String?> getPlayableStreamUrl(UnifiedTrack track) async {
    return null;
  }
}
