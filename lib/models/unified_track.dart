enum MusicProviderType {
  spotify,
  appleMusic,
  youtubeMusic,
  local,
}

enum AudioQualityType {
  automatic,
  highQuality,
  lossless,
  hiResLossless,
}

class UnifiedTrack {
  final String canonicalId;
  final String? isrc;
  final String title;
  final String artist;
  final List<String> artists;
  final String album;
  final String? albumArtUrl;
  final int durationMs;
  final MusicProviderType provider;
  final String providerId;
  final AudioQualityType audioQuality;
  final bool isAvailable;
  final bool explicit;

  const UnifiedTrack({
    required this.canonicalId,
    this.isrc,
    required this.title,
    required this.artist,
    this.artists = const [],
    required this.album,
    this.albumArtUrl,
    required this.durationMs,
    required this.provider,
    required this.providerId,
    this.audioQuality = AudioQualityType.highQuality,
    this.isAvailable = true,
    this.explicit = false,
  });

  Map<String, dynamic> toJson() => {
        'canonicalId': canonicalId,
        'isrc': isrc,
        'title': title,
        'artist': artist,
        'artists': artists,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'durationMs': durationMs,
        'provider': provider.name,
        'providerId': providerId,
        'audioQuality': audioQuality.name,
        'isAvailable': isAvailable,
        'explicit': explicit,
      };

  factory UnifiedTrack.fromJson(Map<String, dynamic> json) => UnifiedTrack(
        canonicalId: json['canonicalId'] ?? '',
        isrc: json['isrc'],
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        artists: List<String>.from(json['artists'] ?? []),
        album: json['album'] ?? '',
        albumArtUrl: json['albumArtUrl'],
        durationMs: json['durationMs'] ?? 0,
        provider: MusicProviderType.values.firstWhere(
          (e) => e.name == json['provider'],
          orElse: () => MusicProviderType.local,
        ),
        providerId: json['providerId'] ?? '',
        audioQuality: AudioQualityType.values.firstWhere(
          (e) => e.name == json['audioQuality'],
          orElse: () => AudioQualityType.highQuality,
        ),
        isAvailable: json['isAvailable'] ?? true,
        explicit: json['explicit'] ?? false,
      );
}
