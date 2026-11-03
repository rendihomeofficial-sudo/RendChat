import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/chat_model.dart';
import '../screens/chat_screen.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize(String uid) async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        final token = await _fcm.getToken();
        if (token != null) {
          await _saveToken(uid, token);
        }

        _fcm.onTokenRefresh.listen((newToken) {
          _saveToken(uid, newToken);
        });

        // Tangani pesan saat aplikasi dibuka dari keadaan terminated via notifikasi
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationClick(initialMessage);
        }

        // Tangani pesan saat aplikasi aktif di latar depan
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Pesan diterima di foreground: ${message.notification?.title}');
        });

        // Tangani saat notifikasi di-klik oleh pengguna dari background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('Notifikasi dibuka oleh pengguna: ${message.data}');
          _handleNotificationClick(message);
        });
      }
    } catch (e) {
      debugPrint('NotificationService init error (platform may not support FCM directly): $e');
    }
  }

  Future<void> _handleNotificationClick(RemoteMessage message) async {
    final chatId = message.data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) return;

    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (!doc.exists) return;
      final chat = Chat.fromFirestore(doc, null);

      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
      );
    } catch (e) {
      debugPrint('Gagal membuka obrolan dari notifikasi: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}
