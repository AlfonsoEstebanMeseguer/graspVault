// Design 2.0 tokens besides colour (spec §5, §8): type scale, radii, spacing
// and motion. Instrument Sans is the UI, Newsreader is what the examiner says,
// Plex Mono is only for clocks (tabular digits that never dance).
import 'package:flutter/material.dart';

abstract final class AppFonts {
  static const sans = 'InstrumentSans';
  static const serif = 'Newsreader';
  static const mono = 'PlexMono';
  static const hand = 'Caveat';
}

abstract final class AppType {
  static const largeTitle = TextStyle(fontFamily: AppFonts.sans, fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.6);
  static const title1 = TextStyle(fontFamily: AppFonts.sans, fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static const title2 = TextStyle(fontFamily: AppFonts.sans, fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const headline = TextStyle(fontFamily: AppFonts.sans, fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: AppFonts.sans, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w400);
  static const footnote = TextStyle(fontFamily: AppFonts.sans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500);
  static const overline = TextStyle(fontFamily: AppFonts.sans, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, letterSpacing: 1.2);
  static const question = TextStyle(fontFamily: AppFonts.serif, fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w500);
  static const questionSmall = TextStyle(fontFamily: AppFonts.serif, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic);
  static const timer = TextStyle(fontFamily: AppFonts.mono, fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  static const timerXl = TextStyle(fontFamily: AppFonts.mono, fontSize: 56, height: 60 / 56, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  static const hand = TextStyle(fontFamily: AppFonts.hand, fontSize: 21, height: 1.1, fontWeight: FontWeight.w600);
}

abstract final class AppRadii {
  static const chip = 10.0;
  static const input = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
}

abstract final class AppSpace {
  /// Screen side margin.
  static const screen = 20.0;
}

abstract final class AppMotion {
  static const smooth = Duration(milliseconds: 280);
  static const part = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
}
