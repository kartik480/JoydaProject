// Shared 0–100 score and 1–3 star rules used across student games.

import 'dart:math' as math;

/// Stars from composite score: same thresholds as grade math/science flows.
int starsFromScore(int score) {
  if (score >= 85) return 3;
  if (score >= 60) return 2;
  return 1;
}

/// Max stars allowed for how many extra failed actions happened
/// (`attempts − successes`, wrong taps, bad checks, etc.).
///
/// Three filled stars only when [mistakeCount] is 0.
int maxStarsForMistakeCount(int mistakeCount) {
  if (mistakeCount <= 0) return 3;
  if (mistakeCount <= 4) return 2;
  return 1;
}

/// Combines score-based stars with the mistake cap (whichever is stricter).
int starsCappedForMistakes(int starsFromScoreFn, int mistakeCount) {
  return math.min(starsFromScoreFn, maxStarsForMistakeCount(mistakeCount)).clamp(1, 3);
}

/// Progress weight 70%, accuracy weight 30%.
({int score, int stars}) scoreAndStarsProgressAccuracy({
  required int progressed,
  required int total,
  required int successCount,
  required int attemptCount,
}) {
  if (total <= 0) {
    return (score: 0, stars: 1);
  }
  final p = (progressed / total).clamp(0.0, 1.0);
  final acc =
      attemptCount > 0 ? (successCount / attemptCount).clamp(0.0, 1.0) : 1.0;
  final score = (p * 70 + acc * 30).round().clamp(0, 100);
  final mistakes = attemptCount >= successCount
      ? (attemptCount - successCount).clamp(0, attemptCount)
      : 0;
  final stars = starsCappedForMistakes(starsFromScore(score), mistakes);
  return (score: score, stars: stars);
}

/// Rounds completed correctly vs total rounds; attempts include wrong tries.
({int score, int stars}) scoreAndStarsRoundGame({
  required int roundsCorrect,
  required int totalRounds,
  required int totalAttempts,
}) {
  return scoreAndStarsProgressAccuracy(
    progressed: roundsCorrect,
    total: totalRounds,
    successCount: roundsCorrect,
    attemptCount: totalAttempts,
  );
}

/// Each mistaken tap lowers the score by 1 from a 100 base (perfect = no extra taps).
/// Wrong taps = [totalAttempts] − [roundsCorrect] (one tap counts as correct per finished round).
/// Stars use [starsFromScore] on that value, then the same mistake cap as other games.
({int score, int stars}) scoreAndStarsRoundGameMinusWrongTaps({
  required int roundsCorrect,
  required int totalAttempts,
}) {
  final wrongTaps = (totalAttempts - roundsCorrect).clamp(0, totalAttempts);
  final score = (100 - wrongTaps).clamp(0, 100);
  final stars = starsCappedForMistakes(starsFromScore(score), wrongTaps);
  return (score: score, stars: stars);
}
