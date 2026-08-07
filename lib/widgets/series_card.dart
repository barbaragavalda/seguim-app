import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/search/data/series.dart';
import '../l10n/generated/app_localizations.dart';
import 'remove_button.dart';
import 'series_poster.dart';
import 'status_tag.dart';

/// Poster-grid card used by both ListDetailScreen and FavoriteSeriesScreen -
/// same layout, only the remove action (and whether it needs a tooltip)
/// differs between the two.
class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.series,
    required this.l10n,
    required this.onRemove,
    this.removeTooltip,
  });

  final Series series;
  final AppLocalizations l10n;
  final VoidCallback onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final year = series.year;
    final status = series.status == null
        ? null
        : localizedSeriesStatus(l10n, series.status!);
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () => context.push('/series/${series.tvdbId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SeriesPoster(
                imageUrl: series.imageUrl,
                watchProgress: series.watchProgress,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: RemoveButton(onTap: onRemove, tooltip: removeTooltip),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            series.name,
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
                      color: seriesStatusColor(series.status!),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
