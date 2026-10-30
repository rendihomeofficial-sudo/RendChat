import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUid = auth.currentUid;

    if (currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred Messages'),
      ),
      body: StreamBuilder<List<Message>>(
        stream: chatService.streamStarredMessages(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_outline_rounded,
                      size: 80,
                      color: WhatsAppTheme.darkTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No starred messages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap and hold on any message to star it, so you can easily find it later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final timeStr = DateFormat('dd/MM/yyyy h:mm a').format(msg.createdAt);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: WhatsAppTheme.darkSurface,
                  child: Text(
                    msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: WhatsAppTheme.primaryTeal),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      msg.senderName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    msg.text,
                    style: const TextStyle(fontSize: 14, color: WhatsAppTheme.darkTextPrimary),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.star_rounded, color: Colors.amber),
                  tooltip: 'Unstar',
                  onPressed: () {
                    chatService.toggleStarMessage(
                      chatId: msg.chatId,
                      messageId: msg.id,
                      userId: currentUid,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
