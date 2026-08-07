import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.fill = 0,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: color, fill: fill),
        ),
      ),
    );
  }
}
