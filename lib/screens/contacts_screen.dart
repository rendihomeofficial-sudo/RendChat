import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  List<AppUser> _allContacts = [];
  List<AppUser> _filtered = [];
  bool _isLoading = true;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final myUid = auth.currentUid;
    if (myUid == null) return;

    final list = await chatService.getAllContacts(myUid);
    if (mounted) {
      setState(() {
        _allContacts = list;
        _filtered = list;
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _allContacts);
    } else {
      setState(() {
        _filtered = _allContacts
            .where((u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q))
            .toList();
      });
    }
  }

  Future<void> _startChatWith(AppUser otherUser) async {
    if (_busyUid != null) return;
    setState(() => _busyUid = otherUser.uid);

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUser = auth.appUser;
    if (currentUser == null) {
      if (mounted) setState(() => _busyUid = null);
      return;
    }

    try {
      final chat = await chatService.getOrCreate1on1Chat(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyUid = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contact'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final user = _filtered[index];
                          final isBusy = _busyUid == user.uid;

                          return ListTile(
                            leading: UserAvatar(
                              name: user.displayName,
                              photoUrl: user.photoURL,
                              showOnlineBadge: true,
                              isOnline: user.online,
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              user.statusMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            trailing: isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                            onTap: isBusy ? null : () => _startChatWith(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
