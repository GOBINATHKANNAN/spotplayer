import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';

class HomeEndlessPlaybackBanner extends HookConsumerWidget {
  const HomeEndlessPlaybackBanner({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final endlessPlayback = ref.watch(
      userPreferencesProvider.select((s) => s.endlessPlayback),
    );

    if (!endlessPlayback) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(25),
        borderRadius: theme.borderRadiusMd,
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Icon(
            SpotubeIcons.radio,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              "Endless Playback Active — Related tracks will auto-play when queue finishes",
              style: theme.typography.small.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          OutlineBadge(
            style: const ButtonStyle.outline(
              size: ButtonSize.small,
              density: ButtonDensity.compact,
            ),
            child: const Text("ON"),
          ),
        ],
      ),
    );
  }
}
