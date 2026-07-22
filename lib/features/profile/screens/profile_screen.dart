import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _clearImageCache(BuildContext context, AppLocalizations l10n) async {
    await DefaultCacheManager().emptyCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.imageCacheCleared)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isLoggedIn
                  ? FilledButton(
                      onPressed: () => ref.read(authProvider.notifier).logOut(),
                      child: Text(l10n.logOut),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.clearImageCache),
            onTap: () => _clearImageCache(context, l10n),
          ),
        ],
      ),
    );
  }
}
