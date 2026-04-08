import 'package:flutter/foundation.dart';

enum UserRole { student, teacher }

enum Grade { lkg, ukg, grade4, grade5 }

extension GradeX on Grade {
  String get label {
    switch (this) {
      case Grade.lkg:
        return 'LKG';
      case Grade.ukg:
        return 'UKG';
      case Grade.grade4:
        return '4th Grade';
      case Grade.grade5:
        return '5th Grade';
    }
  }

  bool get isLowerGrade => this == Grade.lkg || this == Grade.ukg;
}

class GameInfo {
  final String id;
  final String name;
  final String difficulty; // e.g. "Easy", "Medium"
  final int order;

  const GameInfo({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.order,
  });
}

class GameProgress {
  bool completed;
  int? score;
  int? stars;
  Duration? timeSpent;
  DateTime? startedAt;
  DateTime? completedAt;

  GameProgress({
    this.completed = false,
    this.score,
    this.stars,
    this.timeSpent,
    this.startedAt,
    this.completedAt,
  });
}

/// Pilot: in-memory state. LKG/UKG = 5 games each, all unlocked. 4th/5th = sequential unlock.
class AppState extends ChangeNotifier {
  String? _userEmailOrPhone;
  UserRole? _role;
  Grade? _selectedGrade;

  String? get userEmailOrPhone => _userEmailOrPhone;
  UserRole? get role => _role;
  Grade? get selectedGrade => _selectedGrade;

  void setUser(String emailOrPhone) {
    _userEmailOrPhone = emailOrPhone;
    notifyListeners();
  }

  void setRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void setSelectedGrade(Grade? grade) {
    _selectedGrade = grade;
    notifyListeners();
  }

  void logout() {
    _userEmailOrPhone = null;
    _role = null;
    _selectedGrade = null;
    _progress.clear();
    _studentProgress.clear();
    notifyListeners();
  }

  // Per-grade game progress (for current student)
  final Map<Grade, Map<String, GameProgress>> _progress = {};

  Map<String, GameProgress> progressFor(Grade grade) {
    return _progress[grade] ??= {};
  }

  List<GameInfo> gamesFor(Grade grade) {
    switch (grade) {
      case Grade.lkg:
        return const [
          GameInfo(id: 'lkg1', name: 'Shapes & Colors', difficulty: 'Easy', order: 1),
          GameInfo(id: 'lkg2', name: 'Count the Objects', difficulty: 'Easy', order: 2),
          GameInfo(id: 'lkg3', name: 'Match the Picture', difficulty: 'Easy', order: 3),
          GameInfo(id: 'lkg4', name: 'Alphabet with Color Pop', difficulty: 'Easy', order: 4),
          GameInfo(id: 'lkg5', name: 'Sentence Builder', difficulty: 'Easy', order: 5),
        ];
      case Grade.ukg:
        return const [
          GameInfo(id: 'ukg1', name: 'Letter Sounds', difficulty: 'Easy', order: 1),
          GameInfo(id: 'ukg2', name: 'Simple Addition', difficulty: 'Easy', order: 2),
          GameInfo(id: 'ukg3', name: 'What Comes Next?', difficulty: 'Medium', order: 3),
          GameInfo(id: 'ukg4', name: 'Alphabet with Color Pop', difficulty: 'Easy', order: 4),
          GameInfo(id: 'ukg5', name: 'Sentence Builder', difficulty: 'Easy', order: 5),
        ];
      case Grade.grade4:
        return const [
          GameInfo(id: 'g41', name: 'Math Battle: Basics', difficulty: 'Easy', order: 1),
          GameInfo(id: 'g42', name: 'Math Adventure', difficulty: 'Medium', order: 2),
          GameInfo(id: 'g43', name: 'Math Master Challenge', difficulty: 'Hard', order: 3),
          GameInfo(id: 'g4sci1', name: 'Plants Around Us', difficulty: 'Easy', order: 4),
          GameInfo(id: 'g4sci2', name: 'Food Match', difficulty: 'Medium', order: 5),
          GameInfo(id: 'g4sci3', name: 'States of Matter', difficulty: 'Hard', order: 6),
        ];
      case Grade.grade5:
        return const [
          GameInfo(id: 'g51', name: 'Math Battle: Basics', difficulty: 'Easy', order: 1),
          GameInfo(id: 'g52', name: 'Math Adventure', difficulty: 'Medium', order: 2),
          GameInfo(id: 'g53', name: 'Math Master Challenge', difficulty: 'Hard', order: 3),
          GameInfo(id: 'g5sci1', name: 'Plants Around Us', difficulty: 'Easy', order: 4),
          GameInfo(id: 'g5sci2', name: 'Food Match', difficulty: 'Medium', order: 5),
          GameInfo(id: 'g5sci3', name: 'States of Matter', difficulty: 'Hard', order: 6),
        ];
    }
  }

