import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/user_model.dart';
import 'package:messenger_app/models/message_model.dart';

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
  });
}
