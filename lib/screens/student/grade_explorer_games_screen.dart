import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_state.dart';
import '../../core/app_typography.dart';
import '../../core/game_scoring.dart';
import '../../core/india_mainland_outline.dart';
import '../../widgets/post_game_praise_gate.dart';

enum ExplorerGameKind { indiaMap }

ExplorerGameKind explorerGameKindForId(String gameId) {
  switch (gameId) {
    case 'g4exp1':
    case 'g5exp1':
      return ExplorerGameKind.indiaMap;
    default:
      return ExplorerGameKind.indiaMap;
  }
}

enum _QuestionType { stateToCapital, capitalToState, mapIdentify }

class _MapQuestion {
  final _QuestionType type;
  final String state;
  final String capital;
  final List<String> options;
  final String correctAnswer;

  const _MapQuestion({
    required this.type,
    required this.state,
    required this.capital,
    required this.options,
    required this.correctAnswer,
  });
}

class GradeExplorerGamesScreen extends StatefulWidget {
  final Grade grade;
  final String gameId;
  final ExplorerGameKind kind;

  const GradeExplorerGamesScreen({
    super.key,
    required this.grade,
    required this.gameId,
    required this.kind,
  });

  @override
  State<GradeExplorerGamesScreen> createState() => _GradeExplorerGamesScreenState();
}

class _GradeExplorerGamesScreenState extends State<GradeExplorerGamesScreen> {
  static const int _totalQuestions = 20;
  final math.Random _rng = math.Random();

  late final List<_MapQuestion> _deck;
  int _questionIndex = 0;
  int _correct = 0;
  int _firstTryCorrect = 0;
  int _tapsThisQuestion = 0;
  int _attempts = 0;
  bool _gameComplete = false;
  bool _introDismissed = false;
  bool _awaitingNext = false;
  int? _selectedWrong;
  int? _selectedCorrect;
  /// `null` = no popup; `true` / `false` = correct / wrong sheet.
  bool? _feedbackCorrect;
  String _feedbackDetail = '';
  DateTime? _sessionStart;
  int _earnedStars = 3;
  int _finalScore = 0;

  void _resetQuestionInteractionState({bool resetQuestionTapCount = false}) {
    _selectedWrong = null;
    _selectedCorrect = null;
    _awaitingNext = false;
    _feedbackCorrect = null;
    _feedbackDetail = '';
    if (resetQuestionTapCount) {
      _tapsThisQuestion = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _deck = _buildDeck();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroDialog());
  }

  List<_MapQuestion> _buildDeck() {
    const pairs = [
      ('Maharashtra', 'Mumbai'),
      ('Rajasthan', 'Jaipur'),
      ('Karnataka', 'Bengaluru'),
      ('Tamil Nadu', 'Chennai'),
      ('Kerala', 'Thiruvananthapuram'),
      ('Gujarat', 'Gandhinagar'),
      ('Punjab', 'Chandigarh'),
      ('Bihar', 'Patna'),
      ('Uttar Pradesh', 'Lucknow'),
      ('West Bengal', 'Kolkata'),
      ('Madhya Pradesh', 'Bhopal'),
      ('Andhra Pradesh', 'Amaravati'),
    ];

    final capitals = pairs.map((e) => e.$2).toList();
    final states = pairs.map((e) => e.$1).toList();
    final questions = <_MapQuestion>[];

    for (final p in pairs) {
      final s = p.$1;
      final c = p.$2;
      questions.add(
        _MapQuestion(
          type: _QuestionType.stateToCapital,
          state: s,
          capital: c,
          options: _options(c, capitals),
          correctAnswer: c,
        ),
      );
      questions.add(
        _MapQuestion(
          type: _QuestionType.capitalToState,
          state: s,
          capital: c,
          options: _options(s, states),
          correctAnswer: s,
        ),
      );
      questions.add(
        _MapQuestion(
          type: _QuestionType.mapIdentify,
          state: s,
          capital: c,
          options: _options(s, states),
          correctAnswer: s,
        ),
      );
    }
    questions.shuffle(_rng);
    return questions.take(_totalQuestions).toList();
  }

  List<String> _options(String correct, List<String> pool) {
    final set = <String>{correct};
    while (set.length < 4) {
      set.add(pool[_rng.nextInt(pool.length)]);
    }
    final out = set.toList()..shuffle(_rng);
    return out;
  }

