import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';

class CenteredForm extends StatelessWidget {
  const CenteredForm({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxFormWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}
