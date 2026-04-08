import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';

enum _AskKind { letter, color, both }

class _NamedColor {
  final String voiceName; // e.g. "red" for TTS
  final String displayName; // RED
  final Color color;

  const _NamedColor(this.voiceName, this.displayName, this.color);
}

class _BubbleSpec {
  final String id;
  final String letter;
  final _NamedColor named;

  const _BubbleSpec({
    required this.id,
    required this.letter,
    required this.named,
  });
}

/// LKG/UKG: find the bubble by letter, color, or both — calm floating motion, voice prompts.
class AlphabetColorPopGameScreen extends StatefulWidget {
  final Grade grade;

  const AlphabetColorPopGameScreen({super.key, required this.grade});

  String get _gameId => grade == Grade.ukg ? 'ukg4' : 'lkg4';

  @override
  State<AlphabetColorPopGameScreen> createState() => _AlphabetColorPopGameScreenState();
}

class _AlphabetColorPopGameScreenState extends State<AlphabetColorPopGameScreen>
    with TickerProviderStateMixin {
  static const int _totalRounds = 10;
  static const int _simpleRounds = 6;

  static const List<_NamedColor> _palette = [
    _NamedColor('red', 'RED', Color(0xFFE57373)),
    _NamedColor('blue', 'BLUE', Color(0xFF64B5F6)),
    _NamedColor('green', 'GREEN', Color(0xFF81C784)),
    _NamedColor('yellow', 'YELLOW', Color(0xFFFFF176)),
    _NamedColor('orange', 'ORANGE', Color(0xFFFFB74D)),
    _NamedColor('purple', 'PURPLE', Color(0xFFBA68C8)),
  ];

  final FlutterTts _tts = FlutterTts();
  final math.Random _rng = math.Random();

  late AnimationController _floatController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;
  late AnimationController _popController;
  late AnimationController _starController;
  late AnimationController _confettiController;

  List<_BubbleSpec> _bubbles = [];
  List<Alignment> _alignments = [];
  _AskKind _askKind = _AskKind.letter;
  String _targetLetter = 'A';
  _NamedColor _targetNamed = _palette[0];

  int _roundIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  DateTime _sessionStart = DateTime.now();

  bool _roundLocked = false;
  String? _shakingId;
  String? _poppingId;
  bool _showWrongAnswerPopup = false;
  bool _gameComplete = false;
  bool _ttsReady = false;
  late final Completer<void> _ttsEngineReady;

  @override
  void initState() {
    super.initState();
    _ttsEngineReady = Completer<void>();
    _sessionStart = DateTime.now();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _starController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 4));

    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().startGame(widget.grade, widget._gameId);
      _buildRound();
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.08);
      await _tts.setVolume(1.0);
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {
      if (mounted) setState(() => _ttsReady = false);
    } finally {
      if (!_ttsEngineReady.isCompleted) {
        _ttsEngineReady.complete();
      }
    }
  }

  static const Duration _ttsSafetyTimeout = Duration(seconds: 12);

  Future<void> _speak(String text) async {
    if (!_ttsReady || text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts
          .speak(text)
          .timeout(_ttsSafetyTimeout, onTimeout: () {});
    } catch (_) {}
  }

  /// Early rounds: letter-only or color-only (bubbles show one cue each).
  /// After that: merged "Find red A" style only.
  _AskKind _pickAskKind() {
    if (_roundIndex < _simpleRounds) {
      return _rng.nextBool() ? _AskKind.letter : _AskKind.color;
    }
    return _AskKind.both;
  }

  String _instructionForVoice() {
    switch (_askKind) {
      case _AskKind.letter:
        return 'Find ${_targetLetter.toUpperCase()}';
      case _AskKind.color:
        return 'Find ${_targetNamed.voiceName}';
      case _AskKind.both:
        return 'Find ${_targetNamed.voiceName} ${_targetLetter.toUpperCase()}';
    }
  }

  bool _matchesTarget(_BubbleSpec b) {
    switch (_askKind) {
      case _AskKind.letter:
        return b.letter == _targetLetter;
      case _AskKind.color:
        return b.named.displayName == _targetNamed.displayName;
      case _AskKind.both:
        return b.letter == _targetLetter && b.named.displayName == _targetNamed.displayName;
    }
  }

  void _buildRound() {
    _askKind = _pickAskKind();
    _targetLetter = String.fromCharCode(65 + _rng.nextInt(26));
    _targetNamed = _palette[_rng.nextInt(_palette.length)];

    final count = 6 + _rng.nextInt(3);
    final list = <_BubbleSpec>[];

    bool pairTaken(String letter, String colorName) =>
        list.any((b) => b.letter == letter && b.named.displayName == colorName);

    String randomLetter() => String.fromCharCode(65 + _rng.nextInt(26));
    _NamedColor randomNamed() => _palette[_rng.nextInt(_palette.length)];

    switch (_askKind) {
      case _AskKind.letter:
        list.add(_BubbleSpec(id: 'c', letter: _targetLetter, named: randomNamed()));
        var guard = 0;
        while (list.length < count && guard < 400) {
          guard++;
          final L = randomLetter();
          if (L == _targetLetter) continue;
          final nc = randomNamed();
          if (pairTaken(L, nc.displayName)) continue;
          list.add(_BubbleSpec(id: 'x${list.length}', letter: L, named: nc));
        }
        break;
      case _AskKind.color:
        list.add(_BubbleSpec(id: 'c', letter: randomLetter(), named: _targetNamed));
        var guard = 0;
        while (list.length < count && guard < 400) {
          guard++;
          final nc = randomNamed();
          if (nc.displayName == _targetNamed.displayName) continue;
          final L = randomLetter();
          if (pairTaken(L, nc.displayName)) continue;
          list.add(_BubbleSpec(id: 'x${list.length}', letter: L, named: nc));
        }
        break;
      case _AskKind.both:
        list.add(_BubbleSpec(id: 'c', letter: _targetLetter, named: _targetNamed));
        var guard = 0;
        while (list.length < count && guard < 400) {
          guard++;
          final L = randomLetter();
          final nc = randomNamed();
          if (L == _targetLetter && nc.displayName == _targetNamed.displayName) continue;
          if (pairTaken(L, nc.displayName)) continue;
          list.add(_BubbleSpec(id: 'x${list.length}', letter: L, named: nc));
        }
        break;
    }

    list.shuffle(_rng);
    final bubbles = List.generate(
      list.length,
      (i) => _BubbleSpec(id: 'b$i', letter: list[i].letter, named: list[i].named),
    );

    final alignPool = <Alignment>[
      const Alignment(-0.82, -0.5),
      const Alignment(-0.28, -0.58),
      const Alignment(0.32, -0.48),
      const Alignment(0.86, -0.42),
      const Alignment(-0.88, 0.12),
      const Alignment(-0.22, 0.22),
      const Alignment(0.42, 0.16),
      const Alignment(0.9, 0.2),
      const Alignment(-0.52, 0.62),
      const Alignment(0.18, 0.68),
      const Alignment(0.78, 0.64),
    ]..shuffle(_rng);
    final aligns = alignPool.take(count).toList();

    setState(() {
      _bubbles = bubbles;
      _alignments = aligns;
      _roundLocked = false;
      _shakingId = null;
      _poppingId = null;
      _showWrongAnswerPopup = false;
    });

    // Speak as soon as possible after round data is set (no extra frame wait).
    Future.microtask(() {
      if (mounted) unawaited(_announceRoundInstruction());
    });
  }

  Future<void> _announceRoundInstruction() async {
    await _ttsEngineReady.future;
    if (!mounted || !_ttsReady) return;
    await _speak(_instructionForVoice());
  }

  Future<void> _onBubbleTap(_BubbleSpec b) async {
    if (_roundLocked || _gameComplete || _showWrongAnswerPopup) return;
    _totalAttempts++;

    if (_matchesTarget(b)) {
      setState(() {
        _roundLocked = true;
        _poppingId = b.id;
      });
      _correctAnswers++;
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
      _popController.forward(from: 0);
      _starController.forward(from: 0);

      final praise = _rng.nextBool() ? 'Good job!' : 'Well done!';
      // Voice starts immediately alongside pop/star animations.
      await _speak(praise);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      if (_roundIndex + 1 >= _totalRounds) {
        _finishGame();
        return;
      }

      setState(() {
        _roundIndex++;
        _popController.reset();
        _starController.reset();
      });
      _buildRound();
    } else {
      setState(() {
        _shakingId = b.id;
        _showWrongAnswerPopup = true;
      });
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
      // Popup + shake; voice says oops then repeats the question in one flow (reliable on web TTS).
      final again = _instructionForVoice();
      await Future.wait([
        _shakeController.forward(from: 0),
        _speak('Oops, try again. $again'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _showWrongAnswerPopup = false;
        _shakingId = null;
      });
    }
  }

  void _finishGame() {
    if (!mounted) return;
    final stars = _starsEarned();
    final timeSpent = DateTime.now().difference(_sessionStart);
    final score = (_correctAnswers * 100 / _totalRounds).round();
    context.read<AppState>().completeGame(
          widget.grade,
          widget._gameId,
          score: score,
          stars: stars,
          timeSpent: timeSpent,
        );
    if (!mounted) return;
    setState(() {
      _gameComplete = true;
      _confettiController.repeat();
    });
  }

  int _starsEarned() {
    final ratio = _correctAnswers / _totalRounds;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.6) return 2;
    return 1;
  }

  void _replay() {
    _tts.stop();
    _confettiController.stop();
    _confettiController.reset();
    setState(() {
      _roundIndex = 0;
      _correctAnswers = 0;
      _totalAttempts = 0;
      _sessionStart = DateTime.now();
      _gameComplete = false;
      _showWrongAnswerPopup = false;
    });
    context.read<AppState>().startGame(widget.grade, widget._gameId);
    _buildRound();
  }

  void _goHome() {
    _tts.stop();
    Navigator.of(context).pop();
  }

  void _replayInstruction() {
    HapticFeedback.lightImpact();
    unawaited(_replayInstructionVoice());
  }

  Future<void> _replayInstructionVoice() async {
    await _ttsEngineReady.future;
    if (!mounted || !_ttsReady) return;
    await _speak(_instructionForVoice());
  }

  @override
  void dispose() {
    if (!_ttsEngineReady.isCompleted) {
      _ttsEngineReady.complete();
    }
    _tts.stop();
    _floatController.dispose();
    _shakeController.dispose();
    _popController.dispose();
    _starController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      return _EndScreen(
        stars: _starsEarned(),
        correctAnswers: _correctAnswers,
        totalRounds: _totalRounds,
        attempts: _totalAttempts,
        timeSpent: DateTime.now().difference(_sessionStart),
        confetti: _confettiController,
        onReplay: _replay,
        onHome: _goHome,
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
              Color(0xFFF3E5F5),
              Color(0xFFE8EAF6),
              Color(0xFFE0F7FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: AppColors.warmYellow.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _replayInstruction,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.volume_up_rounded, color: Color(0xFF5D4037), size: 26),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < _bubbles.length; i++)
                      _buildBubbleLayer(_bubbles[i], _alignments[i]),
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _starController,
                        builder: (context, child) {
                          final t = _starController.value;
                          if (t == 0) return const SizedBox.shrink();
                          return Opacity(
                            opacity: 1 - t,
                            child: Transform.scale(
                              scale: 0.55 + t * 0.95,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  3,
                                  (j) => Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: AppColors.warmYellow,
                                      size: 32 + t * 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_showWrongAnswerPopup) _buildWrongAnswerOverlay(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, size: 22, color: AppColors.warmYellow.withValues(alpha: 0.9)),
                    const SizedBox(width: 6),
                    Text(
                      '$_correctAnswers / $_totalRounds',
                      style: AppTypography.cardTitle(fontSize: 16),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Q ${_roundIndex + 1} / $_totalRounds',
                      style: AppTypography.body(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.studentHeaderNav,
          ),
          Expanded(
            child: Text(
              'Alphabet with Color Pop',
              style: AppTypography.screenTitle(fontSize: 18, color: AppColors.studentHeaderNav),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBubbleLayer(_BubbleSpec b, Alignment align) {
    const bubbleSize = 76.0;
    final phase = (b.id.hashCode % 628) / 100.0;
    final phase2 = (b.id.hashCode % 314) / 100.0;
    return Align(
      alignment: align,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = _floatController.value * 2 * math.pi;
          final dx = math.sin(t + phase) * 9;
          final dy = math.cos(t * 0.82 + phase2) * 7;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          );
        },
        child: _BubbleButton(
          spec: b,
          askKind: _askKind,
          size: bubbleSize,
          popping: _poppingId == b.id,
          popAnimation: _popController,
          shaking: _shakingId == b.id,
          shakeAnimation: _shakeAnim,
          onTap: () => _onBubbleTap(b),
        ),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  final _BubbleSpec spec;
  final _AskKind askKind;
  final double size;
  final bool popping;
  final AnimationController popAnimation;
  final bool shaking;
  final Animation<double> shakeAnimation;
  final VoidCallback onTap;

  const _BubbleButton({
    required this.spec,
    required this.askKind,
    required this.size,
    required this.popping,
    required this.popAnimation,
    required this.shaking,
    required this.shakeAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLetterRound = askKind == _AskKind.letter;
    final isColorRound = askKind == _AskKind.color;
    final fillColor = isLetterRound ? const Color(0xFFECEFF1) : spec.named.color;
    final borderColor = isLetterRound ? const Color(0xFFB0BEC5) : Colors.white.withValues(alpha: 0.85);

    Widget bubble = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.65),
              blurRadius: 0,
              offset: const Offset(-2, -2),
            ),
          ],
          border: Border.all(color: borderColor, width: 2.5),
        ),
        alignment: Alignment.center,
        child: isColorRound
            ? const SizedBox.shrink()
            : Text(
                spec.letter,
                style: AppTypography.screenTitle(
                  fontSize: 34,
                  color: isLetterRound ? AppColors.heading : _letterColor(spec.named),
                ),
              ),
      ),
    );

    if (popping) {
      bubble = AnimatedBuilder(
        animation: popAnimation,
        builder: (context, child) {
          final v = Curves.easeIn.transform(popAnimation.value);
          return Opacity(
            opacity: 1 - v,
            child: Transform.scale(
              scale: 1 + v * 0.35,
              child: child,
            ),
          );
        },
        child: bubble,
      );
    }

    if (shaking) {
      bubble = AnimatedBuilder(
        animation: shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(shakeAnimation.value, 0),
            child: child,
          );
        },
        child: bubble,
      );
    }

    return bubble;
  }

  static Color _letterColor(_NamedColor n) {
    if (n.displayName == 'YELLOW') return AppColors.heading;
    return Colors.white;
  }
}

