import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'grade_games_screen.dart';
import 'lkg_game_cards_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _navIndex == 0 ? _buildGradeContent(context) : _buildPlaceholderTab(context),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      int total = 0, completed = 0;
      for (final g in Grade.values) {
        final games = state.gamesFor(g);
        final prog = state.progressFor(g);
        for (final game in games) {
          total++;
          if (prog[game.id]?.completed == true) completed++;
        }
      }
      final pct = total > 0 ? (completed / total * 100).round() : 0;

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Good Morning ☀️',
                  style: AppTypography.body(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                ),
                Icon(Icons.notifications_rounded, color: AppColors.warmYellow, size: 26),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hi, Arjun! 👋',
              style: AppTypography.screenTitle(fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome to JoyDa!',
              style: AppTypography.body(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Text(
                    'Overall Progress',
                    style: AppTypography.cardTitle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? completed / total : 0,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warmYellow),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildGradeContent(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundMain,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Your Grade',
              style: AppTypography.screenTitle(fontSize: 20, color: AppColors.studentHeaderNav),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.92,
              children: Grade.values.map((grade) => _GradeGridCard(grade: grade)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(BuildContext context) {
    final labels = ['Games', 'Progress', 'Profile'];
    final index = _navIndex;
    return Container(
      width: double.infinity,
      color: AppColors.backgroundMain,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              labels[index - 1],
              style: AppTypography.screenTitle(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: AppTypography.body(fontSize: 15),
            ),
            if (index == 3) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  context.read<AppState>().logout();
                  Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
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
          _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _navIndex == 0, onTap: () => setState(() => _navIndex = 0), accentColor: const Color(0xFFFF9800)),
          _NavItem(icon: Icons.sports_esports_rounded, label: 'Games', selected: _navIndex == 1, onTap: () => setState(() => _navIndex = 1)),
          _NavItem(icon: Icons.bar_chart_rounded, label: 'Progress', selected: _navIndex == 2, onTap: () => setState(() => _navIndex = 2)),
          _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: _navIndex == 3, onTap: () => setState(() => _navIndex = 3)),
        ],
      ),
    );
  }
}

class _GradeGridCard extends StatelessWidget {
  final Grade grade;

  const _GradeGridCard({required this.grade});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      final games = state.gamesFor(grade);
      final prog = state.progressFor(grade);
      int done = 0;
      for (final g in games) {
        if (prog[g.id]?.completed == true) done++;
      }
      final pct = games.isEmpty ? 0.0 : done / games.length;
      final (icon, iconBg, progressColor) = _styleFor(grade);
      final isUkg = grade == Grade.ukg;

      return Material(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: () {
            state.setSelectedGrade(grade);
            if (grade == Grade.lkg || grade == Grade.ukg) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LkgGameCardsScreen(grade: grade),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GradeGamesScreen(grade: grade),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUkg ? AppColors.warmYellow.withValues(alpha: 0.7) : Colors.grey.shade200,
                width: isUkg ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: progressColor, size: 26),
                  ),
                ),
                Text(
                  grade.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.screenTitle(fontSize: 17, color: AppColors.studentHeaderNav),
                ),
                Text(
                  grade.isLowerGrade ? '${games.length} games · All open' : 'Sequential unlock',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  (IconData, Color, Color) _styleFor(Grade grade) {
    switch (grade) {
      case Grade.lkg:
        return (Icons.local_florist_rounded, const Color(0xFFFFE4EC), Color(0xFF64B5F6));
      case Grade.ukg:
        return (Icons.wb_sunny_rounded, const Color(0xFFFFF8E1), const Color(0xFFFFB74D));
      case Grade.grade4:
        return (Icons.menu_book_rounded, const Color(0xFFE8F5E9), AppColors.freshGreen);
      case Grade.grade5:
        return (Icons.menu_book_rounded, const Color(0xFFE3F2FD), const Color(0xFFE53935));
    }
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
    final textColor = selected
        ? AppColors.heading
        : AppColors.bodyText;
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
