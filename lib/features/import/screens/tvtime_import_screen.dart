import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../data/tvtime_import_api.dart';
import '../providers/pending_count_provider.dart';
import '../providers/tvtime_import_provider.dart';

class TvTimeImportScreen extends ConsumerStatefulWidget {
  const TvTimeImportScreen({super.key});

  @override
  ConsumerState<TvTimeImportScreen> createState() => _TvTimeImportScreenState();
}

class _TvTimeImportScreenState extends ConsumerState<TvTimeImportScreen> {
  @override
  void initState() {
    super.initState();
    // pendingCountProvider itself doesn't need loading here - AppShell
    // already keeps it fresh for as long as the app is open (see its own
    // docblock), same reasoning as ProfileScreen. Only resumeIfInProgress()
    // is genuinely this screen's own responsibility.
    Future.microtask(() {
      // recovers an import the app process has no memory of starting (see
      // TvTimeImportController.resumeIfInProgress()'s own docblock) - a
      // no-op if there's genuinely nothing in progress, or if this screen
      // already knows about one from earlier in the same session.
      ref.read(tvTimeImportProvider.notifier).resumeIfInProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tvTimeImportProvider);
    // same live-polled count as the Perfil tab's badge and its "Sèries i
    // pel·lícules pendents de resoldre" row (see AppShell's own docblock) -
    // not pendingResolutionProvider, which only reloads on specific
    // triggers and used to drift out of sync with the other two while an
    // import kept adding new pending titles in the background
    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTvTimeTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // hidden while the import is actively processing (this same
                // import can keep adding to pendingCount as it runs, so the
                // banner would just be showing a moving target right next to
                // the progress card below it) and once it's done (_DoneView
                // already has its own "Resol X pendents" button for exactly
                // this, no need to say it twice on the same screen); still
                // shown in every other phase (see _PendingMoviesBanner's own
                // docblock on why it's not just a post-import thing)
                if (pendingCount > 0 &&
                    state.phase != TvTimeImportPhase.processing &&
                    state.phase != TvTimeImportPhase.done) ...[
                  _PendingMoviesBanner(count: pendingCount, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                ],
                switch (state.phase) {
                  TvTimeImportPhase.idle => _IdleView(l10n: l10n),
                  TvTimeImportPhase.selected => _SelectedView(
                    l10n: l10n,
                    fileName: state.fileName ?? '',
                    fileSize: state.fileSize ?? 0,
                  ),
                  TvTimeImportPhase.uploading => _UploadingView(l10n: l10n),
                  TvTimeImportPhase.processing => _ProcessingView(
                    l10n: l10n,
                    summary: state.summary,
                  ),
                  TvTimeImportPhase.done => _DoneView(
                    l10n: l10n,
                    summary: state.summary,
                  ),
                  TvTimeImportPhase.failed => _FailedView(l10n: l10n),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above everything else on this screen (regardless of the current
/// import's own phase) whenever there are series/movie titles still waiting
/// to be resolved by hand - see Api\Model\SeriesImportPending/
/// MovieImportPending. Surfaces this proactively rather than only right
/// after a fresh import finishes, since the user may come back to this
/// screen later (e.g. after a page refresh, which loses
/// tvtime_import_provider's own in-memory phase) with no other way to
/// remember there was unfinished business.
class _PendingMoviesBanner extends StatelessWidget {
  const _PendingMoviesBanner({required this.count, required this.l10n});

  final int count;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.coral),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      // stacked rather than side by side - both the label and the CTA are
      // long enough in practice (a 4-line label, a "Resol NNN elements
      // pendents" button) that cramming them into one Row's two columns
      // left them fighting for width and looking uneven; full-width top
      // and bottom instead gives both the same width to work with
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.extension, color: AppColors.coral, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.pendingMoviesRow,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/import/pending'),
              child: Text(l10n.moviesPendingCta(count)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.importTvTimeIntro,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: dividerColor,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: dividerColor),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.file_download,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.dropzoneTitle,
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.dropzoneSub,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () =>
                    ref.read(tvTimeImportProvider.notifier).pickFile(),
                child: Text(l10n.chooseFile),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedView extends ConsumerWidget {
  const _SelectedView({
    required this.l10n,
    required this.fileName,
    required this.fileSize,
  });

  final AppLocalizations l10n;
  final String fileName;
  final int fileSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.folder_zip,
                  size: 18,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatBytes(fileSize),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Symbols.close, size: 18),
                onPressed: () =>
                    ref.read(tvTimeImportProvider.notifier).clearFile(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () =>
              ref.read(tvTimeImportProvider.notifier).startImport(),
          child: Text(l10n.startImport),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadingView extends StatelessWidget {
  const _UploadingView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _ProgressCard(
      title: l10n.uploadingFile,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.l10n, required this.summary});

  final AppLocalizations l10n;
  final TvTimeImportSummary? summary;

  @override
  Widget build(BuildContext context) {
    // A real fraction, not a fake/estimated one - the backend re-parses the
    // export on every batch, so shows_total/movies_total are known from the
    // very first response (see TvTimeImportSummary's own docblock). Capped
    // just under 1.0 while still processing: the last stretch (lists, then
    // whatever's left of movies) can otherwise make the bar sit at a
    // seemingly-finished 100% for a while before the phase actually flips
    // to done.
    final total = (summary?.showsTotal ?? 0) + (summary?.moviesTotal ?? 0);
    final done =
        (summary?.showsSynced ?? 0) +
        (summary?.showsFailed ?? 0) +
        (summary?.moviesSynced ?? 0);
    final progress = total > 0 ? (done / total).clamp(0.0, 0.98) : null;

    return _ProgressCard(
      title: l10n.processingTitle,
      subtitle: l10n.processingSub,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: progress)),
                if (progress != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: (summary?.showsTotal ?? 0) > 0
                      ? '${summary?.showsSynced ?? 0}/${summary?.showsTotal}'
                      : '${summary?.showsSynced ?? 0}',
                  label: l10n.showsStatLabel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  value: '${summary?.episodesWatched ?? 0}',
                  label: l10n.episodesWatchedStatLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${summary?.moviesSynced ?? 0}',
                  label: l10n.moviesImportedStatLabel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  value: '${summary?.listsCreated ?? 0}',
                  label: l10n.listsCreatedStatLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.access_time,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.importBackgroundNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneView extends ConsumerWidget {
  const _DoneView({required this.l10n, required this.summary});

  final AppLocalizations l10n;
  final TvTimeImportSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = summary?.showsFailed ?? 0;
    final pendingCount = (summary?.moviesPending ?? 0) + (summary?.showsPending ?? 0);
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.sage,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Symbols.check, color: AppColors.onSageLight),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.importDoneTitle,
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(l10n.importDoneSub, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: '${summary?.showsSynced ?? 0}',
                label: l10n.showsImportedStatLabel,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Stat(
                value: '${summary?.episodesWatched ?? 0}',
                label: l10n.episodesWatchedStatLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: '${summary?.moviesSynced ?? 0}',
                label: l10n.moviesImportedStatLabel,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Stat(
                value: '${summary?.listsCreated ?? 0}',
                label: l10n.listsCreatedStatLabel,
              ),
            ),
          ],
        ),
        if (pendingCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/import/pending'),
              child: Text(l10n.moviesPendingCta(pendingCount)),
            ),
          ),
        ],
        if (failed > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.info, size: 14, color: AppColors.coral),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.showsFailedWarning(failed),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          // TextButton, not OutlinedButton - matches this app's own
          // established secondary/dismiss-action style (e.g. every dialog's
          // "Cancel·la"), rather than Material's default gray-outline look,
          // which isn't part of this app's palette anywhere else
          child: TextButton(
            onPressed: () {
              ref.read(tvTimeImportProvider.notifier).reset();
              context.pop();
            },
            child: Text(l10n.done),
          ),
        ),
      ],
    );
  }
}

class _FailedView extends ConsumerWidget {
  const _FailedView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.coral,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Symbols.close, color: AppColors.onCoralLight),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.importFailedTitle,
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.importFailedSub,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => ref.read(tvTimeImportProvider.notifier).reset(),
            child: Text(l10n.retry),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
