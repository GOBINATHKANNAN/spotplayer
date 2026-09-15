import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/image/universal_image.dart';
import 'package:spotube/components/links/artist_link.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/services/audio_player/audio_player.dart';

class HomeContinueListeningSection extends HookConsumerWidget {
  const HomeContinueListeningSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final audioState = ref.watch(audioPlayerProvider);
    final activeTrack = audioState.activeTrack;
    final isPlaying = useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    if (activeTrack == null) {
      return const SizedBox.shrink();
    }

    final imagePath = (activeTrack.album.images).asUrlString(
      placeholder: ImagePlaceholder.albumArt,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                borderRadius: theme.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: theme.borderRadiusLg,
                child: UniversalImage(
                  path: imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "CONTINUE LISTENING",
                    style: theme.typography.xSmall.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    activeTrack.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.large.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(2),
                  ArtistLink(
                    artists: activeTrack.artists,
                    textStyle: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            IconButton.primary(
              size: ButtonSize.large,
              icon: Icon(isPlaying ? SpotubeIcons.pause : SpotubeIcons.play),
              onPressed: () {
                if (isPlaying) {
                  audioPlayer.pause();
                } else {
                  audioPlayer.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
