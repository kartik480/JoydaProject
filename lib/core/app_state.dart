import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'joyda_auth_store.dart';

String _randomSalt() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return base64UrlEncode(bytes);
}

String _hashPassword(String salt, String password) {
  return sha256.convert(utf8.encode('$salt::$password')).toString();
}

UserRole? _userRoleFromStored(dynamic raw) {
  if (raw is! String) return null;
  final v = raw.trim().toLowerCase();
  switch (v) {
    case 'student':
      return UserRole.student;
    case 'teacher':
      return UserRole.teacher;
    default:
      return null;
  }
}

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

/// Pilot: in-memory state. All grades: every listed game is unlocked on the games screen.
class AppState extends ChangeNotifier {
  String? _userEmailOrPhone;
  String? _userDisplayName;
  UserRole? _role;
  Grade? _selectedGrade;

  String? get userEmailOrPhone => _userEmailOrPhone;
  /// Full name from sign-up (e.g. "Priya Sharma"); used for greetings.
  String? get userDisplayName => _userDisplayName;
  UserRole? get role => _role;
  Grade? get selectedGrade => _selectedGrade;

  /// Name shown after "Hi, …" on the student home panel.
  String get userGreetingName =>
      (_userDisplayName != null && _userDisplayName!.trim().isNotEmpty)
          ? _userDisplayName!.trim()
          : (_userEmailOrPhone?.trim().isNotEmpty == true ? _userEmailOrPhone!.trim() : 'Student');

