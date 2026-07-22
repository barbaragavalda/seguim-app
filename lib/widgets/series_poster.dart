import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

class SeriesPoster extends StatelessWidget {
  const SeriesPoster({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: imageUrl == null
            ? const _PlaceholderMark()
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _PlaceholderMark(),
                errorWidget: (context, url, error) => const _PlaceholderMark(),
              ),
      ),
    );
  }
}

class _PlaceholderMark extends StatelessWidget {
  const _PlaceholderMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'S!',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
