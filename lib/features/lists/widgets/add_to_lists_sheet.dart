import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../providers/list_membership_provider.dart';

/// Opens the multi-list "add to a list" picker for [tvdbId] - shared by
/// SeriesDetailScreen and MovieDetailScreen ([isMovie] picks which of
/// ListMembershipController's series/movie API calls it makes). Loads
/// membership first so the sheet doesn't flash an empty state before its
/// own first frame.
void showAddToListsSheet(BuildContext context, String tvdbId, {bool isMovie = false}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AddToListsSheet(tvdbId: tvdbId, isMovie: isMovie),
  );
}

class _AddToListsSheet extends ConsumerStatefulWidget {
  const _AddToListsSheet({required this.tvdbId, required this.isMovie});

  final String tvdbId;
  final bool isMovie;

  @override
  ConsumerState<_AddToListsSheet> createState() => _AddToListsSheetState();
}

class _AddToListsSheetState extends ConsumerState<_AddToListsSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(listMembershipProvider.notifier)
          .load(widget.tvdbId, isMovie: widget.isMovie),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(listMembershipProvider);

    return SafeArea(
      // caps the sheet's height so the Flexible below has a bounded parent
      // to size against - showModalBottomSheet otherwise gives its child
      // unbounded height, which a Flexible inside a mainAxisSize.min Column
      // can't lay out against (asserts in debug); this also lets a long
      // list of lists scroll instead of overflowing past the screen
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  l10n.addToListsTitle,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(child: _buildBody(context, l10n, state)),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.createListTitle),
                onTap: () => _createAndAdd(context, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ListMembershipState state,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.errorKey != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          state.errorKey == 'unknown_error' ? l10n.genericError : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(l10n.listsEmpty),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return CheckboxListTile(
          value: item.inList,
          title: Text(item.name),
          onChanged: (_) =>
              ref.read(listMembershipProvider.notifier).toggle(item),
        );
      },
    );
  }

  Future<void> _createAndAdd(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController();
    String? errorText;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.createListTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.listNameLabel,
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                // guards against a double-tap firing Navigator.pop() twice
                // - see lists_screen.dart's _createList for the full
                // explanation
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final error = await ref
                            .read(listMembershipProvider.notifier)
                            .createAndAdd(controller.text.trim());
                        if (error == null) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } else {
                          setState(() {
                            isSaving = false;
                            errorText = error == 'unknown_error'
                                ? l10n.genericError
                                : error;
                          });
                        }
                      },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
