import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

class FloatSinkGameScreen extends StatefulWidget {
  const FloatSinkGameScreen({super.key});

  @override
  State<FloatSinkGameScreen> createState() => _FloatSinkGameScreenState();
}

class _FloatSinkGameScreenState extends State<FloatSinkGameScreen> with TickerProviderStateMixin {
  final List<GameObject> _objects = [
    GameObject(id: 'rock', name: 'Rock', sinks: true),
    GameObject(id: 'leaf', name: 'Leaf', sinks: false),
    GameObject(id: 'paper', name: 'Paper', sinks: false),
  ];

  final Map<String, Offset> _objectPositions = {};
  final Map<String, bool> _objectPlaced = {};
  final Map<String, bool> _objectCorrect = {};
  int _score = 0;
  int _totalPlaced = 0;
  bool _gameCompleted = false;
  
  late AnimationController _splashController;
  late AnimationController _successController;
  String? _lastDroppedObject;

  @override
  void initState() {
    super.initState();
    for (var obj in _objects) {
      _objectPositions[obj.id] = Offset.zero;
      _objectPlaced[obj.id] = false;
      _objectCorrect[obj.id] = false;
    }
    
    _splashController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _splashController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _onObjectDropped(String objectId, Offset position, bool isInWater) {
    setState(() {
      _objectPositions[objectId] = position;
      _objectPlaced[objectId] = true;
      _lastDroppedObject = objectId;
      
      // Object is correct if it's placed in water (isInWater is always true when dropped in glass)
      // The game logic: all objects should be tested in water
      final isCorrect = true; // Always correct when dropped in water, we show the result
      _objectCorrect[objectId] = isCorrect;
      
      _score += 10; // Give points for trying
      _successController.forward(from: 0);
      
      _totalPlaced++;
      
      if (_totalPlaced == _objects.length) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _gameCompleted = true;
            });
          }
        });
      }
    });
  }

  void _resetGame() {
    setState(() {
      for (var obj in _objects) {
        _objectPositions[obj.id] = Offset.zero;
        _objectPlaced[obj.id] = false;
        _objectCorrect[obj.id] = false;
      }
      _score = 0;
      _totalPlaced = 0;
      _gameCompleted = false;
      _lastDroppedObject = null;
    });
    _splashController.reset();
    _successController.reset();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameCompleted) {
      return _buildCompletionScreen();
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
          'Float or Sink?',
          style: AppTypography.cardTitle(fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Score: $_score',
                style: AppTypography.cardTitle(fontSize: 16, color: AppColors.primaryBlue),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildInstructions(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildWaterGlass(),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildObjectList(),
                  ),
                ],
              ),
            ),
            _buildFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Drag objects into the water to see if they float or sink!',
              style: AppTypography.body(fontSize: 14, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterGlass() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Water glass container
          Center(
            child: Container(
              width: 200,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  children: [
                    // Water
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 250,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF87CEEB).withValues(alpha: 0.6),
                              const Color(0xFF4682B4).withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: _buildDroppedObjects(),
                      ),
                    ),
                    // Glass rim
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(17),
                            topRight: Radius.circular(17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Drop target overlay
          Positioned.fill(
            child: DragTarget<GameObject>(
              onAccept: (object) {
                final renderBox = context.findRenderObject() as RenderBox;
                final size = renderBox.size;
                final center = Offset(size.width / 2, size.height / 2);
                _onObjectDropped(object.id, center, true);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: candidateData.isNotEmpty
                        ? Border.all(color: AppColors.freshGreen, width: 3)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDroppedObjects() {
    final placedObjects = _objects.where((obj) => _objectPlaced[obj.id] == true).toList();
    
    return Stack(
      children: placedObjects.asMap().entries.map((entry) {
        final index = entry.key;
        final object = entry.value;
        final isCorrect = _objectCorrect[object.id]!;
        
        // Position objects: floating at top, sinking at bottom
        // Distribute horizontally for multiple objects
        final horizontalOffset = (placedObjects.length > 1) 
            ? (index - (placedObjects.length - 1) / 2) * 70.0
            : 0.0;
        final verticalPosition = object.sinks ? 180.0 : 30.0; // Sinks go to bottom, floats stay at top
        
        return Positioned(
          left: 100 + horizontalOffset - 30, // Center of glass (100) + offset - half object width
          top: verticalPosition,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.bounceOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 50), // Drop animation
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCorrect ? AppColors.freshGreen : Colors.red,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildObjectIcon(object.id),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? AppColors.freshGreen : Colors.red,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildObjectList() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objects',
            style: AppTypography.cardTitle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _objects.length,
              itemBuilder: (context, index) {
                final object = _objects[index];
                final isPlaced = _objectPlaced[object.id] == true;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Draggable<GameObject>(
                    data: object,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildObjectIcon(object.id, size: 40),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildObjectCard(object, isPlaced),
                    ),
                    child: _buildObjectCard(object, isPlaced),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectCard(GameObject object, bool isPlaced) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPlaced ? Colors.grey.shade200 : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaced ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildObjectIcon(object.id),
          ),
          const SizedBox(height: 8),
          Text(
            object.name,
            style: AppTypography.body(fontSize: 12),
          ),
          if (isPlaced)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                _objectCorrect[object.id] == true
                    ? Icons.check_circle
                    : Icons.cancel,
                size: 16,
                color: _objectCorrect[object.id] == true
                    ? AppColors.freshGreen
                    : Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    if (_lastDroppedObject == null) return const SizedBox.shrink();
    
    final object = _objects.firstWhere((o) => o.id == _lastDroppedObject);
    final isCorrect = _objectCorrect[_lastDroppedObject!]!;
    
    return AnimatedBuilder(
      animation: isCorrect ? _successController : _splashController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCorrect
                ? AppColors.freshGreen.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCorrect ? AppColors.freshGreen : Colors.red,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? AppColors.freshGreen : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '${object.name} ${object.sinks ? "sinks" : "floats"}!',
                style: AppTypography.cardTitle(
                  fontSize: 16,
                  color: AppColors.freshGreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionScreen() {
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
                  'You completed the Float or Sink game!',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Final Score',
                        style: AppTypography.body(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_score',
                        style: AppTypography.screenTitle(fontSize: 32, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetGame,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Play Again',
                          style: AppTypography.cardTitle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: AppTypography.cardTitle(fontSize: 16).copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectIcon(String objectId, {double size = 30}) {
    switch (objectId) {
      case 'rock':
        return _RockIcon(size: size);
      case 'leaf':
        return _LeafIcon(size: size);
      case 'paper':
        return _PaperIcon(size: size);
      default:
        return Icon(
          Icons.help_outline_rounded,
          size: size,
          color: AppColors.primaryBlue,
        );
    }
  }

}

// Custom icon widgets for better visual representation
class _RockIcon extends StatelessWidget {
  final double size;

  const _RockIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF8B7355),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.landscape_rounded,
        size: size * 0.6,
        color: const Color(0xFF6B5D47),
      ),
    );
  }
}

class _LeafIcon extends StatelessWidget {
  final double size;

  const _LeafIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.eco_rounded,
        size: size * 0.7,
        color: Colors.white,
      ),
    );
  }
}

class _PaperIcon extends StatelessWidget {
  final double size;

  const _PaperIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.description_rounded,
        size: size * 0.6,
        color: AppColors.primaryBlue,
      ),
    );
  }
}

class GameObject {
  final String id;
  final String name;
  final bool sinks; // true if sinks, false if floats

  GameObject({
    required this.id,
    required this.name,
    required this.sinks,
  });
}
