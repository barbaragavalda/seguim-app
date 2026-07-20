import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: isLoggedIn
            ? FilledButton(
                onPressed: () => ref.read(authProvider.notifier).logOut(),
                child: const Text('Tanca sessió'),
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Inicia sessió per veure el teu perfil',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Inicia sessió'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text("Crea un compte"),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
