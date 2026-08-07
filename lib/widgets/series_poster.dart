import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import 'placeholder_mark.dart';
import 'watch_progress_bar.dart';

class SeriesPoster extends StatelessWidget {
  const SeriesPoster({super.key, this.imageUrl, this.watchProgress});

  final String? imageUrl;

  /// 0.0-1.0, or null to show no progress bar at all.
  final double? watchProgress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl == null
                ? const PlaceholderMark()
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const PlaceholderMark(),
                    errorWidget: (context, url, error) => const PlaceholderMark(),
                  ),
            if (watchProgress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: WatchProgressBar(progress: watchProgress!),
              ),
          ],
        ),
      ),
    );
  }
}
