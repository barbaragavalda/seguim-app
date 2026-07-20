import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: Center(
        child: isLoggedIn
            ? const Text('Encara no hi ha res a la teva watchlist')
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Inicia sessió per veure la teva watchlist',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Inicia sessió'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
