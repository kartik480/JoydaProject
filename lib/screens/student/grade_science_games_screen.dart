import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_state.dart';
import '../../core/game_scoring.dart';
import '../../widgets/post_game_praise_gate.dart';

enum ScienceGameKind { plants, food, matter }

ScienceGameKind scienceGameKindForId(String gameId) {
  switch (gameId) {
    case 'g4sci1':
    case 'g5sci1':
      return ScienceGameKind.plants;
    case 'g4sci2':
    case 'g5sci2':
      return ScienceGameKind.food;
    case 'g4sci3':
    case 'g5sci3':
      return ScienceGameKind.matter;
    default:
      return ScienceGameKind.plants;
  }
}

class _ScienceItem {
  final String id;
  final String label;
  final String emoji;
  final String categoryId;

  const _ScienceItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.categoryId,
  });
}

class _ScienceCategory {
  final String id;
  final String label;

  const _ScienceCategory({required this.id, required this.label});
}

/// Grade 4/5 science drag-and-drop: plants, food sources, states of matter.
class GradeScienceGamesScreen extends StatefulWidget {
  final Grade grade;
  final String gameId;
  final ScienceGameKind kind;

  const GradeScienceGamesScreen({
    super.key,
    required this.grade,
    required this.gameId,
    required this.kind,
  });

  @override
  State<GradeScienceGamesScreen> createState() => _GradeScienceGamesScreenState();
}

