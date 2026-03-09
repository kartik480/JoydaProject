import 'package:flutter/material.dart';

/// JoyDa UI Colour Guidelines (Pilot Version)
class AppColors {
  // Primary – main buttons, highlights, active tabs
  static const Color primaryBlue = Color(0xFF4A90E2);

  // Secondary – rewards, stars, achievements, positive feedback
  static const Color warmYellow = Color(0xFFFFD54F);

  // Accent – success, completed tasks, progress
  static const Color freshGreen = Color(0xFF66BB6A);

  // Backgrounds
  static const Color backgroundMain = Color(0xFFF7F9FC);
  static const Color backgroundCard = Color(0xFFFFFFFF);

  // Text
  static const Color heading = Color(0xFF333333);
  static const Color bodyText = Color(0xFF555555);

  // Legacy aliases for compatibility
  static const Color textDark = heading;
  static const Color textLight = bodyText;
  static const Color splashGradientStart = Color(0xFF3A7BD5);
  static const Color splashGradientEnd = Color(0xFF4A90E2);
  static const Color illustrationBg = Color(0xFFEEF2F7);

  /// Student panel: header & bottom nav
  static const Color studentHeaderNav = Color(0xFF1E3A5F);

  /// Teacher panel: dark header (Ms. Priya's Class style)
  static const Color teacherHeader = Color(0xFF2C3E50);
  static const Color teacherHeaderCard = Color(0xFF3D5266);
}
