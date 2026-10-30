import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'call_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final Chat chat;
  final String title;
  final String? avatarUrl;
  final String currentUserId;

  const ContactInfoScreen({
    super.key,
    required this.chat,
    required this.title,
    this.avatarUrl,
    required this.currentUserId,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  late bool _isLocked;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.chat.isLockedBy(widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.read<ChatService>();
    final title = widget.title;
    final avatarUrl = widget.avatarUrl;
    final chat = widget.chat;
    final currentUserId = widget.currentUserId;

    return Scaffold(
      backgroundColor: WhatsAppTheme.darkChatBg,
      body: CustomScrollView(
        slivers: [
          // WhatsApp Sliver App Bar with Avatar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: WhatsAppTheme.darkSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: Container(
                color: const Color(0xFF1F2C34),
                child: Center(
                  child: UserAvatar(
                    name: title,
                    photoUrl: avatarUrl,
                    radius: 60,
                  ),
                ),
              ),
            ),
          ),

          // Content List
          SliverList(
            delegate: SliverChildListDelegate([
              // Actions row (Audio, Video, Search)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: WhatsAppTheme.darkSurface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionBtn(
                      icon: Icons.call_outlined,
                      label: 'Audio',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              callerName: title,
                              callerAvatar: avatarUrl,
                              isVideo: false,
                            ),
                          ),
                        );
                      },
                    ),
                    _actionBtn(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              callerName: title,
                              callerAvatar: avatarUrl,
                              isVideo: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _actionBtn(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      onTap: () => Navigator.pop(context, 'search'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Media, links, and docs
              Container(
                color: WhatsAppTheme.darkSurface,
                child: ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: WhatsAppTheme.darkTextSecondary),
                  title: const Text('Media, links, and docs'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<List<Message>>(
                        stream: chatService.streamMessages(chat.id),
                        builder: (context, snap) {
                          final count = snap.data?.where((m) => m.mediaUrl != null).length ?? 0;
                          return Text('$count', style: const TextStyle(color: WhatsAppTheme.darkTextSecondary));
                        },
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, 'media'),
                ),
              ),

              const SizedBox(height: 10),

              // Settings List (Mute, Disappearing, Encryption)
              Container(
                color: WhatsAppTheme.darkSurface,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined, color: WhatsAppTheme.darkTextSecondary),
                      title: const Text('Mute notifications'),
                      trailing: Switch(
                        value: false,
                        activeColor: WhatsAppTheme.primaryTeal,
                        activeTrackColor: WhatsAppTheme.primaryTeal.withOpacity(0.5),
                        onChanged: (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(val ? 'Notifications muted' : 'Notifications unmuted')),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: WhatsAppTheme.darkTextSecondary),
                      title: const Text('Disappearing messages'),
                      subtitle: const Text('Off', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                      onTap: () => Navigator.pop(context, 'disappearing'),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.lock_rounded, color: WhatsAppTheme.primaryTeal),
                      title: const Text('Chat lock'),
                      subtitle: Text(
                        _isLocked
                            ? 'Locked with device passcode'
                            : 'Lock and hide this chat on this device',
                        style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                      ),
                      trailing: Switch(
                        value: _isLocked,
                        activeColor: WhatsAppTheme.primaryTeal,
                        onChanged: (val) async {
                          setState(() {
                            _isLocked = val;
                          });
                          await chatService.toggleLockChat(
                            chatId: chat.id,
                            userId: currentUserId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(val ? 'Chat locked and hidden' : 'Chat unlocked')),
                            );
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    const ListTile(
                      leading: Icon(Icons.lock_outline_rounded, color: WhatsAppTheme.darkTextSecondary),
                      title: Text('Encryption'),
                      subtitle: Text(
                        'Messages and calls are end-to-end encrypted. Tap to verify.',
                        style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Danger actions (Clear chat, Block, Report)
              Container(
                color: WhatsAppTheme.darkSurface,
                child: Column(
                  children: [
                    if (!chat.isGroup) ...[
                      Builder(builder: (context) {
                        final otherUid = chat.getOtherUserId(currentUserId);
                        if (otherUid == null) return const SizedBox.shrink();
                        return StreamBuilder<bool>(
                          stream: chatService.streamIsUserBlocked(
                            currentUserId: currentUserId,
                            targetUserId: otherUid,
                          ),
                          builder: (context, snap) {
                            final isBlocked = snap.data ?? false;
                            if (isBlocked) {
                              return ListTile(
                                leading: const Icon(Icons.check_circle_outline_rounded, color: WhatsAppTheme.primaryTeal),
                                title: Text('Unblock $title', style: const TextStyle(color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Contact is currently blocked', style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 12)),
                                onTap: () => _showUnblockDialog(context, chatService, otherUid, title),
                              );
                            }
                            return ListTile(
                              leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                              title: Text('Block $title', style: const TextStyle(color: Colors.redAccent)),
                              onTap: () => _showBlockDialog(context, chatService, otherUid, title),
                            );
                          },
                        );
                      }),
                      const Divider(height: 1, indent: 56),
                    ],
                    ListTile(
                      leading: const Icon(Icons.thumb_down_alt_outlined, color: Colors.redAccent),
                      title: Text(chat.isGroup ? 'Report group' : 'Report $title', style: const TextStyle(color: Colors.redAccent)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${chat.isGroup ? 'Group' : 'Contact'} reported to RenChat')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ]),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, ChatService chatService, String otherUid, String contactName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: Text('Block $contactName?'),
        content: Text(
          'Blocked contacts will no longer be able to call you or send you messages.',
          style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await chatService.blockUser(
                currentUserId: widget.currentUserId,
                targetUserId: otherUid,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$contactName blocked')),
                );
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, ChatService chatService, String otherUid, String contactName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: Text('Unblock $contactName?'),
        content: Text(
          'Unblock this contact to start sending messages and receiving calls again.',
          style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () async {
              Navigator.pop(ctx);
              await chatService.unblockUser(
                currentUserId: widget.currentUserId,
                targetUserId: otherUid,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$contactName unblocked')),
                );
              }
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: WhatsAppTheme.primaryTeal, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: WhatsAppTheme.primaryTeal,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
