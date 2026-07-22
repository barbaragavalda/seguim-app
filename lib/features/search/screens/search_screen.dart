import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/series_poster.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSearch)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              onChanged: (value) =>
                  ref.read(searchProvider.notifier).onQueryChanged(value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchPlaceholder,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _buildBody(context, l10n, searchState)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SearchState state,
  ) {
    if (state.query.trim().isEmpty) {
      return Center(child: Text(l10n.searchPlaceholder));
    }
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorKey != null) {
      return Center(
        child: Text(
          state.errorKey == 'unknown_error'
              ? l10n.genericError
              : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (state.results.isEmpty) {
      return Center(child: Text(l10n.searchNoResults(state.query)));
    }

    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.5,
      ),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final series = state.results[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeriesPoster(imageUrl: series.imageUrl),
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
            if (series.year != null)
              Text(series.year!, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }
}
