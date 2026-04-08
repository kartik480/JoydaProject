import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';

enum MathGameKind { battle, adventure, master }

MathGameKind mathGameKindForId(String gameId) {
  switch (gameId) {
    case 'g41':
    case 'g51':
      return MathGameKind.battle;
    case 'g42':
    case 'g52':
      return MathGameKind.adventure;
    case 'g43':
    case 'g53':
      return MathGameKind.master;
    default:
      return MathGameKind.battle;
  }
}

class _MathQuestion {
  final String text;
  final String correctAnswer;
  final List<String> options;

  const _MathQuestion({
    required this.text,
    required this.correctAnswer,
    required this.options,
  });
}

/// Grade 4/5 mathematics trilogy: Math Battle, Math Adventure, Math Master Challenge.
class GradeMathGamesScreen extends StatefulWidget {
  final Grade grade;
  final String gameId;
  final MathGameKind kind;

  const GradeMathGamesScreen({
    super.key,
    required this.grade,
    required this.gameId,
    required this.kind,
  });

  @override
  State<GradeMathGamesScreen> createState() => _GradeMathGamesScreenState();
}

class _GradeMathGamesScreenState extends State<GradeMathGamesScreen>
    with TickerProviderStateMixin {
  static const int _battleHitsToWin = 6;
  static const int _adventureSteps = 6;
  static const int _masterHitsToWin = 6;

  final math.Random _rng = math.Random();

  late AnimationController _attackController;
  late Animation<double> _attackScale;
  /// Battle: slight rotation when the monster is hit.
  late Animation<double> _monsterWobble;
  /// Battle: bolt icon pulses during the strike.
  late Animation<double> _boltPulse;
  VideoPlayerController? _battleVideoController;
  bool _showBattleHitVideo = false;
  bool _pendingBattleVideoPlay = false;

  bool _introDismissed = false;
  DateTime? _sessionStart;
  int _earnedStars = 3;

  int _correctAnswers = 0;
  int _attempts = 0;
  int _questionIndex = 0;
  _MathQuestion? _currentQuestion;
  int? _selectedWrongIndex;
  int? _selectedCorrectIndex;
  bool _awaitingAdvance = false;

  bool _gameComplete = false;

  /// Math Battle: gentle “try again” hint (no harsh sound).
  bool _battleSoftRetryHint = false;

  List<_MathQuestion> get _adventureLevels => const [
        _MathQuestion(
          text:
              'Riya has 12 apples. She gives 5 to her friend and buys 3 more. How many apples does she have now?',
          correctAnswer: '10',
          options: ['8', '10', '12', '15'],
        ),
        _MathQuestion(
          text: 'Convert 02:15 PM into 24-hour format.',
          correctAnswer: '14:15',
          options: ['14:15', '12:15', '02:15', '16:15'],
        ),
        _MathQuestion(
          text: 'What is 1/2 of 10?',
          correctAnswer: '5',
          options: ['2', '5', '10', '8'],
        ),
        _MathQuestion(
          text: 'A shop has 20 chocolates. 7 are sold. How many are left?',
          correctAnswer: '13',
          options: ['13', '12', '10', '14'],
        ),
        _MathQuestion(
          text: 'A clock shows 7:30 PM. What is it in 24-hour format?',
          correctAnswer: '19:30',
          options: ['19:30', '07:30', '17:30', '21:30'],
        ),
        _MathQuestion(
          text:
              'A bus has 28 seats. 9 seats are empty. How many passengers are on the bus?',
          correctAnswer: '19',
          options: ['17', '19', '21', '37'],
        ),
      ];

  List<_MathQuestion> get _masterLevels => const [
        _MathQuestion(
          text: '2.5 + 1.75 = ?',
          correctAnswer: '4.25',
          options: ['4.25', '3.25', '4.5', '3.75'],
        ),
        _MathQuestion(
          text: '5.0 − 2.35 = ?',
          correctAnswer: '2.65',
          options: ['2.65', '3.65', '2.75', '3.75'],
        ),
        _MathQuestion(
          text:
              'A shop sells a toy for ₹12.50. If you buy 2 toys, how much do you pay?',
          correctAnswer: '25.00',
          options: ['25.00', '24.50', '23.00', '26.00'],
        ),
        _MathQuestion(
          text:
              'Ravi had ₹50. He spent ₹12.75 on a book and ₹10.25 on snacks. How much money is left?',
          correctAnswer: '27.00',
          options: ['27.00', '26.50', '28.00', '25.00'],
        ),
        _MathQuestion(
          text:
              'A bottle has 1.5 litres of water. 0.75 litres is used. How much is left?',
          correctAnswer: '0.75',
          options: ['0.75', '1.25', '0.50', '1.00'],
        ),
        _MathQuestion(
          text: '3.4 + 2.6 = ?',
          correctAnswer: '6.0',
          options: ['6.0', '5.10', '6.10', '5.0'],
        ),
      ];

  @override
  void initState() {
    super.initState();
    _attackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _attackScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _attackController, curve: Curves.easeInOut));
    _monsterWobble = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _attackController, curve: Curves.easeInOut));
    _boltPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 1.0), weight: 3),
    ]).animate(CurvedAnimation(parent: _attackController, curve: Curves.easeInOut));
    if (widget.kind == MathGameKind.battle) {
      _initBattleVideo();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroDialog());
  }

  Future<void> _initBattleVideo() async {
    final controller = VideoPlayerController.asset('images/mon.mp4');
    await controller.initialize();
    await controller.setLooping(false);
    controller.addListener(() {
      if (!mounted || !_showBattleHitVideo) return;
      final value = controller.value;
      if (!value.isPlaying &&
          value.isInitialized &&
          value.position >= value.duration &&
          value.duration > Duration.zero) {
        setState(() => _showBattleHitVideo = false);
        controller.seekTo(Duration.zero);
      }
    });
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _battleVideoController = controller;
    });
    if (_pendingBattleVideoPlay) {
      _pendingBattleVideoPlay = false;
      _playBattleHitVideo();
    }
  }

  Future<void> _playBattleHitVideo() async {
    final controller = _battleVideoController;
    if (controller == null || !controller.value.isInitialized) {
      _pendingBattleVideoPlay = true;
      return;
    }
    _pendingBattleVideoPlay = false;
    await controller.pause();
    await controller.seekTo(Duration.zero);
    if (!mounted) return;
    setState(() => _showBattleHitVideo = true);
    await controller.play();
  }

  @override
  void dispose() {
    _attackController.dispose();
    _battleVideoController?.dispose();
    super.dispose();
  }

  Future<void> _showIntroDialog() async {
    if (!mounted) return;
    final (title, body, sub, hint) = switch (widget.kind) {
      MathGameKind.battle => (
          'Math Battle',
          'Answer correctly to defeat the monster',
          'Each correct answer reduces the monster\'s health',
          _IntroHintBattle(),
        ),
      MathGameKind.adventure => (
          'Math Adventure',
          'Solve the questions and move forward on the path',
          'Reach the end to complete the journey',
          _IntroHintPath(),
        ),
      MathGameKind.master => (
          'Math Master Challenge',
          'Solve the problems to defeat the boss',
          'Harder questions ahead',
          _IntroHintBoss(),
        ),
    };

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: AppTypography.screenTitle(fontSize: 22)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 120, child: hint),
              const SizedBox(height: 16),
              Text(body, style: AppTypography.body(fontSize: 16, height: 1.45)),
              const SizedBox(height: 8),
              Text(
                sub,
                style: AppTypography.body(fontSize: 14, color: AppColors.bodyText, height: 1.4),
              ),
            ],
          ),
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
                _loadNextQuestion();
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _loadNextQuestion() {
    setState(() {
      _selectedWrongIndex = null;
      _selectedCorrectIndex = null;
      _awaitingAdvance = false;
      _battleSoftRetryHint = false;
      switch (widget.kind) {
        case MathGameKind.battle:
          _currentQuestion = _generateBasicQuestion(_rng);
          break;
        case MathGameKind.adventure:
          if (_questionIndex < _adventureLevels.length) {
            _currentQuestion = _shuffledOptionsCopy(_adventureLevels[_questionIndex]);
          } else {
            _currentQuestion = null;
          }
          break;
        case MathGameKind.master:
          if (_questionIndex < _masterLevels.length) {
            _currentQuestion = _shuffledOptionsCopy(_masterLevels[_questionIndex]);
          } else {
            _currentQuestion = null;
          }
          break;
      }
    });
  }

  _MathQuestion _generateBasicQuestion(math.Random r) {
    final t = r.nextInt(5);
    switch (t) {
      case 0:
        final a = r.nextInt(18) + 5;
        final b = r.nextInt(18) + 5;
        final ans = a + b;
        return _MathQuestion(
          text: '$a + $b = ?',
          correctAnswer: '$ans',
          options: _shuffledOptions('$ans', r),
        );
      case 1:
        final a = r.nextInt(25) + 12;
        final b = r.nextInt(a - 2) + 2;
        final ans = a - b;
        return _MathQuestion(
          text: '$a − $b = ?',
          correctAnswer: '$ans',
          options: _shuffledOptions('$ans', r),
        );
      case 2:
        final a = r.nextInt(10) + 2;
        final b = r.nextInt(10) + 2;
        final ans = a * b;
        return _MathQuestion(
          text: '$a × $b = ?',
          correctAnswer: '$ans',
          options: _shuffledOptions('$ans', r),
        );
      case 3:
        final b = r.nextInt(9) + 2;
        final q = r.nextInt(10) + 2;
        final a = b * q;
        return _MathQuestion(
          text: '$a ÷ $b = ?',
          correctAnswer: '$q',
          options: _shuffledOptions('$q', r),
        );
      default:
        final target = r.nextInt(14) + 8;
        final a = r.nextInt(target - 2) + 2;
        final missing = target - a;
        return _MathQuestion(
          text: '$a + __ = $target',
          correctAnswer: '$missing',
          options: _shuffledOptions('$missing', r),
        );
    }
  }

  _MathQuestion _shuffledOptionsCopy(_MathQuestion q) {
    final opts = List<String>.from(q.options)..shuffle(_rng);
    return _MathQuestion(text: q.text, correctAnswer: q.correctAnswer, options: opts);
  }

  List<String> _shuffledOptions(String correct, math.Random r) {
    final set = <String>{correct};
    var guard = 0;
    while (set.length < 4 && guard < 40) {
      guard++;
      final delta = r.nextInt(11) - 5;
      if (delta == 0) continue;
      final tryParse = int.tryParse(correct);
      if (tryParse != null) {
        final w = tryParse + delta;
        if (w >= 0) set.add('$w');
      }
    }
    while (set.length < 4) {
      set.add('${r.nextInt(20) + 1}');
    }
    final list = set.toList()..shuffle(r);
    return list;
  }

  double get _enemyHealthFraction {
    switch (widget.kind) {
      case MathGameKind.battle:
        return 1.0 - (_correctAnswers / _battleHitsToWin).clamp(0.0, 1.0);
      case MathGameKind.adventure:
        return 1.0;
      case MathGameKind.master:
        return 1.0 - (_correctAnswers / _masterHitsToWin).clamp(0.0, 1.0);
    }
  }

  Future<void> _onOptionTap(int index, String label) async {
    final q = _currentQuestion;
    if (q == null || _awaitingAdvance) return;

    _attempts++;
    final isCorrect = label == q.correctAnswer;

    if (isCorrect) {
      final isBattleOrBoss =
          widget.kind == MathGameKind.battle || widget.kind == MathGameKind.master;

      // Monster / boss takes damage in sync with the strike animation.
      if (isBattleOrBoss) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
        setState(() {
          _selectedCorrectIndex = index;
          _awaitingAdvance = true;
          _correctAnswers++;
        });
        if (widget.kind == MathGameKind.battle) {
          _playBattleHitVideo();
        }
        await _attackController.forward(from: 0);
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        setState(() {
          _selectedCorrectIndex = index;
          _awaitingAdvance = true;
        });
        await _attackController.forward(from: 0);
        if (!mounted) return;
        setState(() => _correctAnswers++);
      }

      if (!mounted) return;

      final won = switch (widget.kind) {
        MathGameKind.battle => _correctAnswers >= _battleHitsToWin,
        MathGameKind.adventure => _questionIndex + 1 >= _adventureSteps,
        MathGameKind.master => _correctAnswers >= _masterHitsToWin,
      };

      if (won) {
        _finishGame();
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;

      if (widget.kind == MathGameKind.battle) {
        _loadNextQuestion();
      } else {
        setState(() => _questionIndex++);
        _loadNextQuestion();
      }
    } else {
      if (widget.kind == MathGameKind.battle) {
        // Soft retry: no alert tone, light haptic, gentle copy.
        HapticFeedback.lightImpact();
        setState(() {
          _selectedWrongIndex = index;
          _battleSoftRetryHint = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 720));
        if (!mounted) return;
        setState(() {
          _selectedWrongIndex = null;
          _battleSoftRetryHint = false;
        });
      } else {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.alert);
        setState(() => _selectedWrongIndex = index);
        await Future<void>.delayed(const Duration(milliseconds: 550));
        if (!mounted) return;
        setState(() => _selectedWrongIndex = null);
      }
    }
  }

  void _finishGame() {
    final timeSpent = _sessionStart != null ? DateTime.now().difference(_sessionStart!) : null;
    final needed = switch (widget.kind) {
      MathGameKind.battle => _battleHitsToWin,
      MathGameKind.adventure => _adventureSteps,
      MathGameKind.master => _masterHitsToWin,
    };
    final accuracy = _attempts > 0 ? (_correctAnswers / _attempts).clamp(0.0, 1.0) : 1.0;
    final score = ((_correctAnswers / needed) * 70 + accuracy * 30).round().clamp(0, 100);
    var stars = 1;
    if (score >= 85) {
      stars = 3;
    } else if (score >= 60) {
      stars = 2;
    }
    if (!mounted) return;
    context.read<AppState>().completeGame(
          widget.grade,
          widget.gameId,
          score: score,
          stars: stars,
          timeSpent: timeSpent,
        );
    if (!mounted) return;
    setState(() {
      _earnedStars = stars;
      _gameComplete = true;
    });
  }

  void _replay() {
    setState(() {
      _gameComplete = false;
      _correctAnswers = 0;
      _attempts = 0;
      _questionIndex = 0;
      _sessionStart = DateTime.now();
      _loadNextQuestion();
    });
  }

  void _goHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      return _EndScreen(
        kind: widget.kind,
        stars: _earnedStars,
        correct: _correctAnswers,
        attempts: _attempts,
        timeSpent: _sessionStart != null ? DateTime.now().difference(_sessionStart!) : Duration.zero,
        onReplay: _replay,
        onHome: _goHome,
      );
    }

    if (!_introDismissed) {
      return Scaffold(
        backgroundColor: _backgroundColor(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _currentQuestion;

    return Scaffold(
      backgroundColor: _backgroundColor(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_appBarTitle(), style: AppTypography.cardTitle(fontSize: 17)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (q != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    q.text,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle(fontSize: widget.kind == MathGameKind.adventure ? 19 : 22)
                        .copyWith(height: 1.35),
                  ),
                ),
              if (widget.kind == MathGameKind.battle && _battleSoftRetryHint)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.waving_hand_rounded, color: AppColors.primaryBlue.withValues(alpha: 0.9), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Almost — try another answer. You’ve got this!',
                              style: AppTypography.body(fontSize: 15, color: AppColors.heading, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _buildMiddleVisual(),
              ),
              const SizedBox(height: 12),
              if (q != null) _buildOptions(q),
            ],
          ),
        ),
      ),
    );
  }

  String _appBarTitle() {
    return switch (widget.kind) {
      MathGameKind.battle => 'Math Battle',
      MathGameKind.adventure => 'Math Adventure',
      MathGameKind.master => 'Math Master',
    };
  }

  Color _backgroundColor() {
    return switch (widget.kind) {
      MathGameKind.battle => const Color(0xFFF3E8FF),
      MathGameKind.adventure => const Color(0xFFE8F5E9),
      MathGameKind.master => const Color(0xFFFFE8E0),
    };
  }

  Widget _buildMiddleVisual() {
    return switch (widget.kind) {
      MathGameKind.battle => _buildMonsterArena(),
      MathGameKind.adventure => _buildPathProgress(),
      MathGameKind.master => _buildBossArena(),
    };
  }

  Widget _buildMonsterArena() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HealthBar(
          fraction: _enemyHealthFraction,
          color: const Color(0xFF7C4DFF),
          trackColor: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _attackController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _monsterWobble.value,
              child: Transform.scale(
                scale: _attackScale.value,
                child: child,
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1BEE7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: _showBattleHitVideo && _battleVideoController != null
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _battleVideoController!.value.isInitialized &&
                                      _battleVideoController!.value.size.width > 0
                                  ? _battleVideoController!.value.size.width
                                  : 140,
                              height: _battleVideoController!.value.isInitialized &&
                                      _battleVideoController!.value.size.height > 0
                                  ? _battleVideoController!.value.size.height
                                  : 140,
                              child: VideoPlayer(_battleVideoController!),
                            ),
                          ),
                        )
                      : Image.asset(
                          'images/mon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) =>
                              const Text('👾', style: TextStyle(fontSize: 72)),
                        ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: AnimatedBuilder(
                  animation: _attackController,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _boltPulse.value,
                      child: Icon(Icons.bolt_rounded, color: Colors.amber.shade800, size: 40),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Monster',
          style: AppTypography.cardTitle(fontSize: 16, color: AppColors.heading),
        ),
      ],
    );
  }

  Widget _buildBossArena() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HealthBar(
          fraction: _enemyHealthFraction,
          color: const Color(0xFFE53935),
          trackColor: Colors.white.withValues(alpha: 0.9),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _attackController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _monsterWobble.value,
              child: Transform.scale(
                scale: _attackScale.value,
                child: child,
              ),
            );
          },
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFAB91), Color(0xFFFF7043)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🐉', style: TextStyle(fontSize: 76)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Boss challenge',
          style: AppTypography.cardTitle(fontSize: 16, color: AppColors.heading),
        ),
      ],
    );
  }

  Widget _buildPathProgress() {
    final step = _questionIndex.clamp(0, _adventureSteps - 1);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your journey',
              style: AppTypography.cardTitle(fontSize: 15, color: AppColors.bodyText),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 44,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...List.generate(_adventureSteps, (i) {
                    final cx = 16 + (w - 32) * i / (_adventureSteps - 1);
                    final done = i < step;
                    final here = i == step;
                    return Positioned(
                      left: cx - 10,
                      top: 36,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: done || here ? AppColors.freshGreen : Colors.grey.shade300,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    );
                  }),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    left: (16 + (w - 32) * step / (_adventureSteps - 1)).clamp(8.0, w - 56) - 20,
                    top: 2,
                    child: const Text('🧑‍🎓', style: TextStyle(fontSize: 40)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Step ${step + 1} of $_adventureSteps',
              style: AppTypography.body(fontSize: 14),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptions(_MathQuestion q) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(q.options.length, (i) {
        final label = q.options[i];
        Color? bg;
        Color fg = AppColors.heading;
        if (_selectedCorrectIndex == i) {
          bg = AppColors.freshGreen.withValues(alpha: 0.35);
          fg = const Color(0xFF2E7D32);
        } else if (_selectedWrongIndex == i) {
          if (widget.kind == MathGameKind.battle) {
            bg = const Color(0xFFFFF8E1);
            fg = const Color(0xFFEF6C00);
          } else {
            bg = Colors.red.shade100;
            fg = Colors.red.shade900;
          }
        }
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 50) / 2,
          height: 54,
          child: Material(
            color: bg ?? Colors.white,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _awaitingAdvance ? null : () => _onOptionTap(i, label),
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.cardTitle(fontSize: 18).copyWith(color: fg),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HealthBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final Color trackColor;

  const _HealthBar({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Health',
          textAlign: TextAlign.center,
          style: AppTypography.body(fontSize: 13, color: AppColors.bodyText),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final fill = (w * fraction.clamp(0.0, 1.0)).clamp(0.0, w);
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(width: w, height: 16, color: trackColor),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    width: fill,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IntroHintBattle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE1BEE7),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('👾', style: TextStyle(fontSize: 52))),
        ),
        Positioned(
          right: 24,
          child: Icon(Icons.flash_on_rounded, color: Colors.amber.shade700, size: 40),
        ),
      ],
    );
  }
}

