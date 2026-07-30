import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_spacing.dart';

/// A frosted, floating sticky-header title (like iOS grouped lists): content
/// scrolls under a blurred, translucent bar rather than a solid one. Shared
/// by WatchlistScreen and MoviesScreen's own SliverStickyHeader sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: _height,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.78),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(
            title,
            style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}
