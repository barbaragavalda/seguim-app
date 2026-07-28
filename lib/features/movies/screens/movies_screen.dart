import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';

/// Placeholder tab, alongside the (TV-series-only, for now) Sèries tab -
/// no movie tracking backend exists yet, see the README's "Deferred"
/// note.
class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMovies)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_movies_outlined,
                  size: 48,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.moviesComingSoonTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.moviesComingSoonBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
