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
    // Extra items: emoji visuals (no new image assets required)
    GameObject(id: 'star', name: 'Star', sinks: false),
    GameObject(id: 'feather', name: 'Feather', sinks: false),
    GameObject(id: 'coin', name: 'Coin', sinks: true),
    GameObject(id: 'apple', name: 'Apple', sinks: false),
    GameObject(id: 'duck', name: 'Duck', sinks: false),
    GameObject(id: 'key', name: 'Key', sinks: true),
    GameObject(id: 'balloon', name: 'Balloon', sinks: false),
    GameObject(id: 'brick', name: 'Brick', sinks: true),
    GameObject(id: 'paperclip', name: 'Paperclip', sinks: true),
    GameObject(id: 'orange', name: 'Orange', sinks: false),
    GameObject(id: 'lifebuoy', name: 'Lifebuoy', sinks: false),
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
  final Map<String, AnimationController> _dropControllers = {};
  String? _lastDroppedObject;
  
  // Track drag position for showing options
  String? _draggingObjectId;
  bool _showFloatSinkOptions = false;
  bool? _pendingFloatChoice; // Stores user's choice before drop
  String? _pendingObjectId; // Object ID for pending choice
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

      _dropControllers[obj.id] = AnimationController(
        duration: const Duration(milliseconds: 520), // Snappy drop into water
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
    for (var controller in _dropControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onObjectDropped(
    String objectId,
    Offset position,
    bool isInWater, {
    bool? floatChoice,
  }) {
    // Stop any running animations for this object before replaying
    _floatControllers[objectId]?.stop();
    _sinkControllers[objectId]?.stop();
    _scaleControllers[objectId]?.stop();
    _dropControllers[objectId]?.stop();

    setState(() {
      _objectPositions[objectId] = position;
      _objectPlaced[objectId] = true;
      _lastDroppedObject = objectId;
      _showFloatSinkOptions = false;
      _draggingObjectId = null;
      _frozenObjectId = null;
      _lastColliderState = false;
      
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
      
      // Scale-in + drop first, then float or sink.
      _scaleControllers[objectId]?.forward(from: 0).then((_) => _scaleControllers[objectId]?.stop());
      _dropControllers[objectId]?.forward(from: 0).then((_) {
        _dropControllers[objectId]?.stop();
        if (!mounted) return;
        // Physics: floaters bob, sinkers sink (only reached after a correct prediction from buttons).
        final physicallyFloats = !object.sinks;
        if (physicallyFloats) {
          _floatControllers[objectId]?.repeat(reverse: true);
        } else {
          _sinkControllers[objectId]?.forward(from: 0).then((_) => _sinkControllers[objectId]?.stop());
        }
      });
      
      if (isCorrect) {
        _score += 20;
        _successController.forward(from: 0);
      }
      
      _totalPlaced++;
      
      // Avoid ending the game while answer feedback is being shown.
      // The option-selection flow handles completion after feedback.
      if (_totalPlaced == _objects.length && !_showingFeedback) {
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

    if (!isCorrect) {
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = false;
        _feedbackMessage = 'Try again';
        _showFloatSinkOptions = false;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _showingFeedback = false;
          _feedbackMessage = null;
          _lastAnswerCorrect = null;
          _showFloatSinkOptions = true;
          _frozenObjectId = objectId;
          _draggingObjectId = objectId;
        });
      });
      return;
    }

    setState(() {
      _showingFeedback = true;
      _lastAnswerCorrect = true;
      _feedbackMessage = 'Correct!';
      _showFloatSinkOptions = false;
    });

    _onObjectDropped(objectId, const Offset(0, 0), true, floatChoice: floatChoice);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showingFeedback = false;
        _feedbackMessage = null;
        _lastAnswerCorrect = null;
      });

      if (_currentObjectIndex < _objects.length - 1) {
        _currentObjectIndex++;
        _showNextObject();
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _gameCompleted = true;
            });
          }
        });
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
        _dropControllers[obj.id]?.reset();
      }
      _score = 0;
      _totalPlaced = 0;
      _gameCompleted = false;
      _lastDroppedObject = null;
      _showFloatSinkOptions = false;
      _draggingObjectId = null;
      _pendingFloatChoice = null;
      _pendingObjectId = null;
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 360,
                              height: 610,
                              child: _buildWaterGlass(),
                            ),
                          ),
                        ),
                      ),
                      // Show Float/Sink buttons below container when object is frozen or in collider
                      if (_showFloatSinkOptions &&
                          !_showingFeedback &&
                          (_frozenObjectId != null || _draggingObjectId != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildFloatSinkOptions(_frozenObjectId ?? _draggingObjectId!),
                        ),
                      // Show feedback board when showing feedback
                      if (_showingFeedback && _feedbackMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildFeedbackBoard(),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
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
    final promptObjectId = _frozenObjectId ?? _draggingObjectId;
    final promptObjectName = promptObjectId != null
        ? _objects.firstWhere((o) => o.id == promptObjectId).name
        : 'this object';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Stack(
        children: [
          // Water glass container
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hidden collider UI area: keep functionality, show prompt + object preview.
                Container(
                  width: 320,
                  height: 90,
                  color: Colors.transparent,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Will $promptObjectName float or sink?',
                          style: AppTypography.cardTitle(
                            fontSize: 16,
                            color: AppColors.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (promptObjectId != null) ...[
                          const SizedBox(height: 6),
                          _buildObjectIcon(promptObjectId, size: 34),
                        ],
                      ],
                    ),
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
                          // Inset + clip so objects stay inside the glass interior.
                          child: ClipRect(
                            child: Padding(
                              // Tuned to keep objects inside the container.png glass walls/rim.
                              // Increase bottom inset to avoid the image's transparent "base" area.
                              padding: const EdgeInsets.fromLTRB(50, 44, 50, 92),
                              child: _buildDroppedObjects(),
                            ),
                          ),
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
            height: 90,
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
                  _lastColliderState = true;
                });
              },
              onMove: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.offset);
                // Check if in collider area (top 90px of the container area)
                final isInCollider = localPosition.dy >= 20 && localPosition.dy <= 110;
                
                // Only update state if it changed and no object is frozen (prevents excessive rebuilds)
                if (isInCollider != _lastColliderState && _frozenObjectId == null) {
                  _lastColliderState = isInCollider;
                  if (mounted) {
                    setState(() {
                      _draggingObjectId = details.data.id;
                      _showFloatSinkOptions = isInCollider;
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
            top: 110, // Below collider
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
    
    return LayoutBuilder(
      builder: (context, constraints) {
        const objectSize = 75.0;
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        // Tighten spacing when many objects so they stay inside the glass.
        final n = placedObjects.length;
        final spacing = n <= 1
            ? 0.0
            : math.min(64.0, math.max(22.0, (maxW - objectSize - 6) / (n - 1)));

        double clampDouble(double v, double min, double max) {
          if (max < min) return min;
          if (v < min) return min;
          if (v > max) return max;
          return v;
        }

        return RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: placedObjects.asMap().entries.map((entry) {
              final index = entry.key;
              final object = entry.value;
              final isCorrect = _objectCorrect[object.id]!;
              // Visual motion follows physics, not the child's wrong button choice.
              final physicallyFloats = !object.sinks;

              // Horizontal layout: center then distribute, but always clamp into interior bounds.
              final horizontalCenter = (maxW - objectSize) / 2;
              final horizontalOffset = (placedObjects.length > 1)
                  ? (index - (placedObjects.length - 1) / 2) * spacing
                  : 0.0;
              final left = clampDouble(horizontalCenter + horizontalOffset, 0.0, maxW - objectSize);

              // Vertical base: keep a small top margin so floating bob doesn't cross the rim.
              final top = physicallyFloats ? 2.0 : 5.0;

              return Positioned(
                left: left,
                top: top,
                child: _buildAnimatedObject(
                  object,
                  isCorrect,
                  physicallyFloats,
                  index,
                  waterHeight: maxH,
                  objectSize: objectSize,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  Widget _buildAnimatedObject(
    GameObject object,
    bool isCorrect,
    bool animateAsFloat,
    int index, {
    required double waterHeight,
    required double objectSize,
  }) {
    // Drop from just above the water surface into it.
    const dropDistance = 62.0;

    // Float animation - realistic bobbing motion with Flame-optimized curves
    if (animateAsFloat) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _floatControllers[object.id]!,
            _scaleControllers[object.id]!,
            _dropControllers[object.id]!,
          ]),
          builder: (context, child) {
            final floatValue = _floatControllers[object.id]!.value;
            final scaleValue = _scaleControllers[object.id]!.value;
            final dropValue = _dropControllers[object.id]!.value;
            final dropEase = Curves.easeIn.transform(dropValue);
            final dropYOffset = (-dropDistance) * (1.0 - dropEase);
            
            // Create smooth, subtle bobbing motion - floating on water surface
            // Use simple sine wave for natural water movement
            // Objects should float at the water surface (position 0) with gentle bobbing
            // Base position is 0 (water surface), add small bobbing motion (±1.5px)
            final verticalOffset = dropYOffset + (math.sin(floatValue * 2 * math.pi) * 1.5);
            final horizontalOffset = (math.cos(floatValue * 2 * math.pi) * 1.5); // ±1.5 pixels - minimal drift
            final rotation = (math.sin(floatValue * 2 * math.pi) * 0.03); // Very gentle rotation
            
            // Use controller value directly so animation is seamless across frame boundaries.
            final scale = 0.2 + (_elasticEaseOut(scaleValue) * 0.8);
          
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
      return RepaintBoundary(
        child: AnimatedBuilder(
                animation: Listenable.merge([
                  _sinkControllers[object.id]!,
                  _scaleControllers[object.id]!,
                  _dropControllers[object.id]!,
                ]),
                builder: (context, child) {
                  final sinkAnimating = _sinkControllers[object.id]!.isAnimating;
                  final sinkValue = _sinkControllers[object.id]!.value;
                  final scaleValue = _scaleControllers[object.id]!.value;
                  final dropValue = _dropControllers[object.id]!.value;
                  final dropEase = Curves.easeIn.transform(dropValue);
                  final dropYOffset = (-dropDistance) * (1.0 - dropEase);
            
                  // Smooth sinking motion with cubic easing for acceleration
                  // Keep the object fully inside the available clipped water area.
                  final easedSink = _cubicEaseIn(sinkValue);
                  const startY = 5.0;
                  final maxSink = math.max(0.0, (waterHeight - objectSize) - startY);
                  final verticalOffset = dropYOffset + startY + (easedSink * maxSink);
                  final opacity = 1.0 - (easedSink * 0.1); // Minimal fade as it sinks
                  final sinkScale = 1.0 - (easedSink * 0.05); // Very slight shrink as it sinks
                  
                  // Use controller value directly so drop->sink transition cannot miss frames.
                  final initialScale = 0.2 + (_elasticEaseOut(scaleValue) * 0.8);
                  final finalScale = initialScale * sinkScale;
                
                  return Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: finalScale,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Add blue underwater tint - stronger as object sinks deeper (matrix filter tints only image, no background)
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix([
                                1.0, 0.0, 0.0, 0.0, 0.0, // Red channel
                                0.0, 0.8 + (easedSink * 0.1), 0.0, 0.0, 0.0, // Green channel (reduced for blue tint)
                                0.0, 0.0, 1.0 + (easedSink * 0.2), 0.0, 0.0, // Blue channel (enhanced)
                                0.0, 0.0, 0.0, 1.0, 0.0, // Alpha channel (unchanged - no background)
                              ]),
                              child: _buildObjectIcon(object.id, size: 75),
                            ),
                            if (sinkAnimating && sinkValue > 0.03) _buildSinkBubbles(sinkValue),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      );
    }
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

  Widget _buildSinkBubbles(double sinkValue) {
    final v = sinkValue.clamp(0.0, 1.0);
    final bubbleOpacity = (v * 1.15).clamp(0.0, 0.85);
    final rise = 26.0 * v;

    return IgnorePointer(
      child: Opacity(
        opacity: bubbleOpacity,
        child: SizedBox(
          width: 75,
          height: 75,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildBubble(size: 7, left: 8, top: 16 - rise),
              _buildBubble(size: 5, left: 22, top: 6 - (rise * 0.7)),
              _buildBubble(size: 6, left: 48, top: 12 - (rise * 0.9)),
              _buildBubble(size: 4, left: 60, top: 20 - (rise * 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble({
    required double size,
    required double left,
    required double top,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.75),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 0.8,
          ),
        ),
      ),
    );
  }
  
  Widget _buildFloatSinkOptions(String objectId) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
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
            Text(
              label,
              style: AppTypography.cardTitle(fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeedbackBoard() {
    final isCorrect = _lastAnswerCorrect ?? false;
    final isRetry = !isCorrect && _feedbackMessage == 'Try again';
    final accent = isCorrect
        ? AppColors.freshGreen
        : (isRetry ? const Color(0xFFFF9800) : Colors.red);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent,
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
              isCorrect
                  ? Icons.check_circle_rounded
                  : (isRetry ? Icons.touch_app_rounded : Icons.cancel_rounded),
              color: accent,
              size: 60,
            ),
            const SizedBox(height: 12),
            Text(
              _feedbackMessage ?? '',
              style: AppTypography.cardTitle(
                fontSize: 24,
                color: accent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            color: Colors.white,
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

  /// Objects shown as emoji (clearly different shapes from ball / photos).
  static const Map<String, String> _objectEmojis = {
    'star': '⭐',
    'feather': '🪶',
    'coin': '🪙',
    'apple': '🍎',
    'duck': '🦆',
    'key': '🔑',
    'balloon': '🎈',
    'brick': '🧱',
    'paperclip': '📎',
    'orange': '🍊',
    'lifebuoy': '🛟',
  };

  Widget _buildObjectIcon(String objectId, {double size = 30}) {
    final emoji = _objectEmojis[objectId];
    if (emoji != null && emoji.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: size * 0.62, height: 1),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
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
