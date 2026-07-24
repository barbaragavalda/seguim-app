import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../data/tvtime_import_api.dart';
import '../providers/tvtime_import_provider.dart';

class TvTimeImportScreen extends ConsumerWidget {
  const TvTimeImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tvTimeImportProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTvTimeTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: switch (state.phase) {
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
              TvTimeImportPhase.failed => _FailedView(
                l10n: l10n,
                errorMessage: state.errorMessage,
              ),
            },
          ),
        ),
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
                  Icons.file_download_outlined,
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
                  Icons.folder_zip_outlined,
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
                icon: const Icon(Icons.close, size: 18),
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
    return _ProgressCard(
      title: l10n.processingTitle,
      subtitle: l10n.processingSub,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${summary?.showsSynced ?? 0}',
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
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.access_time,
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
          child: const Icon(Icons.check, color: AppColors.onSageLight),
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
                const Icon(Icons.info_outline, size: 14, color: AppColors.coral),
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
          child: OutlinedButton(
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
  const _FailedView({required this.l10n, required this.errorMessage});

  final AppLocalizations l10n;
  final String? errorMessage;

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
          child: const Icon(Icons.close, color: AppColors.onCoralLight),
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
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              errorMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
