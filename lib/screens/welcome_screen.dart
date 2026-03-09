import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../core/app_typography.dart';
import '../widgets/onboarding_illustration.dart';
import 'auth/enter_email_mobile_screen.dart';

/// Welcome Screen: fulllogo.png only in top panel, then icons panel, Login & Sign Up.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _fullLogoAsset = 'images/fulllogo.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPadding = (constraints.maxHeight * 0.08).clamp(40.0, 80.0);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: topPadding),
                    Image.asset(
                      _fullLogoAsset,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(height: 80);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"Learn through fun games"',
                      style: AppTypography.body(fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    const OnboardingIllustration(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppResponsive.horizontalPadding(context)),
                      child: Text(
                        'Interactive games designed for curious young minds ✨',
                        textAlign: TextAlign.center,
                        style: AppTypography.body(fontSize: 15, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Login & Sign Up panel
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppResponsive.horizontalPadding(context)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: () => _goToAuth(context, isEmail: true),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 2,
                                shadowColor: Colors.black26,
                              ),
                              child: Text(
                                'Login',
                                style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => _goToAuth(context, isEmail: false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryBlue,
                                side: const BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 1,
                                shadowColor: Colors.black12,
                              ),
                              child: Text(
                                'Sign Up',
                                style: AppTypography.cardTitle(fontSize: 16).copyWith(color: AppColors.primaryBlue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: topPadding),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _goToAuth(BuildContext context, {required bool isEmail}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnterEmailMobileScreen(initialModeEmail: isEmail),
      ),
    );
  }
}
