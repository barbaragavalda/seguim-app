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
                SizedBox(
                  width: double.infinity,
                  child: state.inWatchlist
                      ? OutlinedButton.icon(
                          onPressed: () => _requireLogin(
                            context,
                            ref,
                            () => ref
                                .read(seriesDetailProvider.notifier)
                                .toggleWatchlist(),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text(l10n.inWatchlist),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: () => _requireLogin(
                            context,
                            ref,
                            () => ref
                                .read(seriesDetailProvider.notifier)
                                .toggleWatchlist(),
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

class _Header extends StatelessWidget {
  const _Header({required this.series, required this.l10n});

  final SeriesDetail series;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
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

class _SeasonChips extends ConsumerWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selectedSeason,
    required this.l10n,
  });

  final List<int> seasons;
  final int? selectedSeason;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final season = seasons[index];
              final selected = season == selectedSeason;
              return GestureDetector(
                onTap: () => ref
                    .read(seriesDetailProvider.notifier)
                    .selectSeason(season),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                    l10n.seasonLabel(season),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              () => ref
                  .read(seriesDetailProvider.notifier)
                  .toggleEpisodeWatched(episode),
            ),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: episode.watched ? AppColors.sage : Colors.transparent,
                border: episode.watched
                    ? null
                    : Border.all(color: dividerColor, width: 1.5),
              ),
              child: episode.watched
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.onSageLight,
                    )
                  : null,
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
