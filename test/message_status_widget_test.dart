import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/message_model.dart';
import 'package:messenger_app/theme/whatsapp_theme.dart';

/// Widget wrapper terisolasi untuk menguji status pengiriman dan centang biru
class DeliveryStatusTestWidget extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final bool isGroup;

  const DeliveryStatusTestWidget({
    super.key,
    required this.message,
    required this.currentUserId,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = message.readBy.any((uid) => uid != currentUserId) ||
        message.status == DeliveryStatus.read;

    if (isRead) {
      return const Icon(
        Icons.done_all_rounded,
        key: Key('icon_read_blue'),
        size: 15,
        color: WhatsAppTheme.blueCheck,
      );
    }

    switch (message.status) {
      case DeliveryStatus.sending:
        return const Icon(
          Icons.access_time_rounded,
          key: Key('icon_sending'),
          size: 13,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.sent:
        return const Icon(
          Icons.done_rounded,
          key: Key('icon_sent_single'),
          size: 15,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          key: Key('icon_delivered_double_grey'),
          size: 15,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          key: Key('icon_read_blue'),
          size: 15,
          color: WhatsAppTheme.blueCheck,
        );
    }
  }
}

void main() {
  group('Delivery Status & Read Receipt (Blue Check) Tests', () {
    const senderUid = 'user_sender';
    const receiverUid = 'user_receiver';

    testWidgets('1. Menampilkan ikon jam saat pesan status sending', (tester) async {
      final msg = Message(
        id: 'm1',
        chatId: 'c1',
        senderId: senderUid,
        senderName: 'Sender',
        text: 'Halo tes',
        createdAt: DateTime.now(),
        status: DeliveryStatus.sending,
        readBy: const [senderUid],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatusTestWidget(
              message: msg,
              currentUserId: senderUid,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('icon_sending')), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('icon_sending')));
      expect(icon.color, equals(WhatsAppTheme.greyCheck));
    });

    testWidgets('2. Menampilkan centang 1 abu-abu saat pesan berhasil terkirim ke server (sent)', (tester) async {
      final msg = Message(
        id: 'm2',
        chatId: 'c1',
        senderId: senderUid,
        senderName: 'Sender',
        text: 'Pesan terkirim',
        createdAt: DateTime.now(),
        status: DeliveryStatus.sent,
        readBy: const [senderUid],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatusTestWidget(
              message: msg,
              currentUserId: senderUid,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('icon_sent_single')), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('icon_sent_single')));
      expect(icon.icon, equals(Icons.done_rounded));
      expect(icon.color, equals(WhatsAppTheme.greyCheck));
    });

    testWidgets('3. Menampilkan centang 2 abu-abu saat pesan sampai di perangkat penerima (delivered)', (tester) async {
      final msg = Message(
        id: 'm3',
        chatId: 'c1',
        senderId: senderUid,
        senderName: 'Sender',
        text: 'Pesan masuk notifikasi',
        createdAt: DateTime.now(),
        status: DeliveryStatus.delivered,
        readBy: const [senderUid],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatusTestWidget(
              message: msg,
              currentUserId: senderUid,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('icon_delivered_double_grey')), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('icon_delivered_double_grey')));
      expect(icon.icon, equals(Icons.done_all_rounded));
      expect(icon.color, equals(WhatsAppTheme.greyCheck));
    });

    testWidgets('4. Menampilkan centang 2 biru saat pesan dibaca lawan bicara (readBy receiver)', (tester) async {
      // Lawan bicara membuka chat: receiverUid ditambahkan ke readBy
      final msg = Message(
        id: 'm4',
        chatId: 'c1',
        senderId: senderUid,
        senderName: 'Sender',
        text: 'Pesan sudah dibaca',
        createdAt: DateTime.now(),
        status: DeliveryStatus.delivered,
        readBy: const [senderUid, receiverUid], // Dibaca oleh penerima
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatusTestWidget(
              message: msg,
              currentUserId: senderUid,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('icon_read_blue')), findsOneWidget);
      final icon = tester.widget<Icon>(find.byKey(const Key('icon_read_blue')));
      expect(icon.icon, equals(Icons.done_all_rounded));
      expect(icon.color, equals(WhatsAppTheme.blueCheck)); // Warna centang biru WhatsApp (#53BDEB)
    });
  });
}
