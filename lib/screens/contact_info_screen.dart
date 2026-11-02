import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_feedback_widgets.dart';
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
  late bool _isMuted;
  late int? _disappearingDuration;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.chat.isLockedBy(widget.currentUserId);
    _isMuted = widget.chat.isMutedFor(widget.currentUserId);
    _disappearingDuration = widget.chat.disappearingDuration;
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
                        value: _isMuted,
                        activeThumbColor: WhatsAppTheme.primaryTeal,
                        activeTrackColor: WhatsAppTheme.primaryTeal.withValues(alpha: 0.5),
                        onChanged: (val) async {
                          if (val) {
                            int selectedHours = 8;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => StatefulBuilder(
                                builder: (ctx, setDialogState) => AlertDialog(
                                  backgroundColor: WhatsAppTheme.darkSurface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text('Mute Notifications'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RadioListTile<int>(
                                        title: const Text('8 Hours'),
                                        value: 8,
                                        groupValue: selectedHours,
                                        activeColor: WhatsAppTheme.primaryTeal,
                                        onChanged: (v) => setDialogState(() => selectedHours = v!),
                                      ),
                                      RadioListTile<int>(
                                        title: const Text('1 Week'),
                                        value: 168,
                                        groupValue: selectedHours,
                                        activeColor: WhatsAppTheme.primaryTeal,
                                        onChanged: (v) => setDialogState(() => selectedHours = v!),
                                      ),
                                      RadioListTile<int>(
                                        title: const Text('Always'),
                                        value: 876000,
                                        groupValue: selectedHours,
                                        activeColor: WhatsAppTheme.primaryTeal,
                                        onChanged: (v) => setDialogState(() => selectedHours = v!),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('Cancel', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (confirmed == true && mounted) {
                              setState(() => _isMuted = true);
                              await chatService.muteChat(
                                chatId: chat.id,
                                userId: currentUserId,
                                duration: Duration(hours: selectedHours),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notifications muted')),
                                );
                              }
                            }
                          } else {
                            setState(() => _isMuted = false);
                            await chatService.unmuteChat(
                              chatId: chat.id,
                              userId: currentUserId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notifications unmuted')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: WhatsAppTheme.darkTextSecondary),
                      title: const Text('Disappearing messages'),
                      subtitle: Text(
                        _disappearingDuration == 86400
                            ? '24 hours'
                            : (_disappearingDuration == 604800
                                ? '7 days'
                                : (_disappearingDuration == 7776000 ? '90 days' : 'Off')),
                        style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: WhatsAppTheme.darkTextSecondary),
                      onTap: () async {
                        int currentSec = _disappearingDuration ?? 0;
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: WhatsAppTheme.darkSurface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => StatefulBuilder(
                            builder: (ctx, setSheetState) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Disappearing Messages',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'For more privacy and storage, new messages will disappear from this chat for everyone after the selected duration.',
                                      style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 12),
                                    RadioListTile<int>(
                                      title: const Text('24 Hours'),
                                      value: 86400,
                                      groupValue: currentSec,
                                      activeColor: WhatsAppTheme.primaryTeal,
                                      onChanged: (val) async {
                                        setSheetState(() => currentSec = val!);
                                        Navigator.pop(bCtx);
                                        setState(() => _disappearingDuration = 86400);
                                        await chatService.setDisappearingMessages(
                                          chatId: chat.id,
                                          durationInSeconds: 86400,
                                        );
                                      },
                                    ),
                                    RadioListTile<int>(
                                      title: const Text('7 Days'),
                                      value: 604800,
                                      groupValue: currentSec,
                                      activeColor: WhatsAppTheme.primaryTeal,
                                      onChanged: (val) async {
                                        setSheetState(() => currentSec = val!);
                                        Navigator.pop(bCtx);
                                        setState(() => _disappearingDuration = 604800);
                                        await chatService.setDisappearingMessages(
                                          chatId: chat.id,
                                          durationInSeconds: 604800,
                                        );
                                      },
                                    ),
                                    RadioListTile<int>(
                                      title: const Text('90 Days'),
                                      value: 7776000,
                                      groupValue: currentSec,
                                      activeColor: WhatsAppTheme.primaryTeal,
                                      onChanged: (val) async {
                                        setSheetState(() => currentSec = val!);
                                        Navigator.pop(bCtx);
                                        setState(() => _disappearingDuration = 7776000);
                                        await chatService.setDisappearingMessages(
                                          chatId: chat.id,
                                          durationInSeconds: 7776000,
                                        );
                                      },
                                    ),
                                    RadioListTile<int>(
                                      title: const Text('Off'),
                                      value: 0,
                                      groupValue: currentSec,
                                      activeColor: WhatsAppTheme.primaryTeal,
                                      onChanged: (val) async {
                                        setSheetState(() => currentSec = 0);
                                        Navigator.pop(bCtx);
                                        setState(() => _disappearingDuration = null);
                                        await chatService.setDisappearingMessages(
                                          chatId: chat.id,
                                          durationInSeconds: 0,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
                        activeThumbColor: WhatsAppTheme.primaryTeal,
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

  Future<void> _showBlockDialog(BuildContext context, ChatService chatService, String otherUid, String contactName) async {
    final confirmed = await showPremiumActionConfirmDialog(
      context,
      title: 'Blokir $contactName?',
      message: 'Kontak yang diblokir tidak akan dapat mengirim pesan atau melakukan panggilan ke akun Anda.',
      confirmLabel: 'Blokir',
      icon: Icons.block_rounded,
      accentColor: const Color(0xFFEF4444),
      isDestructive: true,
    );

    if (confirmed == true) {
      await chatService.blockUser(
        currentUserId: widget.currentUserId,
        targetUserId: otherUid,
      );
      if (context.mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Kontak Diblokir',
          message: '$contactName telah berhasil diblokir dari kontak Anda.',
          icon: Icons.block_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Future<void> _showUnblockDialog(BuildContext context, ChatService chatService, String otherUid, String contactName) async {
    final confirmed = await showPremiumActionConfirmDialog(
      context,
      title: 'Buka Blokir $contactName?',
      message: 'Buka blokir kontak ini untuk mulai berkirim pesan dan melakukan panggilan suara/video kembali.',
      confirmLabel: 'Buka Blokir',
      icon: Icons.lock_open_rounded,
      accentColor: WhatsAppTheme.primaryTeal,
      isDestructive: false,
    );

    if (confirmed == true) {
      await chatService.unblockUser(
        currentUserId: widget.currentUserId,
        targetUserId: otherUid,
      );
      if (context.mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Blokir Dibuka',
          message: 'Anda sekarang dapat mengirim pesan dan memanggil $contactName.',
          icon: Icons.check_circle_rounded,
          accentColor: WhatsAppTheme.primaryTeal,
        );
      }
    }
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
