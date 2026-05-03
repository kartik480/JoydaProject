import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/joyda_tts_config.dart';
import '../../core/app_state.dart';
import '../../core/game_scoring.dart';
import '../../widgets/post_game_praise_gate.dart';

enum _CountableKind {
  apple,
  star,
  ball,
  rock,
  leaf,
  flower,
  butterfly,
  fish,
  car,
  bear,
  moon,
  cupcake,
  tree,
  laptop,
  duck,
  sun,
  grape,
  orange,
}

extension on _CountableKind {
  String get instructionNoun {
    switch (this) {
      case _CountableKind.apple:
        return 'apples';
      case _CountableKind.star:
        return 'stars';
      case _CountableKind.ball:
        return 'balls';
      case _CountableKind.rock:
        return 'rocks';
      case _CountableKind.leaf:
        return 'leaves';
      case _CountableKind.flower:
        return 'flowers';
      case _CountableKind.butterfly:
        return 'butterflies';
      case _CountableKind.fish:
        return 'fish';
      case _CountableKind.car:
        return 'cars';
      case _CountableKind.bear:
        return 'teddy bears';
      case _CountableKind.moon:
        return 'moons';
      case _CountableKind.cupcake:
        return 'cupcakes';
      case _CountableKind.tree:
        return 'trees';
      case _CountableKind.laptop:
        return 'laptops';
      case _CountableKind.duck:
        return 'ducks';
      case _CountableKind.sun:
        return 'suns';
      case _CountableKind.grape:
        return 'grapes';
      case _CountableKind.orange:
        return 'oranges';
    }
  }

  String get instructionPhrase => 'Count the $instructionNoun';

  /// Web Speech API often clips the first plosive after [stop]; a short vowel-led lead-in avoids "ount the…".
  String get instructionPhraseForTts =>
      kIsWeb ? 'Now, count the $instructionNoun' : instructionPhrase;
}

class _RoundConfig {
  final _CountableKind kind;
  final int correct;
  final List<int> choices; // 3 distinct numbers, includes correct

  const _RoundConfig({
    required this.kind,
    required this.correct,
    required this.choices,
  });
}

/// LKG/UKG: count objects and pick the correct number.
class CountObjectsGameScreen extends StatefulWidget {
  /// Matches [GameInfo] id for Count the Objects (LKG list); completion is stored per [grade].
  static const String progressGameId = 'lkg2';

  final Grade grade;

  const CountObjectsGameScreen({super.key, required this.grade});

  @override
  State<CountObjectsGameScreen> createState() => _CountObjectsGameScreenState();
}

