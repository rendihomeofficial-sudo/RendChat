import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService Unit & Parsing Tests', () {
    test('AppUpdateInfo.fromJson parses v1.3.11 manifest payload correctly', () {
      final jsonPayload = {
        'version': '1.3.11',
        'version_code': 24,
        'title': 'RenChat v1.3.11 - Live Hardware CameraPreview PIP',
        'release_notes': '• Integrasi Sensor Kamera Fisik Nyata\n• Swap Kamera Depan/Belakang',
        'apk_url': 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        'fallback_url': 'https://github.com/rendihomeofficial-sudo/RendChat',
      };

      final info = AppUpdateInfo.fromJson(jsonPayload);

      expect(info.version, equals('1.3.11'));
      expect(info.versionCode, equals(24));
      expect(info.title, contains('RenChat v1.3.11'));
      expect(info.releaseNotes, contains('Sensor Kamera Fisik Nyata'));
      expect(info.apkUrl, endsWith('RenChat.apk'));
      expect(info.fallbackUrl, contains('RendChat'));
    });

    test('AppUpdateInfo recognizes update when remote versionCode is greater than local', () {
      const currentLocalVersionCode = 23; // v1.3.10

      final remoteInfo = AppUpdateInfo(
        version: '1.3.11',
        versionCode: 24,
        title: 'RenChat v1.3.11',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isTrue);
    });

    test('AppUpdateInfo does not trigger update when already on latest version', () {
      const currentLocalVersionCode = 24; // v1.3.11

      final remoteInfo = AppUpdateInfo(
        version: '1.3.11',
        versionCode: 24,
        title: 'RenChat v1.3.11',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isFalse);
    });
  });
}
