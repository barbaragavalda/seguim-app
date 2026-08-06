import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// "Add Seguim! to your home screen from Chrome" tutorial - web-only
/// (native builds are already "installed" by definition), shown after
/// every login (see AppShell's own `ref.listen` on `authProvider`, the
/// same spot every other "just logged in" side effect in this app lives).
class InstallHintDialog {
  InstallHintDialog._();

  static Future<void> maybeShow(BuildContext context) async {
    if (!kIsWeb) return;
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // a lighter, fully opaque tint of sage - not a transparent sage
        // (which would show the dialog's own dim scrim bleeding through)
        backgroundColor: Color.lerp(AppColors.sage, Colors.white, 0.7),
        icon: const Icon(Symbols.install_mobile, color: AppColors.coral),
        title: Text(
          l10n.installHintTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSageLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Step(number: 1, text: l10n.installHintStep1),
            const SizedBox(height: AppSpacing.sm),
            _Step(number: 2, text: l10n.installHintStep2),
            const SizedBox(height: AppSpacing.sm),
            _Step(number: 3, text: l10n.installHintStep3),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.installHintDismiss),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.coral,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.onSageLight),
          ),
        ),
      ],
    );
  }
}
