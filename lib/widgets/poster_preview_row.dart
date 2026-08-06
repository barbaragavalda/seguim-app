import 'package:flutter/material.dart';

import '../features/lists/data/user_list.dart' show ListPreviewItem;
import '../theme/app_spacing.dart';
import 'series_poster.dart';

/// A static (non-draggable, non-tappable) strip of a handful of posters -
/// just a preview of what's inside, not another place to reorder from.
/// Used by ListsScreen's own list rows and ProfileScreen's two fixed
/// "favorites" rows. Always lays out [maxSlots] equal-width slots
/// regardless of how many posters actually came back, filling the extra
/// ones with an invisible spacer - so a poster's own width is always a
/// fixed fraction of the row (1/5 each at the full 5, 1/5 still each at
/// fewer - so 4 posters read as 80% of the row, 3 as 60%, ...), never
/// resized to fill whatever's missing.
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
