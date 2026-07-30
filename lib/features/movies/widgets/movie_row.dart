import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../data/movie_watchlist_item.dart';

/// The landscape-box movie row shared by MoviesScreen and MyMoviesScreen -
/// same visual design as WatchlistItemRow (series), with a watched
/// checkmark badge instead of next-episode/remaining-episodes info, since a
/// movie has no episode progress to show.
class MovieRow extends StatelessWidget {
  const MovieRow({super.key, required this.item, this.onReturned});

  final MovieWatchlistItem item;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () async {
        await context.push('/movies/${item.tvdbId}');
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
                  if (item.year != null) ...[
                    const SizedBox(height: 4),
                    Text(item.year!, style: bodySmall),
                  ],
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.watched ? AppColors.sage : Colors.transparent,
                border: item.watched
                    ? null
                    : Border.all(color: dividerColor, width: 1.5),
              ),
              child: !item.watched
                  ? null
                  : item.watchCount > 1
                  ? Text(
                      'x${item.watchCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSageLight,
                      ),
                    )
                  : const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.onSageLight,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Passive "loading more" spinner shown at the end of an infinite-scroll
/// list - shared by MoviesScreen and MyMoviesScreen, same as
/// watchlist/widgets/watchlist_item_row.dart's own for series.
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
