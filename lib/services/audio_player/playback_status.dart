/// Enumeration representing the fine-grained playback status of the current track
/// in the authoritative PlaybackQueueController lifecycle.
enum TrackPlaybackStatus {
  idle,
  resolving,
  ready,
  playing,
  paused,
  failed,
  unavailable,
  completed,
}
