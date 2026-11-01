import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Upload any file (documents, images, videos, audio, archives) and return public URL or fallback Data URI
  Future<String?> uploadChatFile({
    required String chatId,
    String? filePath,
    Uint8List? fileBytes,
    required String originalFileName,
  }) async {
    final ext = originalFileName.contains('.')
        ? originalFileName.split('.').last.toLowerCase()
        : 'bin';

    Uint8List? rawBytes = fileBytes;
    if (rawBytes == null && filePath != null) {
      try {
        rawBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading file bytes: $e');
      }
    }

    // 1. Coba unggah ke Firebase Storage
    try {
      final fileName = '${_uuid.v4()}_$originalFileName';
      final ref = _storage.ref().child('chats/$chatId/$fileName');

      UploadTask task;
      if (kIsWeb || rawBytes != null) {
        task = ref.putData(
          rawBytes!,
          SettableMetadata(contentType: _guessMime(ext)),
        );
      } else {
        task = ref.putFile(
          File(filePath!),
          SettableMetadata(contentType: _guessMime(ext)),
        );
      }

      final snapshot = await task.timeout(const Duration(seconds: 15));
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Firebase Storage upload failed, using fallback data storage: $e');
    }

    // 2. Fallback cerdas: Simpan file sebagai Base64 Data URI jika ukuran wajar (< 1MB)
    // agar foto dan file langsung terkirim dan terlihat oleh penerima tanpa pernah gagal!
    if (rawBytes != null && rawBytes.length < 1024 * 1024) {
      try {
        final mime = _guessMime(ext);
        final base64String = base64Encode(rawBytes);
        return 'data:$mime;base64,$base64String';
      } catch (e) {
        debugPrint('Fallback base64 encoding error: $e');
      }
    }

    return null;
  }

  // Upload user profile photo
  Future<String?> uploadAvatar({
    required String uid,
    required String filePath,
    Uint8List? fileBytes,
  }) async {
    Uint8List? rawBytes = fileBytes;
    if (rawBytes == null) {
      try {
        rawBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading avatar file: $e');
      }
    }

    // 1. Coba Firebase Storage
    try {
      final ref = _storage.ref().child('users/$uid/avatar.jpg');
      UploadTask task;
      if (kIsWeb || rawBytes != null) {
        task = ref.putData(rawBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        task = ref.putFile(File(filePath), SettableMetadata(contentType: 'image/jpeg'));
      }
      final snapshot = await task.timeout(const Duration(seconds: 12));
      final url = await snapshot.ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).update({'photoURL': url});
      return url;
    } catch (e) {
      debugPrint('Firebase Storage avatar failed, using fallback: $e');
    }

    // 2. Fallback: Base64 Data URI untuk avatar
    if (rawBytes != null) {
      final base64Data = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
      await _firestore.collection('users').doc(uid).update({'photoURL': base64Data});
      return base64Data;
    }

    return null;
  }

  // Upload status photo or media (mendukung gambar, video, dan audio lagu)
  Future<String?> uploadStatusMedia({
    required String userId,
    required String filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';

    Uint8List? rawBytes = fileBytes;
    if (rawBytes == null) {
      try {
        rawBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading status media: $e');
      }
    }

    // 1. Coba Firebase Storage
    try {
      final uniqueName = '${_uuid.v4()}_$fileName';
      final ref = _storage.ref().child('statuses/$userId/$uniqueName');

      UploadTask task;
      if (kIsWeb || rawBytes != null) {
        task = ref.putData(rawBytes!, SettableMetadata(contentType: _guessMime(ext)));
      } else {
        task = ref.putFile(File(filePath), SettableMetadata(contentType: _guessMime(ext)));
      }
      final snapshot = await task.timeout(const Duration(seconds: 15));
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage status media failed, using fallback: $e');
    }

    // 2. Fallback: Data URI untuk status gambar / audio pendek
    if (rawBytes != null && rawBytes.length < 1024 * 1024) {
      final mime = _guessMime(ext);
      return 'data:$mime;base64,${base64Encode(rawBytes)}';
    }

    return null;
  }

  String _guessMime(String ext) {
    switch (ext.toLowerCase()) {
      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      // Archives
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'tar':
      case 'gz':
        return 'application/gzip';
      // Images
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      // Audio & Video
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }
}
