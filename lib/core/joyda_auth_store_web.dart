// Web: persist profiles as raw JSON in window.localStorage (reliable across
// refresh and tab close). Mirror SharedPreferences. Migrate legacy
// flutter.<key> entries (JSON-wrapped string) into the direct key on read.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart';

const _directStorageKey = 'joyda_auth_profiles_json';
const _prefsLogicalKey = 'joyda_registered_profiles';
const _flutterPrefKey = 'flutter.$_prefsLogicalKey';

Storage get _local => window.localStorage;

Future<String?> loadJoydaAuthProfilesJson() async {
  final direct = _local.getItem(_directStorageKey);
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final legacy = _local.getItem(_flutterPrefKey);
  if (legacy != null && legacy.isNotEmpty) {
    try {
      final decoded = jsonDecode(legacy);
      if (decoded is String && decoded.isNotEmpty) {
        _local.setItem(_directStorageKey, decoded);
        return decoded;
      }
    } catch (_) {}
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.getString(_prefsLogicalKey);
}

Future<String?> saveJoydaAuthProfilesJson(String json) async {
  try {
    _local.setItem(_directStorageKey, json);
    if (_local.getItem(_directStorageKey) != json) {
      return 'Could not save your account. Allow site storage (not private mode).';
    }
  } catch (_) {
    return 'Could not save your account. Check browser storage permissions.';
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLogicalKey, json);
    await prefs.reload();
  } catch (_) {}
  return null;
}
