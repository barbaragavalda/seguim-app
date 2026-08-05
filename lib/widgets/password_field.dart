import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A password TextField with a show/hide toggle. Flutter has no built-in
/// obscureText toggle, so this is the standard Material pattern
/// (InputDecoration.suffixIcon + local state) - factored out once here
/// instead of repeating it at every password field in the app.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          tooltip: _obscureText ? l10n.showPassword : l10n.hidePassword,
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}
