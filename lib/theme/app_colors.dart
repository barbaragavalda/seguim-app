import 'package:flutter/material.dart';

/// WCAG contrast (relative luminance, not eyeballed): navy on coral 6.02:1,
/// navy on sage 7.24:1, white on navy 13.04:1, grayLight on navy/navyLight
/// 6.58:1/5.70:1 (all clear AA's 4.5:1) - navy alone covers every brand
/// background, so no separate per-color "on-X" text tones are needed.
class AppColors {
  AppColors._();

  static const coral = Color(0xFFF19372);
  static const sage = Color(0xFF96C5BD);
  static const navy = Color(0xFF182F41);

  // offWhite is the page canvas, white is a card/surface kept pure so it
  // reads as "raised" instead of blending in
  static const offWhite = Color(0xFFF6F9F9);
  static const white = Color(0xFFFFFFFF);

  // navy's "raised surface" counterpart for dark mode, a smaller step than
  // offWhite->white since a night-mode card shouldn't glow
  static const navyLight = Color(0xFF21394D);

  // grayDark reads on light backgrounds, grayLight on dark ones - a single
  // gray can't do both (grayDark on navy is only 2.8:1, under AA)
  static const grayDark = Color(0xFF5B7482);
  static const grayLight = Color(0xFF9FB7C2);
}
