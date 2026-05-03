import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsProfilesKey = 'joyda_registered_profiles';
const _fileName = 'joyda_auth_profiles.json';

Future<File> _profileFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$_fileName');
}

/// Native: prefer on-disk file (reliable), mirror SharedPreferences; migrate from prefs if needed.
Future<String?> loadJoydaAuthProfilesJson() async {
  try {
    final file = await _profileFile();
    if (await file.exists()) {
      final fromFile = await file.readAsString();
      if (fromFile.isNotEmpty) return fromFile;
    }
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final fromPrefs = prefs.getString(_prefsProfilesKey);
  if (fromPrefs != null && fromPrefs.isNotEmpty) {
    try {
      final file = await _profileFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(fromPrefs);
    } catch (_) {}
  }
  return fromPrefs;
}

Future<String?> saveJoydaAuthProfilesJson(String json) async {
  try {
    final file = await _profileFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(json);
  } catch (_) {
    return 'Could not save your account to device storage.';
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsProfilesKey, json);
  await prefs.reload();
  return null;
}
