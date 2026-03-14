import 'dart:math' as math;
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
    GameObject(id: 'ball', name: 'Ball', assetPath: 'images/ball.png', sinks: false),
    GameObject(id: 'rock', name: 'Rock', assetPath: 'images/rock.png', sinks: true),
    GameObject(id: 'sponge', name: 'Sponge', assetPath: 'images/sponge.png', sinks: false),
    GameObject(id: 'paper', name: 'Paper', assetPath: 'images/paper.png', sinks: false),
    GameObject(id: 'leaf', name: 'Leaf', assetPath: 'images/leaf.png', sinks: false),
  ];

  final Map<String, Offset> _objectPositions = {};
  final Map<String, bool> _objectPlaced = {};
  final Map<String, bool> _objectCorrect = {};
  final Map<String, bool> _objectFloatChoice = {}; // User's choice: true = float, false = sink
  int _score = 0;
  int _totalPlaced = 0;
  bool _gameCompleted = false;
  
  late AnimationController _splashController;
  late AnimationController _successController;
  final Map<String, AnimationController> _floatControllers = {};
  final Map<String, AnimationController> _sinkControllers = {};
  final Map<String, AnimationController> _scaleControllers = {};
  String? _lastDroppedObject;
  
  // Track drag position for showing options
  String? _draggingObjectId;
  bool _showFloatSinkOptions = false;
  bool? _pendingFloatChoice; // Stores user's choice before drop
  String? _pendingObjectId; // Object ID for pending choice
  bool _objectFrozenAtTop = false; // Track if object is in collider box
  bool _lastColliderState = false; // Cache to prevent unnecessary setState
  String? _frozenObjectId; // ID of object frozen in collider box
  
  // New state for automatic object display
  int _currentObjectIndex = 0; // Current object being shown
  bool _showingFeedback = false; // Whether we're showing feedback
  String? _feedbackMessage; // Feedback message (correct/wrong)
  bool? _lastAnswerCorrect; // Whether last answer was correct

  @override
  void initState() {
    super.initState();
    for (var obj in _objects) {
      _objectPositions[obj.id] = Offset.zero;
      _objectPlaced[obj.id] = false;
      _objectCorrect[obj.id] = false;
      _objectFloatChoice[obj.id] = false;
      
      // Create animation controllers for each object with Flame-optimized durations
      // Using longer durations for smoother, more natural motion
      _floatControllers[obj.id] = AnimationController(
        duration: const Duration(milliseconds: 3500), // Slower, smoother float
        vsync: this,
      );
      
      _sinkControllers[obj.id] = AnimationController(
        duration: const Duration(milliseconds: 2800), // Smooth sinking with acceleration
        vsync: this,
      );
      
      _scaleControllers[obj.id] = AnimationController(
        duration: const Duration(milliseconds: 500), // Quick scale-in with bounce
        vsync: this,
      );
    }
    
    _splashController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Automatically show first object in collider box
    _showNextObject();
  }

  @override
  void dispose() {
    _splashController.dispose();
    _successController.dispose();
    for (var controller in _floatControllers.values) {
      controller.dispose();
    }
    for (var controller in _sinkControllers.values) {
      controller.dispose();
    }
    for (var controller in _scaleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onObjectDropped(String objectId, Offset position, bool isInWater, {bool? floatChoice}) {
    setState(() {
      _objectPositions[objectId] = position;
      _objectPlaced[objectId] = true;
      _lastDroppedObject = objectId;
      _showFloatSinkOptions = false;
      _draggingObjectId = null;
      
      // Use pending choice if available, otherwise use provided choice, otherwise default
      bool finalChoice;
      if (_pendingObjectId == objectId && _pendingFloatChoice != null) {
        finalChoice = _pendingFloatChoice!;
        _pendingFloatChoice = null;
        _pendingObjectId = null;
      } else if (floatChoice != null) {
        finalChoice = floatChoice;
      } else {
        finalChoice = !_objects.firstWhere((o) => o.id == objectId).sinks;
      }
      
      _objectFloatChoice[objectId] = finalChoice;
      
      final object = _objects.firstWhere((o) => o.id == objectId);
      final userChoice = _objectFloatChoice[objectId]!;
      final isCorrect = (userChoice && !object.sinks) || (!userChoice && object.sinks);
      _objectCorrect[objectId] = isCorrect;
      
      // Start appropriate animation with smooth scale-in
      _scaleControllers[objectId]?.forward(from: 0).then((_) {
        // Stop scale animation after completion to reduce overhead
        _scaleControllers[objectId]?.stop();
      });
      
      if (userChoice) {
        // Float animation - start continuous bobbing with smooth easing
        _floatControllers[objectId]?.repeat(reverse: true);
      } else {
        // Sink animation - animate to bottom with smooth curve
        _sinkControllers[objectId]?.forward(from: 0).then((_) {
          // Stop sink animation after completion
          _sinkControllers[objectId]?.stop();
        });
      }
      
      if (isCorrect) {
        _score += 20; // More points for correct prediction
        _successController.forward(from: 0);
      } else {
        _score += 5; // Fewer points for incorrect
      }
      
      _totalPlaced++;
      
      if (_totalPlaced == _objects.length) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            setState(() {
              _gameCompleted = true;
            });
          }
        });
      }
    });
  }
  
  void _onDragEnd() {
    // Don't clear frozen object - it should stay frozen until user makes a choice
    if (_frozenObjectId != null) {
      // Object is frozen, keep it frozen - don't clear anything
      return;
    }
    
    // Only clear if no object is frozen (normal drag end)
    setState(() {
      _showFloatSinkOptions = false;
      _objectFrozenAtTop = false;
      _draggingObjectId = null;
      _lastColliderState = false;
      // Clear pending choice if drag ends without drop
      if (_pendingObjectId != null && !_objectPlaced[_pendingObjectId!]!) {
        _pendingFloatChoice = null;
        _pendingObjectId = null;
      }
    });
  }
  
  void _onOptionSelected(String objectId, bool floatChoice) {
    final object = _objects.firstWhere((o) => o.id == objectId);
    final isCorrect = (floatChoice && !object.sinks) || (!floatChoice && object.sinks);
    
    setState(() {
      _showingFeedback = true;
      _lastAnswerCorrect = isCorrect;
      _feedbackMessage = isCorrect ? 'Correct!' : 'Wrong!';
      _showFloatSinkOptions = false;
      
      // Record the answer
      _objectFloatChoice[objectId] = floatChoice;
      _objectCorrect[objectId] = isCorrect;
      _objectPlaced[objectId] = true;
      
      if (isCorrect) {
        _score += 20;
        _successController.forward(from: 0);
      } else {
        _score += 5;
      }
      
      _totalPlaced++;
    });
    
    // Show feedback for 2 seconds, then move to next object
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showingFeedback = false;
          _feedbackMessage = null;
          _lastAnswerCorrect = null;
        });
        
        // Move to next object or complete game
        if (_currentObjectIndex < _objects.length - 1) {
          _currentObjectIndex++;
          _showNextObject();
        } else {
          // All objects completed
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _gameCompleted = true;
              });
            }
          });
        }
      }
    });
  }
  
  void _showNextObject() {
    if (_currentObjectIndex < _objects.length) {
      setState(() {
        final object = _objects[_currentObjectIndex];
        _frozenObjectId = object.id;
        _showFloatSinkOptions = true;
        _draggingObjectId = object.id;
      });
    }
  }

  void _resetGame() {
    setState(() {
      for (var obj in _objects) {
        _objectPositions[obj.id] = Offset.zero;
        _objectPlaced[obj.id] = false;
        _objectCorrect[obj.id] = false;
        _objectFloatChoice[obj.id] = false;
        _floatControllers[obj.id]?.reset();
        _sinkControllers[obj.id]?.reset();
        _scaleControllers[obj.id]?.reset();
      }
      _score = 0;
      _totalPlaced = 0;
      _gameCompleted = false;
      _lastDroppedObject = null;
      _showFloatSinkOptions = false;
      _draggingObjectId = null;
      _pendingFloatChoice = null;
      _pendingObjectId = null;
      _objectFrozenAtTop = false;
      _lastColliderState = false;
      _frozenObjectId = null;
      _currentObjectIndex = 0;
      _showingFeedback = false;
      _feedbackMessage = null;
      _lastAnswerCorrect = null;
    });
    _splashController.reset();
    _successController.reset();
    // Show first object again
    _showNextObject();
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Container centered
                    Center(
                      child: _buildWaterGlass(),
                    ),
                    // Show Float/Sink buttons below container when object is frozen or in collider
                    if (_showFloatSinkOptions && !_showingFeedback && (_frozenObjectId != null || _draggingObjectId != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _buildFloatSinkOptions(_frozenObjectId ?? _draggingObjectId!),
                      ),
                    // Show feedback board when showing feedback
                    if (_showingFeedback && _feedbackMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _buildFeedbackBoard(),
                      ),
                    const SizedBox(height: 20),
                    // Object options below container (hidden since we show objects automatically)
                    // _buildObjectList(),
                    const SizedBox(height: 16),
                  ],
                ),
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
              'Look at each object and choose if it will Float or Sink!',
              style: AppTypography.body(fontSize: 14, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterGlass() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Stack(
        children: [
          // Water glass container
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Collider box at top of container
                Container(
                  width: 320,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2), // Match rectangular container
                    border: Border.all(
                      color: (_showFloatSinkOptions && (_draggingObjectId != null || _frozenObjectId != null))
                          ? AppColors.freshGreen
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                    color: (_showFloatSinkOptions && (_draggingObjectId != null || _frozenObjectId != null))
                        ? AppColors.freshGreen.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Stack(
                    children: [
                      // Show object in collider when frozen or dragged there
                      if (_frozenObjectId != null || (_objectFrozenAtTop && _draggingObjectId != null))
                        Center(
                          child: _buildObjectInCollider(),
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.grey.shade400,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                ),
                // Main container - 3D transparent rectangular container
                // Main container - using container.png image (bigger size)
                SizedBox(
                  width: 320,
                  height: 480,
                  child: Stack(
                    children: [
                      // Container image
                      Image.asset(
                        'images/container.png',
                        width: 320,
                        height: 480,
                        fit: BoxFit.contain,
                      ),
                      // Water area for dropped objects (positioned over the water in the image)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 400, // Scaled proportionally for bigger container
                        child: Container(
                          // Transparent overlay to hold dropped objects
                          color: Colors.transparent,
                          child: _buildDroppedObjects(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Drop target overlay for collider box
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            height: 60,
            // Width matches the collider box (320px)
            child: DragTarget<GameObject>(
              onWillAccept: (object) {
                if (object == null) return false;
                // Don't accept if object is already placed or if another object is frozen
                if (_frozenObjectId != null && _frozenObjectId != object.id) {
                  return false;
                }
                return !(_objectPlaced[object.id] ?? false);
              },
              onAccept: (object) {
                // Freeze object in collider and show options
                setState(() {
                  _frozenObjectId = object.id; // Store frozen object ID
                  _draggingObjectId = object.id;
                  _showFloatSinkOptions = true;
                  _objectFrozenAtTop = true;
                  _lastColliderState = true;
                });
              },
              onMove: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.offset);
                // Check if in collider area (top 60px of the container area)
                final isInCollider = localPosition.dy >= 20 && localPosition.dy <= 80;
                
                // Only update state if it changed and no object is frozen (prevents excessive rebuilds)
                if (isInCollider != _lastColliderState && _frozenObjectId == null) {
                  _lastColliderState = isInCollider;
                  if (mounted) {
                    setState(() {
                      _draggingObjectId = details.data.id;
                      _showFloatSinkOptions = isInCollider;
                      _objectFrozenAtTop = isInCollider;
                    });
                  }
                }
              },
              onLeave: (object) {
                // Only clear if object is not frozen (just dragging over, not dropped)
                if (_lastColliderState && _frozenObjectId == null) {
                  _lastColliderState = false;
                  if (mounted) {
                    setState(() {
                      _showFloatSinkOptions = false;
                      _objectFrozenAtTop = false;
                    });
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: candidateData.isNotEmpty
                        ? Border.all(color: AppColors.freshGreen, width: 3)
                        : null,
                  ),
                );
              },
            ),
          ),
          // Drop target overlay for main container (for objects already placed)
          Positioned(
            top: 80, // Below collider
            left: 20,
            right: 20,
            bottom: 20,
            child: DragTarget<GameObject>(
              onWillAccept: (object) {
                if (object == null) return false;
                // Don't accept if object is frozen in collider (waiting for user choice)
                if (_frozenObjectId == object.id) {
                  return false;
                }
                return !(_objectPlaced[object.id] ?? false);
              },
              onAccept: (object) {
                // Only accept if not frozen in collider (collider objects are handled by button selection)
                if (_frozenObjectId != object.id) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final size = renderBox.size;
                  final center = Offset(size.width / 2, size.height / 2);
                  _onObjectDropped(object.id, center, true);
                }
              },
              onMove: (details) {
                // This is for the main container, not the collider
                // Removed setState call - no need to rebuild on every drag movement
                // Only handle if not frozen in collider
                if (_frozenObjectId != details.data.id) {
                  // Just track the drag, no state updates needed
                  _draggingObjectId = details.data.id;
                }
              },
              onLeave: (object) {
                if (object != null && _frozenObjectId != object.id) {
                  _onDragEnd();
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
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
    
    return RepaintBoundary(
      child: Stack(
        children: placedObjects.asMap().entries.map((entry) {
        final index = entry.key;
        final object = entry.value;
        final isCorrect = _objectCorrect[object.id]!;
        final floatChoice = _objectFloatChoice[object.id] ?? false;
        
        // Position objects: floating at top, sinking at bottom
        // Water area is 320px wide, 400px tall
        // Distribute horizontally for multiple objects
        final objectWidth = 75.0;
        final containerWidth = 320.0;
        final horizontalCenter = (containerWidth - objectWidth) / 2; // Center position: (320 - 75) / 2 = 122.5px
        final horizontalOffset = (placedObjects.length > 1) 
            ? (index - (placedObjects.length - 1) / 2) * 80.0 // Spacing for multiple objects
            : 0.0;
        
        // Base vertical position based on user's choice
        // Water area is 400px tall (positioned at bottom of 480px container)
        // Floating objects should be at the water surface (top of water area = 0)
        // Sinking objects: water area is 400px, object is 75px, so bottom position = 400 - 75 = 325px
        final baseVerticalPosition = floatChoice ? 0.0 : 5.0; // Float at surface (0), sink starts at 5px
        
        return Positioned(
          left: horizontalCenter + horizontalOffset, // Center horizontally, add offset for multiple objects
          top: baseVerticalPosition,
          child: _buildAnimatedObject(object, isCorrect, floatChoice, index),
        );
        }).toList(),
      ),
    );
  }
  
  Widget _buildAnimatedObject(GameObject object, bool isCorrect, bool floatChoice, int index) {
    // Float animation - realistic bobbing motion with Flame-optimized curves
    if (floatChoice) {
      // Only listen to scale animation if it's still animating
      final scaleAnimating = _scaleControllers[object.id]!.isAnimating;
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: scaleAnimating
              ? Listenable.merge([_floatControllers[object.id]!, _scaleControllers[object.id]!])
              : _floatControllers[object.id]!,
          builder: (context, child) {
            final floatValue = _floatControllers[object.id]!.value;
            final scaleValue = scaleAnimating 
                ? _scaleControllers[object.id]!.value 
                : 1.0;
            
            // Create smooth, subtle bobbing motion - floating on water surface
            // Use simple sine wave for natural water movement
            // Objects should float at the water surface (position 0) with gentle bobbing
            // Base position is 0 (water surface), add small bobbing motion (±1.5px)
            final verticalOffset = 0.0 + (math.sin(floatValue * 2 * math.pi) * 1.5); // 0px base + ±1.5px bobbing (on water surface)
            final horizontalOffset = (math.cos(floatValue * 2 * math.pi) * 1.5); // ±1.5 pixels - minimal drift
            final rotation = (math.sin(floatValue * 2 * math.pi) * 0.03); // Very gentle rotation
            
            // Smooth scale-in animation with bounce effect (only if animating)
            final scale = _scaleControllers[object.id]!.isAnimating
                ? 0.2 + (_elasticEaseOut(scaleValue) * 0.8)
                : 1.0;
          
          return Transform.translate(
            offset: Offset(horizontalOffset, verticalOffset),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                // Just the icon - no check/cancel icons
                child: _buildObjectIcon(object.id, size: 75),
              ),
            ),
          );
          },
        ),
      );
    } else {
      // Sink animation - smooth sinking to bottom with optimized curves
      final sinkAnimating = _sinkControllers[object.id]!.isAnimating;
      final scaleAnimating = _scaleControllers[object.id]!.isAnimating;
      final needsAnimation = sinkAnimating || scaleAnimating;
      
      return RepaintBoundary(
        child: needsAnimation
            ? AnimatedBuilder(
                animation: Listenable.merge([
                  if (sinkAnimating) _sinkControllers[object.id]!,
                  if (scaleAnimating) _scaleControllers[object.id]!,
                ]),
                builder: (context, child) {
                  final sinkValue = sinkAnimating 
                      ? _sinkControllers[object.id]!.value 
                      : 1.0;
                  final scaleValue = scaleAnimating 
                      ? _scaleControllers[object.id]!.value 
                      : 1.0;
            
                  // Smooth sinking motion with cubic easing for acceleration
                  // Water area is 400px tall, object height is 75px
                  // To keep object fully within water: use 200px to ensure it stays well within bounds
                  // Object bottom will be at 200+75=275px, leaving 125px margin from bottom (400px)
                  final easedSink = _cubicEaseIn(sinkValue);
                  final verticalOffset = 5.0 + (easedSink * 195.0); // Start at 5px, sink to 200px (well within water area)
                  final opacity = 1.0 - (easedSink * 0.1); // Minimal fade as it sinks
                  final sinkScale = 1.0 - (easedSink * 0.05); // Very slight shrink as it sinks
                  
                  // Smooth scale-in animation with bounce (only if animating)
                  final initialScale = scaleAnimating
                      ? 0.2 + (_elasticEaseOut(scaleValue) * 0.8)
                      : 1.0;
                  final finalScale = initialScale * sinkScale;
                
                  return Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: finalScale,
                        // Add blue underwater tint - stronger as object sinks deeper (matrix filter tints only image, no background)
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            1.0, 0.0, 0.0, 0.0, 0.0, // Red channel
                            0.0, 0.8 + (easedSink * 0.1), 0.0, 0.0, 0.0, // Green channel (reduced for blue tint)
                            0.0, 0.0, 1.0 + (easedSink * 0.2), 0.0, 0.0, // Blue channel (enhanced)
                            0.0, 0.0, 0.0, 1.0, 0.0, // Alpha channel (unchanged - no background)
                          ]),
                          child: _buildObjectIcon(object.id, size: 75),
                        ),
                      ),
                    ),
                  );
                },
              )
            : _buildStaticSunkObject(object, isCorrect),
      );
    }
  }
  
  // Static widget for objects that have finished sinking (no animation overhead)
  Widget _buildStaticSunkObject(GameObject object, bool isCorrect) {
    return Transform.translate(
      offset: const Offset(0, 200.0), // At bottom of water area with safe margin (object bottom at 275px, well within 400px)
      child: Opacity(
        opacity: 0.9,
        child: Transform.scale(
          scale: 0.95,
          // Add blue underwater tint for fully sunk objects (matrix filter tints only image, no background)
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              1.0, 0.0, 0.0, 0.0, 0.0, // Red channel
              0.0, 0.7, 0.0, 0.0, 0.0, // Green channel (reduced for blue tint)
              0.0, 0.0, 1.2, 0.0, 0.0, // Blue channel (enhanced)
              0.0, 0.0, 0.0, 1.0, 0.0, // Alpha channel (unchanged - no background)
            ]),
            child: _buildObjectIcon(object.id, size: 75),
          ),
        ),
      ),
    );
  }
  
  // Smooth easing functions inspired by Flame's animation curves
  // These provide smoother, more natural motion than standard Flutter curves
  double _cubicEaseIn(double t) {
    return t * t * t;
  }
  
  // Elastic ease-out for bounce effect (inspired by Flame's animation system)
  double _elasticEaseOut(double t) {
    if (t == 0 || t == 1) return t;
    final p = 0.3;
    final s = p / 4;
    return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1;
  }
  
  Widget _buildObjectInCollider() {
    // Show object if it's frozen in collider or currently being dragged over it
    final objectIdToShow = _frozenObjectId ?? _draggingObjectId;
    if (objectIdToShow == null) {
      return const SizedBox.shrink();
    }
    
    final object = _objects.firstWhere((o) => o.id == objectIdToShow);
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.transparent, // No white background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.freshGreen,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildObjectIcon(object.id, size: 30),
    );
  }
  
  Widget _buildFloatSinkOptions(String objectId) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.primaryBlue, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _buildOptionButton(
                label: 'Float',
                icon: Icons.water_drop_outlined,
                color: AppColors.primaryBlue,
                onTap: () {
                  _onOptionSelected(objectId, true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: _buildOptionButton(
                label: 'Sink',
                icon: Icons.arrow_downward_rounded,
                color: Colors.orange,
                onTap: () {
                  _onOptionSelected(objectId, false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.cardTitle(fontSize: 14, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeedbackBoard() {
    final isCorrect = _lastAnswerCorrect ?? false;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isCorrect ? AppColors.freshGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCorrect ? AppColors.freshGreen : Colors.red,
            width: 3,
          ),
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
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect ? AppColors.freshGreen : Colors.red,
              size: 60,
            ),
            const SizedBox(height: 12),
            Text(
              _feedbackMessage ?? '',
              style: AppTypography.cardTitle(
                fontSize: 24,
                color: isCorrect ? AppColors.freshGreen : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Objects',
            style: AppTypography.cardTitle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          // Grid so all 5 objects (ball, rock, sponge, paper, leaf) are visible
          // Use shrinkWrap to size based on content, not fixed height
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Disable grid scroll, let parent scroll
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              // Higher ratio = shorter cells (0.85 = cells are wider/shorter)
              childAspectRatio: 0.85,
            ),
            itemCount: _objects.length,
              itemBuilder: (context, index) {
                final object = _objects[index];
                final isPlaced = _objectPlaced[object.id] == true;
                final isFrozen = _frozenObjectId == object.id;

                return Draggable<GameObject>(
                    data: object,
                    feedback: isFrozen 
                        ? const SizedBox.shrink() 
                        : Material(
                            color: Colors.transparent,
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                color: Colors.transparent, // No white background
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildObjectIcon(object.id, size: 45),
                            ),
                          ),
                    onDragStarted: () {
                      // Don't allow dragging if frozen
                      if (!isFrozen) {
                        setState(() {
                          _draggingObjectId = object.id;
                        });
                      }
                    },
                    onDragEnd: (details) {
                      // Don't call _onDragEnd if object is frozen - it should stay frozen
                      // Only call if object was being dragged but not frozen
                      if (!isFrozen && _frozenObjectId == null) {
                        _onDragEnd();
                      }
                    },
                    childWhenDragging: isFrozen 
                        ? _buildObjectCard(object, isPlaced, isFrozen: true)
                        : Opacity(
                            opacity: 0.3,
                            child: _buildObjectCard(object, isPlaced),
                          ),
                    child: _buildObjectCard(object, isPlaced, isFrozen: isFrozen),
                  );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildObjectCard(GameObject object, bool isPlaced, {bool isFrozen = false}) {
    return Container(
      padding: const EdgeInsets.all(6), // Further reduced to fit better
      decoration: BoxDecoration(
        color: isFrozen 
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : (isPlaced ? Colors.grey.shade200 : AppColors.backgroundCard),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFrozen 
              ? AppColors.primaryBlue
              : (isPlaced ? Colors.grey.shade300 : Colors.grey.shade200),
          width: isFrozen ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 45, // Slightly smaller
            height: 45, // Slightly smaller
            decoration: BoxDecoration(
              color: Colors.transparent, // No white background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildObjectIcon(object.id, size: 28), // Slightly smaller icon
          ),
          const SizedBox(height: 4), // Reduced spacing
          Text(
            object.name,
            style: AppTypography.body(fontSize: 10), // Smaller font
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isPlaced)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _objectCorrect[object.id] == true
                    ? Icons.check_circle
                    : Icons.cancel,
                size: 12, // Smaller icon
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

  /// Paths by id so icons work even when Draggable carries a stale GameObject
  /// (e.g. after hot reload) where assetPath can be null.
  static const Map<String, String> _objectAssetPaths = {
    'ball': 'images/ball.png',
    'rock': 'images/rock.png',
    'sponge': 'images/sponge.png',
    'paper': 'images/paper.png',
    'leaf': 'images/leaf.png',
  };

  Widget _buildObjectIcon(String objectId, {double size = 30}) {
    final path = _objectAssetPaths[objectId];
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_not_supported_outlined,
            size: size,
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }
    return Icon(
      Icons.help_outline_rounded,
      size: size,
      color: AppColors.primaryBlue,
    );
  }

}

class GameObject {
  final String id;
  final String name;
  /// Nullable so stale instances after hot reload don't throw when read as String.
  final String? assetPath;
  final bool sinks; // true if sinks, false if floats

  GameObject({
    required this.id,
    required this.name,
    this.assetPath,
    required this.sinks,
  });
}
