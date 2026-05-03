import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_typography.dart';

/// Short celebration (e.g. "Brilliant!") before showing the score / end screen.
class PostGamePraiseGate extends StatefulWidget {
  const PostGamePraiseGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2400),
  });

  final Widget child;
  final Duration duration;

  @override
  State<PostGamePraiseGate> createState() => _PostGamePraiseGateState();
}

class _PostGamePraiseGateState extends State<PostGamePraiseGate>
    with SingleTickerProviderStateMixin {
  static const _phrases = [
    'Brilliant!',
    'Awesome!',
    'Fantastic!',
    'Super work!',
    'Amazing!',
    'You did it!',
    'Well done!',
    'Outstanding!',
    'Wonderful!',
    'Great job!',
  ];

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final String _phrase;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _phrase = _phrases[math.Random().nextInt(_phrases.length)];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _controller.forward();
    });
    Future<void>.delayed(widget.duration, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue.withValues(alpha: 0.94),
                const Color(0xFF5C6BC0).withValues(alpha: 0.92),
                const Color(0xFF7C4DFF).withValues(alpha: 0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star_rounded,
                            color: AppColors.warmYellow.withValues(alpha: 0.35 + i * 0.12),
                            size: 28 + i * 4.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ScaleTransition(
                      scale: _scale,
                      child: Text(
                        _phrase,
                        textAlign: TextAlign.center,
                        style: AppTypography.screenTitle(fontSize: 44, color: Colors.white).copyWith(
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 3),
                              blurRadius: 12,
                              color: Color(0x66000000),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Tap anywhere to see your results',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