class _CountObjectsGameScreenState extends State<CountObjectsGameScreen>
    with TickerProviderStateMixin {
  static const int _totalRounds = 10;
  static const int _level1Rounds = 5;

  final FlutterTts _tts = FlutterTts();
  final math.Random _rng = math.Random();

  late AnimationController _starBurstController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  int _roundIndex = 0;
  int _difficultyLevel = 1;
  _RoundConfig? _current;

  int _correctAnswers = 0;
  int _firstTryCorrect = 0;
  int _picksThisRound = 0;
  int _totalAttempts = 0;
  DateTime _sessionStart = DateTime.now();

  bool _answeredCorrectly = false;
  int? _selectedWrong;
  bool _showStarBurst = false;
  bool _showWrongAnswerPopup = false;
  bool _showLevel2Intro = false;
  bool _level2IntroShown = false;
  bool _gameComplete = false;
  late final Completer<void> _ttsEngineReady;

  /// One speech at a time so lines never overlap.
  Future<void> _ttsQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _ttsEngineReady = Completer<void>();
    _sessionStart = DateTime.now();
    _starBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _initTts();
    _nextRound();
  }

  Future<void> _initTts() async {
    try {
      // Web: `true` here can make `speak()` hang or fight the browser synth → stuck audio.
      // Mobile: wait for real completion so we do not stack utterances.
      await JoydaTtsConfig.configureNarration(
        _tts,
        awaitSpeakCompletion: !kIsWeb,
        speechRate: kIsWeb ? 0.5 : 0.48,
        pitch: 1.05,
      );
    } catch (_) {
      // Engine may still speak on some platforms after a failed init step.
    } finally {
      if (!_ttsEngineReady.isCompleted) {
        _ttsEngineReady.complete();
      }
    }
  }

  /// Minimum wall time for one phrase (web: plugin often returns before audio ends).
  int _ttsMinSpeechHoldMs(String text) {
    final n = text.trim().length;
    if (kIsWeb) {
      return (900 + n * 100).clamp(1600, 12000);
    }
    return (220 + n * 40).clamp(320, 5000);
  }

  int _ttsEndTailMs() => kIsWeb ? 450 : 120;

  static const Duration _ttsSpeakTimeout = Duration(seconds: 14);

  Future<void> _speak(String text, {bool hardInterrupt = false}) async {
    if (text.isEmpty) return;
    final spoken = JoydaTtsConfig.casualNarration(text);
    final gate = Completer<void>();
    final previous = _ttsQueue;
    _ttsQueue = gate.future;
    await previous;
    try {
      await _ttsEngineReady.future;
      if (!mounted) return;
      try {
        if (hardInterrupt || !kIsWeb) {
          try {
            await _tts.stop();
          } catch (_) {}
          await Future<void>.delayed(Duration(milliseconds: kIsWeb ? 450 : 70));
        } else {
          await Future<void>.delayed(Duration(milliseconds: kIsWeb ? 180 : 80));
        }
        if (!mounted) return;
        if (kIsWeb) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
          if (!mounted) return;
        }
        final minMs = _ttsMinSpeechHoldMs(spoken);
        final sw = Stopwatch()..start();
        try {
          await _tts.speak(spoken).timeout(_ttsSpeakTimeout);
        } catch (_) {
          try {
            await _tts.stop();
          } catch (_) {}
        }
        final elapsed = sw.elapsedMilliseconds;
        final remaining = minMs - elapsed;
        if (remaining > 0) {
          await Future<void>.delayed(Duration(milliseconds: remaining));
        }
        if (!mounted) return;
        await Future<void>.delayed(Duration(milliseconds: _ttsEndTailMs()));
      } catch (_) {}
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  int _maxCountForRound() {
    return _roundIndex < _level1Rounds ? 5 : 10;
  }

  _RoundConfig _generateRound() {
    final maxN = _maxCountForRound();
    final correct = 1 + _rng.nextInt(maxN);
    final kind = _CountableKind.values[_rng.nextInt(_CountableKind.values.length)];

    final pool = List<int>.generate(maxN, (i) => i + 1)..remove(correct);
    pool.shuffle(_rng);
    final wrong = pool.take(2).toList();
    final choices = [correct, wrong[0], wrong[1]]..shuffle(_rng);
    return _RoundConfig(kind: kind, correct: correct, choices: choices);
  }

  void _nextRound() {
    final enteringLevel2 = _roundIndex == _level1Rounds && !_level2IntroShown;
    setState(() {
      _current = _generateRound();
      _answeredCorrectly = false;
      _picksThisRound = 0;
      _selectedWrong = null;
      _showStarBurst = false;
      _showWrongAnswerPopup = false;
      _difficultyLevel = _roundIndex < _level1Rounds ? 1 : 2;
      _showLevel2Intro = enteringLevel2;
    });
    if (enteringLevel2) {
      return;
    }
    // Gap after previous line finished (min-hold + tail already ran in _speak).
    final gap = kIsWeb ? const Duration(milliseconds: 550) : const Duration(milliseconds: 220);
    Future<void>.delayed(gap).then((_) {
      if (mounted) unawaited(_announceRoundInstruction());
    });
  }

  void _dismissLevel2Intro() {
    HapticFeedback.lightImpact();
    setState(() {
      _showLevel2Intro = false;
      _level2IntroShown = true;
    });
    final gap = kIsWeb ? const Duration(milliseconds: 550) : const Duration(milliseconds: 220);
    Future<void>.delayed(gap).then((_) {
      if (mounted) unawaited(_announceRoundInstruction());
    });
  }

  /// Speaks after TTS init finishes — avoids missing the first "Count the …" on cold start.
  Future<void> _announceRoundInstruction() async {
    await _ttsEngineReady.future;
    if (!mounted || _current == null) return;
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || _current == null) return;
    }
    await _speak(_current!.kind.instructionPhraseForTts);
  }

  void _onReplayInstruction() {
    HapticFeedback.lightImpact();
    unawaited(_replayInstruction());
  }

  Future<void> _replayInstruction() async {
    await _ttsEngineReady.future;
    final c = _current;
    if (!mounted || c == null) return;
    await _speak(c.kind.instructionPhraseForTts, hardInterrupt: true);
  }

  Future<void> _onPickNumber(int value) async {
    if (_gameComplete ||
        _current == null ||
        _answeredCorrectly ||
        _showWrongAnswerPopup ||
        _showLevel2Intro) {
      return;
    }

    final cfg = _current!;
    _totalAttempts++;
    _picksThisRound++;

    if (value == cfg.correct) {
      setState(() {
        _answeredCorrectly = true;
        _selectedWrong = null;
        _correctAnswers++;
        _showStarBurst = true;
      });
      if (_picksThisRound == 1) {
        _firstTryCorrect++;
      }
      HapticFeedback.mediumImpact();
      _starBurstController.forward(from: 0);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // hardInterrupt: stop "Count the …" before feedback (mobile + clean slate).
      await _speak('Great job!', hardInterrupt: true);
      if (!mounted) return;

      if (_roundIndex + 1 >= _totalRounds) {
        final r = _roundScoreStars();
        if (mounted) {
          context.read<AppState>().completeGame(
                widget.grade,
                CountObjectsGameScreen.progressGameId,
                score: r.score,
                stars: r.stars,
                timeSpent: _timeSpent,
              );
        }
        if (mounted) setState(() => _gameComplete = true);
        return;
      }

      setState(() => _roundIndex++);
      _nextRound();
    } else {
      setState(() {
        _selectedWrong = value;
        _showWrongAnswerPopup = true;
      });
      HapticFeedback.heavyImpact();
      unawaited(_shakeController.forward(from: 0));
      unawaited(_runWrongAnswerFeedback());
    }
  }

  Future<void> _runWrongAnswerFeedback() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted || !_showWrongAnswerPopup) return;
    final wrongLine = 'Oops! Let us try the next question.';
    await _speak(wrongLine, hardInterrupt: true);
    if (!mounted) return;
    setState(() {
      _showWrongAnswerPopup = false;
      _selectedWrong = null;
    });
    if (_roundIndex + 1 >= _totalRounds) {
      final r = _roundScoreStars();
      if (mounted) {
        context.read<AppState>().completeGame(
              widget.grade,
              CountObjectsGameScreen.progressGameId,
              score: r.score,
              stars: r.stars,
              timeSpent: _timeSpent,
            );
      }
      if (mounted) setState(() => _gameComplete = true);
      return;
    }
    setState(() => _roundIndex++);
    _nextRound();
  }

  void _restartGame() {
    try {
      _tts.stop();
    } catch (_) {}
    setState(() {
      _roundIndex = 0;
      _correctAnswers = 0;
      _firstTryCorrect = 0;
      _picksThisRound = 0;
      _totalAttempts = 0;
      _sessionStart = DateTime.now();
      _gameComplete = false;
      _answeredCorrectly = false;
      _selectedWrong = null;
      _showStarBurst = false;
      _showWrongAnswerPopup = false;
      _showLevel2Intro = false;
      _level2IntroShown = false;
    });
    _nextRound();
  }

  void _goHome(BuildContext context) {
    _tts.stop();
    Navigator.of(context).pop();
  }

  ({int score, int stars}) _roundScoreStars() {
    return scoreAndStarsRoundGameMinusWrongTaps(
      roundsCorrect: _correctAnswers,
      totalAttempts: _totalAttempts,
    );
  }

  Duration get _timeSpent => DateTime.now().difference(_sessionStart);

  @override
  void dispose() {
    if (!_ttsEngineReady.isCompleted) {
      _ttsEngineReady.complete();
    }
    _tts.stop();
    _starBurstController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      final end = _roundScoreStars();
      return PostGamePraiseGate(
        child: _EndScreen(
          stars: end.stars,
          score: end.score,
          firstTryCorrect: _firstTryCorrect,
          totalRounds: _totalRounds,
          attempts: _totalAttempts,
          timeSpent: _timeSpent,
          onReplay: _restartGame,
          onHome: () => _goHome(context),
        ),
      );
    }

    final cfg = _current;
    if (cfg == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F4FC),
              Color(0xFFF5E6F0),
              Color(0xFFFFF3E0),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  _buildTopBar(context),
                  _buildInstructionRow(),
                  Expanded(child: _buildObjectArea(cfg)),
                  _buildNumberPad(cfg),
                  const SizedBox(height: 12),
                  _buildProgressChip(),
                  const SizedBox(height: 8),
                ],
              ),
              if (_showStarBurst) _buildStarBurstOverlay(),
              if (_showWrongAnswerPopup) _buildWrongAnswerOverlay(),
              if (_showLevel2Intro) _buildLevel2IntroOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.studentHeaderNav,
          ),
          Expanded(
            child: Text(
              'Count the Objects',
              style: AppTypography.screenTitle(fontSize: 20, color: AppColors.studentHeaderNav),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Level $_difficultyLevel',
              style: AppTypography.cardTitle(fontSize: 13, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.warmYellow.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _onReplayInstruction,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.volume_up_rounded, color: Color(0xFF5D4037), size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectArea(_RoundConfig cfg) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 48;
        final maxH = constraints.maxHeight;
        final cell = math.min(56.0, math.min(maxW / 6, maxH / 4));
        final spacing = cell * 0.35;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(cfg.correct, (i) => _ObjectGlyph(kind: cfg.kind, size: cell)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberPad(_RoundConfig cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: cfg.choices.map((n) {
          final isCorrectPick = _answeredCorrectly && n == cfg.correct;
          final isWrongShake = _selectedWrong == n;
          Widget btn = _NumberChoiceButton(
            number: n,
            highlighted: isCorrectPick,
            onTap: () => _onPickNumber(n),
          );
          if (isWrongShake) {
            btn = AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: btn,
            );
          }
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: btn,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressChip() {
    return Text(
      'Question ${_roundIndex + 1} of $_totalRounds',
      style: AppTypography.body(fontSize: 14, color: AppColors.bodyText),
    );
  }

  Widget _buildLevel2IntroOverlay() {
    final accent = AppColors.primaryBlue;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rocket_launch_rounded, color: accent, size: 56),
                const SizedBox(height: 14),
                Text(
                  'Level 2',
                  style: AppTypography.cardTitle(fontSize: 26, color: accent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nice work! Now you can count up to 10 objects on the screen.',
                  style: AppTypography.body(fontSize: 16, color: AppColors.bodyText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _dismissLevel2Intro,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      "Let's go!",
                      style: AppTypography.cardTitle(fontSize: 17, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWrongAnswerOverlay() {
    const accent = Color(0xFFE53935);
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel_rounded, color: accent, size: 60),
                const SizedBox(height: 12),
                Text(
                  'Wrong answer',
                  style: AppTypography.cardTitle(fontSize: 24, color: accent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Listen for the hint, then tap another answer.',
                  style: AppTypography.body(fontSize: 14, color: AppColors.bodyText, height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarBurstOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _starBurstController,
          builder: (context, child) {
            final t = _starBurstController.value;
            return CustomPaint(
              painter: _StarBurstPainter(progress: t),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _ObjectGlyph extends StatelessWidget {
  final _CountableKind kind;
  final double size;

  const _ObjectGlyph({required this.kind, required this.size});

  static const Map<_CountableKind, String> _emoji = {
    _CountableKind.apple: '🍎',
    _CountableKind.flower: '🌸',
    _CountableKind.butterfly: '🦋',
    _CountableKind.fish: '🐟',
    _CountableKind.car: '🚗',
    _CountableKind.bear: '🧸',
    _CountableKind.moon: '🌙',
    _CountableKind.cupcake: '🧁',
    _CountableKind.tree: '🌳',
    _CountableKind.duck: '🦆',
    _CountableKind.sun: '☀️',
    _CountableKind.grape: '🍇',
    _CountableKind.orange: '🍊',
  };

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _CountableKind.star:
        return Icon(Icons.star_rounded, size: size, color: AppColors.warmYellow);
      case _CountableKind.laptop:
        return Icon(Icons.laptop_mac_rounded, size: size, color: AppColors.primaryBlue);
      case _CountableKind.ball:
        return Image.asset(
          'images/ball.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('⚽', style: TextStyle(fontSize: size * 0.95)),
        );
      case _CountableKind.rock:
        return Image.asset(
          'images/rock.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('🪨', style: TextStyle(fontSize: size * 0.95)),
        );
      case _CountableKind.leaf:
        return Image.asset(
          'images/leaf.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('🍃', style: TextStyle(fontSize: size * 0.95)),
        );
      case _CountableKind.apple:
      case _CountableKind.flower:
      case _CountableKind.butterfly:
      case _CountableKind.fish:
      case _CountableKind.car:
      case _CountableKind.bear:
      case _CountableKind.moon:
      case _CountableKind.cupcake:
      case _CountableKind.tree:
      case _CountableKind.duck:
      case _CountableKind.sun:
      case _CountableKind.grape:
      case _CountableKind.orange:
        final ch = _emoji[kind] ?? '❓';
        return Text(ch, style: TextStyle(fontSize: size * 0.95));
    }
  }
}

class _NumberChoiceButton extends StatelessWidget {
  final int number;
  final bool highlighted;
  final VoidCallback onTap;

  const _NumberChoiceButton({
    required this.number,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.freshGreen.withValues(alpha: 0.35) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: highlighted ? 6 : 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? AppColors.freshGreen : Colors.grey.shade300,
              width: highlighted ? 3 : 1.5,
            ),
          ),
          child: Text(
            '$number',
            style: AppTypography.screenTitle(
              fontSize: 32,
              color: highlighted ? AppColors.freshGreen : AppColors.heading,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  final double progress;

  _StarBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 3; i++) {
      final delay = i * 0.12;
      final localT = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final angle = -1.2 + i * 1.2;
      final dist = 40.0 + 80 * localT;
      final o = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final scale = 0.3 + 0.9 * Curves.easeOut.transform(localT);
      final alpha = (1 - localT) * 0.85;
      paint.color = AppColors.warmYellow.withValues(alpha: alpha);
      _drawStar(canvas, o, 18 * scale, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rad = (i * math.pi / points) - math.pi / 2;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(rad) * rr, math.sin(rad) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter oldDelegate) => oldDelegate.progress != progress;
}

class _EndScreen extends StatelessWidget {
  final int stars;
  final int score;
  final int firstTryCorrect;
  final int totalRounds;
  final int attempts;
  final Duration timeSpent;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  // ignore: prefer_const_constructors_in_immutables — non-const avoids hot-reload failures when fields change
  _EndScreen({
    required this.stars,
    required this.score,
    required this.firstTryCorrect,
    required this.totalRounds,
    required this.attempts,
    required this.timeSpent,
    required this.onReplay,
    required this.onHome,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFFFF8E1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Well done!',
                  style: AppTypography.screenTitle(fontSize: 32, color: AppColors.studentHeaderNav),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.star_rounded,
                        size: 52,
                        color: i < stars ? AppColors.warmYellow : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: $score / 100',
                  style: AppTypography.body(
                    fontSize: 22,
                    color: AppColors.bodyText,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'First try: $firstTryCorrect / $totalRounds',
                  style: AppTypography.cardTitle(fontSize: 18, color: AppColors.heading),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total taps: $attempts · Time: ${_formatDuration(timeSpent)}',
                  style: AppTypography.body(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onReplay,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Try again', style: AppTypography.cardTitle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: onHome,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.studentHeaderNav,
                      side: const BorderSide(color: AppColors.primaryBlue, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Home', style: AppTypography.cardTitle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
