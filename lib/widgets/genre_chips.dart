import 'package:flutter/material.dart';

import '../features/movie_detail/data/movie_detail.dart' show MovieGenre;
import '../l10n/generated/app_localizations.dart';
import 'status_tag.dart';

class GenreChips extends StatelessWidget {
  const GenreChips({super.key, required this.genres, required this.l10n});

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
