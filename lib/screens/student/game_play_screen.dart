import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';

class GamePlayScreen extends StatefulWidget {
  final Grade grade;
  final GameInfo game;

  const GamePlayScreen({super.key, required this.grade, required this.game});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  bool _completed = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startGame(widget.grade, widget.game.id);
      setState(() => _startTime = DateTime.now());
    });
  }

  void _completeGame() {
    final duration = _startTime != null ? DateTime.now().difference(_startTime!) : null;
    context.read<AppState>().completeGame(
          widget.grade,
          widget.game.id,
          score: 85,
          stars: 3,
          timeSpent: duration,
        );
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return _SuccessScreen(
        game: widget.game,
        onDone: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.game.name,
          style: AppTypography.cardTitle(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'Pilot game screen',
                style: AppTypography.body(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'This is a placeholder for "${widget.game.name}". In the full app, you would see clear visuals, smooth animations, and simple instructions.',
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 15, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    _completeGame();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.freshGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Complete game (demo)', style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  final GameInfo game;
  final VoidCallback onDone;

  const _SuccessScreen({required this.game, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration_rounded,
                  size: 80,
                  color: AppColors.warmYellow,
                ),
                const SizedBox(height: 24),
                Text(
                  'Great job!',
                  style: AppTypography.screenTitle(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'You completed "${game.name}"',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Icon(Icons.star_rounded, color: AppColors.warmYellow, size: 40)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: 85',
                  style: AppTypography.cardTitle(fontSize: 18),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text('Back to Home', style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
