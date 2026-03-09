import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Panel with three images: fulllogo (top), joystick & book (bottom).
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key});

  static const _joystickAsset = 'images/joystick.png';
  static const _starAsset = 'images/star.png';
  static const _bookAsset = 'images/book.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.illustrationBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: star
          _PanelImage(asset: _starAsset, width: 56, height: 56),
          const SizedBox(height: 10),
          // Bottom: joystick (left), book (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PanelImage(asset: _joystickAsset, width: 56, height: 56),
              const SizedBox(width: 16),
              _PanelImage(asset: _bookAsset, width: 56, height: 56),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelImage extends StatelessWidget {
  const _PanelImage({
    required this.asset,
    this.width = 56,
    this.height = 56,
  });

  final String asset;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        asset,
        width: width - 12,
        height: height - 12,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            asset.contains('joystick')
                ? Icons.sports_esports_rounded
                : asset.contains('book')
                    ? Icons.menu_book_rounded
                    : Icons.star_rounded,
            size: 28,
            color: AppColors.bodyText,
          );
        },
      ),
    );
  }
}