  /// Persists profile (username + password hash) and sets the current session.
  /// Returns `null` on success, or an error message (e.g. username already taken).
  Future<String?> registerAccount({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final u = username.trim();
    final key = u.toLowerCase();
    final display = '${firstName.trim()} ${lastName.trim()}'.trim();
    final raw = await loadJoydaAuthProfilesJson();
    final map = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            map[e.key.toString().toLowerCase()] = e.value;
          }
        }
      } catch (_) {}
    }
    final existing = map[key];
    if (existing is Map) {
      final em = Map<String, dynamic>.from(existing);
      final hasPwd = (em['passwordHash'] is String && (em['passwordHash'] as String).isNotEmpty) &&
          (em['salt'] is String && (em['salt'] as String).isNotEmpty);
      if (hasPwd) {
        return 'That username is already taken. Log in or pick another username.';
      }
    } else if (existing != null) {
      return 'That username is already taken. Log in or pick another username.';
    }
    final salt = _randomSalt();
    final passwordHash = _hashPassword(salt, password);
    final emailTrim = email.trim();
    _userEmailOrPhone = u;
    _userDisplayName = display.isNotEmpty ? display : u;
    _role = role;
    map[key] = {
      'displayName': _userDisplayName,
      'email': emailTrim,
      'role': role.name,
      'salt': salt,
      'passwordHash': passwordHash,
    };
    final encoded = jsonEncode(map);
    final saveErr = await saveJoydaAuthProfilesJson(encoded);
    if (saveErr != null) {
      return saveErr;
    }
    notifyListeners();
    return null;
  }

  /// Verifies username or email + password against saved sign-up data, then starts session.
  /// Returns `null` on success, or an error message.
  Future<String?> loginAccount(String username, String password) async {
    final u = username.trim();
    final key = u.toLowerCase();
    final raw = await loadJoydaAuthProfilesJson();
    Map<String, dynamic>? entry;
    String? resolvedUsernameKey;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final root = decoded.map((k, v) => MapEntry(k.toString().toLowerCase(), v));
          final byName = root[key];
          if (byName is Map) {
            entry = byName.map((k, v) => MapEntry(k.toString(), v));
            resolvedUsernameKey = key;
          } else {
            for (final e in root.entries) {
              if (e.value is! Map) continue;
              final pm = (e.value as Map).map((k, v) => MapEntry(k.toString(), v));
              final em = pm['email'];
              if (em is String && em.trim().toLowerCase() == key) {
                entry = pm;
                resolvedUsernameKey = e.key;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }
    if (entry == null) {
      return 'No account found for that username or email.';
    }
    final salt = entry['salt'] as String?;
    final storedHash = entry['passwordHash'] as String?;
    if (salt == null || storedHash == null || salt.isEmpty || storedHash.isEmpty) {
      return 'This account has no saved password. Please sign up again.';
    }
    if (_hashPassword(salt, password) != storedHash) {
      return 'Incorrect password.';
    }
    _userEmailOrPhone = resolvedUsernameKey ?? u;
    final d = entry['displayName'];
    if (d is String && d.trim().isNotEmpty) {
      _userDisplayName = d.trim();
    } else {
      _userDisplayName = u;
    }
    _role = _userRoleFromStored(entry['role']);
    notifyListeners();
    return null;
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
    _userDisplayName = null;
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
        ];
      case Grade.ukg:
        return const [
          GameInfo(id: 'ukg1', name: 'Letter Sounds', difficulty: 'Easy', order: 1),
          GameInfo(id: 'ukg2', name: 'Simple Addition', difficulty: 'Easy', order: 2),
          GameInfo(id: 'ukg3', name: 'What Comes Next?', difficulty: 'Medium', order: 3),
          GameInfo(id: 'ukg4', name: 'Alphabet with Color Pop', difficulty: 'Easy', order: 4),
        ];
      case Grade.grade4:
        return const [
          GameInfo(id: 'g41', name: 'Math Battle: Basics', difficulty: 'Easy', order: 1),
          GameInfo(id: 'g42', name: 'Math Adventure', difficulty: 'Medium', order: 2),
          GameInfo(id: 'g43', name: 'Math Master Challenge', difficulty: 'Hard', order: 3),
          GameInfo(id: 'g4sci1', name: 'Plants Around Us', difficulty: 'Easy', order: 4),
          GameInfo(id: 'g4sci2', name: 'Food Match', difficulty: 'Medium', order: 5),
          GameInfo(id: 'g4sci3', name: 'States of Matter', difficulty: 'Hard', order: 6),
          GameInfo(id: 'g4exp1', name: 'India Map Challenge', difficulty: 'Medium', order: 7),
          GameInfo(id: 'g4exp2', name: 'Float or Sink?', difficulty: 'Medium', order: 8),
          GameInfo(id: 'g4eng1', name: 'Sentence Builder', difficulty: 'Medium', order: 9),
        ];
      case Grade.grade5:
        return const [
          GameInfo(id: 'g51', name: 'Math Battle: Basics', difficulty: 'Easy', order: 1),
          GameInfo(id: 'g52', name: 'Math Adventure', difficulty: 'Medium', order: 2),
          GameInfo(id: 'g53', name: 'Math Master Challenge', difficulty: 'Hard', order: 3),
          GameInfo(id: 'g5sci1', name: 'Plants Around Us', difficulty: 'Easy', order: 4),
          GameInfo(id: 'g5sci2', name: 'Food Match', difficulty: 'Medium', order: 5),
          GameInfo(id: 'g5sci3', name: 'States of Matter', difficulty: 'Hard', order: 6),
          GameInfo(id: 'g5exp1', name: 'India Map Challenge', difficulty: 'Medium', order: 7),
          GameInfo(id: 'g5exp2', name: 'Float or Sink?', difficulty: 'Medium', order: 8),
          GameInfo(id: 'g5eng1', name: 'Sentence Builder', difficulty: 'Medium', order: 9),
        ];
    }
  }

  bool isGameUnlocked(Grade grade, String gameId) {
    if (grade.isLowerGrade) return true;
    return gamesFor(grade).any((g) => g.id == gameId);
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
      final currentName = current?.name ?? '';
      if (current != null && !_studentProgress.any((s) => s.name == currentName)) {
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
      name: userGreetingName,
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
