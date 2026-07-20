import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_spacing.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea un compte')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Nom')),
            const SizedBox(height: AppSpacing.sm),
            const TextField(
              decoration: InputDecoration(labelText: 'Correu electrònic'),
            ),
            const SizedBox(height: AppSpacing.sm),
            const TextField(
              decoration: InputDecoration(labelText: 'Contrasenya'),
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
              child: const Text('Crea el compte'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Ja tens compte? Inicia sessió'),
            ),
          ],
        ),
      ),
    );
  }
}
