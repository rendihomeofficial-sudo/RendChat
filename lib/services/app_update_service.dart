import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
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
      releaseNotes: json['release_notes'] as String? ??
          'Versi baru RenChat telah tersedia.',
      apkUrl: json['apk_url'] as String? ??
          'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest',
      fallbackUrl: json['fallback_url'] as String? ??
          'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest',
    );
  }
}

/// Menyimpan dan memantau status pembaruan aplikasi.
///
/// Diubah menjadi [ChangeNotifier] supaya banner pembaruan di HomeScreen
/// bisa bereaksi otomatis begitu pemeriksaan selesai, tanpa perlu
/// memuat ulang halaman.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _rawManifestUrl =
      'https://raw.githubusercontent.com/rendihomeofficial-sudo/RendChat/main/version.json';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/rendihomeofficial-sudo/RendChat/releases/latest';

  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;
  bool _hasCheckedThisSession = false;
  String? _lastError;

  String _currentVersion = '1.0.0';
  int _currentVersionCode = 1;

  /// Informasi pembaruan yang tersedia (null bila sudah versi terbaru).
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// True bila ada versi baru yang belum diunduh.
  bool get hasUpdate => _updateInfo != null;

  bool get isChecking => _isChecking;
  String? get lastError => _lastError;
  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;

  /// Membaca versi aplikasi yang benar-benar terpasang (dari package info).
  Future<void> _loadLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      _currentVersionCode = int.tryParse(info.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('Gagal membaca versi aplikasi: $e');
    }
  }

  /// Pemeriksaan pembaruan otomatis saat aplikasi dibuka.
  ///
  /// Menunda sebentar agar transisi ke HomeScreen tidak terasa berat.
  Future<void> checkUpdateOnStartup() async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    await _loadLocalVersion();

    // Beri jeda 3 detik setelah home screen terbuka agar transisi halus.
    await Future.delayed(const Duration(seconds: 3));
    await checkUpdate(silentIfUpToDate: true);
  }

  /// Memeriksa pembaruan dari GitHub.
  Future<void> checkUpdate({bool silentIfUpToDate = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    _lastError = null;
    notifyListeners();

    try {
      await _loadLocalVersion();
      final info = await _fetchLatestVersionInfo();

      if (info == null) {
        _updateInfo = null;
        if (!silentIfUpToDate) {
          _lastError = 'Tidak dapat memeriksa pembaruan saat ini.';
        }
        return;
      }

      if (info.versionCode > _currentVersionCode) {
        _updateInfo = info;
      } else {
        _updateInfo = null;
        if (!silentIfUpToDate) {
          _lastError = null;
        }
      }
    } catch (e) {
      _updateInfo = null;
      _lastError = 'Gagal terhubung ke server pembaruan: $e';
      debugPrint('Gagal memeriksa pembaruan: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<AppUpdateInfo?> _fetchLatestVersionInfo() async {
    // 1. Coba dari raw GitHub version.json
    try {
      final resp = await http
          .get(Uri.parse(_rawManifestUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (_) {
      // Lanjut ke fallback.
    }

    // 2. Fallback: coba dari GitHub Releases API
    try {
      final resp = await http
          .get(
            Uri.parse(_releasesApiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '');
        final body = data['body'] as String? ?? 'Versi baru RenChat.';
        final assets = (data['assets'] as List<dynamic>?) ?? [];
        String apkDownload =
            'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest';
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
          fallbackUrl:
              'https://github.com/rendihomeofficial-sudo/RendChat/releases/latest',
        );
      }
    } catch (_) {}

    return null;
  }

  static int _parseVersionCode(String ver) {
    try {
      final digits = ver.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Membuka halaman unduhan APK di browser.
  Future<void> openDownloadPage(AppUpdateInfo info) async {
    final target = Uri.parse(
      info.apkUrl.isNotEmpty ? info.apkUrl : info.fallbackUrl,
    );
    try {
      if (await canLaunchUrl(target)) {
        await launchUrl(target, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final fallback = Uri.parse(info.fallbackUrl);
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Menutup banner pembaruan tanpa memasang ulang.
  void dismissUpdateBanner() {
    if (_updateInfo == null) return;
    _updateInfo = null;
    notifyListeners();
  }
}

/// Banner popup otomatis yang muncul di HomeScreen ketika versi baru tersedia.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppUpdateService>();
    final info = service.updateInfo;
    if (info == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: WhatsAppTheme.primaryTeal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: WhatsAppTheme.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Versi ${info.version} tersedia (Anda: v${service.currentVersion})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WhatsAppTheme.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => service.openDownloadPage(info),
            style: TextButton.styleFrom(
              foregroundColor: WhatsAppTheme.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Perbarui',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: service.dismissUpdateBanner,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: WhatsAppTheme.darkTextSecondary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }
}

/// Dialog konfirmasi pembaruan manual (dipakai dari ProfileScreen).
Future<void> showUpdateDialog(BuildContext context) async {
  final service = context.read<AppUpdateService>();
  await service.checkUpdate(silentIfUpToDate: true);
  final info = service.updateInfo;

  if (!context.mounted) return;

  if (info == null) {
    final error = service.lastError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Anda sudah menggunakan versi terbaru RenChat '
                  'v${service.currentVersion}.',
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
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
            child: const Icon(
              Icons.system_update_rounded,
              color: WhatsAppTheme.primaryTeal,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pembaruan Tersedia!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'RenChat v${info.version} (Saat ini: v${service.currentVersion})',
                  style: const TextStyle(
                    color: WhatsAppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
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
              'Versi terbaru RenChat telah dirilis di GitHub. Perbarui aplikasi '
              'untuk mendapatkan fitur baru dan stabilitas terbaik.',
              style: TextStyle(
                color: WhatsAppTheme.darkTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.new_releases_outlined,
                        size: 16,
                        color: WhatsAppTheme.primaryTeal,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Catatan Perubahan:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: WhatsAppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: WhatsAppTheme.darkTextPrimary,
                    ),
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
          child: const Text(
            'Nanti Saja',
            style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: WhatsAppTheme.primaryTeal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text(
            'Perbarui Sekarang',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await service.openDownloadPage(info);
          },
        ),
      ],
    ),
  );
}
