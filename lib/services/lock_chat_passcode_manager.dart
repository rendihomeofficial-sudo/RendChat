import 'package:flutter/foundation.dart';

class LockChatPasscodeManager {
  static final LockChatPasscodeManager _instance = LockChatPasscodeManager._internal();
  factory LockChatPasscodeManager() => _instance;
  LockChatPasscodeManager._internal();

  String _currentPasscode = '1234';
  bool _hideLockedChatsFolder = false;

  final ValueNotifier<String> passcodeNotifier = ValueNotifier<String>('1234');
  final ValueNotifier<bool> hideLockedChatsNotifier = ValueNotifier<bool>(false);

  String get currentPasscode => _currentPasscode;
  bool get hideLockedChatsFolder => _hideLockedChatsFolder;

  bool verify(String inputPin) {
    return inputPin == _currentPasscode;
  }

  void setPasscode(String newPin) {
    if (newPin.length == 4) {
      _currentPasscode = newPin;
      passcodeNotifier.value = newPin;
    }
  }

  void setHideLockedChats(bool hide) {
    _hideLockedChatsFolder = hide;
    hideLockedChatsNotifier.value = hide;
  }

  void resetToDefault() {
    _currentPasscode = '1234';
    _hideLockedChatsFolder = false;
    passcodeNotifier.value = '1234';
    hideLockedChatsNotifier.value = false;
  }
}
