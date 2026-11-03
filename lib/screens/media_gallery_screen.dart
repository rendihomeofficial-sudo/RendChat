import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';

class MediaGalleryScreen extends StatelessWidget {
  final String chatId;
  final String title;

  const MediaGalleryScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final chatService = context.read<ChatService>();
    final myUid = context.read<AuthService>().currentUid;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: WhatsAppTheme.darkChatBg,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: WhatsAppTheme.primaryTeal,
            labelColor: WhatsAppTheme.primaryTeal,
            unselectedLabelColor: WhatsAppTheme.darkTextSecondary,
            tabs: [
              Tab(text: 'Media'),
              Tab(text: 'Docs'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: StreamBuilder<Chat?>(
          stream: chatService.streamChat(chatId),
          builder: (context, chatSnap) {
            final clearedTime = (myUid != null) ? chatSnap.data?.getClearedAt(myUid) : null;

            return StreamBuilder<List<Message>>(
              stream: chatService.streamMessages(chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data ?? [];
                if (clearedTime != null) {
                  messages = messages.where((m) => m.createdAt.isAfter(clearedTime)).toList();
                }

                final mediaMsgs = messages.where((m) => m.type == MessageType.image && m.mediaUrl != null).toList();
                final docMsgs = messages.where((m) => m.type == MessageType.file && m.mediaUrl != null).toList();
                final linkMsgs = messages.where((m) => m.text.contains('http://') || m.text.contains('https://')).toList();

                return TabBarView(
                  children: [
                    // 1. Media Grid
                    mediaMsgs.isEmpty
                        ? const Center(child: Text('No media shared yet', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(4),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: mediaMsgs.length,
                            itemBuilder: (context, idx) {
                              final msg = mediaMsgs[idx];
                              return Image.network(
                                msg.mediaUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF233138),
                                  child: const Icon(Icons.broken_image, color: Colors.white30),
                                ),
                              );
                            },
                          ),

                    // 2. Documents List
                    docMsgs.isEmpty
                        ? const Center(child: Text('No documents shared yet', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)))
                        : ListView.separated(
                            itemCount: docMsgs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (context, idx) {
                              final msg = docMsgs[idx];
                              final ext = (msg.fileName != null && msg.fileName!.contains('.'))
                                  ? msg.fileName!.split('.').last.toLowerCase()
                                  : '';
                              final isPdf = ext == 'pdf';
                              final docColor = isPdf ? const Color(0xFFE53935) : WhatsAppTheme.primaryTeal;

                              return ListTile(
                                onTap: () async {
                                  final url = msg.mediaUrl;
                                  if (url != null && url.isNotEmpty) {
                                    final uri = Uri.tryParse(url);
                                    if (uri != null && await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: docColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                                    color: docColor,
                                  ),
                                ),
                                title: Text(msg.fileName ?? 'Document', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    Text('${((msg.fileSize ?? 0) / 1024).toStringAsFixed(1)} KB'),
                                    if (ext.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${ext.toUpperCase()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: docColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(Icons.download_rounded, size: 20, color: WhatsAppTheme.darkTextSecondary),
                              );
                            },
                          ),

                    // 3. Links List
                    linkMsgs.isEmpty
                        ? const Center(child: Text('No links shared yet', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)))
                        : ListView.separated(
                            itemCount: linkMsgs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (context, idx) {
                              final msg = linkMsgs[idx];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF2A3942),
                                  child: Icon(Icons.link_rounded, color: WhatsAppTheme.primaryTeal),
                                ),
                                title: Text(msg.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text(msg.senderName, style: const TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                              );
                            },
                          ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
