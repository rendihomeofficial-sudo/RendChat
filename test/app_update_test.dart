import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService Unit & Parsing Tests', () {
    test('AppUpdateInfo.fromJson parses v1.3.9 manifest payload correctly', () {
      final jsonPayload = {
        'version': '1.3.9',
        'version_code': 22,
        'title': 'RenChat v1.3.9 - Live Video Call Audio Nyata',
        'release_notes': '• Input Audio Mikrofon Realtime\n• Swap Dinamis Panggilan',
        'apk_url': 'https://github.com/rendihomeofficial-sudo/RendChat/releases/download/v1.3.9/RenChat.apk',
        'fallback_url': 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest',
      };

      final info = AppUpdateInfo.fromJson(jsonPayload);

      expect(info.version, equals('1.3.9'));
      expect(info.versionCode, equals(22));
      expect(info.title, contains('RenChat v1.3.9'));
      expect(info.releaseNotes, contains('Input Audio Mikrofon Realtime'));
      expect(info.apkUrl, endsWith('RenChat.apk'));
      expect(info.fallbackUrl, contains('releases/latest'));
    });

    test('AppUpdateInfo recognizes update when remote versionCode is greater than local', () {
      const currentLocalVersionCode = 21; // v1.3.8

      final remoteInfo = AppUpdateInfo(
        version: '1.3.9',
        versionCode: 22,
        title: 'RenChat v1.3.9',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/download/v1.3.9/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isTrue);
    });

    test('AppUpdateInfo does not trigger update when already on latest version', () {
      const currentLocalVersionCode = 22; // v1.3.9

      final remoteInfo = AppUpdateInfo(
        version: '1.3.9',
        versionCode: 22,
        title: 'RenChat v1.3.9',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/download/v1.3.9/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isFalse);
    });
  });
}
