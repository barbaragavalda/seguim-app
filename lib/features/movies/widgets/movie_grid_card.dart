import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../lists/data/list_movie.dart';

/// Poster-grid tile shared by MyMoviesScreen and MoviesScreen. [onReturned]
/// is only passed by MoviesScreen, to refresh when a movie marked watched
/// on the detail screen should disappear from its always-"not watched" list.
class MovieGridCard extends StatelessWidget {
  const MovieGridCard({
    super.key,
    required this.movie,
    required this.l10n,
    this.onReturned,
  });

  final ListMovie movie;
  final AppLocalizations l10n;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    final year = movie.year;
    final status = movie.status == null
        ? null
        : localizedMovieStatus(l10n, movie.status!);
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () async {
        await context.push('/movies/${movie.tvdbId}');
        onReturned?.call();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // no watchProgress - a movie is binary (watched or not)
          SeriesPoster(imageUrl: movie.imageUrl),
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
