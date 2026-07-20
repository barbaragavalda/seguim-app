import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccount)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(decoration: InputDecoration(labelText: l10n.name)),
            const SizedBox(height: AppSpacing.sm),
            TextField(decoration: InputDecoration(labelText: l10n.email)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              decoration: InputDecoration(labelText: l10n.password),
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                ref.read(authProvider.notifier).logIn();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
                }
              },
              child: Text(l10n.registerSubmit),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.haveAccountLogin),
            ),
          ],
        ),
      ),
    );
  }
}
