import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await ref
        .read(authProvider.notifier)
        .logIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || !success) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logIn)),
      body: CenteredForm(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.email),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: l10n.password),
            obscureText: true,
          ),
          if (authState.errorKey != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              authState.errorKey == 'unknown_error'
                  ? l10n.genericError
                  : authState.errorKey!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: authState.isLoading ? null : _submit,
            child: authState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.logIn),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.push('/register'),
            child: Text(l10n.noAccountRegister),
          ),
          TextButton(
            onPressed: () => context.push('/forgot-password'),
            child: Text(l10n.forgotPassword),
          ),
        ],
      ),
    );
  }
}
