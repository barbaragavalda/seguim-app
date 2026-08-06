import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../../../widgets/series_poster.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/user_list.dart';
import '../providers/lists_provider.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  static const _loadMoreThreshold = 300;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as the other tab
    // screens' initState (WatchlistScreen, ProfileScreen, ...)
    Future.microtask(() => ref.read(listsProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(listsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(listsProvider.notifier).load();
      }
    });

    if (!isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: CenteredForm(
            children: [
              Text(l10n.listsLoginPrompt, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.push('/login'),
                child: Text(l10n.logIn),
              ),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLists),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add),
            onPressed: () => _createList(context, ref),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, l10n, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ListsState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorKey != null) {
      return Center(
        child: Text(
          state.errorKey == 'unknown_error' ? l10n.genericError : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (state.items.isEmpty) {
      return Center(child: Text(l10n.listsEmpty));
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.items.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(state.items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final list = state.items[index];
              return _ListRow(key: ValueKey(list.id), index: index, list: list, l10n: l10n);
            },
          ),
        ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  void _onReorder(List<UserList> items, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = [...items];
    final moving = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moving);
    final afterId = newIndex == 0 ? null : reordered[newIndex - 1].id;
    ref.read(listsProvider.notifier).reorder(moving.id, afterId: afterId);
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
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
                // - see ListDetailScreen._rename for the full explanation
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final error = await ref
                            .read(listsProvider.notifier)
                            .createList(controller.text.trim());
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

class _ListRow extends ConsumerWidget {
  const _ListRow({
    super.key,
    required this.index,
    required this.list,
    required this.l10n,
  });

  final int index;
  final UserList list;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/lists/${list.id}', extra: list.name),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') _rename(context, ref);
                      if (value == 'delete') _delete(context, ref);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Symbols.drag_handle),
                    ),
                  ),
                ],
              ),
              if (list.seriesCount > 0 || list.moviesCount > 0)
                Text(
                  switch ((list.seriesCount > 0, list.moviesCount > 0)) {
                    (true, true) => l10n.listItemCountSummaryBoth(
                      list.seriesCount,
                      list.moviesCount,
                    ),
                    (true, false) => l10n.listItemCountSummarySeriesOnly(list.seriesCount),
                    (false, true) => l10n.listItemCountSummaryMoviesOnly(list.moviesCount),
                    (false, false) => '',
                  },
                  style: subtitleStyle,
                ),
              if (list.preview.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _ListPreviewRow(items: list.preview),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: list.name);
    String? errorText;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.renameListTitle),
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
                // - see ListDetailScreen._rename for the full explanation
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final error = await ref
                            .read(listsProvider.notifier)
                            .renameList(list.id, controller.text.trim());
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteListConfirmTitle),
        content: Text(l10n.deleteListConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteListConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(listsProvider.notifier).deleteList(list.id);
    }
  }
}

/// A static (non-draggable, non-tappable) strip of the list's own first
/// few posters - just a preview of what's inside, not another place to
/// reorder from (that stays ListDetailScreen's own job, via its already
/// draggable poster grid). Always lays out _maxSlots equal-width slots
/// (mirrors Lists\Index's own PREVIEW_LIMIT) regardless of how many posters
/// actually came back, filling the extra ones with an invisible spacer -
/// so a poster's own width is always a fixed fraction of the row (1/5 each
/// at the full 5, 1/5 still each at fewer - so 4 posters read as 80% of the
/// row, 3 as 60%, ...), never resized to fill whatever's missing
class _ListPreviewRow extends StatelessWidget {
  const _ListPreviewRow({required this.items});

  final List<ListPreviewItem> items;

  static const _maxSlots = 5;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _maxSlots; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: i < items.length
                ? SeriesPoster(imageUrl: items[i].imageUrl)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
