import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/circle_button.dart';
import '../../../widgets/genre_chips.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/status_tag.dart';
import '../../../widgets/trailer_button.dart';
import '../../../widgets/watch_progress_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lists/widgets/add_to_lists_sheet.dart';
import '../data/series_detail.dart';
import '../providers/series_detail_provider.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.tvdbId});

  final String tvdbId;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  static const _overviewCollapsedLength = 140;

  bool _overviewExpanded = false;

  @override
  void initState() {
    super.initState();
    // defer: can't modify provider state during build
    Future.microtask(
      () => ref.read(seriesDetailProvider.notifier).load(widget.tvdbId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(seriesDetailProvider);

    ref.listen(seriesDetailProvider, (previous, next) {
      final actionErrorKey = next.actionErrorKey;
      if (actionErrorKey != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_actionErrorMessage(l10n, actionErrorKey))),
        );
        ref.read(seriesDetailProvider.notifier).clearActionError();
      }
    });

    return Scaffold(body: SafeArea(child: _buildBody(context, l10n, state)));
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SeriesDetailState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.series == null) {
      return Center(
        child: Text(l10n.genericError, textAlign: TextAlign.center),
      );
    }

    final series = state.series!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            series: series,
            l10n: l10n,
            watchProgress: state.watchProgress,
            isFavorite: state.isFavorite,
          ),
          Padding(
            // no bottom inset - _SeasonChips (below) needs to bleed edge-to-edge
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(series: series, l10n: l10n),
                const SizedBox(height: AppSpacing.md),
                if (state.inWatchlist) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          active: state.archived,
                          activeIcon: Symbols.unarchive,
                          inactiveIcon: Symbols.archive,
                          activeLabel: l10n.unarchiveAction,
                          inactiveLabel: l10n.archiveAction,
                          onPressed: () => _requireLogin(
                            context,
                            ref,
                            () => ref
                                .read(seriesDetailProvider.notifier)
                                .setArchived(!state.archived),
                          ),
                        ),
                      ),
                      // only relevant once something's actually watched
                      if (state.hasAnyWatchedEpisode) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ToggleButton(
                            active: state.removed,
                            activeIcon: Symbols.visibility,
                            inactiveIcon: Symbols.visibility_off,
                            activeLabel: l10n.restoreAction,
                            inactiveLabel: l10n.markRemovedAction,
                            onPressed: () => _requireLogin(
                              context,
                              ref,
                              () => ref
                                  .read(seriesDetailProvider.notifier)
                                  .setRemoved(!state.removed),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // only offered once there's nothing watched to lose
                  if (!state.hasAnyWatchedEpisode) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _requireLogin(
                          context,
                          ref,
                          () => _handleRemoveFromWatchlist(context, ref),
                        ),
                        icon: const Icon(Symbols.delete_outline),
                        label: Text(l10n.removeFromWatchlistAction),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _requireLogin(
                        context,
                        ref,
                        () => ref
                            .read(seriesDetailProvider.notifier)
                            .addToWatchlist(),
                      ),
                      icon: const Icon(Symbols.add),
                      label: Text(l10n.addToWatchlist),
                    ),
                  ),
                if (series.genres.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  GenreChips(genres: series.genres, l10n: l10n),
                ],
                if (series.overview != null && series.overview!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildOverview(context, l10n, series.overview!),
                ],
                if (series.trailer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  TrailerButton(trailer: series.trailer!, l10n: l10n),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.episodesSectionTitle,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          if (state.seasonNumbers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _SeasonChips(
              seasons: state.seasonNumbers,
              selectedSeason: state.selectedSeason,
              l10n: l10n,
            ),
          ],
          Padding(
            // top: sm is the gap to the season chips (or title, if none);
            // bottom: md is the page's usual bottom margin
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...state.episodesForSelectedSeason.map(
                  (episode) => _EpisodeRow(episode: episode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    AppLocalizations l10n,
    String overview,
  ) {
    final isLong = overview.length > _overviewCollapsedLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overview,
          maxLines: _overviewExpanded ? null : 4,
          overflow: _overviewExpanded
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _overviewExpanded = !_overviewExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _overviewExpanded ? l10n.readLess : l10n.readMore,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The archive/mark-removed toggles on a series already in the watchlist -
/// both reversible, unlike the hard-delete "remove entirely" action.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.active,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onPressed,
  });

  final bool active;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // overrides the theme's default AppRadius.sm - deliberately more rounded
    // than other buttons
    final shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
    );

    if (active) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(activeIcon),
        label: Text(activeLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(shape: shape),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(inactiveIcon),
      label: Text(inactiveLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(shape: shape),
    );
  }
}

String _actionErrorMessage(AppLocalizations l10n, String errorKey) {
  switch (errorKey) {
    case 'has_watch_history':
      return l10n.removeFromWatchlistHasHistoryError;
    default:
      return l10n.genericError;
  }
}

