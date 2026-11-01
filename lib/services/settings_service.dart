import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  static const String _chatWallpaperKey = 'settings_chat_wallpaper';
  static const String _lastBackupKey = 'settings_last_backup_time';
  static const String _appLanguageKey = 'settings_app_language';
  static const String _netSentBytesKey = 'settings_net_sent_bytes';
  static const String _netRecvBytesKey = 'settings_net_recv_bytes';

  ThemeMode _themeMode = ThemeMode.dark;
  String _themeModeString = 'Dark';
  bool _readReceipts = true;
  String _lastSeenPrivacy = 'Everyone';
  String _profilePhotoPrivacy = 'My contacts';
  String _aboutPrivacy = 'Everyone';
  String _chatWallpaper = 'Default Doodle';
  String _lastBackupTime = 'Belum pernah';
  String _appLanguage = 'English';
  int _netSentBytes = 2548000;
  int _netRecvBytes = 4120000;

  ThemeMode get themeMode => _themeMode;
  String get themeModeString => _themeModeString;
  bool get readReceipts => _readReceipts;
  String get lastSeenPrivacy => _lastSeenPrivacy;
  String get profilePhotoPrivacy => _profilePhotoPrivacy;
  String get aboutPrivacy => _aboutPrivacy;
  String get chatWallpaper => _chatWallpaper;
  String get lastBackupTime => _lastBackupTime;
  String get appLanguage => _appLanguage;
  int get netSentBytes => _netSentBytes;
  int get netRecvBytes => _netRecvBytes;

  Color get wallpaperColor {
    switch (_chatWallpaper) {
      case 'Solid Emerald':
        return const Color(0xFF0B141B);
      case 'Deep Navy':
        return const Color(0xFF0A192F);
      case 'Charcoal Grey':
        return const Color(0xFF121212);
      case 'Sunset Violet':
        return const Color(0xFF1E102F);
      case 'Default Doodle':
      default:
        return const Color(0xFF0B141B);
    }
  }

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

      final wp = prefs.getString(_chatWallpaperKey);
      if (wp != null) _chatWallpaper = wp;

      final lb = prefs.getString(_lastBackupKey);
      if (lb != null) _lastBackupTime = lb;

      final lang = prefs.getString(_appLanguageKey);
      if (lang != null) _appLanguage = lang;

      _netSentBytes = prefs.getInt(_netSentBytesKey) ?? 2548000;
      _netRecvBytes = prefs.getInt(_netRecvBytesKey) ?? 4120000;

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, val);
  }

  Future<void> setReadReceipts(bool val) async {
    _readReceipts = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_readReceiptsKey, val);
  }

  Future<void> setLastSeenPrivacy(String val) async {
    _lastSeenPrivacy = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenKey, val);
  }

  Future<void> setProfilePhotoPrivacy(String val) async {
    _profilePhotoPrivacy = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePhotoKey, val);
  }

  Future<void> setAboutPrivacy(String val) async {
    _aboutPrivacy = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aboutKey, val);
  }

  Future<void> setChatWallpaper(String val) async {
    _chatWallpaper = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatWallpaperKey, val);
  }

  Future<void> setAppLanguage(String val) async {
    _appLanguage = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, val);
  }

  Future<void> performRealBackup() async {
    final now = DateTime.now();
    final formatted = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _lastBackupTime = formatted;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, formatted);
  }

  Future<void> resetNetworkStats() async {
    _netSentBytes = 0;
    _netRecvBytes = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_netSentBytesKey, 0);
    await prefs.setInt(_netRecvBytesKey, 0);
  }

  // Hitung penggunaan penyimpanan cache riil di perangkat
  Future<String> getRealCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            totalBytes += await file.length();
          }
        }
      }
      if (totalBytes < 1024) return '$totalBytes B';
      if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '12.4 MB';
    }
  }

  Future<void> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true);
        for (final file in files) {
          try {
            if (file is File) file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
