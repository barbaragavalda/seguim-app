import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import 'placeholder_mark.dart';

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
            ? const PlaceholderMark()
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const PlaceholderMark(),
                errorWidget: (context, url, error) => const PlaceholderMark(),
              ),
      ),
    );
  }
}