/// Redirects to login instead of silently no-op-ing for signed-out visitors.
void _requireLogin(BuildContext context, WidgetRef ref, VoidCallback action) {
  if (ref.read(authProvider).isLoggedIn) {
    action();
  } else {
    context.push('/login');
  }
}

void _showAddToLists(BuildContext context, String tvdbId) {
  showAddToListsSheet(context, tvdbId);
}

/// If earlier episodes in the season are still unwatched, asks whether to
/// mark those too rather than silently leaving a gap.
Future<void> _handleEpisodeTap(
  BuildContext context,
  WidgetRef ref,
  Episode episode,
) async {
  final notifier = ref.read(seriesDetailProvider.notifier);
  if (episode.watched) {
    return _handleWatchedEpisodeTap(context, ref, episode);
  }

  final earlierUnwatched = notifier.unwatchedBefore(episode);
  if (earlierUnwatched.isEmpty) {
    return notifier.toggleEpisodeWatched(episode);
  }

  final l10n = AppLocalizations.of(context)!;
  final markAll = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.markPreviousEpisodesTitle),
      content: Text(l10n.markPreviousEpisodesPrompt),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.markOnlyThisOne),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.markAllPrevious),
        ),
      ],
    ),
  );
  if (markAll == null) return;
  if (markAll) {
    await notifier.markWatchedThrough(episode);
  } else {
    await notifier.toggleEpisodeWatched(episode);
  }
}

/// Confirms first - unlike setArchived/setRemoved, this can't be undone.
Future<void> _handleRemoveFromWatchlist(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.removeFromWatchlistConfirmTitle),
      content: Text(l10n.removeFromWatchlistConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(l10n.removeFromWatchlistConfirmButton),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(seriesDetailProvider.notifier).removeFromWatchlist();
  }
}

enum _WatchedEpisodeAction { delete, watchOnce, rewatch }

