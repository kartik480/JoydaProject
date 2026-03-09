import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// JoyDa logo graphic — uses images/logo.png (unchanged).
class JoydaLogo extends StatelessWidget {
  const JoydaLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _LogoPlaceholder(size: size);
        },
      ),
    );
  }
}

/// Visible fallback when logo.png is missing or fails to load (e.g. on splash).
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B00), Color(0xFFFFD000)],
        ),
      ),
      child: Icon(Icons.casino_rounded, size: size * 0.5, color: Colors.white),
    );
  }
}

/// JoyDa wordmark only — brand doc: Baloo font, gradient #FF6B00 → #FFD000 (light bg) or white (dark bg).
class JoydaWordmark extends StatelessWidget {
  const JoydaWordmark({
    super.key,
    this.fontSize = 28,
    this.lightBackground = true,
  });

  final double fontSize;
  final bool lightBackground;

  static const Color _gradientStart = Color(0xFFFF6B00);
  static const Color _gradientEnd = Color(0xFFFFD000);

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.5,
    );

    if (lightBackground) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, _gradientEnd],
        ).createShader(bounds),
        child: Text('JoyDa', style: style.copyWith(color: Colors.white)),
      );
    }
    return Text(
      'JoyDa',
      style: style.copyWith(color: Colors.white),
    );
  }
}
