import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';

/// Returns an icon that fits the game name (e.g. Shapes & Colors → palette).
IconData _gameIconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('shape') || lower.contains('color')) return Icons.palette_rounded;
  if (lower.contains('letter') || lower.contains('sound')) return Icons.abc_rounded;
  if (lower.contains('count') || lower.contains('object')) return Icons.numbers_rounded;
  if (lower.contains('addition') || lower.contains('add')) return Icons.add_circle_rounded;
  if (lower.contains('multiplication') || lower.contains('multiply')) return Icons.calculate_rounded;
  if (lower.contains('word') || lower.contains('builder')) return Icons.text_fields_rounded;
  if (lower.contains('match') || lower.contains('picture')) return Icons.image_rounded;
  return Icons.sports_esports_rounded;
}

/// Teacher panel: header, content (Students or Game progress), bottom nav.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _navIndex = 0; // 0 = Home, 1 = Game progress, 2 = Game Insights

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        bottom: false,
        child: Consumer<AppState>(
          builder: (context, state, _) {
            if (_navIndex == 2) {
              return Column(
                children: [
                  _buildGameInsightsHeader(context),
                  Expanded(
                    child: Container(
                      color: AppColors.backgroundCard,
                      child: _buildGameInsightsPage(state),
                    ),
                  ),
                  _buildBottomNav(context),
                ],
              );
            }
            return Column(
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: Container(
                    color: AppColors.backgroundCard,
                    child: _navIndex == 0
                        ? _buildStudentsSection(context, state)
                        : _buildGameProgressPage(state),
                  ),
                ),
                _buildBottomNav(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 12 + bottomPadding,
      ),
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
            onTap: () => setState(() => _navIndex = 0),
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Game progress',
            selected: _navIndex == 1,
            onTap: () => setState(() => _navIndex = 1),
          ),
          _NavItem(
            icon: Icons.lightbulb_rounded,
            label: 'Game Insights',
            selected: _navIndex == 2,
            onTap: () => setState(() => _navIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInsightsHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A7BD5), Color(0xFF4A90E2)],
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => setState(() => _navIndex = 0),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Game Insights',
                          style: AppTypography.screenTitle(fontSize: 22, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Which games are most/least completed',
                          style: AppTypography.body(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameInsightsPage(AppState state) {
    final totalStudents = state.totalStudents;
    final counts = state.gameCompletionCounts;
    if (counts.isEmpty) {
      return Center(
        child: Text('No game data yet', style: AppTypography.body(fontSize: 15)),
      );
    }
    // Build list of all games with grade, difficulty, count
    final List<({String name, String gradeLabel, String difficulty, int count})> items = [];
    for (final grade in Grade.values) {
      for (final game in state.gamesFor(grade)) {
        final count = counts[game.name] ?? 0;
        items.add((name: game.name, gradeLabel: grade.label, difficulty: game.difficulty, count: count));
      }
    }
    items.sort((a, b) => b.count.compareTo(a.count)); // highest first for display
    final maxCount = items.isEmpty ? 1 : items.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final total = totalStudents > 0 ? totalStudents : 1;
    final lowest = items.isEmpty ? null : items.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Completion Rates',
            style: AppTypography.screenTitle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ...items.map((e) {
            final rate = totalStudents > 0 ? (e.count / totalStudents * 100).round() : 0;
            final color = rate >= 70
                ? AppColors.freshGreen
                : rate >= 40
                    ? AppColors.primaryBlue
                    : rate >= 20
                        ? AppColors.warmYellow
                        : const Color(0xFFE57373);
            return _GameInsightCard(
              name: e.name,
              icon: _gameIconForName(e.name),
              subtitle: '${e.gradeLabel} · ${e.difficulty}',
              rate: rate,
              rateColor: color,
              progress: maxCount > 0 ? e.count / maxCount : 0.0,
              progressColor: color,
            );
          }),
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppColors.warmYellow, size: 22),
              const SizedBox(width: 8),
              Text('Insight', style: AppTypography.screenTitle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.illustrationBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              lowest != null
                  ? '${lowest.name} (${lowest.gradeLabel}) has the lowest completion rate. Consider reviewing in class.'
                  : 'No insights yet.',
              style: AppTypography.body(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameProgressPage(AppState state) {
    final counts = state.gameCompletionCounts;
    final entries = counts.entries.toList()
      ..sort((a, b) => (b.value).compareTo(a.value));
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No game data yet',
          style: AppTypography.body(fontSize: 15),
        ),
      );
    }
    final maxCount = entries.isEmpty ? 1 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text(
          'Game progress',
          style: AppTypography.screenTitle(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Completion count by game',
          style: AppTypography.body(fontSize: 13).copyWith(color: AppColors.bodyText.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 20),
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final e = entry.value;
          final progress = maxCount > 0 ? e.value / maxCount : 0.0;
          return _GameProgressCard(
            gameName: e.key,
            icon: _gameIconForName(e.key),
            completedCount: e.value,
            progress: progress,
            accentColor: _gameProgressCardColor(index),
          );
        }),
      ],
    );
  }

  static const _gameProgressCardColors = [
    Color(0xFF4A90E2),
    Color(0xFF66BB6A),
    Color(0xFFF5A623),
    Color(0xFF9C27B0),
    Color(0xFF00ACC1),
  ];

  Color _gameProgressCardColor(int index) {
    return _gameProgressCardColors[index % _gameProgressCardColors.length];
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final greeting = _greeting();
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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    greeting,
                    style: AppTypography.body(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_rounded, color: AppColors.warmYellow, size: 24),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (Route<dynamic> route) => false);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Ms. Priya's Class",
                style: AppTypography.screenTitle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeaderStatCard(
                      value: '${state.totalStudents}',
                      label: 'Students',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeaderStatCard(
                      value: '${state.totalGamesCompleted}',
                      label: 'Games Done',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeaderStatCard(
                      value: '${state.averageProgressPercent}%',
                      label: 'Avg Progress',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  Widget _buildStudentsSection(BuildContext context, AppState state) {
    final list = state.studentProgressList;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(
              'Students',
              style: AppTypography.screenTitle(fontSize: 18),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: AppTypography.cardTitle(fontSize: 14).copyWith(color: AppColors.primaryBlue),
                  ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primaryBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final s = list[index];
                final avatarColor = _avatarColor(index);
                return _StudentCard(
                  name: s.name,
                  gamesCompleted: s.gamesCompleted,
                  timeSpent: s.timeSpent,
                  progressPercent: s.progressPercent,
                  avatarColor: avatarColor,
                );
              },
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  static const _avatarColors = [
    Color(0xFF4A90E2), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFF5A623), // orange
    Color(0xFFE91E63), // pink
  ];

  Color _avatarColor(int index) {
    return _avatarColors[index % _avatarColors.length];
  }
}

class _GameInsightCard extends StatelessWidget {
  const _GameInsightCard({
    required this.name,
    required this.icon,
    required this.subtitle,
    required this.rate,
    required this.rateColor,
    required this.progress,
    required this.progressColor,
  });

  final String name;
  final IconData icon;
  final String subtitle;
  final int rate;
  final Color rateColor;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.illustrationBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 24, color: progressColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.cardTitle(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.body(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rate%',
                  style: AppTypography.cardTitle(fontSize: 13).copyWith(color: rateColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: progressColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameProgressCard extends StatelessWidget {
  const _GameProgressCard({
    required this.gameName,
    required this.icon,
    required this.completedCount,
    required this.progress,
    required this.accentColor,
  });

  final String gameName;
  final IconData icon;
  final int completedCount;
  final double progress;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 26, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameName,
                      style: AppTypography.cardTitle(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.freshGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$completedCount completed',
                        style: AppTypography.cardTitle(fontSize: 12).copyWith(color: AppColors.freshGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.bodyText;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: (selected ? AppTypography.cardTitle(fontSize: 12) : AppTypography.body(fontSize: 12)).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  const _HeaderStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTypography.screenTitle(fontSize: 22, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.body(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.name,
    required this.gamesCompleted,
    required this.timeSpent,
    required this.progressPercent,
    required this.avatarColor,
  });

  final String name;
  final int gamesCompleted;
  final Duration timeSpent;
  final int progressPercent;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final timeStr = timeSpent.inMinutes < 60
        ? '${timeSpent.inMinutes} min spent'
        : '${timeSpent.inHours}h ${timeSpent.inMinutes % 60}m spent';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppTypography.cardTitle(fontSize: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.cardTitle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$gamesCompleted games · $timeStr',
                  style: AppTypography.body(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 64,
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: avatarColor.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(avatarColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$progressPercent%',
                style: AppTypography.cardTitle(fontSize: 14).copyWith(color: avatarColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
