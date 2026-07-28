import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/status_tag.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lists/providers/list_membership_provider.dart';
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
    // Riverpod forbids modifying provider state synchronously during a
    // widget lifecycle method (initState runs as part of the widget tree
    // building) - defer to the next microtask so load()'s first `state =`
    // assignment happens after building has finished.
    Future.microtask(
      () => ref.read(seriesDetailProvider.notifier).load(widget.tvdbId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(seriesDetailProvider);

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
          _Header(series: series, l10n: l10n),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(series: series, l10n: l10n),
                const SizedBox(height: AppSpacing.md),
                if (state.inWatchlist)
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          active: state.archived,
                          activeIcon: Icons.unarchive_outlined,
                          inactiveIcon: Icons.archive_outlined,
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
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ToggleButton(
                          active: state.removed,
                          activeIcon: Icons.visibility_outlined,
                          inactiveIcon: Icons.visibility_off_outlined,
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
                  )
                else
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
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addToWatchlist),
                    ),
                  ),
                if (series.overview != null && series.overview!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildOverview(context, l10n, series.overview!),
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
                const SizedBox(height: AppSpacing.sm),
                if (state.seasonNumbers.isNotEmpty)
                  _SeasonChips(
                    seasons: state.seasonNumbers,
                    selectedSeason: state.selectedSeason,
                    l10n: l10n,
                  ),
                const SizedBox(height: AppSpacing.sm),
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
/// both are reversible flags (unlike the plain hard-delete "remove
/// entirely" action, which stays out of this screen - see
/// SeriesDetailController.addToWatchlist()'s docblock).
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
    // same two-state look as the old "+ Watchlist"/"A la watchlist" toggle:
    // filled (solid background) for the inactive/default action, outlined
    // (border only) once it's active
    if (active) {
      final primary = Theme.of(context).colorScheme.primary;
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(activeIcon),
        label: Text(activeLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(inactiveIcon),
      label: Text(inactiveLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Watchlist and "mark watched" both need a real logged-in user; viewing
/// the series itself does not. Redirect to login instead of silently
/// no-op-ing when a signed-out visitor taps either action.
void _requireLogin(BuildContext context, WidgetRef ref, VoidCallback action) {
  if (ref.read(authProvider).isLoggedIn) {
    action();
  } else {
    context.push('/login');
  }
}

/// Opens the multi-list "add to a list" picker for [tvdbId] - loads
/// membership first so the sheet doesn't flash an empty state before its
/// own first frame.
void _showAddToLists(BuildContext context, String tvdbId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AddToListsSheet(tvdbId: tvdbId),
  );
}

class _AddToListsSheet extends ConsumerStatefulWidget {
  const _AddToListsSheet({required this.tvdbId});

  final String tvdbId;

  @override
  ConsumerState<_AddToListsSheet> createState() => _AddToListsSheetState();
}

class _AddToListsSheetState extends ConsumerState<_AddToListsSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(listMembershipProvider.notifier).load(widget.tvdbId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(listMembershipProvider);

    return SafeArea(
      // caps the sheet's height so the Flexible below has a bounded parent
      // to size against - showModalBottomSheet otherwise gives its child
      // unbounded height, which a Flexible inside a mainAxisSize.min Column
      // can't lay out against (asserts in debug); this also lets a long
      // list of lists scroll instead of overflowing past the screen
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  l10n.addToListsTitle,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(child: _buildBody(context, l10n, state)),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.createListTitle),
                onTap: () => _createAndAdd(context, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ListMembershipState state,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.errorKey != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          state.errorKey == 'unknown_error' ? l10n.genericError : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(l10n.listsEmpty),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return CheckboxListTile(
          value: item.inList,
          title: Text(item.name),
          onChanged: (_) =>
              ref.read(listMembershipProvider.notifier).toggle(item),
        );
      },
    );
  }

  Future<void> _createAndAdd(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController();
    String? errorText;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.createListTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.listNameLabel,
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                // guards against a double-tap firing Navigator.pop() twice
                // - see lists_screen.dart's _createList for the full
                // explanation
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final error = await ref
                            .read(listMembershipProvider.notifier)
                            .createAndAdd(controller.text.trim());
                        if (error == null) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } else {
                          setState(() {
                            isSaving = false;
                            errorText = error == 'unknown_error'
                                ? l10n.genericError
                                : error;
                          });
                        }
                      },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tapping to mark an episode watched, when earlier episodes in the same
/// season are still unwatched, asks whether to mark those too rather than
/// silently leaving a gap.
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

enum _WatchedEpisodeAction { delete, watchOnce, rewatch }

/// Tapping an already-watched episode is ambiguous now that rewatching is
/// its own action - asks which one was meant instead of always deleting
/// the watch history outright (toggleEpisodeWatched's old, sole behavior).
/// The "watch it only once" choice (undo any rewatches, keep watchCount at
/// 1) only makes sense - and only shows up - once it's actually been
/// rewatched.
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
  const _Header({required this.series, required this.l10n});

  final SeriesDetail series;
  final AppLocalizations l10n;

  // on a wide (desktop web) screen, a plain AspectRatio(16/9) grows its
  // height with the full screen width with no upper bound - capping it
  // here keeps AspectRatio's normal behavior on mobile (width/16*9 stays
  // well under this) while turning the header into a shorter, wider crop
  // (still BoxFit.cover, so no distortion) past this point
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
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: _CircleButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: _CircleButton(
                icon: Icons.playlist_add,
                onTap: () => _requireLogin(
                  context,
                  ref,
                  () => _showAddToLists(context, series.tvdbId),
                ),
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
    return ImageFiltered(
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
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.darkBg),
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

  @override
  void initState() {
    super.initState();
    // the season list/selection isn't known until after first layout, and
    // ensureVisible needs the chip's own context to already have a size -
    // defer to the next frame, same reasoning as the various providers'
    // "modify state outside build" comments elsewhere in this app
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _SeasonChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSeason != oldWidget.selectedSeason) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    final chipContext = _chipKeys[widget.selectedSeason]?.currentContext;
    if (chipContext == null) return;
    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // built eagerly (not ListView.builder/.separated's lazy,
            // viewport-only building) so ensureVisible always has a real
            // context to scroll to, even for a season chip that starts out
            // off-screen - season counts are small enough that this never
            // costs anything in practice
            //
            // extra blank space on both ends (matching the fade gradients'
            // width below) so ensureVisible's alignment:0.5 can actually
            // center the first/last chip instead of clamping against
            // min/maxScrollExtent - without this, the first or last chip
            // (exactly the "default to the last watched season" case) ends
            // up flush against the edge, under the fade, looking like the
            // scroll didn't happen at all
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                                ? AppColors.darkBg
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: selected
                                  ? AppColors.darkBg
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            widget.l10n.seasonLabel(season),
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
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: IgnorePointer(
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scaffoldBg, scaffoldBg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scaffoldBg.withValues(alpha: 0), scaffoldBg],
                  ),
                ),
              ),
            ),
          ),
        ],
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
        // matches _WatchlistItemRow's own fix: without this, the row's
        // default center alignment vertically centers the thumb within
        // whatever height the (now-unwrapped, since removing the title's
        // ellipsis) title/subtitle column ends up needing
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
                  '${episode.seasonNumber}x${episode.episodeNumber.toString().padLeft(2, '0')}'
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
            onTap: () => _requireLogin(
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
                    : Border.all(color: dividerColor, width: 1.5),
              ),
              child: !episode.watched
                  ? null
                  : episode.watchCount > 1
                  ? Text(
                      'x${episode.watchCount}',
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
