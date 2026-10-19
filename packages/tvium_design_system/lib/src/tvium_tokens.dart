import 'package:flutter/material.dart';

abstract final class TviumColors {
  static const Color canvasDark = Color(0xFF071320);
  static const Color canvasDarkSecondary = Color(0xFF0A1A2A);
  static const Color surfaceDark = Color(0xFF102338);
  static const Color raisedDark = Color(0xFF162C44);
  static const Color textDark = Color(0xFFF3F7FF);
  static const Color mutedDark = Color(0xFFA9B7C8);
  static const Color accentDark = Color(0xFF24D9FF);
  static const Color accentDeep = Color(0xFF00B7FF);
  static const Color amber = Color(0xFFFFCA5A);
  static const Color live = Color(0xFFFF4E68);
  static const Color canvasLight = Color(0xFFF6F7F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color raisedLight = Color(0xFFECEFF2);
  static const Color textLight = Color(0xFF13161A);
  static const Color mutedLight = Color(0xFF5B6572);
  static const Color accentLight = Color(0xFF087F73);
  static const Color error = live;
}

abstract final class TviumSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class TviumRadius {
  static const double control = 8;
  static const double card = 12;
  static const double surface = 16;
  static const double hero = 24;
  static const double pill = 999;
}
