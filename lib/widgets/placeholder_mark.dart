import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class PlaceholderMark extends StatelessWidget {
  const PlaceholderMark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.placeholderBackground,
      child: Center(
        child: Text(
          'S!',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
