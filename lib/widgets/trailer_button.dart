import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/movie_detail/data/movie_detail.dart' show MovieTrailer;
import '../l10n/generated/app_localizations.dart';

class TrailerButton extends StatelessWidget {
  const TrailerButton({super.key, required this.trailer, required this.l10n});

  final MovieTrailer trailer;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(trailer.url),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Symbols.play_circle),
        label: Text(l10n.watchTrailerAction),
      ),
    );
  }
}
