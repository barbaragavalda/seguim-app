import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/status_tag.dart';
import '../data/watchlist_item.dart';

/// The landscape-box series row shared by WatchlistScreen and
/// MySeriesScreen - same visual design ("igual que el watchlist"), just
/// with a different [onReturned] hook so each screen can refresh its own
/// provider after the series detail screen may have changed watched/
/// watchlist state.
class WatchlistItemRow extends StatelessWidget {
  const WatchlistItemRow({
    super.key,
    required this.item,
    required this.l10n,
    this.onReturned,
  });

  final WatchlistItem item;
  final AppLocalizations l10n;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () async {
        await context.push('/series/${item.tvdbId}');
        onReturned?.call();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: dividerColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 108,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.imageUrl == null
                      ? const PlaceholderMark(fontSize: 15)
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) =>
                              const PlaceholderMark(fontSize: 15),
                          errorWidget: (context, url, error) =>
                              const PlaceholderMark(fontSize: 15),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.episodeCode != null)
                    Text.rich(
                      TextSpan(
                        style: bodySmall,
                        children: [
                          TextSpan(text: '${l10n.nextEpisodeLabel} '),
                          TextSpan(
                            text: item.episodeCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          TextSpan(text: ' · ${item.nextEpisodeName ?? ''}'),
                        ],
                      ),
                    )
                  else if (item.premiereInDays != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusTag(
                          label: l10n.premiereUpcoming,
                          color: seriesStatusColor('Upcoming'),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.premiereInDays(item.premiereInDays!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodySmall,
                          ),
                        ),
                      ],
                    ),
                  if (item.remainingEpisodes > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.episodesRemaining(item.remainingEpisodes),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Passive "loading more" spinner shown at the end of an infinite-scroll
/// list - shared by WatchlistScreen and MySeriesScreen.
class LoadingMoreIndicator extends StatelessWidget {
  const LoadingMoreIndicator({super.key, required this.isLoadingMore});

  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (!isLoadingMore) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
