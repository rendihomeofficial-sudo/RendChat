import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Upload any file (documents, images, videos, audio, archives) and return public URL
  Future<String?> uploadChatFile({
    required String chatId,
    String? filePath,
    Uint8List? fileBytes,
    required String originalFileName,
  }) async {
    try {
      final ext = originalFileName.contains('.')
          ? originalFileName.split('.').last
          : 'bin';
      final fileName = '${_uuid.v4()}_$originalFileName';
      final ref = _storage.ref().child('chats/$chatId/$fileName');

      UploadTask task;
      if (kIsWeb || fileBytes != null) {
        if (fileBytes == null) {
          throw Exception('File bytes required for web upload');
        }
        task = ref.putData(
          fileBytes,
          SettableMetadata(contentType: _guessMime(ext)),
        );
      } else {
        if (filePath == null) throw Exception('File path is required');
        task = ref.putFile(
          File(filePath),
          SettableMetadata(contentType: _guessMime(ext)),
        );
      }

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('StorageService upload error: $e');
      return null;
    }
  }

  // Upload user profile photo
  Future<String?> uploadAvatar({
    required String uid,
    required String filePath,
    Uint8List? fileBytes,
  }) async {
    try {
      final ref = _storage.ref().child('users/$uid/avatar.jpg');
      UploadTask task;
      if (kIsWeb || fileBytes != null) {
        if (fileBytes == null) throw Exception('File bytes required on web');
        task = ref.putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        task = ref.putFile(File(filePath), SettableMetadata(contentType: 'image/jpeg'));
      }
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();

      // Update user doc photoURL
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoURL': url,
      });

      return url;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return null;
    }
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
      default:
        return 'application/octet-stream';
    }
  }
}
