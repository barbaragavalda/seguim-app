import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A thin bar, as wide as its parent, showing what fraction of a series'
/// episodes have been watched - coral while in progress, sage once it
/// reaches 100% (matches the sage "watched" mark used elsewhere, e.g. the
/// episode-watched circle on series detail's own episode rows). Meant to
/// sit at the very bottom of a poster or backdrop image via a Positioned
/// inside the same Stack.
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