  Future<void> _showIntroDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Explore India', style: AppTypography.screenTitle(fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 110,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text('Map highlight', style: AppTypography.body(fontSize: 13, color: AppColors.bodyText)),
                ],
              ),
            ),
            Text('Answer correctly to explore the map', style: AppTypography.body(fontSize: 16)),
            const SizedBox(height: 8),
            Text('States and capitals', style: AppTypography.body(fontSize: 14, color: AppColors.bodyText)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!mounted) return;
              context.read<AppState>().startGame(widget.grade, widget.gameId);
              setState(() {
                _introDismissed = true;
                _sessionStart = DateTime.now();
              });
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  String _questionText(_MapQuestion q) {
    switch (q.type) {
      case _QuestionType.stateToCapital:
        return 'What is the capital of ${q.state}?';
      case _QuestionType.capitalToState:
        return 'Which state has capital ${q.capital}?';
      case _QuestionType.mapIdentify:
        return 'Identify this highlighted state';
    }
  }

  Future<void> _onOptionTap(int idx) async {
    if (_awaitingNext || _gameComplete) return;
    final q = _deck[_questionIndex];
    _tapsThisQuestion++;
    _attempts++;
    final selected = q.options[idx];
    final isCorrect = selected == q.correctAnswer;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      setState(() {
        _selectedCorrect = idx;
        _awaitingNext = true;
        _correct++;
        _feedbackCorrect = true;
        _feedbackDetail = q.correctAnswer;
      });
      if (_tapsThisQuestion == 1) {
        _firstTryCorrect++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      if (_questionIndex >= _deck.length - 1) {
        setState(() {
          _resetQuestionInteractionState();
        });
        _finishGame();
      } else {
        setState(() {
          _questionIndex++;
          _resetQuestionInteractionState(resetQuestionTapCount: true);
        });
      }
    } else {
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _selectedWrong = idx;
        _awaitingNext = true;
        _feedbackCorrect = false;
        _feedbackDetail = q.correctAnswer;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      if (_questionIndex >= _deck.length - 1) {
        setState(() {
          _resetQuestionInteractionState();
        });
        _finishGame();
      } else {
        setState(() {
          _questionIndex++;
          _resetQuestionInteractionState(resetQuestionTapCount: true);
        });
      }
    }
  }

  void _finishGame() {
    final duration = _sessionStart != null ? DateTime.now().difference(_sessionStart!) : Duration.zero;
    final r = scoreAndStarsProgressAccuracy(
      progressed: _correct,
      total: _deck.length,
      successCount: _correct,
      attemptCount: _attempts,
    );
    context.read<AppState>().completeGame(
          widget.grade,
          widget.gameId,
          score: r.score,
          stars: r.stars,
          timeSpent: duration,
        );
    setState(() {
      _earnedStars = r.stars;
      _finalScore = r.score;
      _gameComplete = true;
    });
  }

  void _replay() {
    setState(() {
      _questionIndex = 0;
      _correct = 0;
      _firstTryCorrect = 0;
      _attempts = 0;
      _finalScore = 0;
      _gameComplete = false;
      _sessionStart = DateTime.now();
      _resetQuestionInteractionState(resetQuestionTapCount: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      final mins = (_sessionStart != null ? DateTime.now().difference(_sessionStart!).inMinutes : 0);
      final secs = (_sessionStart != null ? DateTime.now().difference(_sessionStart!).inSeconds % 60 : 0);
      return PostGamePraiseGate(
        child: Scaffold(
          backgroundColor: AppColors.backgroundMain,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 14),
                    Text('India Explorer Complete!', style: AppTypography.screenTitle(fontSize: 26), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Reward unlocked', style: AppTypography.body(fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Icon(Icons.star_rounded, color: i < _earnedStars ? AppColors.warmYellow : Colors.grey.shade300, size: 38),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: $_finalScore / 100',
                      style: AppTypography.body(fontSize: 15, color: AppColors.bodyText),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'First try: $_firstTryCorrect / ${_deck.length}',
                      textAlign: TextAlign.center,
                      style: AppTypography.cardTitle(fontSize: 20, color: AppColors.heading),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total attempts: $_attempts · Time: ${mins}m ${secs}s',
                      style: AppTypography.body(fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(onPressed: _replay, child: const Text('Try again')),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to games')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_introDismissed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = _deck[_questionIndex];
    final progress = (_questionIndex + (_selectedCorrect != null ? 1 : 0)) / _deck.length;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF2F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            title: Text('India Map Challenge', style: AppTypography.cardTitle(fontSize: 17)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_questionText(q), textAlign: TextAlign.center, style: AppTypography.screenTitle(fontSize: 20)),
                  const SizedBox(height: 10),
                  _MapPanel(
                    highlightedState: q.state,
                    // Red marker on the state for every question type (including capital→state).
                    showHighlightDot: true,
                    progress: progress.clamp(0.0, 1.0),
                    glow: _selectedCorrect != null,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(q.options.length, (i) {
                      Color? bg;
                      Color fg = AppColors.heading;
                      if (_selectedCorrect == i) {
                        bg = AppColors.freshGreen.withValues(alpha: 0.25);
                        fg = const Color(0xFF2E7D32);
                      } else if (_selectedWrong == i) {
                        bg = Colors.red.shade100;
                        fg = Colors.red.shade900;
                      }
                      return SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 46) / 2,
                        height: 54,
                        child: Material(
                          color: bg ?? Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _onOptionTap(i),
                            child: Center(
                              child: Text(q.options[i], style: AppTypography.cardTitle(fontSize: 16).copyWith(color: fg)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_feedbackCorrect != null)
          Positioned.fill(
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42)),
                child: Center(
                  child: _AnswerFeedbackCard(
                    isCorrect: _feedbackCorrect!,
                    correctAnswer: _feedbackDetail,
                    question: q,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dimmed overlay card for right / wrong answer feedback.
class _AnswerFeedbackCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final _MapQuestion question;

  const _AnswerFeedbackCard({
    required this.isCorrect,
    required this.correctAnswer,
    required this.question,
  });

  String get _detailLine {
    if (isCorrect) {
      switch (question.type) {
        case _QuestionType.stateToCapital:
          return 'Capital: $correctAnswer';
        case _QuestionType.capitalToState:
          return 'State: $correctAnswer';
        case _QuestionType.mapIdentify:
          return correctAnswer;
      }
    }
    // Do not show the correct answer on wrong attempts.
    return 'Pick a different answer.';
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF2E7D32);
    final red = Colors.red.shade800;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 56,
                    color: isCorrect ? green : red,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isCorrect ? 'Correct!' : 'Not quite',
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle(fontSize: 24).copyWith(color: isCorrect ? green : red),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _detailLine,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(fontSize: 16, color: AppColors.bodyText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  final String highlightedState;
  /// When false, the map is shown without a marker (all in-game questions currently pass true).
  final bool showHighlightDot;
  final double progress;
  final bool glow;

  const _MapPanel({
    required this.highlightedState,
    required this.showHighlightDot,
    required this.progress,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: LayoutBuilder(
                builder: (context, c) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'images/india.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _IndiaMapMarkerPainter(
                          showHighlight: showHighlightDot,
                          highlightLonLat:
                              showHighlightDot ? indiaStateCentroidLonLat[highlightedState] : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(glow ? AppColors.freshGreen : AppColors.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndiaMapMarkerPainter extends CustomPainter {
  _IndiaMapMarkerPainter({
    required this.showHighlight,
    required this.highlightLonLat,
  });

  final bool showHighlight;
  final (double, double)? highlightLonLat;

  @override
  void paint(Canvas canvas, Size size) {
    if (showHighlight && highlightLonLat != null) {
      final (hlon, hlat) = highlightLonLat!;
      // `images/india.png` is square; compute where it is rendered inside panel.
      final imageSide = size.width < size.height ? size.width : size.height;
      final imageRect = Rect.fromLTWH(
        (size.width - imageSide) / 2,
        (size.height - imageSide) / 2,
        imageSide,
        imageSide,
      );
      // Calibrated bounds of India drawing inside india.png (normalized in image space).
      const mapLeftN = 0.09;
      const mapTopN = 0.09;
      const mapRightN = 0.90;
      const mapBottomN = 0.90;
      final mapRect = Rect.fromLTRB(
        imageRect.left + imageRect.width * mapLeftN,
        imageRect.top + imageRect.height * mapTopN,
        imageRect.left + imageRect.width * mapRightN,
        imageRect.top + imageRect.height * mapBottomN,
      );
      const minLon = indiaMainlandMinLon;
      const maxLon = indiaMainlandMaxLon;
      const minLat = indiaMainlandMinLat;
      const maxLat = indiaMainlandMaxLat;
      final geoW = maxLon - minLon;
      final geoH = maxLat - minLat;
      final center = Offset(
        mapRect.left + (hlon - minLon) / geoW * mapRect.width,
        mapRect.top + (maxLat - hlat) / geoH * mapRect.height,
      );
      final ring = Paint()..color = Colors.white.withValues(alpha: 0.95);
      final outer = Paint()..color = const Color(0xFFE53935);
      final inner = Paint()..color = const Color(0xFFB71C1C);
      final dotR = (imageSide * 0.0135).clamp(6.0, 10.5);
      canvas.drawCircle(center, dotR + 2.5, ring);
      canvas.drawCircle(center, dotR, outer);
      canvas.drawCircle(center, dotR * 0.45, inner);
    }
  }

  @override
  bool shouldRepaint(covariant _IndiaMapMarkerPainter oldDelegate) =>
      oldDelegate.showHighlight != showHighlight ||
      oldDelegate.highlightLonLat != highlightLonLat;
}
