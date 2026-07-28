import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../../auth/providers/auth_provider.dart';

/// Custom user-curated series lists - the backend (Api\Model\UserList/
/// UserListSerie) exists but isn't exposed over HTTP yet, so this is a
/// placeholder shell: the login gate and the tab itself are real, the
/// actual list data isn't wired up until those endpoints land.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.listsComingSoonMessage,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
