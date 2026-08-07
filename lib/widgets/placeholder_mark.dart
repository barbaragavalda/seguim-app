import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The app's own "S!" mark (Seguim!) - shown wherever a series/movie poster
/// is missing or still loading. Always "S!", regardless of what it's
/// standing in for (a movie included) - it's the app's own placeholder, not
/// a per-content-type label, so there's no `label` override to get wrong.
class PlaceholderMark extends StatelessWidget {
  const PlaceholderMark({super.key, this.fontSize = 32});

  final double fontSize;

  static const _mark = 'S!';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      // derived from the 2 grays rather than its own named color - see
      // AppColors' own docblock
      color: isDark
          ? AppColors.grayLight.withValues(alpha: 0.15)
          : AppColors.grayDark.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          _mark,
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
