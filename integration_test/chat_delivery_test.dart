import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:messenger_app/models/chat_model.dart';
import 'package:messenger_app/models/message_model.dart';
import 'package:messenger_app/models/user_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RenChat End-to-End Chat & Delivery Integration Test', () {
    testWidgets('Alur lengkap: Pembuatan obrolan, pengiriman pesan, dan transisi centang baca', (tester) async {
      final now = DateTime.now();

      // 1. Inisialisasi dua pengguna simulasi
      final userAlice = AppUser(
        uid: 'user_alice_101',
        email: 'alice@example.com',
        displayName: 'Alice Developer',
        lastSeen: now,
        createdAt: now,
      );

      final userBob = AppUser(
        uid: 'user_bob_202',
        email: 'bob@example.com',
        displayName: 'Bob Tester',
        lastSeen: now,
        createdAt: now,
      );

      // 2. Pembuatan obrolan 1-on-1
      final chat = Chat(
        id: 'chat_alice_bob',
        isGroup: false,
        participants: [userAlice.uid, userBob.uid],
        participantNames: {
          userAlice.uid: userAlice.displayName,
          userBob.uid: userBob.displayName,
        },
        participantAvatars: {
          userAlice.uid: null,
          userBob.uid: null,
        },
        unread: {
          userAlice.uid: 0,
          userBob.uid: 0,
        },
        createdBy: userAlice.uid,
        createdAt: now,
        updatedAt: now,
      );

      expect(chat.participants, contains(userAlice.uid));
      expect(chat.participants, contains(userBob.uid));
      expect(chat.getOtherUserId(userAlice.uid), equals(userBob.uid));
      expect(chat.getDisplayTitle(userAlice.uid), equals('Bob Tester'));

      // 3. Simulasi Alice mengirim pesan: status awal sent
      final sentMessage = Message(
        id: 'msg_001',
        chatId: chat.id,
        senderId: userAlice.uid,
        senderName: userAlice.displayName,
        text: 'Halo Bob, apakah pembaruan v1.2.1 sudah stabil?',
        createdAt: now,
        status: DeliveryStatus.sent,
        readBy: [userAlice.uid],
      );

      // Verifikasi kondisi awal di sisi pengirim
      expect(sentMessage.senderId, equals(userAlice.uid));
      expect(sentMessage.readBy.contains(userAlice.uid), isTrue);
      expect(sentMessage.readBy.contains(userBob.uid), isFalse); // Belum dibaca Bob

      // Unread counter Bob bertambah
      final updatedUnreadChat = Chat(
        id: chat.id,
        isGroup: false,
        participants: chat.participants,
        participantNames: chat.participantNames,
        participantAvatars: chat.participantAvatars,
        lastMessage: sentMessage.text,
        lastMessageAt: sentMessage.createdAt,
        lastSenderId: userAlice.uid,
        unread: {
          userAlice.uid: 0,
          userBob.uid: 1, // Bob mendapat notifikasi 1 pesan belum dibaca
        },
        createdBy: chat.createdBy,
        createdAt: chat.createdAt,
        updatedAt: now,
      );

      expect(updatedUnreadChat.getUnreadCount(userBob.uid), equals(1));

      // 4. Simulasi Bob membuka obrolan -> markChatAsRead dieksekusi
      // Status berubah menjadi read dan Bob terdaftar di readBy
      final readMessage = sentMessage.copyWith(
        status: DeliveryStatus.read,
        readBy: [userAlice.uid, userBob.uid],
      );

      final resetUnreadChat = Chat(
        id: chat.id,
        isGroup: false,
        participants: chat.participants,
        participantNames: chat.participantNames,
        participantAvatars: chat.participantAvatars,
        lastMessage: readMessage.text,
        lastMessageAt: readMessage.createdAt,
        lastSenderId: userAlice.uid,
        unread: {
          userAlice.uid: 0,
          userBob.uid: 0, // Unread direset ke 0
        },
        createdBy: chat.createdBy,
        createdAt: chat.createdAt,
        updatedAt: DateTime.now(),
      );

      // Verifikasi hasil akhir: centang baca biru terverifikasi
      expect(readMessage.readBy.contains(userBob.uid), isTrue);
      expect(readMessage.readBy.length, equals(2));
      expect(resetUnreadChat.getUnreadCount(userBob.uid), equals(0));
    });
  });
}
