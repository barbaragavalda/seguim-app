import 'package:flutter/material.dart';

/// The app's entire color system - 3 brand colors, white (two tones, for
/// contrast against each other), and 2 grays (one per direction: readable
/// on light backgrounds, readable on dark backgrounds). Everything else
/// (dividers, placeholders, "text on X") is derived from these via opacity
/// or reused directly - never a new named hex value.
///
/// Text-on-brand-color contrast, checked against WCAG (relative luminance
/// formula) rather than assumed:
/// - navy on coral: 6.02:1 (AA requires 4.5:1)
/// - navy on sage: 7.24:1 (clears AAA's 7:1)
/// - white on navy: 13.04:1
/// - grayLight on navy / navyLight: 6.58:1 / 5.70:1
/// navy alone clears every brand-color background comfortably, so there's
/// no need for separate per-color "on-coral"/"on-sage" text tones.
class AppColors {
  AppColors._();

  // the 3 corporate colors
  static const coral = Color(0xFFF19372);
  static const sage = Color(0xFF96C5BD);
  static const navy = Color(0xFF182F41);

  // white, two tones - offWhite is the page canvas, white is a card/surface
  // sitting on top of it, kept pure so it actually reads as "raised"
  // instead of blending in
  static const offWhite = Color(0xFFF6F9F9);
  static const white = Color(0xFFFFFFFF);

  // navy's own "raised surface" counterpart for dark mode - same relationship
  // to navy as white has to offWhite, just a much smaller step (a night-mode
  // card shouldn't glow)
  static const navyLight = Color(0xFF21394D);

  // secondary/muted text - grayDark reads on light backgrounds (offWhite/
  // white), grayLight reads on dark ones (navy/navyLight). A single gray
  // can't do both: grayDark on navy only reaches 2.8:1, well under AA.
  static const grayDark = Color(0xFF5B7482);
  static const grayLight = Color(0xFF9FB7C2);
}
