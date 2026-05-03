import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import 'grade_explorer_games_screen.dart';
import 'float_sink_game_screen.dart';
import 'grade_math_games_screen.dart';
import 'grade_science_games_screen.dart';
import 'sentence_builder_game_screen.dart';
import '../../widgets/post_game_praise_gate.dart';

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

  bool get _isSentenceBuilder =>
      widget.game.id == 'g4eng1' || widget.game.id == 'g5eng1';

  bool get _isGradeMathGame {
    const ids = {'g41', 'g42', 'g43', 'g51', 'g52', 'g53'};
    return ids.contains(widget.game.id);
  }

  bool get _isGradeScienceGame {
    const ids = {'g4sci1', 'g4sci2', 'g4sci3', 'g5sci1', 'g5sci2', 'g5sci3'};
    return ids.contains(widget.game.id);
  }

  bool get _isExplorerGame {
    const ids = {'g4exp1', 'g5exp1'};
    return ids.contains(widget.game.id);
  }

  bool get _isFloatSinkExplorerGame {
    const ids = {'g4exp2', 'g5exp2'};
    return ids.contains(widget.game.id);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isSentenceBuilder ||
          _isGradeMathGame ||
          _isGradeScienceGame ||
          _isExplorerGame ||
          _isFloatSinkExplorerGame) {
        return;
      }
      context.read<AppState>().startGame(widget.grade, widget.game.id);
      setState(() => _startTime = DateTime.now());
    });
  }

  void _replayDemo() {
    context.read<AppState>().startGame(widget.grade, widget.game.id);
    setState(() {
      _completed = false;
      _startTime = DateTime.now();
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
      return PostGamePraiseGate(
        child: _SuccessScreen(
          game: widget.game,
          onReplay: _replayDemo,
          onDone: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
        ),
      );
    }

    if (_isSentenceBuilder) {
      return SentenceBuilderGameScreen(
        grade: widget.grade,
        gameId: widget.game.id,
      );
    }

    if (_isGradeMathGame) {
      return GradeMathGamesScreen(
        grade: widget.grade,
        gameId: widget.game.id,
        kind: mathGameKindForId(widget.game.id),
      );
    }

    if (_isGradeScienceGame) {
      return GradeScienceGamesScreen(
        grade: widget.grade,
        gameId: widget.game.id,
        kind: scienceGameKindForId(widget.game.id),
      );
    }

    if (_isExplorerGame) {
      return GradeExplorerGamesScreen(
        grade: widget.grade,
        gameId: widget.game.id,
        kind: explorerGameKindForId(widget.game.id),
      );
    }

    if (_isFloatSinkExplorerGame) {
      return const FloatSinkGameScreen();
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
  final VoidCallback onReplay;
  final VoidCallback onDone;

  const _SuccessScreen({required this.game, required this.onReplay, required this.onDone});

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
                const SizedBox(height: 10),
                Text(
                  'First try: 1 / 1',
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle(fontSize: 18, color: AppColors.heading),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onReplay,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text('Try again', style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onDone,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Back to Home', style: AppTypography.cardTitle(fontSize: 16)),
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

