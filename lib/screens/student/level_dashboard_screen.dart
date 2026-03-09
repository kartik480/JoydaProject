import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'float_sink_game_screen.dart';

class LevelDashboardScreen extends StatefulWidget {
  final Grade grade;

  const LevelDashboardScreen({super.key, required this.grade});

  @override
  State<LevelDashboardScreen> createState() => _LevelDashboardScreenState();
}

class _LevelDashboardScreenState extends State<LevelDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildLevelDashboard(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A7BD5),
            Color(0xFF4A90E2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.25),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.grade.label} Level Dashboard',
                  style: AppTypography.screenTitle(fontSize: 20, color: Colors.white),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a level to start',
                  style: AppTypography.body(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDashboard(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundMain,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Levels',
              style: AppTypography.screenTitle(fontSize: 20, color: AppColors.studentHeaderNav),
            ),
            const SizedBox(height: 20),
            _buildLevelButton(context, level: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, {required int level}) {
    return Material(
      color: AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          if (level == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FloatSinkGameScreen(),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: AppTypography.screenTitle(
                      fontSize: 28,
                      color: const Color(0xFF64B5F6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: AppTypography.cardTitle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to start',
                      style: AppTypography.body(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.bodyText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
