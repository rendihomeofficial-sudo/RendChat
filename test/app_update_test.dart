import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService Unit & Parsing Tests', () {
    test('AppUpdateInfo.fromJson parses v1.3.12 manifest payload correctly', () {
      final jsonPayload = {
        'version': '1.3.12',
        'version_code': 25,
        'title': 'RenChat v1.3.12 - Set Izin AndroidManifest Lengkap',
        'release_notes': '• Set Izin Lengkap Android\n• Penyimpanan & Media Universal',
        'apk_url': 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        'fallback_url': 'https://github.com/rendihomeofficial-sudo/RendChat',
      };

      final info = AppUpdateInfo.fromJson(jsonPayload);

      expect(info.version, equals('1.3.12'));
      expect(info.versionCode, equals(25));
      expect(info.title, contains('RenChat v1.3.12'));
      expect(info.releaseNotes, contains('Set Izin Lengkap Android'));
      expect(info.apkUrl, endsWith('RenChat.apk'));
      expect(info.fallbackUrl, contains('RendChat'));
    });

    test('AppUpdateInfo recognizes update when remote versionCode is greater than local', () {
      const currentLocalVersionCode = 24; // v1.3.11

      final remoteInfo = AppUpdateInfo(
        version: '1.3.12',
        versionCode: 25,
        title: 'RenChat v1.3.12',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isTrue);
    });

    test('AppUpdateInfo does not trigger update when already on latest version', () {
      const currentLocalVersionCode = 25; // v1.3.12

      final remoteInfo = AppUpdateInfo(
        version: '1.3.12',
        versionCode: 25,
        title: 'RenChat v1.3.12',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isFalse);
    });
  });
}
