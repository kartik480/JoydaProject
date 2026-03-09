import 'package:flutter/material.dart';
import '../core/app_typography.dart';
import '../widgets/joyda_logo.dart';
import '../widgets/loading_dots.dart';
import 'welcome_screen.dart';

const _fullLogoAsset = 'images/fulllogo.png';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 seconds then navigate
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A7BD5),
            Color(0xFF4A90E2),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                _fullLogoAsset,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JoydaLogo(size: 56),
                      SizedBox(height: 12),
                      JoydaWordmark(fontSize: 22, lightBackground: false),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"Learn through fun games"',
              style: AppTypography.body(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(flex: 3),
            const LoadingDots(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
    return Scaffold(body: body);
  }
}
