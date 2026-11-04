import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/professional_qr_card.dart';
import 'camera_qr_scanner_screen.dart';
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

  Future<void> _onSearch() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _filtered = _allContacts);
      return;
    }

    final lower = q.toLowerCase();
    final localMatches = _allContacts
        .where((u) =>
            u.displayName.toLowerCase().contains(lower) ||
            u.email.toLowerCase().contains(lower))
        .toList();

    setState(() => _filtered = localMatches);

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final myUid = auth.currentUid;
    if (myUid == null) return;

    try {
      final remoteMatches = await chatService.searchUsers(q, myUid);
      if (mounted && _searchController.text.trim() == q) {
        final combinedMap = <String, AppUser>{};
        for (final u in localMatches) {
          combinedMap[u.uid] = u;
        }
        for (final u in remoteMatches) {
          combinedMap[u.uid] = u;
        }
        setState(() => _filtered = combinedMap.values.toList());
      }
    } catch (_) {}
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

  void _showMyQrCodeDialog() {
    final auth = context.read<AuthService>();
    final user = auth.appUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfessionalQrCard(
              uid: user.uid,
              displayName: user.displayName,
              photoUrl: user.photoURL,
              subtitle: 'Arahkan kamera pemindai ke barcode ini untuk mengobrol instan.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: WhatsAppTheme.darkSurface,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white12),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Tutup'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanBarcodeDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraQrScannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Kontak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Kode QR Saya',
            onPressed: _showMyQrCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Pindai Kode Teman',
            onPressed: _showScanBarcodeDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Aksi Cepat Barcode & Undang Teman
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: WhatsAppTheme.darkSurface,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WhatsAppTheme.primaryTeal,
                      side: const BorderSide(color: WhatsAppTheme.primaryTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Kode QR Saya'),
                    onPressed: _showMyQrCodeDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: WhatsAppTheme.primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Pindai Barcode'),
                    onPressed: _showScanBarcodeDialog,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari teman dari nama atau email...',
                prefixIcon: const Icon(Icons.search, color: WhatsAppTheme.primaryTeal),
                filled: true,
                fillColor: WhatsAppTheme.darkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Pengguna RenChat (${_filtered.length} terdaftar)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: WhatsAppTheme.primaryTeal),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada pengguna ditemukan',
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
                              user.statusMessage.isNotEmpty ? user.statusMessage : user.email,
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
                                : const Icon(Icons.chat_bubble_outline_rounded, color: WhatsAppTheme.primaryTeal),
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
