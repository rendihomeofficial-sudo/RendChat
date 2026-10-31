import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/user_model.dart';
import 'package:messenger_app/models/message_model.dart';
import 'package:messenger_app/models/status_model.dart';
import 'package:messenger_app/models/call_model.dart';

void main() {
  group('Model Unit Tests', () {
    test('AppUser blockedUsers and isBlocked behavior', () {
      final now = DateTime.now();
      final user = AppUser(
        uid: 'user1',
        email: 'user1@example.com',
        displayName: 'User One',
        lastSeen: now,
        createdAt: now,
        blockedUsers: const ['user2', 'user3'],
      );

      expect(user.isBlocked('user2'), isTrue);
      expect(user.isBlocked('user3'), isTrue);
      expect(user.isBlocked('user4'), isFalse);

      final updated = user.copyWith(blockedUsers: ['user4']);
      expect(updated.isBlocked('user4'), isTrue);
      expect(updated.isBlocked('user2'), isFalse);
    });

    test('Message copyWith and reaction properties', () {
      final now = DateTime.now();
      final msg = Message(
        id: 'msg1',
        chatId: 'chat1',
        senderId: 'user1',
        senderName: 'User One',
        text: 'Hello World',
        createdAt: now,
        reactions: const {'user2': '❤️'},
        starredBy: const ['user1'],
      );

      expect(msg.isStarredBy('user1'), isTrue);
      expect(msg.isStarredBy('user2'), isFalse);
      expect(msg.reactions['user2'], equals('❤️'));
    });

    test('StatusModel properties and isViewedBy check', () {
      final now = DateTime.now();
      final status = StatusModel(
        id: 'status_1',
        userId: 'user1',
        userName: 'User One',
        text: 'Hello from RenChat Status!',
        backgroundColor: 0xFF005C4B,
        createdAt: now,
        viewedBy: const ['user1', 'user2'],
      );

      expect(status.isViewedBy('user2'), isTrue);
      expect(status.isViewedBy('user3'), isFalse);
      expect(status.backgroundColor, equals(0xFF005C4B));
    });

    test('CallModel properties and status check', () {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_1',
        callerId: 'user1',
        callerName: 'User One',
        receiverId: 'user2',
        receiverName: 'User Two',
        isVideo: true,
        status: 'connected',
        createdAt: now,
        durationSeconds: 42,
      );

      expect(call.isVideo, isTrue);
      expect(call.status, equals('connected'));
      expect(call.durationSeconds, equals(42));
    });
  });
}
