import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A thin bar, as wide as its parent, showing what fraction of a series'
/// episodes have been watched - coral while in progress, sage once it
/// reaches 100% (matches the sage "watched" mark used elsewhere). Meant to
/// sit at the bottom of a poster/backdrop via a Positioned in the same
/// Stack.
class WatchProgressBar extends StatelessWidget {
  const WatchProgressBar({super.key, required this.progress});

  final double progress;

  static const double height = 5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black.withValues(alpha: 0.35)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              color: progress >= 1.0 ? AppColors.sage : AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
