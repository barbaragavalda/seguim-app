import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

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
          _Header(movie: movie, l10n: l10n, isFavorite: state.isFavorite),
          Padding(
            // no bottom inset when there's a cast to show - _CastRow
            // (below, outside this Padding) needs to bleed edge-to-edge,
            // same reasoning as SeriesDetailScreen's own split Padding
            // around _SeasonChips; the page's usual bottom margin is
            // restored by the SizedBox right after _CastRow instead
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              movie.cast.isNotEmpty ? 0 : AppSpacing.md,
            ),
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
                      icon: const Icon(Symbols.check_circle_outline),
                      label: Text(
                        state.watchCount > 1
                            ? l10n.watchedTimesLabel(state.watchCount)
                            : l10n.watchedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      icon: const Icon(Symbols.check),
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
                      icon: const Icon(Symbols.add),
                      label: Text(l10n.addToWatchlist),
                    ),
                  ),
                ],
                if (movie.genres.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _GenreChips(genres: movie.genres, l10n: l10n),
                ],
                if (movie.overview != null && movie.overview!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildOverview(context, l10n, movie.overview!),
                ],
                if (movie.trailer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TrailerButton(trailer: movie.trailer!, l10n: l10n),
                ],
                if (movie.cast.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.castSectionTitle,
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          if (movie.cast.isNotEmpty) ...[
            _CastRow(cast: movie.cast),
            const SizedBox(height: AppSpacing.md),
          ],
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
  const _Header({
    required this.movie,
    required this.l10n,
    required this.isFavorite,
  });

  final MovieDetail movie;
  final AppLocalizations l10n;
  final bool isFavorite;

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
                icon: Symbols.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Row(
                children: [
                  _CircleButton(
                    icon: Symbols.favorite,
                    fill: isFavorite ? 1 : 0,
                    color: isFavorite ? AppColors.coral : AppColors.darkBg,
                    onTap: () => _requireLogin(
                      context,
                      ref,
                      () => ref
                          .read(movieDetailProvider.notifier)
                          .setFavorite(!isFavorite),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CircleButton(
                    icon: Symbols.playlist_add,
                    onTap: () => _requireLogin(
                      context,
                      ref,
                      () => showAddToListsSheet(context, movie.tvdbId, isMovie: true),
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
          imageUrl: movie.imageUrl!,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              const PlaceholderMark(fontSize: 40),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.fill = 0,
    this.color = AppColors.darkBg,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double fill;
  final Color color;

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
          child: Icon(icon, size: 18, color: color, fill: fill),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.movie, required this.l10n});

  final MovieDetail movie;
  final AppLocalizations l10n;

  // full date when TheTVDB has one (its `first_release.date`), falling back
  // to just the year for a movie synced before that field was added
  String? _releaseDateLabel(BuildContext context) {
    final releaseDate = movie.releaseDate;
    if (releaseDate == null) return movie.year;
    final date = DateTime.tryParse(releaseDate);
    if (date == null) return movie.year;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM y', locale).format(date);
  }

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
          _stat(context, _releaseDateLabel(context) ?? '–', l10n.yearStatLabel),
          _divider(dividerColor),
          _stat(
            context,
            movie.runtime == null ? '–' : l10n.runtimeMinutes(movie.runtime!),
            l10n.movieRuntimeStatLabel,
          ),
          if (movie.contentRating != null) ...[
            _divider(dividerColor),
            _stat(
              context,
              movie.contentRating!.rating,
              l10n.contentRatingStatLabel,
            ),
          ],
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

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.genres, required this.l10n});

  final List<MovieGenre> genres;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final genre in genres)
          StatusTag(
            label: localizedGenre(l10n, genre.slug, genre.name),
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

class _TrailerButton extends StatelessWidget {
  const _TrailerButton({required this.trailer, required this.l10n});

  final MovieTrailer trailer;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(trailer.url),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Symbols.play_circle),
        label: Text(l10n.watchTrailerAction),
      ),
    );
  }
}

class _CastRow extends StatelessWidget {
  const _CastRow({required this.cast});

  final List<MovieCastMember> cast;

  static const _cardWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: cast.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final member = cast[index];
          return SizedBox(
            width: _cardWidth,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    width: _cardWidth,
                    height: _cardWidth,
                    child: member.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: member.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const PlaceholderMark(fontSize: 20),
                          )
                        : const PlaceholderMark(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.characterName != null)
                  Text(
                    member.characterName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: subtitleStyle?.copyWith(fontSize: 11),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
