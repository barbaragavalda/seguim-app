import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Logo + app name + one-line description, shown wherever a logged-out
/// visitor lands. Exists because Google's OAuth verification flagged the
/// app's public homepage for not explaining its purpose anywhere - a bare
/// "log in" prompt wasn't enough for a reviewer to tell what the app is.
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
