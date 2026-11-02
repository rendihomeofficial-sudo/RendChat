import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/chat_model.dart';
import 'package:messenger_app/models/message_model.dart';

void main() {
  group('WhatsApp-Style Clear Chat (clearedAt per-user) Tests', () {
    test('User with clearedAt only sees messages created AFTER cleared time', () {
      final userA = 'user_A';
      final userB = 'user_B';

      final t1 = DateTime(2026, 11, 2, 10, 0);
      final t2 = DateTime(2026, 11, 2, 10, 30);
      final clearTimeA = DateTime(2026, 11, 2, 10, 45);
      final t3 = DateTime(2026, 11, 2, 11, 0);

      final chat = Chat(
        id: 'chat_123',
        isGroup: false,
        participants: [userA, userB],
        createdBy: userA,
        createdAt: t1,
        updatedAt: t3,
        clearedAt: {
          userA: clearTimeA,
        },
      );

      final msg1 = Message(
        id: 'msg_1',
        chatId: 'chat_123',
        senderId: userB,
        senderName: 'User B',
        text: 'Halo pesan lama sebelum clear',
        createdAt: t1,
      );

      final msg2 = Message(
        id: 'msg_2',
        chatId: 'chat_123',
        senderId: userA,
        senderName: 'User A',
        text: 'Ini juga pesan sebelum clear',
        createdAt: t2,
      );

      final msg3 = Message(
        id: 'msg_3',
        chatId: 'chat_123',
        senderId: userB,
        senderName: 'User B',
        text: 'Pesan baru setelah User A clear obrolan',
        createdAt: t3,
      );

      final allMessages = [msg1, msg2, msg3];

      // Verifikasi pesan yang terlihat oleh User A (hanya msg3 yang setelah clearTimeA)
      final visibleForUserA = allMessages
          .where((m) => chat.isMessageVisibleFor(userA, m.createdAt))
          .toList();
      expect(visibleForUserA.length, 1);
      expect(visibleForUserA.first.id, 'msg_3');

      // Verifikasi pesan yang terlihat oleh User B (User B belum clear, melihat semua 3 pesan)
      final visibleForUserB = allMessages
          .where((m) => chat.isMessageVisibleFor(userB, m.createdAt))
          .toList();
      expect(visibleForUserB.length, 3);
    });

    test('Chat serialization preserves clearedAt map', () {
      final userA = 'user_A';
      final clearTime = DateTime(2026, 11, 2, 12, 0);

      final chat = Chat(
        id: 'chat_test',
        isGroup: false,
        participants: [userA, 'user_B'],
        createdBy: userA,
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 2),
        clearedAt: {
          userA: clearTime,
        },
      );

      final map = chat.toFirestore();
      expect(map.containsKey('clearedAt'), true);
      expect(chat.getClearedAt(userA), clearTime);
      expect(chat.getClearedAt('user_B'), isNull);
    });
  });
}
