import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUserId = auth.currentUid;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: WhatsAppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Archived'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'settings') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: WhatsAppTheme.darkSurface,
                    title: const Text('Archive settings'),
                    content: const Text(
                      'Keep chats archived\n\nArchived chats will remain archived when you receive a new message.',
                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done', style: TextStyle(color: WhatsAppTheme.primaryTeal)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text('Archive settings'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Chat>>(
        stream: chatService.streamUserChats(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allChats = snapshot.data ?? [];
          final archivedChats = allChats.where((c) => c.isArchivedBy(currentUserId)).toList();

          if (archivedChats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: WhatsAppTheme.darkSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.archive_outlined, size: 56, color: WhatsAppTheme.primaryTeal),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'These chats stay archived when new messages are received. Tap to change',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: archivedChats.length,
            separatorBuilder: (_, __) => const Divider(indent: 74, height: 1),
            itemBuilder: (context, index) {
              final chat = archivedChats[index];
              final title = chat.getDisplayTitle(currentUserId);
              final avatar = chat.getDisplayAvatar(currentUserId);

              return ListTile(
                leading: UserAvatar(
                  name: title,
                  photoUrl: avatar,
                  radius: 24,
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  chat.lastMessage ?? 'No messages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.unarchive_outlined, color: WhatsAppTheme.primaryTeal),
                  tooltip: 'Unarchive chat',
                  onPressed: () async {
                    await chatService.toggleArchiveChat(
                      chatId: chat.id,
                      userId: currentUserId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat unarchived')),
                      );
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