class _EndScreen extends StatelessWidget {
  final int stars;
  final int correctAnswers;
  final int totalRounds;
  final int attempts;
  final Duration timeSpent;
  final AnimationController confetti;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _EndScreen({
    required this.stars,
    required this.correctAnswers,
    required this.totalRounds,
    required this.attempts,
    required this.timeSpent,
    required this.confetti,
    required this.onReplay,
    required this.onHome,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFCE4EC),
                  Color(0xFFE8EAF6),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Great Job!',
                      style: AppTypography.screenTitle(fontSize: 34, color: AppColors.studentHeaderNav),
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
                    const SizedBox(height: 24),
                    Text(
                      '$correctAnswers / $totalRounds correct',
                      style: AppTypography.cardTitle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attempts: $attempts · Time: ${_fmt(timeSpent)}',
                      style: AppTypography.body(fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: onReplay,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Replay', style: AppTypography.cardTitle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.studentHeaderNav,
                          side: const BorderSide(color: AppColors.primaryBlue, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Go to Games Home', style: AppTypography.cardTitle(fontSize: 17)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: confetti,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SoftConfettiPainter(progress: confetti.value),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftConfettiPainter extends CustomPainter {
  final double progress;

  _SoftConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    for (var i = 0; i < 36; i++) {
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height * 0.4;
      final speed = 0.3 + rnd.nextDouble() * 0.5;
      final y = (baseY + progress * size.height * speed * 1.2) % (size.height + 40);
      final w = 5 + rnd.nextDouble() * 5;
      final h = 4 + rnd.nextDouble() * 6;
      final rot = progress * math.pi * 2 * (0.5 + rnd.nextDouble());
      final colors = [
        const Color(0xFFFFCDD2),
        const Color(0xFFC5CAE9),
        const Color(0xFFC8E6C9),
        const Color(0xFFFFF9C4),
      ];
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        const Radius.circular(2),
      );
      canvas.drawRRect(r, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SoftConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
