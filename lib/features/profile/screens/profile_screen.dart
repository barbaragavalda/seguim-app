import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/app_intro.dart';
import '../../../widgets/centered_form.dart';
import '../../../widgets/password_field.dart';
import '../../../widgets/poster_preview_row.dart';
import '../../../widgets/status_tag.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_summary_provider.dart';
import '../../import/providers/pending_count_provider.dart';
import '../../import/providers/tvtime_import_provider.dart';
import '../../lists/data/user_list.dart' show ListPreviewItem;
import '../data/account_api.dart';
import '../data/profile_quotes.dart';
import '../providers/account_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // once per State instance, not per build, so it doesn't reshuffle on every
  // rebuild; every language's list must stay the same length for this index
  late final int _quoteIndex = Random().nextInt(
    profileQuotesByLanguage['en']!.length,
  );

  @override
  void initState() {
    super.initState();
    // pendingCountProvider isn't loaded here - AppShell keeps it fresh
    // for the app's whole lifetime, not just while this screen is visible
    Future.microtask(() {
      ref.read(accountProvider.notifier).load();
      ref.read(favoritesSummaryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    // catches the case where authProvider's token restore (async, from
    // secure storage) finishes after initState()'s microtask already ran
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(accountProvider.notifier).load();
        ref.read(favoritesSummaryProvider.notifier).load();
      }
    });

    if (!isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CenteredForm(
                  children: [
                    const AppIntro(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.profileLoginPrompt,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: Text(l10n.logIn),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(l10n.createAccount),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: _AttributionFooter(),
              ),
            ],
          ),
        ),
      );
    }

    final account = ref.watch(accountProvider);

    if (account.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final quotes =
        profileQuotesByLanguage[languageCode] ?? profileQuotesByLanguage['en']!;
    final quote = quotes[_quoteIndex % quotes.length];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            _WelcomeSection(
              username: account.username ?? '',
              email: account.email ?? '',
              quote: quote,
            ),
            if (account.stats != null) _StatsSection(stats: account.stats!),
            _AccountSection(account: account),
            const _FollowingSection(),
            const _ImportSection(),
            const _FooterSection(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({
    required this.username,
    required this.email,
    required this.quote,
  });

  final String username;
  final String email;
  final ProfileQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Stack(
      children: [
        // forces the gradient to fade to alpha 0 by the box's bottom edge,
        // since RadialGradient's own falloff just gets clipped there
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0.5, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: DecoratedBox(
              // same gradient as the app icon's "S!" wordmark, at low alpha
              // so it reads as a background wash, not a logo fill
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.sage.withValues(alpha: 0.22),
                    AppColors.coral.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeGreeting(username),
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${quote.text}"',
                  style: GoogleFonts.fraunces(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '— ${quote.source}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.coral.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Same visual language as _StatsRow elsewhere, but a 2x2 grid since 4
/// stats in one row got cramped.
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final AccountStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dividerColor = Theme.of(context).dividerColor;

    return _Section(
      title: l10n.statsSectionTitle,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: dividerColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  _statTile(context, stats.episodesWatched, l10n.statEpisodesWatched),
                  _divider(dividerColor),
                  _statTile(context, stats.seriesAdded, l10n.statSeriesAdded),
                ],
              ),
            ),
            Container(height: 1, color: dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  _statTile(context, stats.moviesWatched, l10n.statMoviesWatched),
                  _divider(dividerColor),
                  _statTile(context, stats.moviesAdded, l10n.statMoviesAdded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Container(width: 1, height: 32, color: color);
  }

  Widget _statTile(BuildContext context, int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.account});

  final AccountState account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return _Section(
      title: l10n.accountSectionTitle,
      child: _Card(
        children: [
          _AccountRow(
            icon: Symbols.badge,
            label: l10n.username,
            value: account.username ?? '',
            onTap: () => _editUsername(context, ref),
          ),
          _AccountRow(
            icon: Symbols.mail_outline,
            label: l10n.email,
            value: account.email ?? '',
            onTap: () => _editEmail(context, ref),
          ),
          _AccountRow(
            icon: Symbols.lock_outline,
            label: l10n.password,
            value: l10n.changePasswordValue,
            onTap: () => _changePassword(context, ref),
          ),
          _AccountRow(
            icon: Symbols.language,
            label: l10n.languageRow,
            value:
                languageNativeNames[Localizations.localeOf(context)
                    .languageCode] ??
                '',
            onTap: () => _changeLanguage(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final current = Localizations.localeOf(context).languageCode;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.changeLanguageTitle),
        children: [
          for (final culture in supportedLanguageCultures)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(culture),
              child: Row(
                children: [
                  Expanded(
                    child: Text(languageNativeNames[culture] ?? culture),
                  ),
                  if (culture == current)
                    const Icon(Symbols.check, size: 18, color: AppColors.coral),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;

    await ref.read(localeProvider.notifier).setLocale(selected);
    if (ref.read(authProvider).isLoggedIn) {
      await ref.read(accountProvider.notifier).updateLanguage(selected);
    }
  }

  Future<void> _editUsername(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await _showEditFieldDialog(
      context: context,
      title: l10n.editUsernameTitle,
      label: l10n.username,
      initialValue: account.username ?? '',
      onSave: (value) =>
          ref.read(accountProvider.notifier).updateUsername(value),
    );
  }

  /// Two steps: request the change, then confirm with the code sent to the
  /// new address.
  Future<void> _editEmail(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final emailController = TextEditingController(text: account.email ?? '');
    final codeController = TextEditingController();
    var codeSent = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.editEmailTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (codeSent) ...[
                  Text(
                    l10n.emailChangeCodeSentPrompt,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !codeSent,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    errorText: !codeSent ? errorText : null,
                  ),
                ),
                if (codeSent) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: l10n.resetCode,
                      errorText: errorText,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (!codeSent) {
                    final error = await ref
                        .read(accountProvider.notifier)
                        .requestEmailChange(emailController.text.trim());
                    if (error == null) {
                      setState(() {
                        codeSent = true;
                        errorText = null;
                      });
                    } else {
                      setState(() {
                        errorText = error == 'unknown_error'
                            ? l10n.genericError
                            : error;
                      });
                    }
                  } else {
                    final error = await ref
                        .read(accountProvider.notifier)
                        .confirmEmailChange(codeController.text.trim());
                    if (error == null) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.emailChanged)),
                        );
                      }
                    } else {
                      setState(() {
                        errorText = error == 'unknown_error'
                            ? l10n.genericError
                            : error;
                      });
                    }
                  }
                },
                child: Text(codeSent ? l10n.save : l10n.sendResetCode),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final currentController = TextEditingController();
    final newController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.changePasswordTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PasswordField(
                  controller: currentController,
                  labelText: l10n.currentPasswordLabel,
                ),
                const SizedBox(height: AppSpacing.sm),
                PasswordField(
                  controller: newController,
                  labelText: l10n.newPasswordLabel,
                  errorText: errorText,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final error = await ref
                      .read(accountProvider.notifier)
                      .changePassword(
                        currentPassword: currentController.text,
                        newPassword: newController.text,
                      );
                  if (error == null) {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passwordChanged)),
                      );
                    }
                  } else {
                    setState(() {
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

  Future<void> _showEditFieldDialog({
    required BuildContext context,
    required String title,
    required String label,
    required String initialValue,
    TextInputType? keyboardType,
    required Future<String?> Function(String value) onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(labelText: label, errorText: errorText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final error = await onSave(controller.text.trim());
                  if (error == null) {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } else {
                    setState(() {
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

class _FollowingSection extends ConsumerWidget {
  const _FollowingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favorites = ref.watch(favoritesSummaryProvider);

    return _Section(
      title: l10n.followingSectionTitle,
      child: _Card(
        children: [
          _FavoriteRow(
            label: l10n.favoriteSeriesRow,
            count: favorites.seriesCount,
            countLabel: favorites.seriesCount > 0
                ? l10n.listItemCountSummarySeriesOnly(favorites.seriesCount)
                : null,
            preview: favorites.seriesPreview,
            onTap: () => context.push('/favorites/series'),
          ),
          _FavoriteRow(
            label: l10n.favoriteMoviesRow,
            count: favorites.moviesCount,
            countLabel: favorites.moviesCount > 0
                ? l10n.listItemCountSummaryMoviesOnly(favorites.moviesCount)
                : null,
            preview: favorites.moviesPreview,
            onTap: () => context.push('/favorites/movies'),
          ),
          _ActiveRow(
            icon: Symbols.tv,
            fill: 0,
            label: l10n.mySeriesRow,
            onTap: () => context.push('/my-series'),
          ),
          _ActiveRow(
            icon: Symbols.local_activity,
            fill: 1,
            label: l10n.myMoviesRow,
            onTap: () => context.push('/my-movies'),
          ),
        ],
      ),
    );
  }
}

class _ImportSection extends ConsumerWidget {
  const _ImportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (!kIsWeb) {
      // both rows below are web-only (TV Time import is a file upload flow
      // not wired up on mobile) - no section at all if neither can show
      return const SizedBox.shrink();
    }

    // reflects this session's local provider state, not a fresh server
    // check - misses only an import left running from a since-restarted
    // session that hasn't reopened the import screen (resumeIfInProgress())
    final importPhase = ref.watch(
      tvTimeImportProvider.select((s) => s.phase),
    );
    final importing = importPhase == TvTimeImportPhase.processing;
    final importChip = switch (importPhase) {
      TvTimeImportPhase.processing => StatusTag(
        label: l10n.importInProgressChip,
        color: AppColors.coral,
      ),
      TvTimeImportPhase.done => StatusTag(
        label: l10n.importDoneChip,
        color: AppColors.sage,
      ),
      _ => null,
    };

    return _Section(
      title: l10n.importSectionTitle,
      child: _Card(
        children: [
          _AccountRow(
            icon: Symbols.folder_zip,
            label: l10n.importFromTvTime,
            value: '',
            trailing: importChip,
            onTap: () => context.push('/import/tvtime'),
          ),
          _PendingResolutionAccountRow(
            // 0 while importing - resolving is blocked, no point advertising it
            badgeCount: importing ? 0 : ref.watch(pendingCountProvider),
            importing: importing,
          ),
        ],
      ),
    );
  }
}

// disabled/greyed out while importing, matching PendingResolutionScreen's
// own refusal to show its normal content then
class _PendingResolutionAccountRow extends StatelessWidget {
  const _PendingResolutionAccountRow({
    required this.badgeCount,
    required this.importing,
  });

  final int badgeCount;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return InkWell(
      onTap: importing ? null : () => context.push('/import/pending'),
      child: Opacity(
        opacity: importing ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 13,
          ),
          child: Row(
            children: [
              _RowIcon(icon: Symbols.extension),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.pendingMoviesRow,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                _CountBadge(count: badgeCount),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(Symbols.chevron_right, size: 18, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterSection extends ConsumerWidget {
  const _FooterSection();

  Future<void> _clearImageCache(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await DefaultCacheManager().emptyCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.imageCacheCleared)));
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAccountConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref.read(accountProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlainActionRow(
            icon: Symbols.reset_image,
            label: l10n.clearImageCache,
            onTap: () => _clearImageCache(context, l10n),
          ),
          _PlainActionRow(
            icon: Symbols.exit_to_app,
            label: l10n.logOut,
            onTap: () => ref.read(authProvider.notifier).logOut(),
          ),
          _PlainActionRow(
            icon: Symbols.person_off,
            label: l10n.deleteAccountRow,
            color: AppColors.coral,
            onTap: () => _deleteAccount(context, ref, l10n),
          ),
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: _AttributionFooter(),
          ),
        ],
      ),
    );
  }
}

/// TheTVDB attribution + app version - shown regardless of login state,
/// unlike _FooterSection's other rows which need a real session.
class _AttributionFooter extends StatelessWidget {
  const _AttributionFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // the slug is translated per language server-side with no
    // reverse-routing to ask for it, so it's spelled out here; falls back
    // to 'ca' beyond the app's three supported locales
    const privacySlugs = {
      'ca': 'privacitat',
      'es': 'privacidad',
      'en': 'privacy',
    };
    final privacyLang = privacySlugs.containsKey(
      Localizations.localeOf(context).languageCode,
    )
        ? Localizations.localeOf(context).languageCode
        : 'ca';

    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(
                'https://api-seguim.cuinadeprofit.cat/$privacyLang/${privacySlugs[privacyLang]}',
              ),
            ),
            child: Text(
              l10n.privacyPolicyLink,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: GestureDetector(
            // TheTVDB's API terms require attribution linking to TheTVDB.com
            onTap: () => launchUrl(Uri.parse('https://thetvdb.com')),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  // white-text variant for dark theme; default is unreadable there
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/attribution/thetvdb_logo_dark.png'
                      : 'assets/attribution/thetvdb_logo.png',
                  height: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.theTvdbAttribution,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.versionLabel(version),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  // shown between label and chevron, independent of value
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            _RowIcon(icon: icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // an empty value shouldn't still claim half the row
            if (value.isNotEmpty)
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Icon(Symbols.chevron_right, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Pinned above the plain _ActiveRow entries; same content shape as a real
/// ListsScreen row (name, count, poster preview) but without
/// rename/reorder, since favorites aren't real UserList rows.
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.label,
    required this.count,
    required this.countLabel,
    required this.preview,
    required this.onTap,
  });

  final String label;
  final int count;
  final String? countLabel;
  final List<ListPreviewItem> preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Symbols.chevron_right, size: 18, color: textSecondary),
              ],
            ),
            if (countLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                countLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (preview.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              PosterPreviewRow(items: preview),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.icon,
    this.fill,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final double? fill;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            _RowIcon(icon: icon, fill: fill),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Symbols.chevron_right, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

class _PlainActionRow extends StatelessWidget {
  const _PlainActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: rowColor),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: rowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, this.fill});

  final IconData icon;

  /// Material Symbols fill axis; null leaves Icon.fill unset.
  final double? fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      child: Icon(
        icon,
        fill: fill,
        size: 22,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }
}
