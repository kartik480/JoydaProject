import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';

/// Unique word chip (handles repeated words like "the").
class _WordToken {
  final String id;
  final String text;

  const _WordToken(this.id, this.text);
}

class _SentenceLevel {
  final List<String> words;

  const _SentenceLevel(this.words);

  int get length => words.length;
}

enum _FeedbackOverlay { none, wrongSentence, rightSentence }

/// UKG/LKG: drag jumbled words into slots to build correct sentences.
class SentenceBuilderGameScreen extends StatefulWidget {
  final Grade grade;
  final String gameId;

  const SentenceBuilderGameScreen({
    super.key,
    required this.grade,
    required this.gameId,
  });

  @override
  State<SentenceBuilderGameScreen> createState() => _SentenceBuilderGameScreenState();
}

class _SentenceBuilderGameScreenState extends State<SentenceBuilderGameScreen>
    with TickerProviderStateMixin {
  static const List<_SentenceLevel> _levels = [
    _SentenceLevel(['The', 'boy', 'is', 'playing']),
    _SentenceLevel(['The', 'children', 'are', 'playing', 'in', 'the', 'park']),
    _SentenceLevel(['She', 'is', 'reading', 'a', 'book']),
    _SentenceLevel(['The', 'sun', 'rises', 'in', 'the', 'east']),
    _SentenceLevel(['We', 'play', 'in', 'the', 'garden']),
    _SentenceLevel(['The', 'little', 'girl', 'likes', 'to', 'dance']),
  ];

  final math.Random _rng = math.Random();
  final FlutterTts _tts = FlutterTts();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  late final Completer<void> _ttsEngineReady;

  bool _introDismissed = false;
  DateTime? _sessionStart;
  int _earnedStars = 3;

  int _levelIndex = 0;
  List<_WordToken?> _slots = [];
  List<_WordToken> _bank = [];

  bool _sentenceLocked = false;
  bool _allCorrect = false;
  bool _gameComplete = false;
  _FeedbackOverlay _overlay = _FeedbackOverlay.none;

  int _correctSentences = 0;
  int _checkAttempts = 0;
  int _dragEpoch = 0;

  bool get _feedbackBlocking => _overlay != _FeedbackOverlay.none;

  static const Duration _ttsSafetyTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _ttsEngineReady = Completer<void>();
    _initTts();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroDialog());
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.05);
      await _tts.setVolume(1.0);
    } catch (_) {
      // TTS may still work on some platforms after a failed init step.
    } finally {
      if (!_ttsEngineReady.isCompleted) {
        _ttsEngineReady.complete();
      }
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text).timeout(_ttsSafetyTimeout, onTimeout: () {});
    } catch (_) {}
  }

  Future<void> _showIntroDialog() async {
    if (!mounted || _introDismissed) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Sentence Builder',
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle(fontSize: 22, color: AppColors.studentHeaderNav),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Arrange the words to form a correct sentence',
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle(fontSize: 17),
                ),
                const SizedBox(height: 10),
                Text(
                  'Put the words in the right order',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 15, color: AppColors.bodyText),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: AppColors.primaryBlue, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Drag words into slots',
                          style: AppTypography.body(fontSize: 15, color: AppColors.heading),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() {
                  _introDismissed = true;
                  _sessionStart = DateTime.now();
                });
                context.read<AppState>().startGame(widget.grade, widget.gameId);
                _loadLevel(0);
                WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpTtsAfterUserGesture());
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Start', style: AppTypography.cardTitle(fontSize: 16, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Web (and some platforms) need speech inside a user gesture; unlock after Start.
  Future<void> _warmUpTtsAfterUserGesture() async {
    await _ttsEngineReady.future;
    if (!mounted) return;
    try {
      await _tts.setVolume(1.0);
      if (kIsWeb) {
        await _tts.speak('Let\'s build sentences!').timeout(_ttsSafetyTimeout, onTimeout: () {});
      }
    } catch (_) {}
  }

  void _loadLevel(int index) {
    final level = _levels[index];
    final tokens = <_WordToken>[
      for (var i = 0; i < level.words.length; i++)
        _WordToken('L${index}_$i', level.words[i]),
    ];
    tokens.shuffle(_rng);
    setState(() {
      _levelIndex = index;
      _slots = List<_WordToken?>.filled(level.length, null);
      _bank = List<_WordToken>.from(tokens);
      _sentenceLocked = false;
      _allCorrect = false;
      _overlay = _FeedbackOverlay.none;
    });
  }

  void _clearTokenFromSlotsAndBank(_WordToken t) {
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i]?.id == t.id) _slots[i] = null;
    }
    _bank.removeWhere((w) => w.id == t.id);
  }

  void _placeInSlot(_WordToken token, int slotIndex) {
    if (_sentenceLocked || _feedbackBlocking) return;
    setState(() {
      _clearTokenFromSlotsAndBank(token);
      final displaced = _slots[slotIndex];
      if (displaced != null) {
        _bank.add(displaced);
      }
      _slots[slotIndex] = token;
    });
  }

  Future<void> _onWordDroppedOnSlot(_WordToken token, int slotIndex) async {
    if (_sentenceLocked || _feedbackBlocking) return;
    _placeInSlot(token, slotIndex);
    if (_allSlotsFilled && _orderIsCorrect()) {
      await _runSentenceSuccess();
      return;
    }
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> _runSentenceSuccess() async {
    if (_sentenceLocked || !mounted) return;
    _checkAttempts++;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _sentenceLocked = true;
      _allCorrect = true;
      _correctSentences++;
      _overlay = _FeedbackOverlay.rightSentence;
    });
    await _ttsEngineReady.future;
    if (!mounted) return;
    final praise = _rng.nextBool()
        ? 'Great job! That is the correct sentence.'
        : 'Well done! Perfect sentence.';
    await _speak(praise);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _overlay = _FeedbackOverlay.none);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (_levelIndex + 1 >= _levels.length) {
      _finishGame();
    } else {
      _loadLevel(_levelIndex + 1);
    }
  }

  void _returnToBank(_WordToken token) {
    if (_sentenceLocked || _feedbackBlocking) return;
    setState(() {
      for (var i = 0; i < _slots.length; i++) {
        if (_slots[i]?.id == token.id) {
          _slots[i] = null;
          break;
        }
      }
      if (!_bank.any((w) => w.id == token.id)) {
        _bank.add(token);
      }
    });
  }

  bool get _allSlotsFilled => _slots.isNotEmpty && _slots.every((s) => s != null);

  bool _orderIsCorrect() {
    final level = _levels[_levelIndex];
    for (var i = 0; i < level.length; i++) {
      if (_slots[i]?.text != level.words[i]) return false;
    }
    return true;
  }

  /// After a wrong answer: clear sentence slots and put all words in the bank (shuffled)
  /// so each chip is ready to drag into a slot again.
  void _collectWordsIntoBankForRetry() {
    final level = _levels[_levelIndex];
    final byId = <String, _WordToken>{};
    for (final t in _slots) {
      if (t != null) byId[t.id] = t;
    }
    for (final t in _bank) {
      byId[t.id] = t;
    }
    final collected = byId.values.toList();
    if (collected.length != level.length) {
      _loadLevel(_levelIndex);
      return;
    }
    collected.shuffle(_rng);
    setState(() {
      _slots = List<_WordToken?>.filled(level.length, null);
      _bank = collected;
      _dragEpoch++;
    });
  }

  Future<void> _onCheckSentence() async {
    if (!_allSlotsFilled || _sentenceLocked || _feedbackBlocking) return;
    if (_orderIsCorrect()) {
      await _runSentenceSuccess();
      return;
    }
    _checkAttempts++;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    setState(() => _overlay = _FeedbackOverlay.wrongSentence);
    await _ttsEngineReady.future;
    if (!mounted) return;
    await Future.wait([
      _shakeController.forward(from: 0),
      _speak(
        'Oops, not quite right. Try again. Put the words in the correct order.',
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _overlay = _FeedbackOverlay.none);
    _collectWordsIntoBankForRetry();
  }

  void _finishGame() {
    final timeSpent = _sessionStart != null ? DateTime.now().difference(_sessionStart!) : null;
    final total = _levels.length;
    final accuracy = _checkAttempts > 0 ? (_correctSentences / _checkAttempts).clamp(0.0, 1.0) : 1.0;
    final score = ((_correctSentences / total) * 70 + accuracy * 30).round().clamp(0, 100);
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

  void _goHome() {
    _tts.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!_ttsEngineReady.isCompleted) {
      _ttsEngineReady.complete();
    }
    _tts.stop();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      return _StoryCompleteScreen(
        stars: _earnedStars,
        correctSentences: _correctSentences,
        totalSentences: _levels.length,
        attempts: _checkAttempts,
        timeSpent: _sessionStart != null ? DateTime.now().difference(_sessionStart!) : Duration.zero,
        onHome: _goHome,
      );
    }

    if (!_introDismissed) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final storyProgress = (_correctSentences / _levels.length).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.studentHeaderNav,
          onPressed: _goHome,
        ),
        title: Text(
          'Sentence Builder',
          style: AppTypography.cardTitle(fontSize: 18, color: AppColors.studentHeaderNav),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Arrange the words to form a correct sentence',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(fontSize: 15, color: AppColors.heading, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 22, color: AppColors.primaryBlue.withValues(alpha: 0.85)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: storyProgress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.freshGreen),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Story: Sentence ${_levelIndex + 1} of ${_levels.length}',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(fontSize: 13, color: AppColors.bodyText),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your sentence',
                      style: AppTypography.cardTitle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        );
                      },
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < _slots.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _buildSlot(i),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Word bank — drag into slots above',
                      style: AppTypography.cardTitle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 2,
                      child: DragTarget<_WordToken>(
                        onWillAcceptWithDetails: (_) => !_sentenceLocked && !_feedbackBlocking,
                        onAcceptWithDetails: (details) => _returnToBank(details.data),
                        builder: (context, candidate, rejected) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: candidate.isNotEmpty
                                  ? AppColors.warmYellow.withValues(alpha: 0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: candidate.isNotEmpty
                                    ? AppColors.warmYellow
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: _bank.isEmpty
                                ? Center(
                                    child: Text(
                                      'All words placed',
                                      style: AppTypography.body(fontSize: 14, color: AppColors.bodyText),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: _bank.map((t) => _buildDraggableChip(t)).toList(),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _allSlotsFilled && !_sentenceLocked && !_feedbackBlocking
                            ? _onCheckSentence
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.freshGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Check sentence',
                          style: AppTypography.cardTitle(fontSize: 17, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
            ),
          ),
          if (_overlay != _FeedbackOverlay.none) _buildFeedbackOverlay(),
        ],
      ),
    );
  }

  Widget _buildFeedbackOverlay() {
    final (accent, icon, title, body) = switch (_overlay) {
      _FeedbackOverlay.wrongSentence => (
          const Color(0xFFE53935),
          Icons.edit_note_rounded,
          'Not quite right',
          'All words are now in the word bank. Drag each one into a slot in order, then tap Check sentence.',
        ),
      _FeedbackOverlay.rightSentence => (
          const Color(0xFF2E7D32),
          Icons.check_circle_rounded,
          'Correct!',
          'Great sentence!',
        ),
      _FeedbackOverlay.none => (
          Colors.transparent,
          Icons.info_outline,
          '',
          '',
        ),
    };
    if (_overlay == _FeedbackOverlay.none) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
                Icon(icon, color: accent, size: 56),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTypography.cardTitle(fontSize: 24, color: accent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: AppTypography.body(fontSize: 15, color: AppColors.bodyText, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(int index) {
    final token = _slots[index];
    final lockedOk = _sentenceLocked && _allCorrect;
    final borderColor = lockedOk
        ? AppColors.freshGreen
        : token != null
            ? AppColors.primaryBlue.withValues(alpha: 0.45)
            : Colors.grey.shade400;

    Widget slotContent;
    if (token == null) {
      slotContent = Text(
        '___',
        style: AppTypography.body(fontSize: 16, color: Colors.grey.shade400),
      );
    } else if (lockedOk) {
      slotContent = Text(
        token.text,
        style: AppTypography.cardTitle(fontSize: 16, color: AppColors.freshGreen),
      );
    } else {
      slotContent = Draggable<_WordToken>(
        key: ValueKey<String>('slot-$index-${token.id}-$_dragEpoch'),
        data: token,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: _wordChip(token.text, highlighted: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _wordChip(token.text),
        ),
        child: _wordChip(token.text),
      );
    }

    return DragTarget<_WordToken>(
      onWillAcceptWithDetails: (_) => !_sentenceLocked && !_feedbackBlocking,
      onAcceptWithDetails: (d) => unawaited(_onWordDroppedOnSlot(d.data, index)),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minWidth: 72, minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: lockedOk
                ? AppColors.freshGreen.withValues(alpha: 0.15)
                : highlight
                    ? AppColors.primaryBlue.withValues(alpha: 0.12)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: lockedOk ? 2.5 : 1.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: slotContent,
        );
      },
    );
  }

  Widget _buildDraggableChip(_WordToken token) {
    return Draggable<_WordToken>(
      key: ValueKey<String>('bank-${token.id}-$_dragEpoch'),
      data: token,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: _wordChip(token.text, highlighted: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _wordChip(token.text),
      ),
      child: _wordChip(token.text),
    );
  }

  Widget _wordChip(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryBlue.withValues(alpha: 0.12) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.primaryBlue : AppColors.primaryBlue.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.cardTitle(
          fontSize: 16,
          color: AppColors.heading,
        ),
      ),
    );
  }
}

class _StoryCompleteScreen extends StatelessWidget {
  final int stars;
  final int correctSentences;
  final int totalSentences;
  final int attempts;
  final Duration timeSpent;
  final VoidCallback onHome;

  const _StoryCompleteScreen({
    required this.stars,
    required this.correctSentences,
    required this.totalSentences,
    required this.attempts,
    required this.timeSpent,
    required this.onHome,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.auto_stories_rounded, size: 88, color: AppColors.primaryBlue),
              const SizedBox(height: 20),
              Text(
                'Story completed!',
                style: AppTypography.screenTitle(fontSize: 28, color: AppColors.studentHeaderNav),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You built every sentence.',
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 16, color: AppColors.bodyText),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.star_rounded,
                      size: 48,
                      color: i < stars ? AppColors.warmYellow : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sentences completed: $correctSentences / $totalSentences',
                style: AppTypography.cardTitle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Check attempts: $attempts · Time: ${_formatTime(timeSpent)}',
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 15),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onHome,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Back', style: AppTypography.cardTitle(fontSize: 17, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
