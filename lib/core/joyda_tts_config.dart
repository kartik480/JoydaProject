import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Shared Joyda narration: **Indian English** (`en-IN`) when the engine supports it,
/// with `en-US` fallback. Optionally picks an `en-IN` system voice on Android.
///
/// “Slang” here is delivered mainly through **accent/locale** and a slightly chatty
/// pace/pitch — not by rewriting lesson content.
class JoydaTtsConfig {
  JoydaTtsConfig._();

  static const String indianEnglish = 'en-IN';
  static const String fallbackEnglish = 'en-US';

  /// Configure [tts] once before [FlutterTts.speak] calls.
  ///
  /// [awaitSpeakCompletion]: pass `false` on web for count-style games if the engine
  /// hangs (see `count_objects_game_screen`); other screens may use `true`.
  static Future<void> configureNarration(
    FlutterTts tts, {
    required bool awaitSpeakCompletion,
    required double speechRate,
    required double pitch,
  }) async {
    try {
      await tts.awaitSpeakCompletion(awaitSpeakCompletion);
    } catch (_) {}

    var indianOk = false;
    try {
      final r = await tts.setLanguage(indianEnglish);
      indianOk = _languageSetSucceeded(r);
    } catch (_) {
      indianOk = false;
    }
    if (!indianOk) {
      try {
        await tts.setLanguage(fallbackEnglish);
      } catch (_) {}
    } else if (!kIsWeb) {
      await _preferIndianSystemVoice(tts);
    }

    try {
      await tts.setSpeechRate(speechRate);
      await tts.setPitch(pitch);
      await tts.setVolume(1.0);
    } catch (_) {}
  }

  static bool _languageSetSucceeded(dynamic result) {
    if (result == true || result == 1) return true;
    if (result is String) {
      final s = result.toLowerCase();
      return s.contains('en-in') || s.contains('en_in');
    }
    return false;
  }

  static Future<void> _preferIndianSystemVoice(FlutterTts tts) async {
    try {
      final raw = await tts.getVoices;
      if (raw is! List) return;
      Map<dynamic, dynamic>? pick;
      for (final v in raw) {
        if (v is! Map) continue;
        final loc = v['locale']?.toString().toLowerCase() ?? '';
        if (loc.contains('en-in') || loc.contains('en_in')) {
          pick = v;
          break;
        }
      }
      if (pick == null) return;
      final name = pick['name']?.toString();
      final locale = pick['locale']?.toString();
      if (name == null || locale == null) return;
      await tts.setVoice({'name': name, 'locale': locale});
    } catch (_) {}
  }

  /// Optional light phrasing so lines sound a bit more like casual Indian English chat
  /// (still clear for kids). Pass strings right before `speak`.
  static String casualNarration(String line) {
    var s = line.trim();
    if (s.isEmpty) return s;
    if (s == 'Great job!') return 'Super, great job!';
    if (s.startsWith('Oops,')) return s.replaceFirst('Oops,', 'Arre,');
    if (s.contains("Let's build sentences!")) {
      return s.replaceFirst("Let's build sentences!", "Let's build sentences together!");
    }
    return s;
  }
}
