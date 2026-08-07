import 'package:flutter/material.dart';

import '../features/lists/data/user_list.dart' show ListPreviewItem;
import '../theme/app_spacing.dart';
import 'series_poster.dart';

/// A static (non-draggable, non-tappable) preview strip. Always lays out
/// [maxSlots] equal-width slots, filling missing ones with an invisible
/// spacer, so a poster's width stays a fixed fraction of the row instead of
/// resizing to fill whatever's missing.
class PosterPreviewRow extends StatelessWidget {
  const PosterPreviewRow({super.key, required this.items, this.maxSlots = 5});

  final List<ListPreviewItem> items;
  final int maxSlots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < maxSlots; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: i < items.length
                ? SeriesPoster(imageUrl: items[i].imageUrl)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
