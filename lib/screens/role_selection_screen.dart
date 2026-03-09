import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';
import '../core/app_state.dart';
import 'student/student_home_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.student;

  void _continue() {
    context.read<AppState>().setRole(_selectedRole);
    if (_selectedRole == UserRole.student) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TeacherDashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.heading,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPadding = (constraints.maxHeight * 0.12).clamp(48.0, 100.0);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Who are you?',
                        style: AppTypography.screenTitle(fontSize: 24),
                      ),
                      const SizedBox(width: 6),
                      Text('✨', style: AppTypography.body(fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your role to continue',
                    style: AppTypography.body(fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  _RoleCard(
                    title: 'Student',
                    subtitle: 'Play games & track progress',
                    icon: Icons.backpack_rounded,
                    iconBgColor: const Color(0xFFFFE4EC),
                    iconColor: const Color(0xFFE91E63),
                    selected: _selectedRole == UserRole.student,
                    onTap: () => setState(() => _selectedRole = UserRole.student),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: 'Teacher',
                    subtitle: 'Monitor class performance',
                    icon: Icons.school_rounded,
                    iconBgColor: const Color(0xFFFFF8E1),
                    iconColor: const Color(0xFFF9A825),
                    selected: _selectedRole == UserRole.teacher,
                    onTap: () => setState(() => _selectedRole = UserRole.teacher),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedRole == UserRole.student
                                ? 'Continue as Student'
                                : 'Continue as Teacher',
                            style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryBlue.withValues(alpha: 0.06)
          : AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primaryBlue.withValues(alpha: 0.6) : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.body(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                size: selected ? 24 : 16,
                color: selected ? AppColors.primaryBlue : AppColors.bodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