class _IntroHintPath extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏁', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.freshGreen.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('🧑‍🎓', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.flag_rounded, color: Color(0xFF66BB6A), size: 32),
      ],
    );
  }
}

class _IntroHintBoss extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🐉', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: 0.85,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: Colors.red.shade400,
          ),
        ),
      ],
    );
  }
}

class _EndScreen extends StatelessWidget {
  final MathGameKind kind;
  final int stars;
  final int correct;
  final int attempts;
  final Duration timeSpent;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _EndScreen({
    required this.kind,
    required this.stars,
    required this.correct,
    required this.attempts,
    required this.timeSpent,
    required this.onReplay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, emoji) = switch (kind) {
      MathGameKind.battle => ('Monster defeated!', 'Math Battle — reward unlocked', '🏆'),
      MathGameKind.adventure => ('Great job!', 'You completed the journey', '🎉'),
      MathGameKind.master => ('Challenge completed!', 'Math Master — special badge', '🌟'),
    };

    final mins = timeSpent.inMinutes;
    final secs = timeSpent.inSeconds % 60;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(title, style: AppTypography.screenTitle(fontSize: 26), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTypography.body(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warmYellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded, color: Color(0xFFFF8F00)),
                    const SizedBox(width: 8),
                    Text(
                      'Badge earned',
                      style: AppTypography.cardTitle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Icon(
                    Icons.star_rounded,
                    color: i < stars ? AppColors.warmYellow : Colors.grey.shade300,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Correct: $correct · Attempts: $attempts · Time: ${mins}m ${secs}s',
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 14, height: 1.4),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: onReplay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Replay', style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: onHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Back to games', style: AppTypography.cardTitle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
