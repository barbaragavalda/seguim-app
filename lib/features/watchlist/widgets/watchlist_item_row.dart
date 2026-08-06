import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

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
///
/// [onToggleWatched], when given, adds a third column to the row - a small
/// circle marking [item.nextEpisodeTvdbId] watched right from the list,
/// without opening the series detail screen. Only WatchlistScreen passes
/// it today; hidden entirely once there's nothing left to mark (item's own
/// nextEpisodeTvdbId null, e.g. a not-yet-aired series).
class WatchlistItemRow extends StatelessWidget {
  const WatchlistItemRow({
    super.key,
    required this.item,
    required this.l10n,
    this.onReturned,
    this.onToggleWatched,
  });

  final WatchlistItem item;
  final AppLocalizations l10n;
  final VoidCallback? onReturned;
  final VoidCallback? onToggleWatched;

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
                  // AnimatedSwitcher cross-fades the whole block (next
                  // episode + remaining count together, not each text
                  // separately) whenever any of them changes - keyed on
                  // their own values so marking an episode watched from
                  // this row (which reloads the list, see
                  // WatchlistController.markEpisodeWatched()'s own
                  // docblock) visibly signals "this updated", not just a
                  // silent snap to the new numbers
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(
                        '${item.episodeCode}-${item.premiereInDays}-${item.remainingEpisodes}',
                      ),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                TextSpan(
                                  text: ' · ${item.nextEpisodeName ?? ''}',
                                ),
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
            if (onToggleWatched != null && item.nextEpisodeTvdbId != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _MarkWatchedButton(
                  dividerColor: dividerColor,
                  onTap: onToggleWatched!,
                ),
              ),
            ],
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

/// The row's "mark next episode watched" button - an empty circle (not a
/// checkmark) on purpose, see WatchlistItemRow's own child comment on why.
/// Stateful only for its own tap animation (a quick scale pulse, entirely
/// separate from AnimatedSwitcher's own fade on the next-episode text once
/// the reload actually lands) - gives instant feedback that the tap
/// registered even during the network round-trip, using nothing beyond
/// core Flutter animation classes (AnimationController/CurvedAnimation/
/// ScaleTransition).
class _MarkWatchedButton extends StatefulWidget {
  const _MarkWatchedButton({required this.dividerColor, required this.onTap});

  final Color dividerColor;
  final VoidCallback onTap;

  @override
  State<_MarkWatchedButton> createState() => _MarkWatchedButtonState();
}

class _MarkWatchedButtonState extends State<_MarkWatchedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  ).drive(Tween(begin: 1.0, end: 1.35));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    widget.onTap();
    await _controller.forward();
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.dividerColor, width: 1.5),
          ),
          child: Icon(Symbols.check, size: 14, color: widget.dividerColor),
        ),
      ),
    );
  }
}
