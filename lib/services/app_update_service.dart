import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

/// Menyimpan dan memantau status pembaruan aplikasi serta mengelola download langsung di dalam aplikasi.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const MethodChannel _installerChannel =
      MethodChannel('com.chat.messenger/app_installer');

  static const String _githubContentsRawUrl =
      'https://api.github.com/repos/rendihomeofficial-sudo/RendChat/contents/version.json?ref=main';
  static const String _rawManifestUrl =
      'https://raw.githubusercontent.com/rendihomeofficial-sudo/RendChat/main/version.json';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/rendihomeofficial-sudo/RendChat/releases/latest';

  AppUpdateInfo? _updateInfo;
  AppUpdateInfo? _latestReleaseInfo;
  bool _isChecking = false;
  bool _hasCheckedThisSession = false;
  String? _lastError;

  String _currentVersion = '1.0.0';
  int _currentVersionCode = 1;

  // Status Download In-App
  bool _isDownloading = false;
  double _downloadProgress = 0.0; // 0.0 to 1.0
  String _downloadStatusText = '';
  String? _downloadedApkPath;

  AppUpdateInfo? get updateInfo => _updateInfo;
  AppUpdateInfo? get latestReleaseInfo => _latestReleaseInfo;
  bool get hasUpdate => _updateInfo != null;
  bool get isChecking => _isChecking;
  String? get lastError => _lastError;
  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadStatusText => _downloadStatusText;
  String? get downloadedApkPath => _downloadedApkPath;

  Future<void> _loadLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      _currentVersionCode = int.tryParse(info.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('Gagal membaca versi aplikasi: $e');
    }
  }

  Future<void> checkUpdateOnStartup() async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    await _loadLocalVersion();
    await Future.delayed(const Duration(seconds: 3));
    await checkUpdate(silentIfUpToDate: true);
  }

  Future<void> checkUpdate({bool silentIfUpToDate = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    _lastError = null;
    notifyListeners();

    try {
      await _loadLocalVersion();
      final info = await _fetchLatestVersionInfo();
      _latestReleaseInfo = info;

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
    // 1. Coba ambil version.json langsung via GitHub REST API (bebas cache CDN Fastly)
    try {
      final resp = await http.get(
        Uri.parse(_githubContentsRawUrl),
        headers: {
          'Accept': 'application/vnd.github.raw',
          'User-Agent': 'RenChat-App',
        },
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (_) {}

    // 2. Coba ambil dari raw.githubusercontent.com
    try {
      final resp = await http
          .get(Uri.parse(_rawManifestUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (_) {}

    // 3. Fallback ke GitHub Releases latest endpoint
    try {
      final resp = await http
          .get(
            Uri.parse(_releasesApiUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'RenChat-App',
            },
          )
          .timeout(const Duration(seconds: 10));
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

  /// Download langsung di dalam aplikasi dengan progress bar streaming.
  Future<void> startInAppDownload({
    required AppUpdateInfo info,
    required BuildContext context,
  }) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadStatusText = 'Menghubungi server unduhan...';
    _downloadedApkPath = null;
    notifyListeners();

    try {
      String downloadUrl = info.apkUrl;
      if (!downloadUrl.toLowerCase().endsWith('.apk')) {
        // Coba ambil direct download dari GitHub Releases jika url masih link release
        final latest = await _fetchLatestVersionInfo();
        if (latest != null && latest.apkUrl.toLowerCase().endsWith('.apk')) {
          downloadUrl = latest.apkUrl;
        }
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception('Server mengembalikan kode status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      
      // Bersihkan APK lama di cache jika ada
      final oldApks = tempDir.listSync().where((f) => f.path.endsWith('.apk'));
      for (final old in oldApks) {
        try {
          old.deleteSync();
        } catch (_) {}
      }

      final saveFile = File('${tempDir.path}/RenChat_v${info.version}.apk');
      final sink = saveFile.openWrite();

      int received = 0;
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            _downloadProgress = (received / contentLength).clamp(0.0, 1.0);
            final percent = (_downloadProgress * 100).toInt();
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (contentLength / (1024 * 1024)).toStringAsFixed(1);
            _downloadStatusText = '$percent% ($mbReceived MB / $mbTotal MB)';
          } else {
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            _downloadStatusText = 'Mengunduh: $mbReceived MB...';
          }
          notifyListeners();
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();
      client.close();

      _downloadProgress = 1.0;
      _downloadStatusText = 'Unduhan selesai! Membuka penginstal...';
      _downloadedApkPath = saveFile.path;
      _isDownloading = false;
      notifyListeners();

      // Panggil penginstal Android
      await installApk(saveFile.path);
    } catch (e) {
      debugPrint('Error downloading update in-app: $e');
      _isDownloading = false;
      _downloadStatusText = 'Gagal mengunduh langsung: $e';
      notifyListeners();

      // Fallback jika direct download gagal, arahkan ke browser
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unduhan in-app terhambat, membuka peramban... ($e)'),
            action: SnackBarAction(
              label: 'Buka',
              onPressed: () => openDownloadPage(info),
            ),
          ),
        );
        await openDownloadPage(info);
      }
    }
  }

  /// Memanggil Intent Penginstal Android bawaan sistem lewat MethodChannel.
  Future<bool> installApk(String filePath) async {
    try {
      final res = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Gagal memicu penginstal APK Android: $e');
      return false;
    }
  }

  /// Membuka halaman unduhan APK di browser (sebagai fallback).
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
    // Sembunyikan banner saat modal dialog update / proses download sedang aktif
    // agar tampilan progres download hanya ada satu (yaitu di tengah layar / dialog).
    if (info == null || service.isDownloading) return const SizedBox.shrink();

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                      service.isDownloading
                          ? service.downloadStatusText
                          : 'Versi ${info.version} tersedia (Anda: v${service.currentVersion})',
                      style: TextStyle(
                        fontSize: 11,
                        color: service.isDownloading
                            ? WhatsAppTheme.primaryTeal
                            : WhatsAppTheme.darkTextSecondary,
                        fontWeight: service.isDownloading
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (!service.isDownloading)
                TextButton(
                  onPressed: () => showUpdateDialog(context),
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
        ],
      ),
    );
  }
}

/// Dialog konfirmasi & progress pembaruan in-app.
Future<void> showUpdateDialog(BuildContext context) async {
  final service = context.read<AppUpdateService>();

  // Tampilkan indikator loading ringan jika sedang memeriksa
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: Card(
        color: Color(0xFF1F2C34),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(WhatsAppTheme.primaryTeal)),
              SizedBox(width: 16),
              Text(
                'Memeriksa pembaruan...',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  await service.checkUpdate(silentIfUpToDate: false);

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // Tutup loading dialog

  final info = service.updateInfo;

  if (info == null) {
    final error = service.lastError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: WhatsAppTheme.primaryTeal, size: 28),
            SizedBox(width: 12),
            Text('Aplikasi Up to Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error ??
                  'RenChat Anda sudah menggunakan versi resmi paling baru: v${service.currentVersion} (Build ${service.currentVersionCode}).',
              style: const TextStyle(color: WhatsAppTheme.darkTextPrimary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, size: 16, color: WhatsAppTheme.primaryTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua fitur panggilan, pesan, dan enkripsi berfungsi secara optimal.',
                      style: TextStyle(fontSize: 11.5, color: WhatsAppTheme.primaryTeal),
                    ),
                  ),
                ],
              ),
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
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Consumer<AppUpdateService>(
      builder: (context, updateSvc, _) {
        return AlertDialog(
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
                      'Pembaruan RenChat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Versi v${info.version} (Saat ini: v${updateSvc.currentVersion})',
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
                if (!updateSvc.isDownloading && updateSvc.downloadedApkPath == null) ...[
                  const Text(
                    'Pembaruan akan diunduh langsung di dalam aplikasi tanpa perlu '
                    'membuka browser Chrome, menghemat penyimpanan dan otomatis siap pasang.',
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
                              'Catatan Pembaruan:',
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
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: WhatsAppTheme.primaryTeal),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pemasangan otomatis menimpa versi lama tanpa menghilangkan chat atau riwayat Anda.',
                                  style: TextStyle(fontSize: 11, color: WhatsAppTheme.primaryTeal, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (updateSvc.isDownloading) ...[
                  // Tampilan Progress Download
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2C34),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mengunduh APK...',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${(updateSvc.downloadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: WhatsAppTheme.primaryTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: updateSvc.downloadProgress > 0 ? updateSvc.downloadProgress : null,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(WhatsAppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          updateSvc.downloadStatusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Download Selesai
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: WhatsAppTheme.primaryTeal),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: WhatsAppTheme.primaryTeal, size: 48),
                        const SizedBox(height: 10),
                        const Text(
                          'Pembaruan Siap Dipasang!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Berkas update RenChat v${info.version} telah tersimpan. Ketuk "Pasang Sekarang" untuk menyelesaikan pembaruan.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!updateSvc.isDownloading)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                ),
              ),
            if (!updateSvc.isDownloading && updateSvc.downloadedApkPath == null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.downloading_rounded, size: 18),
                label: const Text(
                  'Unduh Langsung',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await updateSvc.startInAppDownload(
                    info: info,
                    context: context,
                  );
                },
              ),
            if (updateSvc.downloadedApkPath != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.install_mobile_rounded, size: 18),
                label: const Text(
                  'Pasang Sekarang',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await updateSvc.installApk(updateSvc.downloadedApkPath!);
                },
              ),
          ],
        );
      },
    ),
  );
}
