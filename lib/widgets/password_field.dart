import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/generated/app_localizations.dart';

/// A password TextField with a show/hide toggle. Flutter has no built-in
/// obscureText toggle, so this factors out the standard Material pattern
/// (suffixIcon + local state) instead of repeating it per field.
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
            _obscureText ? Symbols.visibility : Symbols.visibility_off,
          ),
          tooltip: _obscureText ? l10n.showPassword : l10n.hidePassword,
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}