  bool isGameUnlocked(Grade grade, String gameId) {
    if (grade.isLowerGrade) return true;
    final games = gamesFor(grade);
    final prog = progressFor(grade);
    final index = games.indexWhere((g) => g.id == gameId);
    if (index <= 0) return true;
    final prev = games[index - 1];
    return prog[prev.id]?.completed ?? false;
  }

  void startGame(Grade grade, String gameId) {
    final p = progressFor(grade);
    p[gameId] = GameProgress(startedAt: DateTime.now());
    notifyListeners();
  }

  void completeGame(Grade grade, String gameId, {int score = 0, int stars = 3, Duration? timeSpent}) {
    final p = progressFor(grade);
    final existing = p[gameId];
    p[gameId] = GameProgress(
      completed: true,
      score: score,
      stars: stars,
      timeSpent: timeSpent ?? (existing?.startedAt != null ? DateTime.now().difference(existing!.startedAt!) : null),
      startedAt: existing?.startedAt,
      completedAt: DateTime.now(),
    );
    notifyListeners();
  }

  GameProgress? getGameProgress(Grade grade, String gameId) => progressFor(grade)[gameId];

  // Student progress for teacher dashboard (pilot: mock + current user as one student)
  final List<StudentProgressSummary> _studentProgress = [];

  List<StudentProgressSummary> get studentProgressList {
    if (_studentProgress.isEmpty) {
      _studentProgress.addAll(_mockStudents());
      final current = _currentStudentSummary();
      if (current != null && !_studentProgress.any((s) => s.name == 'You')) {
        _studentProgress.insert(0, current);
      }
    }
    return _studentProgress;
  }

  StudentProgressSummary? _currentStudentSummary() {
    if (_userEmailOrPhone == null) return null;
    int totalGames = 0, completed = 0;
    Duration totalTime = Duration.zero;
    for (final g in Grade.values) {
      final games = gamesFor(g);
      final p = progressFor(g);
      for (final game in games) {
        totalGames++;
        final prog = p[game.id];
        if (prog?.completed == true) {
          completed++;
          if (prog!.timeSpent != null) totalTime += prog.timeSpent!;
        }
      }
    }
    final pct = totalGames > 0 ? (completed / totalGames * 100).round() : 0;
    return StudentProgressSummary(
      name: 'You',
      gamesCompleted: completed,
      totalGames: totalGames,
      progressPercent: pct,
      timeSpent: totalTime,
    );
  }

  List<StudentProgressSummary> _mockStudents() {
    return [
      StudentProgressSummary(name: 'Riya', gamesCompleted: 5, totalGames: 12, progressPercent: 42, timeSpent: const Duration(minutes: 45)),
      StudentProgressSummary(name: 'Arjun', gamesCompleted: 8, totalGames: 12, progressPercent: 67, timeSpent: const Duration(minutes: 62)),
      StudentProgressSummary(name: 'Sana', gamesCompleted: 3, totalGames: 12, progressPercent: 25, timeSpent: const Duration(minutes: 28)),
      StudentProgressSummary(name: 'Vikram', gamesCompleted: 11, totalGames: 12, progressPercent: 92, timeSpent: const Duration(minutes: 95)),
    ];
  }

  int get totalStudents => studentProgressList.length;
  int get totalGamesCompleted => studentProgressList.fold(0, (s, e) => s + e.gamesCompleted);
  int get averageProgressPercent {
    final list = studentProgressList;
    if (list.isEmpty) return 0;
    return (list.fold(0, (s, e) => s + e.progressPercent) / list.length).round();
  }

  /// Which games completed most (for teacher) – pilot: mock + current user
  Map<String, int> get gameCompletionCounts {
    final counts = <String, int>{};
    for (final g in Grade.values) {
      for (final game in gamesFor(g)) {
        if (getGameProgress(g, game.id)?.completed == true) {
          counts[game.name] = (counts[game.name] ?? 0) + 1;
        }
      }
    }
    const mockCompletions = {
      'Shapes & Colors': 4,
      'Count the Objects': 3,
      'Letter Sounds': 4,
      'Simple Addition': 3,
      'Math Battle: Basics': 2,
      'Math Adventure': 2,
    };
    for (final e in mockCompletions.entries) {
      counts[e.key] = (counts[e.key] ?? 0) + e.value;
    }
    return counts;
  }
}

class StudentProgressSummary {
  final String name;
  final int gamesCompleted;
  final int totalGames;
  final int progressPercent;
  final Duration timeSpent;

  StudentProgressSummary({
    required this.name,
    required this.gamesCompleted,
    required this.totalGames,
    required this.progressPercent,
    required this.timeSpent,
  });
}
