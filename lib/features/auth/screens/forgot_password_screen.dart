import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/centered_form.dart';
import '../data/auth_api.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = AuthApi();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _errorKey;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isLoading = true;
      _errorKey = null;
    });
    try {
      await _api.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorKey = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorKey = 'unknown_error';
      });
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorKey = null;
    });
    try {
      await _api.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordResetSuccess)));
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorKey = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorKey = 'unknown_error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: CenteredForm(
        children: [
          Text(
            _codeSent ? l10n.resetCodeSentPrompt : l10n.forgotPasswordPrompt,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.email),
            keyboardType: TextInputType.emailAddress,
            enabled: !_codeSent,
          ),
          if (_codeSent) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(labelText: l10n.resetCode),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.newPassword),
              obscureText: true,
            ),
          ],
          if (_errorKey != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorKey == 'unknown_error' ? l10n.genericError : _errorKey!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isLoading
                ? null
                : (_codeSent ? _resetPassword : _sendCode),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_codeSent ? l10n.resetPasswordSubmit : l10n.sendResetCode),
          ),
        ],
      ),
    );
  }
}
