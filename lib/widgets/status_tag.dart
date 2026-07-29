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
