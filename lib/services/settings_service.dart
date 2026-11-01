import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();
  factory SettingsService() => instance;
  SettingsService._internal() {
    _loadFromPrefs();
  }

  static const String _themeModeKey = 'settings_theme_mode';
  static const String _readReceiptsKey = 'settings_read_receipts';
  static const String _lastSeenKey = 'settings_last_seen_privacy';
  static const String _profilePhotoKey = 'settings_profile_photo_privacy';
  static const String _aboutKey = 'settings_about_privacy';

  ThemeMode _themeMode = ThemeMode.dark;
  String _themeModeString = 'Dark';
  bool _readReceipts = true;
  String _lastSeenPrivacy = 'Everyone';
  String _profilePhotoPrivacy = 'My contacts';
  String _aboutPrivacy = 'Everyone';

  ThemeMode get themeMode => _themeMode;
  String get themeModeString => _themeModeString;
  bool get readReceipts => _readReceipts;
  String get lastSeenPrivacy => _lastSeenPrivacy;
  String get profilePhotoPrivacy => _profilePhotoPrivacy;
  String get aboutPrivacy => _aboutPrivacy;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString(_themeModeKey);
      if (themeStr != null) {
        _themeModeString = themeStr;
        _themeMode = _parseThemeMode(themeStr);
      }
      final rr = prefs.getBool(_readReceiptsKey);
      if (rr != null) _readReceipts = rr;

      final ls = prefs.getString(_lastSeenKey);
      if (ls != null) _lastSeenPrivacy = ls;

      final pp = prefs.getString(_profilePhotoKey);
      if (pp != null) _profilePhotoPrivacy = pp;

      final ab = prefs.getString(_aboutKey);
      if (ab != null) _aboutPrivacy = ab;

      notifyListeners();
    } catch (e) {
      debugPrint('SettingsService load error: $e');
    }
  }

  ThemeMode _parseThemeMode(String val) {
    switch (val.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'system default':
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(String val) async {
    _themeModeString = val;
    _themeMode = _parseThemeMode(val);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, val);
    } catch (_) {}
  }

  Future<void> setReadReceipts(bool val) async {
    _readReceipts = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_readReceiptsKey, val);
    } catch (_) {}
  }

  Future<void> setLastSeenPrivacy(String val) async {
    _lastSeenPrivacy = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSeenKey, val);
    } catch (_) {}
  }

  Future<void> setProfilePhotoPrivacy(String val) async {
    _profilePhotoPrivacy = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profilePhotoKey, val);
    } catch (_) {}
  }

  Future<void> setAboutPrivacy(String val) async {
    _aboutPrivacy = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aboutKey, val);
    } catch (_) {}
  }
}
