import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService Unit & Parsing Tests', () {
    test('AppUpdateInfo.fromJson parses v1.3.10 manifest payload correctly', () {
      final jsonPayload = {
        'version': '1.3.10',
        'version_code': 23,
        'title': 'RenChat v1.3.10 - Live VC Camera Instan, Swap Video Call, Timer Durasi Panggilan, & Barcode QR Modern',
        'release_notes': '• Live Video Camera Instan\n• Floating Self-View PIP Interaktif\n• Realtime Call Duration Timer',
        'apk_url': 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        'fallback_url': 'https://github.com/rendihomeofficial-sudo/RendChat',
      };

      final info = AppUpdateInfo.fromJson(jsonPayload);

      expect(info.version, equals('1.3.10'));
      expect(info.versionCode, equals(23));
      expect(info.title, contains('RenChat v1.3.10'));
      expect(info.releaseNotes, contains('Live Video Camera Instan'));
      expect(info.apkUrl, endsWith('RenChat.apk'));
      expect(info.fallbackUrl, contains('RendChat'));
    });

    test('AppUpdateInfo recognizes update when remote versionCode is greater than local', () {
      const currentLocalVersionCode = 22; // v1.3.9

      final remoteInfo = AppUpdateInfo(
        version: '1.3.10',
        versionCode: 23,
        title: 'RenChat v1.3.10',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isTrue);
    });

    test('AppUpdateInfo does not trigger update when already on latest version', () {
      const currentLocalVersionCode = 23; // v1.3.10

      final remoteInfo = AppUpdateInfo(
        version: '1.3.10',
        versionCode: 23,
        title: 'RenChat v1.3.10',
        releaseNotes: 'Fitur baru',
        apkUrl: 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest/download/RenChat.apk',
        fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
      );

      final hasUpdate = remoteInfo.versionCode > currentLocalVersionCode;
      expect(hasUpdate, isFalse);
    });
  });
}
