import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/whatsapp_theme.dart';

class AppUpdateInfo {
  final String version;
  final int versionCode;
  final String title;
  final String releaseNotes;
  final String apkUrl;
  final String fallbackUrl;

  const AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.title,
    required this.releaseNotes,
    required this.apkUrl,
    required this.fallbackUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Pembaruan Tersedia',
      releaseNotes: json['release_notes'] as String? ?? 'Versi baru RenChat telah tersedia.',
      apkUrl: json['apk_url'] as String? ?? 'https://github.com/rendihomeofficial-sudo/RendChat',
      fallbackUrl: json['fallback_url'] as String? ?? 'https://github.com/rendihomeofficial-sudo/RendChat',
    );
  }
}

class AppUpdateService {
  static const String currentVersion = '1.0.0';
  static const int currentVersionCode = 1;

  static const String _rawManifestUrl =
      'https://raw.githubusercontent.com/rendihomeofficial-sudo/RendChat/main/version.json';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/rendihomeofficial-sudo/RendChat/releases/latest';

  static bool _hasPromptedThisSession = false;

  /// Memeriksa pembaruan otomatis saat aplikasi dibuka
  static Future<void> checkUpdateOnStartup(BuildContext context) async {
    if (_hasPromptedThisSession) return;
    // Beri jeda 3 detik setelah home screen terbuka agar transisi halus
    await Future.delayed(const Duration(seconds: 3));
    if (!context.mounted) return;
    await checkUpdate(context, silentIfUpToDate: true);
  }

  /// Memeriksa pembaruan dari GitHub
  static Future<void> checkUpdate(
    BuildContext context, {
    bool silentIfUpToDate = false,
  }) async {
    try {
      final info = await _fetchLatestVersionInfo();
      if (info == null) {
        if (!silentIfUpToDate && context.mounted) {
          _showToast(context, 'Tidak dapat memeriksa pembaruan saat ini.');
        }
        return;
      }

      final isNewer = info.versionCode > currentVersionCode ||
          _compareSemver(info.version, currentVersion) > 0;

      if (isNewer && context.mounted) {
        _hasPromptedThisSession = true;
        _showUpdateDialog(context, info);
      } else {
        if (!silentIfUpToDate && context.mounted) {
          _showUpToDateDialog(context);
        }
      }
    } catch (e) {
      if (!silentIfUpToDate && context.mounted) {
        _showToast(context, 'Gagal terhubung ke server pembaruan: $e');
      }
    }
  }

  static Future<AppUpdateInfo?> _fetchLatestVersionInfo() async {
    // 1. Coba dari raw GitHub version.json
    try {
      final rawUri = Uri.parse(_rawManifestUrl);
      final jsonStr = await _httpGet(rawUri);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (_) {}

    // 2. Fallback: coba dari GitHub Releases API
    try {
      final apiUri = Uri.parse(_releasesApiUrl);
      final jsonStr = await _httpGet(apiUri);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '');
        final body = data['body'] as String? ?? 'Versi baru RenChat.';
        final assets = (data['assets'] as List<dynamic>?) ?? [];
        String apkDownload = 'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest';
        for (final item in assets) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkDownload = item['browser_download_url'] as String? ?? apkDownload;
            break;
          }
        }
        return AppUpdateInfo(
          version: tagName,
          versionCode: _parseVersionCode(tagName),
          title: 'RenChat Pembaruan Baru',
          releaseNotes: body,
          apkUrl: apkDownload,
          fallbackUrl: 'https://github.com/rendihomeofficial-sudo/RendChat',
        );
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _httpGet(Uri uri) async {
    if (kIsWeb) {
      // Pada web, browser security cross-origin berlaku
      return null;
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    client.userAgent = 'RenChat-AppUpdate';
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
        return utf8.decode(bytes);
      }
      return null;
    } finally {
      client.close();
    }
  }

  static int _compareSemver(String a, String b) {
    try {
      final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final aVal = i < aParts.length ? aParts[i] : 0;
        final bVal = i < bParts.length ? bParts[i] : 0;
        if (aVal != bVal) return aVal.compareTo(bVal);
      }
    } catch (_) {}
    return 0;
  }

  static int _parseVersionCode(String ver) {
    try {
      final digits = ver.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: WhatsAppTheme.primaryTeal, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pembaruan Tersedia!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'RenChat v${info.version} (Saat ini: v$currentVersion)',
                    style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Versi terbaru RenChat telah dirilis di GitHub. Perbarui aplikasi untuk mendapatkan fitur baru dan stabilitas terbaik.',
                style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2C34),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.new_releases_outlined, size: 16, color: WhatsAppTheme.primaryTeal),
                        SizedBox(width: 6),
                        Text('Catatan Perubahan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: WhatsAppTheme.primaryTeal)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.releaseNotes,
                      style: const TextStyle(fontSize: 12, height: 1.4, color: WhatsAppTheme.darkTextPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: WhatsAppTheme.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Perbarui Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              final target = Uri.parse(info.apkUrl.isNotEmpty ? info.apkUrl : info.fallbackUrl);
              if (await canLaunchUrl(target)) {
                await launchUrl(target, mode: LaunchMode.externalApplication);
              } else {
                final fallback = Uri.parse(info.fallbackUrl);
                await launchUrl(fallback, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  static void _showUpToDateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: WhatsAppTheme.primaryTeal, size: 26),
            SizedBox(width: 10),
            Text('Aplikasi Terkini'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda sudah menggunakan versi terbaru RenChat v1.0.0.'),
            SizedBox(height: 8),
            Text(
              'Aplikasi akan otomatis memberi tahu Anda jika ada pembaruan baru dari repository GitHub.',
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
