import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/account_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as SeriesDetailScreen/
    // WatchlistScreen's initState
    Future.microtask(() => ref.read(accountProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(accountProvider.notifier).load();
      }
    });

    if (!isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: CenteredForm(
            children: [
              Text(l10n.profileLoginPrompt, textAlign: TextAlign.center),
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
      );
    }

    final account = ref.watch(accountProvider);

    if (account.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            _WelcomeSection(
              username: account.username ?? '',
              email: account.email ?? '',
            ),
            _AccountSection(account: account),
            const _SeriesSection(),
            const _FooterSection(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.username, required this.email});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.7, -1.4),
          radius: 1.6,
          colors: [
            AppColors.coral.withValues(alpha: 0.24),
            AppColors.coral.withValues(alpha: 0),
          ],
        ),
      ),
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
                color: AppColors.onCoralLight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.welcomeGreeting(username),
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w900, fontSize: 23),
          ),
          const SizedBox(height: 3),
          Text(email, style: Theme.of(context).textTheme.bodySmall),
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
            icon: Icons.edit_outlined,
            label: l10n.username,
            value: account.username ?? '',
            onTap: () => _editUsername(context, ref),
          ),
          _AccountRow(
            icon: Icons.mail_outline,
            label: l10n.email,
            value: account.email ?? '',
            onTap: () => _editEmail(context, ref),
          ),
          _AccountRow(
            icon: Icons.lock_outline,
            label: l10n.password,
            value: l10n.changePasswordValue,
            onTap: () => _changePassword(context, ref),
          ),
        ],
      ),
    );
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

  Future<void> _editEmail(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await _showEditFieldDialog(
      context: context,
      title: l10n.editEmailTitle,
      label: l10n.email,
      initialValue: account.email ?? '',
      keyboardType: TextInputType.emailAddress,
      onSave: (value) => ref.read(accountProvider.notifier).updateEmail(value),
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
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.currentPasswordLabel,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.newPasswordLabel,
                    errorText: errorText,
                  ),
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

class _SeriesSection extends StatelessWidget {
  const _SeriesSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Section(
      title: l10n.seriesSectionTitle,
      tag: l10n.comingSoonTag,
      child: _Card(
        children: [
          _ComingSoonRow(icon: Icons.list_alt, label: l10n.seriesListsRow),
          _ComingSoonRow(
            icon: Icons.archive_outlined,
            label: l10n.archivedSeriesRow,
          ),
          _ComingSoonRow(
            icon: Icons.pause_circle_outlined,
            label: l10n.droppedSeriesRow,
          ),
        ],
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
            icon: Icons.delete_sweep_outlined,
            label: l10n.clearImageCache,
            onTap: () => _clearImageCache(context, l10n),
          ),
          if (kIsWeb)
            _PlainActionRow(
              icon: Icons.file_upload_outlined,
              label: l10n.importFromTvTime,
              onTap: () => context.push('/import/tvtime'),
            ),
          _PlainActionRow(
            icon: Icons.logout,
            label: l10n.logOut,
            onTap: () => ref.read(authProvider.notifier).logOut(),
          ),
          _PlainActionRow(
            icon: Icons.warning_amber_outlined,
            label: l10n.deleteAccountRow,
            color: AppColors.coral,
            onTap: () => _deleteAccount(context, ref, l10n),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '';
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  l10n.versionLabel(version),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.tag});

  final String title;
  final String? tag;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                      color: AppColors.onSageLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
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
  });

  final IconData icon;
  final String label;
  final String value;
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
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          _RowIcon(icon: icon, dimmed: true),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: textSecondary),
        ],
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

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, this.dimmed = false});

  final IconData icon;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Icon(
          icon,
          size: 16,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
