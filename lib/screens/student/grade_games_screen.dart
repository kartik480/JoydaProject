import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'game_play_screen.dart';
class GradeGamesScreen extends StatefulWidget {
  final Grade grade;

  const GradeGamesScreen({super.key, required this.grade});

  @override
  State<GradeGamesScreen> createState() => _GradeGamesScreenState();
}

class _GradeGamesScreenState extends State<GradeGamesScreen> {
  int _navIndex = 1; // Games selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildContent(context),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final (badgeBg, badgeIcon) = _gradeBadgeStyle(widget.grade);
    final subtitle = widget.grade.isLowerGrade
        ? '3 games · All unlocked · Free exploration'
        : '3 games · Sequential unlock';

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${widget.grade.label} Games',
                  style: AppTypography.screenTitle(fontSize: 20, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.body(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.grade.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _gradeBadgeStyle(Grade grade) {
    switch (grade) {
      case Grade.lkg:
        return (const Color(0xFFEC407A), Icons.local_florist_rounded);
      case Grade.ukg:
        return (const Color(0xFFFFB74D), Icons.wb_sunny_rounded);
      case Grade.grade4:
        return (AppColors.freshGreen, Icons.menu_book_rounded);
      case Grade.grade5:
        return (AppColors.primaryBlue, Icons.menu_book_rounded);
    }
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final games = state.gamesFor(widget.grade);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final unlocked = state.isGameUnlocked(widget.grade, game.id);
              final progress = state.getGameProgress(widget.grade, game.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _GameListCard(
                  game: game,
                  unlocked: unlocked,
                  progress: progress,
                  onTap: unlocked
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GamePlayScreen(grade: widget.grade, game: game),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: _navIndex == 0,
            onTap: () => Navigator.of(context).pop(),
            accentColor: const Color(0xFFFF9800),
          ),
          _NavItem(
            icon: Icons.sports_esports_rounded,
            label: 'Games',
            selected: _navIndex == 1,
            onTap: () {},
            accentColor: AppColors.primaryBlue,
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Progress',
            selected: _navIndex == 2,
            onTap: () => setState(() => _navIndex = 2),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            selected: _navIndex == 3,
            onTap: () => setState(() => _navIndex = 3),
          ),
        ],
      ),
    );
  }
}

class _GameListCard extends StatelessWidget {
  final GameInfo game;
  final bool unlocked;
  final GameProgress? progress;
  final VoidCallback? onTap;

  const _GameListCard({
    required this.game,
    required this.unlocked,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = progress?.completed ?? false;
    final started = progress != null && !completed;
    final progressValue = completed ? 1.0 : (started ? 0.6 : 0.0);
    final stars = progress?.stars ?? 0;

    return Material(
      color: AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: unlocked ? 1 : 0.7,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GameIcon(game: game, unlocked: unlocked),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: AppTypography.cardTitle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.freshGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              game.difficulty,
                              style: AppTypography.cardTitle(fontSize: 12).copyWith(color: AppColors.freshGreen),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '~8 min',
                            style: AppTypography.body(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed ? AppColors.freshGreen : AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusWidget(
                  completed: completed,
                  started: started,
                  progressValue: progressValue,
                  stars: completed ? 3 : stars,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameIcon extends StatelessWidget {
  final GameInfo game;
  final bool unlocked;

  const _GameIcon({required this.game, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final (bg, child) = _iconContent(game, unlocked);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  (Color, Widget) _iconContent(GameInfo game, bool unlocked) {
    if (!unlocked) {
      return (Colors.grey.shade300, Icon(Icons.lock_rounded, color: Colors.grey.shade600, size: 26));
    }
    final colors = [
      const Color(0xFF64B5F6),
      const Color(0xFFFFF176),
      const Color(0xFF81C784),
      const Color(0xFFE3F2FD),
      const Color(0xFFFFE0B2),
      const Color(0xFFF8BBD9),
    ];
    final index = game.order - 1;
    final bg = colors[index % colors.length];
    final icon = _iconForGame(game.id);
    return (bg, Icon(icon, color: Colors.white, size: 28));
  }

  static IconData _iconForGame(String gameId) {
    switch (gameId) {
      case 'lkg1':
        return Icons.palette_rounded; // Shapes & Colors
      case 'lkg2':
        return Icons.numbers_rounded; // Count the Objects
      case 'lkg3':
        return Icons.image_rounded; // Match the Picture
      case 'ukg1':
        return Icons.abc_rounded; // Letter Sounds
      case 'ukg2':
        return Icons.add_circle_rounded; // Simple Addition
      case 'ukg3':
        return Icons.arrow_forward_rounded; // What Comes Next?
      case 'g41':
        return Icons.close_rounded; // Multiplication Master
      case 'g42':
        return Icons.text_fields_rounded; // Word Builder
      case 'g43':
        return Icons.psychology_rounded; // Logic Puzzles
      case 'g51':
        return Icons.pie_chart_rounded; // Fractions Fun
      case 'g52':
        return Icons.science_rounded; // Science Quiz
      case 'g53':
        return Icons.lightbulb_rounded; // Critical Thinking
      default:
        return Icons.sports_esports_rounded;
    }
  }
}

class _StatusWidget extends StatelessWidget {
  final bool completed;
  final bool started;
  final double progressValue;
  final int stars;

  const _StatusWidget({
    required this.completed,
    required this.started,
    required this.progressValue,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Icon(Icons.star_rounded, color: AppColors.warmYellow, size: 20)),
          ),
          const SizedBox(height: 2),
          Text(
            'Done!',
            style: AppTypography.cardTitle(fontSize: 12).copyWith(color: AppColors.freshGreen),
          ),
        ],
      );
    }
    if (started) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Icon(
              Icons.star_rounded,
              color: i < (stars.clamp(0, 3)) ? AppColors.warmYellow : Colors.grey.shade300,
              size: 20,
            )),
          ),
          const SizedBox(height: 2),
          Text(
            '${(progressValue * 100).round()}%',
            style: AppTypography.cardTitle(fontSize: 12).copyWith(color: AppColors.primaryBlue),
          ),
        ],
      );
    }
    return Text(
      'Not started',
      style: AppTypography.body(fontSize: 12),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? (accentColor ?? AppColors.primaryBlue)
        : AppColors.bodyText;
    final textColor = selected ? AppColors.heading : AppColors.bodyText;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: (selected ? AppTypography.cardTitle(fontSize: 12) : AppTypography.body(fontSize: 12)).copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