/// Tapping an already-watched episode is ambiguous now that rewatching is
/// its own action - asks which one was meant rather than always deleting
/// history. The "watch it only once" choice only shows up once rewatched.
Future<void> _handleWatchedEpisodeTap(
  BuildContext context,
  WidgetRef ref,
  Episode episode,
) async {
  final l10n = AppLocalizations.of(context)!;
  final action = await showDialog<_WatchedEpisodeAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unwatchEpisodeTitle),
      content: Text(l10n.unwatchEpisodePrompt),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_WatchedEpisodeAction.delete),
          child: Text(l10n.deleteWatchAction),
        ),
        if (episode.watchCount > 1)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_WatchedEpisodeAction.watchOnce),
            child: Text(l10n.watchOnceAction),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_WatchedEpisodeAction.rewatch),
          child: Text(l10n.rewatchAction),
        ),
      ],
    ),
  );

  final notifier = ref.read(seriesDetailProvider.notifier);
  switch (action) {
    case _WatchedEpisodeAction.delete:
      await notifier.toggleEpisodeWatched(episode);
    case _WatchedEpisodeAction.watchOnce:
      await notifier.undoRewatch(episode);
    case _WatchedEpisodeAction.rewatch:
      await notifier.rewatchEpisode(episode);
    case null:
      break;
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.series,
    required this.l10n,
    this.watchProgress,
    required this.isFavorite,
  });

  final SeriesDetail series;
  final AppLocalizations l10n;
  final double? watchProgress;
  final bool isFavorite;

  // caps unbounded growth of AspectRatio(16/9) on wide/desktop screens
  static const double _maxHeight = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackdrop(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x1A000000),
                    Color(0x26000000),
                    Color(0x8C000000),
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            if (watchProgress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: WatchProgressBar(progress: watchProgress!),
              ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: CircleButton(
                icon: Symbols.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Row(
                children: [
                  CircleButton(
                    icon: Symbols.favorite,
                    fill: isFavorite ? 1 : 0,
                    color: isFavorite ? AppColors.coral : AppColors.navy,
                    onTap: () => _requireLogin(
                      context,
                      ref,
                      () => ref
                          .read(seriesDetailProvider.notifier)
                          .setFavorite(!isFavorite),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CircleButton(
                    icon: Symbols.playlist_add,
                    onTap: () => _requireLogin(
                      context,
                      ref,
                      () => _showAddToLists(context, series.tvdbId),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    series.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                      height: 1.22,
                      shadows: const [
                        Shadow(color: Color(0x59000000), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (series.yearStart != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            series.yearStart!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Color(0x59000000), blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      if (series.status != null)
                        StatusTag(
                          label: localizedSeriesStatus(l10n, series.status!),
                          color: seriesStatusColor(series.status!),
                          backgroundOpacity: 1,
                          textColor: seriesStatusOnColor(series.status!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    if (series.backgroundUrl != null) {
      return CachedNetworkImage(
        imageUrl: series.backgroundUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallback(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    if (series.imageUrl == null) {
      return const PlaceholderMark(fontSize: 40);
    }
    // ImageFiltered's blur paints beyond its layout bounds - Stack's own
    // clipBehavior isn't enough to contain it
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0x59000000),
            BlendMode.darken,
          ),
          child: CachedNetworkImage(
            imageUrl: series.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                const PlaceholderMark(fontSize: 40),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.series, required this.l10n});

  final SeriesDetail series;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          _stat(
            context,
            series.seasonCount == null ? '–' : '${series.seasonCount}',
            l10n.seasonsStatLabel,
          ),
          _divider(dividerColor),
          _stat(context, _yearsLabel(), l10n.yearsStatLabel),
          _divider(dividerColor),
          _stat(
            context,
            series.averageRuntime == null
                ? '–'
                : l10n.runtimeMinutes(series.averageRuntime!),
            l10n.runtimeStatLabel,
          ),
        ],
      ),
    );
  }

  String _yearsLabel() {
    final start = series.yearStart;
    if (start == null) return '–';
    if (series.status == 'Continuing') {
      return '$start–${l10n.presentYear}';
    }
    final end = series.yearEnd;
    if (end != null && end != start) {
      return '$start–$end';
    }
    return start;
  }

  Widget _divider(Color color) {
    return Container(width: 1, height: 32, color: color);
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SeasonChips extends ConsumerStatefulWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selectedSeason,
    required this.l10n,
  });

  final List<int> seasons;
  final int? selectedSeason;
  final AppLocalizations l10n;

  @override
  ConsumerState<_SeasonChips> createState() => _SeasonChipsState();
}

class _SeasonChipsState extends ConsumerState<_SeasonChips> {
  // keyed by season number (not index) so a key stays attached to the
  // same chip across rebuilds regardless of list content changes
  final Map<int, GlobalKey> _chipKeys = {};

  // owned directly rather than static Scrollable.ensureVisible, which walks
  // every ancestor Scrollable - including the page's own outer
  // SingleChildScrollView - and would jump the whole page to show one chip
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // defer to next frame: ensureVisible needs the chip to already have a
    // laid-out size
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _SeasonChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSeason != oldWidget.selectedSeason) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final chipContext = _chipKeys[widget.selectedSeason]?.currentContext;
    final renderObject = chipContext?.findRenderObject();
    if (renderObject == null || !_scrollController.hasClients) return;
    _scrollController.position.ensureVisible(
      renderObject,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        // built eagerly, not lazily, so ensureVisible always has a real
        // context to scroll to, even for an off-screen chip - season counts
        // are small enough this costs nothing
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            for (final season in widget.seasons) ...[
              Builder(
                builder: (context) {
                  final selected = season == widget.selectedSeason;
                  final chipKey = _chipKeys.putIfAbsent(
                    season,
                    () => GlobalKey(),
                  );
                  return GestureDetector(
                    key: chipKey,
                    onTap: () => ref
                        .read(seriesDetailProvider.notifier)
                        .selectSeason(season),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.navy
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: selected
                              ? AppColors.navy
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        season == 0
                            ? widget.l10n.specialsLabel
                            : widget.l10n.seasonLabel(season),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (season != widget.seasons.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends ConsumerWidget {
  const _EpisodeRow({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Theme.of(context).dividerColor;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        // without this, default center alignment centers the thumb against
        // whatever height the title/subtitle column ends up needing
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 84,
              height: 48,
              child: episode.imageUrl == null
                  ? const PlaceholderMark(fontSize: 15)
                  : CachedNetworkImage(
                      imageUrl: episode.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const PlaceholderMark(fontSize: 15),
                      errorWidget: (context, url, error) =>
                          const PlaceholderMark(fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // "0x03" is noise in the Especials tab - only one season 0 exists
                  '${episode.seasonNumber == 0 ? 'E' : '${episode.seasonNumber}x'}'
                  '${episode.episodeNumber.toString().padLeft(2, '0')}'
                  '${episode.name != null ? ' · ${episode.name}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _episodeSubtitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
              ],
            ),
          ),
          GestureDetector(
            // no handler at all (not one that no-ops) for episodes that
            // haven't aired, so there's no accidental login prompt
            onTap: !episode.hasAired
                ? null
                : () => _requireLogin(
                    context,
                    ref,
                    () => _handleEpisodeTap(context, ref, episode),
                  ),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: episode.watched ? AppColors.sage : Colors.transparent,
                border: episode.watched
                    ? null
                    : Border.all(
                        color: episode.hasAired
                            ? dividerColor
                            : dividerColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
              ),
              child: !episode.watched
                  ? null
                  : episode.watchCount > 1
                  ? Text(
                      'x${episode.watchCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    )
                  : const Icon(
                      Symbols.check,
                      size: 14,
                      color: AppColors.navy,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _episodeSubtitle(BuildContext context) {
    final parts = <String>[];
    if (episode.aired != null) {
      final date = DateTime.tryParse(episode.aired!);
      if (date != null) {
        final locale = Localizations.localeOf(context).toString();
        parts.add(DateFormat('d MMM y', locale).format(date));
      }
    }
    if (episode.runtime != null) {
      parts.add(AppLocalizations.of(context)!.runtimeMinutes(episode.runtime!));
    }
    return parts.join(' · ');
  }
}