class _GradeScienceGamesScreenState extends State<GradeScienceGamesScreen>
    with TickerProviderStateMixin {
  static const List<_ScienceItem> _plantsItems = [
    _ScienceItem(id: 'rose', label: 'Rose', emoji: '🌹', categoryId: 'shrub'),
    _ScienceItem(id: 'mango', label: 'Mango Tree', emoji: '🥭', categoryId: 'tree'),
    _ScienceItem(id: 'grass', label: 'Grass', emoji: '🌾', categoryId: 'herb'),
    _ScienceItem(id: 'money', label: 'Money Plant', emoji: '🪴', categoryId: 'climber'),
    _ScienceItem(id: 'pumpkin', label: 'Pumpkin Plant', emoji: '🎃', categoryId: 'creeper'),
    _ScienceItem(id: 'mint', label: 'Mint', emoji: '🌿', categoryId: 'herb'),
  ];

  static const List<_ScienceCategory> _plantsCategories = [
    _ScienceCategory(id: 'herb', label: 'Herb'),
    _ScienceCategory(id: 'shrub', label: 'Shrub'),
    _ScienceCategory(id: 'tree', label: 'Tree'),
    _ScienceCategory(id: 'climber', label: 'Climber'),
    _ScienceCategory(id: 'creeper', label: 'Creeper'),
  ];

  static const List<_ScienceItem> _foodItems = [
    _ScienceItem(id: 'milk', label: 'Milk', emoji: '🥛', categoryId: 'animal'),
    _ScienceItem(id: 'egg', label: 'Egg', emoji: '🥚', categoryId: 'animal'),
    _ScienceItem(id: 'rice', label: 'Rice', emoji: '🍚', categoryId: 'plant'),
    _ScienceItem(id: 'apple', label: 'Apple', emoji: '🍎', categoryId: 'plant'),
    _ScienceItem(id: 'honey', label: 'Honey', emoji: '🍯', categoryId: 'animal'),
    _ScienceItem(id: 'curd', label: 'Curd', emoji: '🥣', categoryId: 'animal'),
    _ScienceItem(id: 'fish', label: 'Fish', emoji: '🐟', categoryId: 'animal'),
    _ScienceItem(id: 'chicken', label: 'Chicken', emoji: '🍗', categoryId: 'animal'),
    _ScienceItem(id: 'banana', label: 'Banana', emoji: '🍌', categoryId: 'plant'),
    _ScienceItem(id: 'carrot', label: 'Carrot', emoji: '🥕', categoryId: 'plant'),
    _ScienceItem(id: 'wheat', label: 'Wheat', emoji: '🌾', categoryId: 'plant'),
    _ScienceItem(id: 'corn', label: 'Corn', emoji: '🌽', categoryId: 'plant'),
  ];

  static const List<_ScienceCategory> _foodCategories = [
    _ScienceCategory(id: 'plant', label: 'Plant'),
    _ScienceCategory(id: 'animal', label: 'Animal'),
  ];

  static const List<_ScienceItem> _matterItems = [
    _ScienceItem(id: 'water', label: 'Water', emoji: '💧', categoryId: 'liquid'),
    _ScienceItem(id: 'milk', label: 'Milk', emoji: '🥛', categoryId: 'liquid'),
    _ScienceItem(id: 'stone', label: 'Stone', emoji: '🪨', categoryId: 'solid'),
    _ScienceItem(id: 'air', label: 'Air', emoji: '💨', categoryId: 'gas'),
    _ScienceItem(id: 'juice', label: 'Juice', emoji: '🧃', categoryId: 'liquid'),
    _ScienceItem(id: 'balloon', label: 'Balloon air', emoji: '🎈', categoryId: 'gas'),
  ];

  static const List<_ScienceCategory> _matterCategories = [
    _ScienceCategory(id: 'solid', label: 'Solid'),
    _ScienceCategory(id: 'liquid', label: 'Liquid'),
    _ScienceCategory(id: 'gas', label: 'Gas'),
  ];

  final math.Random _rng = math.Random();

  late List<_ScienceItem> _itemsPool;
  late List<_ScienceCategory> _categories;
  int _roundItemCount = 0;
  final Map<String, List<_ScienceItem>> _placedByCategory = {};

  bool _introDismissed = false;
  DateTime? _sessionStart;
  int _correctCount = 0;
  int _firstTryCorrect = 0;
  bool _hadWrongDropSinceLastPlace = false;
  int _attempts = 0;
  int _earnedStars = 3;
  int _finalScore = 0;
  bool _gameComplete = false;

  String? _flashGreenId;
  String? _flashRedId;
  DateTime? _lastWrongFeedbackAt;
  late AnimationController _leafPulseController;
  late Animation<double> _leafScale;

  @override
  void initState() {
    super.initState();
    _leafPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _leafScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _leafPulseController, curve: Curves.easeOut));
    _initRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroDialog());
  }

  void _initRound() {
    switch (widget.kind) {
      case ScienceGameKind.plants:
        _categories = List.from(_plantsCategories);
        _itemsPool = List.from(_plantsItems)..shuffle(_rng);
        break;
      case ScienceGameKind.food:
        _categories = List.from(_foodCategories);
        _itemsPool = List.from(_foodItems)..shuffle(_rng);
        break;
      case ScienceGameKind.matter:
        _categories = List.from(_matterCategories);
        _itemsPool = List.from(_matterItems)..shuffle(_rng);
        break;
    }
    _placedByCategory.clear();
    for (final c in _categories) {
      _placedByCategory[c.id] = [];
    }
    _roundItemCount = _itemsPool.length;
    _hadWrongDropSinceLastPlace = false;
  }

  @override
  void dispose() {
    _leafPulseController.dispose();
    super.dispose();
  }

  double get _gardenFill =>
      _roundItemCount == 0 ? 0 : _correctCount / _roundItemCount;

  Future<void> _showIntroDialog() async {
    if (!mounted) return;
    final (title, body, sub, hint) = switch (widget.kind) {
      ScienceGameKind.plants => (
          'Plants Around Us',
          'Drag each plant to the correct category',
          'Herb, Shrub, Tree, Climber, Creeper',
          _IntroHintDrag(emoji: '🌱', caption: 'Drag plant into category'),
        ),
      ScienceGameKind.food => (
          'Food Match',
          'Match each food item to its source',
          'Plant or Animal',
          _IntroHintDrag(emoji: '🍽️', caption: 'Drag food → category'),
        ),
      ScienceGameKind.matter => (
          'States of Matter',
          'Sort items into Solid, Liquid or Gas',
          'Think carefully before placing',
          _IntroHintDrag(emoji: '⚗️', caption: 'Drag item into category'),
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
              SizedBox(height: 100, child: hint),
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
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.freshGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  List<_ScienceItem> get _masterItemList {
    return switch (widget.kind) {
      ScienceGameKind.plants => _plantsItems,
      ScienceGameKind.food => _foodItems,
      ScienceGameKind.matter => _matterItems,
    };
  }

  _ScienceItem? _itemById(String id) {
    for (final i in _masterItemList) {
      if (i.id == id) return i;
    }
    return null;
  }

  bool _matchesCategory(String itemId, String categoryId) {
    final item = _itemById(itemId);
    return item != null && item.categoryId == categoryId;
  }

  void _onDragStarted() {
    _lastWrongFeedbackAt = null;
  }

  void _onWrongTarget(String categoryId) {
    final now = DateTime.now();
    if (_lastWrongFeedbackAt != null &&
        now.difference(_lastWrongFeedbackAt!) < const Duration(milliseconds: 380)) {
      return;
    }
    _lastWrongFeedbackAt = now;
    _attempts++;
    _hadWrongDropSinceLastPlace = true;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.alert);
    setState(() => _flashRedId = categoryId);
    Future<void>.delayed(const Duration(milliseconds: 420)).then((_) {
      if (mounted) setState(() => _flashRedId = null);
    });
  }

  Future<void> _onCorrectDrop(String categoryId, String itemId) async {
    final item = _itemById(itemId);
    if (item == null) return;
    if (!_itemsPool.any((e) => e.id == itemId)) return;

    final firstTryPlace = !_hadWrongDropSinceLastPlace;
    _attempts++;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _flashGreenId = categoryId;
      _itemsPool.removeWhere((e) => e.id == itemId);
      _placedByCategory[categoryId]!.add(item);
      _correctCount++;
    });
    if (firstTryPlace) {
      _firstTryCorrect++;
    }
    _hadWrongDropSinceLastPlace = false;
    if (widget.kind == ScienceGameKind.plants) {
      await _leafPulseController.forward(from: 0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) setState(() => _flashGreenId = null);

    if (_itemsPool.isEmpty) {
      _finishGame();
    }
  }

  void _finishGame() {
    final timeSpent = _sessionStart != null ? DateTime.now().difference(_sessionStart!) : null;
    final total = _roundItemCount > 0 ? _roundItemCount : 1;
    final r = scoreAndStarsProgressAccuracy(
      progressed: _correctCount,
      total: total,
      successCount: _correctCount,
      attemptCount: _attempts,
    );
    if (!mounted) return;
    context.read<AppState>().completeGame(
          widget.grade,
          widget.gameId,
          score: r.score,
          stars: r.stars,
          timeSpent: timeSpent,
        );
    if (!mounted) return;
    setState(() {
      _earnedStars = r.stars;
      _finalScore = r.score;
      _gameComplete = true;
    });
  }

  void _replay() {
    setState(() {
      _gameComplete = false;
      _finalScore = 0;
      _correctCount = 0;
      _firstTryCorrect = 0;
      _hadWrongDropSinceLastPlace = false;
      _attempts = 0;
      _sessionStart = DateTime.now();
      _initRound();
    });
  }

  void _goHome() => Navigator.of(context).pop();

  Color _backgroundColor() {
    return switch (widget.kind) {
      ScienceGameKind.plants => const Color(0xFFE8F5E9),
      ScienceGameKind.food => const Color(0xFFFFF8E7),
      ScienceGameKind.matter => const Color(0xFFECEFF1),
    };
  }

  String _instructionLine() {
    return switch (widget.kind) {
      ScienceGameKind.plants => 'Drag each plant into the correct category',
      ScienceGameKind.food => 'Match each food item with its source',
      ScienceGameKind.matter => 'Sort each item into Solid, Liquid or Gas',
    };
  }

  String _appBarTitle() {
    return switch (widget.kind) {
      ScienceGameKind.plants => 'Plants Around Us',
      ScienceGameKind.food => 'Food Match',
      ScienceGameKind.matter => 'States of Matter',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      return PostGamePraiseGate(
        child: _ScienceEndScreen(
          kind: widget.kind,
          stars: _earnedStars,
          score: _finalScore,
          firstTryCorrect: _firstTryCorrect,
          totalItems: _roundItemCount > 0 ? _roundItemCount : 1,
          attempts: _attempts,
          timeSpent: _sessionStart != null ? DateTime.now().difference(_sessionStart!) : Duration.zero,
          onReplay: _replay,
          onHome: _goHome,
        ),
      );
    }

    if (!_introDismissed) {
      return Scaffold(
        backgroundColor: _backgroundColor(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
        child: Stack(
          children: [
            if (widget.kind == ScienceGameKind.plants) _GardenBackdrop(fill: _gardenFill),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _instructionLine(),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(fontSize: 15, height: 1.35, color: AppColors.heading),
                  ),
                  const SizedBox(height: 12),
                  if (widget.kind == ScienceGameKind.food)
                    Expanded(child: _buildFoodLayout())
                  else
                    Expanded(child: _buildPlantsOrMatterLayout()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableGrid() {
    if (_itemsPool.isEmpty) {
      return Center(
        child: Text('Great!', style: AppTypography.screenTitle(fontSize: 20)),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: _itemsPool
            .map((item) => _DraggablePlantCard(item: item, onDragStarted: _onDragStarted))
            .toList(),
      ),
    );
  }

  Widget _buildFoodLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: Material(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Food items', style: AppTypography.cardTitle(fontSize: 14, color: AppColors.bodyText)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _itemsPool
                            .map(
                              (item) => _DraggablePlantCard(
                                item: item,
                                compact: true,
                                onDragStarted: _onDragStarted,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 9,
          child: Column(
            children: _categories.map((c) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CategoryDropBox(
                    category: c,
                    placed: _placedByCategory[c.id] ?? [],
                    flashGreen: _flashGreenId == c.id,
                    flashRed: _flashRedId == c.id,
                    vertical: true,
                    willAcceptItem: (itemId) => _matchesCategory(itemId, c.id),
                    onWrongAttempt: _onWrongTarget,
                    onCorrectDrop: (itemId) => _onCorrectDrop(c.id, itemId),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Draggable pool + category targets (no outer scroll — grid shares height).
  Widget _buildPlantsOrMatterLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 10,
          child: AnimatedBuilder(
            animation: _leafPulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.kind == ScienceGameKind.plants ? _leafScale.value : 1.0,
                child: child,
              );
            },
            child: _buildDraggableGrid(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 15,
          child: _buildCategoryDropBars(),
        ),
      ],
    );
  }

  Widget _categoryDropCell(int index) {
    final c = _categories[index];
    return _CategoryDropBox(
      category: c,
      placed: _placedByCategory[c.id] ?? [],
      flashGreen: _flashGreenId == c.id,
      flashRed: _flashRedId == c.id,
      vertical: true,
      matterFx: widget.kind == ScienceGameKind.matter,
      willAcceptItem: (itemId) => _matchesCategory(itemId, c.id),
      onWrongAttempt: _onWrongTarget,
      onCorrectDrop: (itemId) => _onCorrectDrop(c.id, itemId),
    );
  }

  /// Fills available height: single centered column, equal-height slots — no scrolling.
  Widget _buildCategoryDropBars() {
    const gap = 8.0;
    final n = _categories.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final contentW = (maxW * 0.82).clamp(280.0, 400.0);

        return Center(
          child: SizedBox(
            width: contentW,
            height: maxH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(height: gap),
                  Expanded(child: _categoryDropCell(i)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroHintDrag extends StatelessWidget {
  final String emoji;
  final String caption;

  const _IntroHintDrag({required this.emoji, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: AppColors.freshGreen.withValues(alpha: 0.85), size: 32),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.4)),
              ),
              child: Text('?', style: AppTypography.cardTitle(fontSize: 18)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(caption, style: AppTypography.body(fontSize: 13, color: AppColors.bodyText)),
      ],
    );
  }
}

class _GardenBackdrop extends StatelessWidget {
  final double fill;

  const _GardenBackdrop({required this.fill});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: 0.15 + fill * 0.55,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: Text('🌳🌼🌿', style: TextStyle(fontSize: 56), textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePlantCard extends StatelessWidget {
  final _ScienceItem item;
  final bool compact;
  final VoidCallback? onDragStarted;

  const _DraggablePlantCard({required this.item, this.compact = false, this.onDragStarted});

  @override
  Widget build(BuildContext context) {
    final w = compact ? 88.0 : 100.0;
    final h = compact ? 92.0 : 104.0;
    final card = Material(
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.emoji, style: TextStyle(fontSize: compact ? 30 : 34)),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(fontSize: compact ? 11 : 12, height: 1.15),
            ),
          ],
        ),
      ),
    );

    return Draggable<String>(
      data: item.id,
      onDragStarted: onDragStarted,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: 0.92,
          child: SizedBox(width: w, height: h, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _SciencePlacedChip extends StatelessWidget {
  final _ScienceItem item;

  const _SciencePlacedChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(fontSize: 12, color: AppColors.heading),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop zone for **Plants Around Us**, **Food Match**, and **States of Matter** (same widget).
/// Drag feedback is neutral while hovering; correct vs wrong is decided only in [onAcceptWithDetails].
class _CategoryDropBox extends StatelessWidget {
  final _ScienceCategory category;
  final List<_ScienceItem> placed;
  final bool flashGreen;
  final bool flashRed;
  final bool vertical;
  final bool matterFx;
  final bool Function(String itemId) willAcceptItem;
  final void Function(String categoryId) onWrongAttempt;
  final void Function(String itemId) onCorrectDrop;

  const _CategoryDropBox({
    required this.category,
    required this.placed,
    required this.flashGreen,
    required this.flashRed,
    required this.vertical,
    this.matterFx = false,
    required this.willAcceptItem,
    required this.onWrongAttempt,
    required this.onCorrectDrop,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white.withValues(alpha: 0.9);
    Color bg = Colors.white.withValues(alpha: 0.82);
    if (flashGreen) {
      border = const Color(0xFF66BB6A);
      bg = const Color(0xFFC8E6C9).withValues(alpha: 0.65);
    } else if (flashRed) {
      border = const Color(0xFFE57373);
      bg = const Color(0xFFFFCDD2).withValues(alpha: 0.55);
    }

    return DragTarget<String>(
      // Always accept here so we only evaluate correct/wrong on release (onAccept).
      // If we returned false while hovering wrong zones, Flutter would still leak hints
      // via candidateData on the one "true" target (blue border = answer).
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final id = details.data;
        if (willAcceptItem(id)) {
          onCorrectDrop(id);
        } else {
          onWrongAttempt(category.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        const radius = 14.0;
        // Same neutral hover on every category — does not signal right vs wrong.
        final hoverBorder = Colors.blueGrey.withValues(alpha: 0.42);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: hovering ? hoverBorder : border,
                width: hovering ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (matterFx && category.id == 'liquid')
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF81D4FA).withValues(alpha: flashGreen ? 0.35 : 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                if (matterFx && category.id == 'gas')
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFB3E5FC).withValues(alpha: flashGreen ? 0.4 : 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(vertical ? 6 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vertical)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300.withValues(alpha: 0.55)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              category.label,
                              textAlign: TextAlign.center,
                              style: AppTypography.cardTitle(fontSize: 13, color: AppColors.heading),
                            ),
                          ),
                        )
                      else
                        Text(
                          category.label,
                          textAlign: TextAlign.center,
                          style: AppTypography.cardTitle(fontSize: 13),
                        ),
                      SizedBox(height: vertical ? 4 : 6),
                      Expanded(
                        child: placed.isEmpty
                            ? Center(
                                child: vertical
                                    ? Text(
                                        'Drop here',
                                        style: AppTypography.body(fontSize: 12, color: Colors.grey.shade500),
                                      )
                                    : Icon(Icons.touch_app_rounded, color: Colors.grey.shade400, size: 22),
                              )
                            : vertical
                                ? Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: placed.map((e) => _SciencePlacedChip(item: e)).toList(),
                                    ),
                                  )
                                : Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: placed
                                        .map(
                                          (e) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(e.emoji, style: const TextStyle(fontSize: 22)),
                                              Text(e.label, style: AppTypography.body(fontSize: 10), textAlign: TextAlign.center),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScienceEndScreen extends StatelessWidget {
  final ScienceGameKind kind;
  final int stars;
  final int score;
  final int firstTryCorrect;
  final int totalItems;
  final int attempts;
  final Duration timeSpent;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  // ignore: prefer_const_constructors_in_immutables — non-const avoids hot-reload failures when fields change
  _ScienceEndScreen({
    required this.kind,
    required this.stars,
    required this.score,
    required this.firstTryCorrect,
    required this.totalItems,
    required this.attempts,
    required this.timeSpent,
    required this.onReplay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, emoji, badge) = switch (kind) {
      ScienceGameKind.plants => (
          'Well done!',
          'Your garden looks amazing — reward unlocked',
          '🌻',
          'Garden badge',
        ),
      ScienceGameKind.food => (
          'Great job!',
          'Your plate is full — reward unlocked',
          '🍽️',
          'Food explorer badge',
        ),
      ScienceGameKind.matter => (
          'Challenge completed!',
          'You sorted every category — reward unlocked',
          '✨',
          'Scientist badge',
        ),
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
                    Text(badge, style: AppTypography.cardTitle(fontSize: 15)),
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
              const SizedBox(height: 8),
              Text(
                'Score: $score / 100',
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 15, color: AppColors.bodyText),
              ),
              if (kind != ScienceGameKind.plants) ...[
                const SizedBox(height: 10),
                Text(
                  'First try: $firstTryCorrect / $totalItems',
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle(fontSize: 20, color: AppColors.heading),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Total attempts: $attempts · Time: ${mins}m ${secs}s',
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
                  child: Text('Try again', style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white)),
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
