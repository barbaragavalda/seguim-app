import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Logo + app name + one-line description of what Seguim! actually does -
/// shown wherever a logged-out visitor lands (WatchlistScreen and
/// ProfileScreen's own logged-out branches, both reachable without an
/// account). Exists specifically because Google's OAuth verification
/// flagged this app's public homepage for not explaining its purpose
/// anywhere - a bare "log in" prompt with no name/logo/description wasn't
/// enough for a reviewer (or a first-time visitor) to tell what the app
/// even is.
class AppIntro extends StatelessWidget {
  const AppIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.asset(
            'assets/icon/icon.png',
            width: 84,
            height: 84,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Seguim!',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w900, fontSize: 28),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.appIntroDescription,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
