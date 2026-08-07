import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/lists/data/list_movie.dart';
import '../l10n/generated/app_localizations.dart';
import 'remove_button.dart';
import 'series_poster.dart';
import 'status_tag.dart';

/// Poster-grid card used by both ListDetailScreen and FavoriteMoviesScreen -
/// mirrors SeriesCard exactly, own docblock has the full reasoning.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.l10n,
    required this.onRemove,
    this.removeTooltip,
  });

  final ListMovie movie;
  final AppLocalizations l10n;
  final VoidCallback onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final year = movie.year;
    final status = movie.status == null
        ? null
        : localizedMovieStatus(l10n, movie.status!);
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () => context.push('/movies/${movie.tvdbId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SeriesPoster(imageUrl: movie.imageUrl),
              Positioned(
                top: 4,
                right: 4,
                child: RemoveButton(onTap: onRemove, tooltip: removeTooltip),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            movie.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          if (year != null || status != null)
            Row(
              children: [
                if (year != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(year, style: subtitleStyle),
                  ),
                if (status != null)
                  Flexible(
                    child: StatusTag(
                      label: status,
                      color: movieStatusColor(movie.status!),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
