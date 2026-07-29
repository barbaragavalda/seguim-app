import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/status_tag.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lists/widgets/add_to_lists_sheet.dart';
import '../data/movie_detail.dart';
import '../providers/movie_detail_provider.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  const MovieDetailScreen({super.key, required this.tvdbId});

  final String tvdbId;

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  static const _overviewCollapsedLength = 140;

  bool _overviewExpanded = false;

  @override
  void initState() {
    super.initState();
    // Riverpod forbids modifying provider state synchronously during a
    // widget lifecycle method - defer to the next microtask, same reasoning
    // as SeriesDetailScreen.initState
    Future.microtask(
      () => ref.read(movieDetailProvider.notifier).load(widget.tvdbId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(movieDetailProvider);

    return Scaffold(body: SafeArea(child: _buildBody(context, l10n, state)));
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    MovieDetailState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.movie == null) {
      return Center(
        child: Text(l10n.genericError, textAlign: TextAlign.center),
      );
    }

    final movie = state.movie!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(movie: movie, l10n: l10n),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(movie: movie, l10n: l10n),
                const SizedBox(height: AppSpacing.md),
                if (state.watched)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _requireLogin(
                        context,
                        ref,
                        () => _handleWatchedTap(context, ref, state),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        state.watchCount > 1
                            ? l10n.watchedTimesLabel(state.watchCount)
                            : l10n.watchedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _requireLogin(
                        context,
                        ref,
                        () => ref.read(movieDetailProvider.notifier).toggleWatched(),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.markWatchedAction),
                    ),
                  ),
                if (!state.inWatchlist && !state.watched) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _requireLogin(
                        context,
                        ref,
                        () => ref.read(movieDetailProvider.notifier).addToWatchlist(),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addToWatchlist),
                    ),
                  ),
                ],
                if (movie.overview != null && movie.overview!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildOverview(context, l10n, movie.overview!),
                ],
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

/// Watchlist/"mark watched" both need a real logged-in user; viewing the
/// movie itself does not - same as SeriesDetailScreen's own _requireLogin.
void _requireLogin(BuildContext context, WidgetRef ref, VoidCallback action) {
  if (ref.read(authProvider).isLoggedIn) {
    action();
  } else {
    context.push('/login');
  }
}

enum _WatchedMovieAction { delete, watchOnce, rewatch }

/// Tapping an already-watched movie is ambiguous now that rewatching is its
/// own action - asks which one was meant instead of always deleting the
/// watch history outright, same dialog shape as SeriesDetailScreen's
/// _handleWatchedEpisodeTap. The "watch it only once" choice only shows up
/// once it's actually been rewatched.
Future<void> _handleWatchedTap(
  BuildContext context,
  WidgetRef ref,
  MovieDetailState state,
) async {
  final l10n = AppLocalizations.of(context)!;
  final action = await showDialog<_WatchedMovieAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unwatchMovieTitle),
      content: Text(l10n.unwatchMoviePrompt),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_WatchedMovieAction.delete),
          child: Text(l10n.deleteWatchAction),
        ),
        if (state.watchCount > 1)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_WatchedMovieAction.watchOnce),
            child: Text(l10n.watchOnceAction),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_WatchedMovieAction.rewatch),
          child: Text(l10n.rewatchAction),
        ),
      ],
    ),
  );

  final notifier = ref.read(movieDetailProvider.notifier);
  switch (action) {
    case _WatchedMovieAction.delete:
      await notifier.toggleWatched();
    case _WatchedMovieAction.watchOnce:
      await notifier.undoRewatch();
    case _WatchedMovieAction.rewatch:
      await notifier.rewatch();
    case null:
      break;
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.movie, required this.l10n});

  final MovieDetail movie;
  final AppLocalizations l10n;

  // same reasoning as SeriesDetailScreen's own _Header._maxHeight
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
                  () => showAddToListsSheet(context, movie.tvdbId, isMovie: true),
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
                    movie.displayTitle,
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
                      if (movie.year != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            movie.year!,
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
                      if (movie.status != null)
                        StatusTag(
                          label: localizedMovieStatus(l10n, movie.status!),
                          color: movieStatusColor(movie.status!),
                          backgroundOpacity: 1,
                          textColor: movieStatusOnColor(movie.status!),
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
    if (movie.backgroundUrl != null) {
      return CachedNetworkImage(
        imageUrl: movie.backgroundUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallback(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    if (movie.imageUrl == null) {
      return const PlaceholderMark(fontSize: 40, label: 'P!');
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0x59000000),
          BlendMode.darken,
        ),
        child: CachedNetworkImage(
          imageUrl: movie.imageUrl!,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              const PlaceholderMark(fontSize: 40, label: 'P!'),
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
  const _StatsRow({required this.movie, required this.l10n});

  final MovieDetail movie;
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
          _stat(context, movie.year ?? '–', l10n.yearStatLabel),
          _divider(dividerColor),
          _stat(
            context,
            movie.runtime == null ? '–' : l10n.runtimeMinutes(movie.runtime!),
            l10n.runtimeStatLabel,
          ),
        ],
      ),
    );
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
