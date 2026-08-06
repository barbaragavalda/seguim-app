import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../../../widgets/password_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_button/google_sign_in_button.dart';

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
    _afterLogin();
  }

  Future<void> _handleGoogleIdToken(String idToken) async {
    final success = await ref
        .read(authProvider.notifier)
        .logInWithGoogle(idToken);
    if (!mounted || !success) return;
    _afterLogin();
  }

  void _handleGoogleError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
  }

  void _afterLogin() {
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
          GoogleSignInButton(
            label: l10n.continueWithGoogle,
            onIdToken: _handleGoogleIdToken,
            onError: _handleGoogleError,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  l10n.orDividerLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.email),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordField(
            controller: _passwordController,
            labelText: l10n.password,
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
