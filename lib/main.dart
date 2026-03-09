import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/app_colors.dart';
import 'core/app_responsive.dart';
import 'core/app_state.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Use only bundled fonts so Baloo 2 & Nunito look the same on all devices
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.backgroundMain,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const JoydaApp());
}

class JoydaApp extends StatelessWidget {
  const JoydaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'JoyDa',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: AppResponsive.textScaler(context),
            ),
            child: child!,
          );
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            brightness: Brightness.light,
            primary: AppColors.primaryBlue,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.backgroundMain,
          textTheme: TextTheme(
            headlineLarge: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.heading),
            headlineMedium: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.heading),
            titleLarge: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.heading),
            titleMedium: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.heading),
            bodyLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.bodyText),
            bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.bodyText),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
        },
      ),
    );
  }
}
