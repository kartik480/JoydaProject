import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'alphabet_color_pop_game_screen.dart';
import 'count_objects_game_screen.dart';
import 'float_sink_game_screen.dart';
import 'sentence_builder_game_screen.dart';

/// LKG / UKG: choose a game card before opening the full game.
class LkgGameCardsScreen extends StatelessWidget {
  final Grade grade;

  const LkgGameCardsScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildBody(context),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game Cards',
                  style: AppTypography.screenTitle(fontSize: 20, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${grade.label} · Tap a card to play',
                  style: AppTypography.body(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GameCardTile(
            title: 'Float and Sink',
            subtitle: 'Science · Tap to start',
            iconBg: const Color(0xFFE3F2FD),
            icon: Icons.water_rounded,
            iconColor: const Color(0xFF42A5F5),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const FloatSinkGameScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _GameCardTile(
            title: 'Count the Objects',
            subtitle: 'Math · Counting & numbers',
            iconBg: const Color(0xFFE8F5E9),
            icon: Icons.filter_9_plus_rounded,
            iconColor: AppColors.freshGreen,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const CountObjectsGameScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _GameCardTile(
            title: 'Alphabet with Color Pop',
            subtitle: 'Letters & colors · Listen & tap',
            iconBg: const Color(0xFFF3E5F5),
            icon: Icons.bubble_chart_rounded,
            iconColor: const Color(0xFFAB47BC),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => AlphabetColorPopGameScreen(grade: grade),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _GameCardTile(
            title: 'Sentence Builder',
            subtitle: 'English · Drag words into order',
            iconBg: const Color(0xFFE8F5E9),
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.freshGreen,
            onTap: () {
              final gameId = grade == Grade.ukg ? 'ukg5' : 'lkg5';
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SentenceBuilderGameScreen(
                    grade: grade,
                    gameId: gameId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GameCardTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _GameCardTile({
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTypography.body(fontSize: 14)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.bodyText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
