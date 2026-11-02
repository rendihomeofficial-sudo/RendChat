import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/lock_chat_passcode_manager.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class LockedChatsScreen extends StatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> {
  bool _isUnlocked = false;
  final _pinController = TextEditingController();
  String _errorMessage = '';

  void _verifyPin() {
    final pin = _pinController.text.trim();
    final validPin = LockChatPasscodeManager().currentPasscode;
    if (pin == validPin) {
      setState(() {
        _isUnlocked = true;
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please enter your secret 4-digit PIN ($validPin)';
      });
    }
  }

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
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, size: 20, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Locked Chats'),
          ],
        ),
      ),
      body: !_isUnlocked
          ? _buildPasscodeLockView(context)
          : StreamBuilder<List<Chat>>(
              stream: chatService.streamUserChats(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allChats = snapshot.data ?? [];
                final lockedChats = allChats.where((c) => c.isLockedBy(currentUserId)).toList();

                if (lockedChats.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: const BoxDecoration(
                              color: WhatsAppTheme.darkSurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 60, color: WhatsAppTheme.primaryTeal),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No locked chats yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Chats added to Locked Chats will stay hidden behind your device passcode or fingerprint.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: lockedChats.length,
                  separatorBuilder: (_, __) => const Divider(indent: 74, height: 1),
                  itemBuilder: (context, index) {
                    final chat = lockedChats[index];
                    final title = chat.getDisplayTitle(currentUserId);
                    final avatar = chat.getDisplayAvatar(currentUserId);

                    final clearedTime = chat.getClearedAt(currentUserId);
                    final isClearedForMe = clearedTime != null &&
                        chat.lastMessageAt != null &&
                        !chat.lastMessageAt!.isAfter(clearedTime);

                    return ListTile(
                      leading: UserAvatar(
                        name: title,
                        photoUrl: avatar,
                        radius: 24,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.lock_rounded, size: 16, color: WhatsAppTheme.primaryTeal),
                        ],
                      ),
                      subtitle: Text(
                        isClearedForMe
                            ? 'Obrolan telah dibersihkan'
                            : (chat.lastMessage ?? 'No messages'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontStyle: isClearedForMe ? FontStyle.italic : FontStyle.normal,
                          color: isClearedForMe
                              ? WhatsAppTheme.darkTextSecondary.withValues(alpha: 0.6)
                              : WhatsAppTheme.darkTextSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_open_rounded, color: WhatsAppTheme.primaryTeal),
                        tooltip: 'Unlock chat',
                        onPressed: () async {
                          await chatService.toggleLockChat(
                            chatId: chat.id,
                            userId: currentUserId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chat removed from Locked Chats')),
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

  Widget _buildPasscodeLockView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WhatsAppTheme.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2),
              ),
              child: const Icon(Icons.fingerprint_rounded, size: 72, color: WhatsAppTheme.primaryTeal),
            ),
            const SizedBox(height: 24),
            const Text(
              'RenChat Locked Chats',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your PIN or Passcode to view secret conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _pinController,
                obscureText: true,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: const TextStyle(letterSpacing: 8, color: WhatsAppTheme.darkTextSecondary),
                  filled: true,
                  fillColor: WhatsAppTheme.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: WhatsAppTheme.primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock'),
              onPressed: _verifyPin,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                final cur = LockChatPasscodeManager().currentPasscode;
                setState(() {
                  _pinController.text = cur;
                });
                _verifyPin();
              },
              child: Text(
                'Use Current PIN (${LockChatPasscodeManager().currentPasscode})',
                style: const TextStyle(color: WhatsAppTheme.darkTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
