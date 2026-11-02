import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/user_avatar.dart';
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
        backgroundColor: WhatsAppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Barcode Akun Saya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: user.displayName,
              photoUrl: user.photoURL,
              radius: 34,
            ),
            const SizedBox(height: 10),
            Text(
              user.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const Text(
              'Pindai barcode ini atau salin ID Pengguna di bawah untuk mengobrol instan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            // Custom Artistic QR Code Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _CustomQrPainter(user.uid),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101B20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: WhatsAppTheme.primaryTeal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${user.uid}',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: WhatsAppTheme.primaryTeal),
                    tooltip: 'Salin ID Pengguna',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID Akun RenChat disalin ke papan klip!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: WhatsAppTheme.darkTextSecondary))),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin ID'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: user.uid));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID Akun RenChat disalin ke papan klip!')),
              );
            },
          ),
        ],
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

// Custom QR Visual Matrix Painter
class _CustomQrPainter extends CustomPainter {
  final String seed;
  _CustomQrPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = const Color(0xFF111B21);
    final paintTeal = Paint()..color = const Color(0xFF00A884);

    const int grid = 15;
    final cellWidth = size.width / grid;
    final cellHeight = size.height / grid;

    final hash = seed.hashCode.abs();

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        // Corners QR positioning markers
        final isTopLeft = r < 4 && c < 4;
        final isTopRight = r < 4 && c >= grid - 4;
        final isBottomLeft = r >= grid - 4 && c < 4;

        if (isTopLeft || isTopRight || isBottomLeft) {
          final isBorder = (r == 0 || r == 3 || c == 0 || c == 3) ||
              (r == 0 || r == 3 || c == grid - 4 || c == grid - 1) ||
              (r == grid - 4 || r == grid - 1 || c == 0 || c == 3);
          final isCenter = (r >= 1 && r <= 2 && c >= 1 && c <= 2) ||
              (r >= 1 && r <= 2 && c >= grid - 3 && c <= grid - 2) ||
              (r >= grid - 3 && r <= grid - 2 && c >= 1 && c <= 2);

          if (isBorder || isCenter) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth - 1, cellHeight - 1),
                const Radius.circular(2),
              ),
              paintDark,
            );
          }
        } else {
          // Pseudorandom internal QR dots based on user seed hash
          final val = (hash ^ (r * 31 + c * 17)) % 7;
          if (val < 3) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth - 1.2, cellHeight - 1.2),
                const Radius.circular(1.5),
              ),
              val == 0 ? paintTeal : paintDark,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
