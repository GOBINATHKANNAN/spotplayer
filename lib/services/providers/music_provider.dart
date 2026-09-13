import 'package:spotube/models/unified_track.dart';

abstract class MusicProvider {
  String get providerId;
  MusicProviderType get type;

  Future<bool> connect();
  Future<void> disconnect();
  Future<bool> isAuthenticated();
  Future<UnifiedTrack?> getTrack(String id);
  Future<List<UnifiedTrack>> search(String query);
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId);
  Future<String?> getPlayableStreamUrl(UnifiedTrack track);
}
