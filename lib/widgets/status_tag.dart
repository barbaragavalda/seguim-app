import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

String localizedSeriesStatus(AppLocalizations l10n, String status) {
  switch (status) {
    case 'Continuing':
      return l10n.seriesStatusContinuing;
    case 'Ended':
      return l10n.seriesStatusEnded;
    case 'Upcoming':
      return l10n.seriesStatusUpcoming;
    default:
      return status;
  }
}

Color seriesStatusColor(String status) {
  switch (status) {
    case 'Continuing':
      return AppColors.sage;
    case 'Ended':
      return AppColors.coral;
    case 'Upcoming':
      return AppColors.darkBg;
    default:
      return AppColors.lightTextSecondary;
  }
}

/// Readable text color for a solid (fully opaque) [seriesStatusColor]
/// background, as used over the series detail header photo.
Color seriesStatusOnColor(String status) {
  switch (status) {
    case 'Continuing':
      return AppColors.onSageLight;
    case 'Ended':
      return AppColors.onCoralLight;
    case 'Upcoming':
      return Colors.white;
    default:
      return AppColors.lightTextPrimary;
  }
}

String localizedMovieStatus(AppLocalizations l10n, String status) {
  switch (status) {
    case 'Released':
      return l10n.movieStatusReleased;
    case 'Planned':
      return l10n.movieStatusPlanned;
    case 'In Production':
      return l10n.movieStatusInProduction;
    case 'Rumored':
      return l10n.movieStatusRumored;
    case 'Canceled':
      return l10n.movieStatusCanceled;
    default:
      return status;
  }
}

Color movieStatusColor(String status) {
  switch (status) {
    case 'Released':
      return AppColors.sage;
    case 'In Production':
    case 'Planned':
      return AppColors.darkBg;
    case 'Canceled':
      return AppColors.coral;
    default:
      return AppColors.lightTextSecondary;
  }
}

/// Readable text color for a solid (fully opaque) [movieStatusColor]
/// background, as used over the movie detail header photo - same reasoning
/// as seriesStatusOnColor.
Color movieStatusOnColor(String status) {
  switch (status) {
    case 'Released':
      return AppColors.onSageLight;
    case 'In Production':
    case 'Planned':
      return Colors.white;
    case 'Canceled':
      return AppColors.onCoralLight;
    default:
      return AppColors.lightTextPrimary;
  }
}

/// TheTVDB's genre taxonomy has no translations of its own (see
/// Api\Model\MovieGenre's docblock on the backend) - localized here from
/// the stable `slug` TheTVDB assigns each genre, falling back to the raw
/// (English) `name` for a slug this app hasn't added a translation for yet.
String localizedGenre(AppLocalizations l10n, String slug, String name) {
  switch (slug) {
    case 'soap':
      return l10n.genreSoap;
    case 'science-fiction':
      return l10n.genreScienceFiction;
    case 'reality':
      return l10n.genreReality;
    case 'news':
      return l10n.genreNews;
    case 'mini-series':
      return l10n.genreMiniSeries;
    case 'horror':
      return l10n.genreHorror;
    case 'home-and-garden':
      return l10n.genreHomeAndGarden;
    case 'game-show':
      return l10n.genreGameShow;
    case 'food':
      return l10n.genreFood;
    case 'fantasy':
      return l10n.genreFantasy;
    case 'family':
      return l10n.genreFamily;
    case 'drama':
      return l10n.genreDrama;
    case 'documentary':
      return l10n.genreDocumentary;
    case 'crime':
      return l10n.genreCrime;
    case 'comedy':
      return l10n.genreComedy;
    case 'children':
      return l10n.genreChildren;
    case 'animation':
      return l10n.genreAnimation;
    case 'adventure':
      return l10n.genreAdventure;
    case 'action':
      return l10n.genreAction;
    case 'sport':
      return l10n.genreSport;
    case 'suspense':
      return l10n.genreSuspense;
    case 'talk-show':
      return l10n.genreTalkShow;
    case 'thriller':
      return l10n.genreThriller;
    case 'travel':
      return l10n.genreTravel;
    case 'western':
      return l10n.genreWestern;
    case 'anime':
      return l10n.genreAnime;
    case 'romance':
      return l10n.genreRomance;
    case 'musical':
      return l10n.genreMusical;
    case 'podcast':
      return l10n.genrePodcast;
    case 'mystery':
      return l10n.genreMystery;
    case 'indie':
      return l10n.genreIndie;
    case 'history':
      return l10n.genreHistory;
    case 'war':
      return l10n.genreWar;
    case 'martial-arts':
      return l10n.genreMartialArts;
    case 'awards-show':
      return l10n.genreAwardsShow;
    default:
      return name;
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.label,
    required this.color,
    this.backgroundOpacity = 0.15,
    this.textColor,
  });

  final String label;
  final Color color;
  final double backgroundOpacity;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor ?? color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
