import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockChatPasscodeManager {
  static final LockChatPasscodeManager _instance = LockChatPasscodeManager._internal();
  factory LockChatPasscodeManager() => _instance;
  LockChatPasscodeManager._internal() {
    _loadFromPreferences();
  }

  static const String _passcodeKey = 'locked_chats_pin';
  static const String _hideFolderKey = 'locked_chats_hide_folder';

  String _currentPasscode = '1234';
  bool _hideLockedChatsFolder = false;

  final ValueNotifier<String> passcodeNotifier = ValueNotifier<String>('1234');
  final ValueNotifier<bool> hideLockedChatsNotifier = ValueNotifier<bool>(false);

  String get currentPasscode => _currentPasscode;
  bool get hideLockedChatsFolder => _hideLockedChatsFolder;

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPin = prefs.getString(_passcodeKey);
      final savedHide = prefs.getBool(_hideFolderKey);

      if (savedPin != null && savedPin.length == 4) {
        _currentPasscode = savedPin;
        passcodeNotifier.value = savedPin;
      }
      if (savedHide != null) {
        _hideLockedChatsFolder = savedHide;
        hideLockedChatsNotifier.value = savedHide;
      }
    } catch (e) {
      debugPrint('Error loading locked chat passcode from prefs: $e');
    }
  }

  bool verify(String inputPin) {
    return inputPin == _currentPasscode;
  }

  Future<void> setPasscode(String newPin) async {
    if (newPin.length == 4) {
      _currentPasscode = newPin;
      passcodeNotifier.value = newPin;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_passcodeKey, newPin);
      } catch (e) {
        debugPrint('Error saving passcode to prefs: $e');
      }
    }
  }

  Future<void> setHideLockedChats(bool hide) async {
    _hideLockedChatsFolder = hide;
    hideLockedChatsNotifier.value = hide;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideFolderKey, hide);
    } catch (e) {
      debugPrint('Error saving hideLockedChats to prefs: $e');
    }
  }

  Future<void> resetToDefault() async {
    _currentPasscode = '1234';
    _hideLockedChatsFolder = false;
    passcodeNotifier.value = '1234';
    hideLockedChatsNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_passcodeKey);
      await prefs.remove(_hideFolderKey);
    } catch (e) {
      debugPrint('Error resetting passcode in prefs: $e');
    }
  }
}
