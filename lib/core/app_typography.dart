import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// JoyDa typography: Screen Title = Baloo 2 700, Card Title = Baloo 2 600, Body = Nunito 400.
class AppTypography {
  /// Screen Title — Baloo 2, weight 700 (e.g. "Select Your Grade")
  static TextStyle screenTitle({double? fontSize, Color? color}) =>
      GoogleFonts.baloo2(
        fontWeight: FontWeight.w700,
        fontSize: fontSize ?? 20,
        color: color ?? AppColors.heading,
      );

  /// Card Title — Baloo 2, weight 600 (e.g. "Number World")
  static TextStyle cardTitle({double? fontSize, Color? color}) =>
      GoogleFonts.baloo2(
        fontWeight: FontWeight.w600,
        fontSize: fontSize ?? 16,
        color: color ?? AppColors.heading,
      );

  /// Body Text — Nunito, weight 400
  static TextStyle body({double? fontSize, Color? color, double? height}) =>
      GoogleFonts.nunito(
        fontWeight: FontWeight.w400,
        fontSize: fontSize ?? 14,
        height: height,
        color: color ?? AppColors.bodyText,
      );
}
