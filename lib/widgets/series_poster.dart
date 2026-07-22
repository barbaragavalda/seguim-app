import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

const _grayscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class SeriesPoster extends StatelessWidget {
  const SeriesPoster({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          color: Theme.of(context).cardColor,
          child: imageUrl == null
              ? const _PlaceholderLogo()
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _PlaceholderLogo(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _PlaceholderLogo();
                  },
                ),
        ),
      ),
    );
  }
}

class _PlaceholderLogo extends StatelessWidget {
  const _PlaceholderLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.4,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
          child: Image.asset('assets/icon/icon.png'),
        ),
      ),
    );
  }
}
