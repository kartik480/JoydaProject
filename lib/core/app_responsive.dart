import 'package:flutter/material.dart';

/// Design reference: 360 logical px width (typical phone).
const double _designWidth = 360.0;
const double _designHeight = 760.0;

/// Screen-responsive helpers so layout and text scale consistently across devices.
class AppResponsive {
  AppResponsive._();

  /// Scale factor from design width (1.0 at 360px, >1 on wider screens).
  static double widthScale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w / _designWidth).clamp(0.85, 1.35);
  }

  /// Scale factor from design height.
  static double heightScale(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h / _designHeight).clamp(0.85, 1.25);
  }

  /// Scaled horizontal padding (use for screen edges).
  static double horizontalPadding(BuildContext context) {
    return 20.0 * widthScale(context);
  }

  /// Scaled value: use for font sizes or spacing (e.g. 16 -> scaled 16 on 360, ~18 on 400).
  static double scale(BuildContext context, double value) {
    return value * widthScale(context);
  }

  /// Text scaler that respects device accessibility but clamps so our font sizes stay in range.
  static TextScaler textScaler(BuildContext context) {
    final mq = MediaQuery.textScalerOf(context);
    final scale = mq.scale(1.0);
    final clamped = scale.clamp(0.9, 1.3);
    return TextScaler.linear(clamped);
  }

  /// Whether the screen is considered compact (phone).
  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600;
  }
}
